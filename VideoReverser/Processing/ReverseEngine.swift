import AVFoundation
import CoreVideo

/// Produces a video-only file containing `timeRange` of the source asset with
/// its frames in reverse order.
///
/// Sample buffers can't simply be re-timed backwards in a single pass without
/// holding the whole clip in memory, so the range is split into short time
/// chunks processed back-to-front: each chunk is decoded, its frames appended
/// in reverse with monotonically increasing timestamps, then released.
enum ReverseEngine {
    enum EngineError: Error {
        case noVideoTrack
        case readFailed
        case writeFailed
    }

    /// Seconds of decoded frames held in memory at once.
    private static let chunkSeconds = 0.5

    static func reverseVideo(
        asset: AVAsset,
        timeRange: CMTimeRange,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard let videoTrack = try await asset.loadTracks(withMediaType: .video).first else {
            throw EngineError.noVideoTrack
        }
        let naturalSize = try await videoTrack.load(.naturalSize)
        let transform = try await videoTrack.load(.preferredTransform)

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reversed-\(UUID().uuidString).mp4")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .mp4)
        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: [
            AVVideoCodecKey: AVVideoCodecType.h264,
            AVVideoWidthKey: Int(naturalSize.width),
            AVVideoHeightKey: Int(naturalSize.height),
        ])
        writerInput.expectsMediaDataInRealTime = false
        writerInput.transform = transform
        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: nil
        )
        writer.add(writerInput)
        guard writer.startWriting() else {
            throw writer.error ?? EngineError.writeFailed
        }
        writer.startSession(atSourceTime: .zero)

        let chunks = chunkRanges(for: timeRange)
        var outputTime = CMTime.zero

        // Chunks run back-to-front so the last frames of the source come first.
        for (index, chunk) in chunks.enumerated() {
            try Task.checkCancellation()

            let samples = try readSamples(asset: asset, track: videoTrack, range: chunk)

            for sampleIndex in stride(from: samples.count - 1, through: 0, by: -1) {
                let sample = samples[sampleIndex]
                guard let pixelBuffer = CMSampleBufferGetImageBuffer(sample) else { continue }

                while !writerInput.isReadyForMoreMediaData {
                    try await Task.sleep(nanoseconds: 5_000_000)
                }
                guard adaptor.append(pixelBuffer, withPresentationTime: outputTime) else {
                    writer.cancelWriting()
                    throw writer.error ?? EngineError.writeFailed
                }
                outputTime = outputTime + frameDuration(at: sampleIndex, in: samples, chunk: chunk)
            }

            progress(Double(index + 1) / Double(chunks.count))
        }

        writerInput.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? EngineError.writeFailed
        }
        return outputURL
    }

    /// The chunk ranges covering `timeRange`, ordered last-to-first.
    private static func chunkRanges(for timeRange: CMTimeRange) -> [CMTimeRange] {
        let chunkDuration = CMTime(seconds: chunkSeconds, preferredTimescale: 600)
        var ranges: [CMTimeRange] = []
        var end = timeRange.end
        while end > timeRange.start {
            let start = max(end - chunkDuration, timeRange.start)
            ranges.append(CMTimeRange(start: start, end: end))
            end = start
        }
        return ranges
    }

    /// Decodes every video sample within `range`, in presentation order.
    private static func readSamples(
        asset: AVAsset,
        track: AVAssetTrack,
        range: CMTimeRange
    ) throws -> [CMSampleBuffer] {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = range
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            kCVPixelBufferPixelFormatTypeKey as String:
                kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        ])
        output.alwaysCopiesSampleData = false
        guard reader.canAdd(output) else { throw EngineError.readFailed }
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? EngineError.readFailed
        }

        var samples: [CMSampleBuffer] = []
        while let sample = output.copyNextSampleBuffer() {
            if CMSampleBufferGetImageBuffer(sample) != nil {
                samples.append(sample)
            }
        }
        guard reader.status == .completed else {
            throw reader.error ?? EngineError.readFailed
        }
        // Decode order can differ from presentation order (B-frames).
        return samples.sorted {
            CMSampleBufferGetPresentationTimeStamp($0) < CMSampleBufferGetPresentationTimeStamp($1)
        }
    }

    /// Display duration of the frame at `index`: the gap to the next frame's
    /// timestamp, or to the chunk end for the last frame.
    private static func frameDuration(
        at index: Int,
        in samples: [CMSampleBuffer],
        chunk: CMTimeRange
    ) -> CMTime {
        let pts = CMSampleBufferGetPresentationTimeStamp(samples[index])
        let next = index + 1 < samples.count
            ? CMSampleBufferGetPresentationTimeStamp(samples[index + 1])
            : chunk.end
        let duration = next - pts
        // Guard against zero/negative gaps from odd streams.
        if duration <= .zero {
            return CMTime(value: 1, timescale: 30)
        }
        return duration
    }
}
