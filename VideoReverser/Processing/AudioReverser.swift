import AVFoundation
import CoreMedia

/// Produces an audio-only file (AAC in .m4a) containing `timeRange` of the
/// source asset's audio with its samples in reverse order.
///
/// Audio is small enough to hold decoded in memory (stereo 16-bit at 48 kHz is
/// ~11 MB per minute), so unlike video this is a single pass: decode to PCM,
/// reverse frame-wise, re-encode.
enum AudioReverser {
    enum ReverserError: Error {
        case readFailed
        case writeFailed
        case formatUnavailable
    }

    /// Returns nil when the asset has no audio track.
    static func reverseAudio(asset: AVAsset, timeRange: CMTimeRange) async throws -> URL? {
        guard let audioTrack = try await asset.loadTracks(withMediaType: .audio).first else {
            return nil
        }

        let (pcm, sampleRate, channels) = try decodePCM(asset: asset, track: audioTrack, range: timeRange)
        guard !pcm.isEmpty else { return nil }

        let reversed = reverseFrames(pcm, bytesPerFrame: 2 * channels)
        return try await encodeAAC(pcm: reversed, sampleRate: sampleRate, channels: channels)
    }

    // MARK: Decode

    private static func decodePCM(
        asset: AVAsset,
        track: AVAssetTrack,
        range: CMTimeRange
    ) throws -> (data: Data, sampleRate: Double, channels: Int) {
        let reader = try AVAssetReader(asset: asset)
        reader.timeRange = range
        let output = AVAssetReaderTrackOutput(track: track, outputSettings: [
            AVFormatIDKey: kAudioFormatLinearPCM,
            AVLinearPCMBitDepthKey: 16,
            AVLinearPCMIsFloatKey: false,
            AVLinearPCMIsBigEndianKey: false,
            AVLinearPCMIsNonInterleaved: false,
        ])
        guard reader.canAdd(output) else { throw ReverserError.readFailed }
        reader.add(output)
        guard reader.startReading() else {
            throw reader.error ?? ReverserError.readFailed
        }

        var data = Data()
        var sampleRate: Double = 0
        var channels = 0

        while let sample = output.copyNextSampleBuffer() {
            if sampleRate == 0,
               let description = CMSampleBufferGetFormatDescription(sample),
               let asbd = CMAudioFormatDescriptionGetStreamBasicDescription(description) {
                sampleRate = asbd.pointee.mSampleRate
                channels = Int(asbd.pointee.mChannelsPerFrame)
            }
            guard let blockBuffer = CMSampleBufferGetDataBuffer(sample) else { continue }
            let length = CMBlockBufferGetDataLength(blockBuffer)
            var chunk = Data(count: length)
            let status = chunk.withUnsafeMutableBytes { pointer in
                CMBlockBufferCopyDataBytes(
                    blockBuffer,
                    atOffset: 0,
                    dataLength: length,
                    destination: pointer.baseAddress!
                )
            }
            guard status == kCMBlockBufferNoErr else { throw ReverserError.readFailed }
            data.append(chunk)
        }
        guard reader.status == .completed else {
            throw reader.error ?? ReverserError.readFailed
        }
        guard sampleRate > 0, channels > 0 else {
            return (Data(), 0, 0)
        }
        return (data, sampleRate, channels)
    }

    // MARK: Reverse

    /// Reverses interleaved PCM frame-by-frame (keeping channel order intact
    /// within each frame).
    private static func reverseFrames(_ data: Data, bytesPerFrame: Int) -> Data {
        let frameCount = data.count / bytesPerFrame
        var output = Data(count: frameCount * bytesPerFrame)
        output.withUnsafeMutableBytes { (destination: UnsafeMutableRawBufferPointer) in
            data.withUnsafeBytes { (source: UnsafeRawBufferPointer) in
                let src = source.baseAddress!
                let dst = destination.baseAddress!
                for frame in 0..<frameCount {
                    dst.advanced(by: frame * bytesPerFrame).copyMemory(
                        from: src.advanced(by: (frameCount - 1 - frame) * bytesPerFrame),
                        byteCount: bytesPerFrame
                    )
                }
            }
        }
        return output
    }

    // MARK: Encode

    private static func encodeAAC(pcm: Data, sampleRate: Double, channels: Int) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("reversed-audio-\(UUID().uuidString).m4a")

        let writer = try AVAssetWriter(outputURL: outputURL, fileType: .m4a)
        let writerInput = AVAssetWriterInput(mediaType: .audio, outputSettings: [
            AVFormatIDKey: kAudioFormatMPEG4AAC,
            AVSampleRateKey: sampleRate,
            AVNumberOfChannelsKey: channels,
            AVEncoderBitRateKey: 128_000,
        ])
        writerInput.expectsMediaDataInRealTime = false
        writer.add(writerInput)
        guard writer.startWriting() else {
            throw writer.error ?? ReverserError.writeFailed
        }
        writer.startSession(atSourceTime: .zero)

        let formatDescription = try pcmFormatDescription(sampleRate: sampleRate, channels: channels)
        let bytesPerFrame = 2 * channels
        let framesPerChunk = 8192
        let totalFrames = pcm.count / bytesPerFrame
        var frameCursor = 0

        while frameCursor < totalFrames {
            try Task.checkCancellation()
            let frames = min(framesPerChunk, totalFrames - frameCursor)
            let byteRange = (frameCursor * bytesPerFrame)..<((frameCursor + frames) * bytesPerFrame)
            let sample = try makePCMSampleBuffer(
                bytes: pcm.subdata(in: byteRange),
                frames: frames,
                startFrame: frameCursor,
                sampleRate: sampleRate,
                formatDescription: formatDescription
            )

            while !writerInput.isReadyForMoreMediaData {
                try await Task.sleep(nanoseconds: 5_000_000)
            }
            guard writerInput.append(sample) else {
                writer.cancelWriting()
                throw writer.error ?? ReverserError.writeFailed
            }
            frameCursor += frames
        }

        writerInput.markAsFinished()
        await writer.finishWriting()
        guard writer.status == .completed else {
            throw writer.error ?? ReverserError.writeFailed
        }
        return outputURL
    }

    private static func pcmFormatDescription(
        sampleRate: Double,
        channels: Int
    ) throws -> CMAudioFormatDescription {
        var asbd = AudioStreamBasicDescription(
            mSampleRate: sampleRate,
            mFormatID: kAudioFormatLinearPCM,
            mFormatFlags: kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked,
            mBytesPerPacket: UInt32(2 * channels),
            mFramesPerPacket: 1,
            mBytesPerFrame: UInt32(2 * channels),
            mChannelsPerFrame: UInt32(channels),
            mBitsPerChannel: 16,
            mReserved: 0
        )
        var description: CMAudioFormatDescription?
        let status = CMAudioFormatDescriptionCreate(
            allocator: kCFAllocatorDefault,
            asbd: &asbd,
            layoutSize: 0,
            layout: nil,
            magicCookieSize: 0,
            magicCookie: nil,
            extensions: nil,
            formatDescriptionOut: &description
        )
        guard status == noErr, let description else {
            throw ReverserError.formatUnavailable
        }
        return description
    }

    private static func makePCMSampleBuffer(
        bytes: Data,
        frames: Int,
        startFrame: Int,
        sampleRate: Double,
        formatDescription: CMAudioFormatDescription
    ) throws -> CMSampleBuffer {
        var blockBuffer: CMBlockBuffer?
        var status = CMBlockBufferCreateWithMemoryBlock(
            allocator: kCFAllocatorDefault,
            memoryBlock: nil,
            blockLength: bytes.count,
            blockAllocator: nil,
            customBlockSource: nil,
            offsetToData: 0,
            dataLength: bytes.count,
            flags: 0,
            blockBufferOut: &blockBuffer
        )
        guard status == kCMBlockBufferNoErr, let blockBuffer else {
            throw ReverserError.writeFailed
        }
        status = bytes.withUnsafeBytes { pointer in
            CMBlockBufferReplaceDataBytes(
                with: pointer.baseAddress!,
                blockBuffer: blockBuffer,
                offsetIntoDestination: 0,
                dataLength: bytes.count
            )
        }
        guard status == kCMBlockBufferNoErr else { throw ReverserError.writeFailed }

        var sampleBuffer: CMSampleBuffer?
        status = CMAudioSampleBufferCreateReadyWithPacketDescriptions(
            allocator: kCFAllocatorDefault,
            dataBuffer: blockBuffer,
            formatDescription: formatDescription,
            sampleCount: frames,
            presentationTimeStamp: CMTime(
                value: CMTimeValue(startFrame),
                timescale: CMTimeScale(sampleRate)
            ),
            packetDescriptions: nil,
            sampleBufferOut: &sampleBuffer
        )
        guard status == noErr, let sampleBuffer else {
            throw ReverserError.writeFailed
        }
        return sampleBuffer
    }
}
