import AVFoundation

/// Runs the full pipeline: reverse the needed range, optionally reverse the
/// audio, assemble the final composition per the chosen mode, apply the speed
/// change, and export.
///
/// Progress is reported 0...1: reversing ≈ 0–0.55, audio ≈ 0.55–0.6,
/// export ≈ 0.6–1.
enum VideoProcessor {
    enum ProcessorError: Error {
        case noVideoTrack
        case compositionFailed
        case exportFailed
    }

    static func process(
        sourceURL: URL,
        configuration: EditorConfiguration,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        let asset = AVURLAsset(url: sourceURL)
        let duration = try await asset.load(.duration)
        guard let sourceVideo = try await asset.loadTracks(withMediaType: .video).first else {
            throw ProcessorError.noVideoTrack
        }
        let sourceTransform = try await sourceVideo.load(.preferredTransform)
        let sourceAudio = try await asset.loadTracks(withMediaType: .audio).first

        let window = effectRange(for: configuration, duration: duration)

        // 1. Reversed video clip for the effect range.
        let reversedVideoURL = try await ReverseEngine.reverseVideo(
            asset: asset,
            timeRange: window
        ) { fraction in
            progress(fraction * 0.55)
        }
        defer { try? FileManager.default.removeItem(at: reversedVideoURL) }

        // 2. Reversed audio, when requested.
        var reversedAudioURL: URL?
        if configuration.audio == .reverse {
            reversedAudioURL = try await AudioReverser.reverseAudio(asset: asset, timeRange: window)
        }
        defer {
            if let reversedAudioURL {
                try? FileManager.default.removeItem(at: reversedAudioURL)
            }
        }
        progress(0.6)

        // 3. Assemble the composition.
        let composition = try await buildComposition(
            asset: asset,
            sourceVideo: sourceVideo,
            sourceAudio: sourceAudio,
            sourceTransform: sourceTransform,
            duration: duration,
            effectRange: window,
            reversedVideoURL: reversedVideoURL,
            reversedAudioURL: reversedAudioURL,
            configuration: configuration
        )

        // 4. Export.
        return try await export(
            composition: composition,
            quality: configuration.quality
        ) { fraction in
            progress(0.6 + fraction * 0.4)
        }
    }

    // MARK: Segments

    private struct Segment {
        /// nil source range means "the reversed clip"; otherwise a forward
        /// pass over this range of the original.
        let forwardRange: CMTimeRange?
        /// Whether the speed change applies to this segment.
        let scaled: Bool
    }

    private static func effectRange(
        for configuration: EditorConfiguration,
        duration: CMTime
    ) -> CMTimeRange {
        guard configuration.mode.usesRangeSelection else {
            return CMTimeRange(start: .zero, duration: duration)
        }
        let start = CMTime(seconds: max(configuration.rangeStart, 0), preferredTimescale: 600)
        let minimumEnd = start + CMTime(value: 60, timescale: 600)
        let end = max(
            min(CMTime(seconds: configuration.rangeEnd, preferredTimescale: 600), duration),
            minimumEnd
        )
        return CMTimeRange(start: start, end: end)
    }

    private static func segments(
        for configuration: EditorConfiguration,
        duration: CMTime,
        effectRange: CMTimeRange
    ) -> [Segment] {
        switch configuration.mode {
        case .reverseAll:
            return [Segment(forwardRange: nil, scaled: true)]
        case .boomerang:
            return [
                Segment(forwardRange: CMTimeRange(start: .zero, duration: duration), scaled: true),
                Segment(forwardRange: nil, scaled: true),
            ]
        case .replayPart:
            // Play up to the end of the moment, rewind through it, then
            // continue from its start — like a sports replay.
            var result: [Segment] = []
            if effectRange.end > .zero {
                result.append(Segment(
                    forwardRange: CMTimeRange(start: .zero, end: effectRange.end),
                    scaled: false
                ))
            }
            result.append(Segment(forwardRange: nil, scaled: true))
            if effectRange.start < duration {
                result.append(Segment(
                    forwardRange: CMTimeRange(start: effectRange.start, end: duration),
                    scaled: false
                ))
            }
            return result
        }
    }

    // MARK: Composition

    private static func buildComposition(
        asset: AVAsset,
        sourceVideo: AVAssetTrack,
        sourceAudio: AVAssetTrack?,
        sourceTransform: CGAffineTransform,
        duration: CMTime,
        effectRange: CMTimeRange,
        reversedVideoURL: URL,
        reversedAudioURL: URL?,
        configuration: EditorConfiguration
    ) async throws -> AVMutableComposition {
        let reversedAsset = AVURLAsset(url: reversedVideoURL)
        guard let reversedVideo = try await reversedAsset.loadTracks(withMediaType: .video).first else {
            throw ProcessorError.compositionFailed
        }
        let reversedDuration = try await reversedAsset.load(.duration)

        var reversedAudio: AVAssetTrack?
        var reversedAudioDuration = CMTime.zero
        if let reversedAudioURL {
            let audioAsset = AVURLAsset(url: reversedAudioURL)
            reversedAudio = try await audioAsset.loadTracks(withMediaType: .audio).first
            reversedAudioDuration = try await audioAsset.load(.duration)
        }

        let composition = AVMutableComposition()
        guard let videoTrack = composition.addMutableTrack(
            withMediaType: .video,
            preferredTrackID: kCMPersistentTrackID_Invalid
        ) else {
            throw ProcessorError.compositionFailed
        }
        videoTrack.preferredTransform = sourceTransform

        let wantsAudio = configuration.audio != .mute && sourceAudio != nil
        let audioTrack = wantsAudio
            ? composition.addMutableTrack(withMediaType: .audio, preferredTrackID: kCMPersistentTrackID_Invalid)
            : nil

        var cursor = CMTime.zero
        var scaledWindows: [CMTimeRange] = []

        for segment in segments(for: configuration, duration: duration, effectRange: effectRange) {
            let insertedDuration: CMTime

            if let forwardRange = segment.forwardRange {
                try videoTrack.insertTimeRange(forwardRange, of: sourceVideo, at: cursor)
                if let audioTrack, let sourceAudio {
                    try? audioTrack.insertTimeRange(forwardRange, of: sourceAudio, at: cursor)
                }
                insertedDuration = forwardRange.duration
            } else {
                let reversedRange = CMTimeRange(start: .zero, duration: reversedDuration)
                try videoTrack.insertTimeRange(reversedRange, of: reversedVideo, at: cursor)
                if let audioTrack {
                    if let reversedAudio {
                        let audioRange = CMTimeRange(
                            start: .zero,
                            duration: min(reversedAudioDuration, reversedDuration)
                        )
                        try? audioTrack.insertTimeRange(audioRange, of: reversedAudio, at: cursor)
                    } else if configuration.audio == .keep, let sourceAudio {
                        // Forward audio over the reversed footage.
                        let audioRange = CMTimeRange(
                            start: effectRange.start,
                            duration: min(effectRange.duration, reversedDuration)
                        )
                        try? audioTrack.insertTimeRange(audioRange, of: sourceAudio, at: cursor)
                    }
                }
                insertedDuration = reversedDuration
            }

            if segment.scaled {
                scaledWindows.append(CMTimeRange(start: cursor, duration: insertedDuration))
            }
            cursor = cursor + insertedDuration
        }

        // Apply the speed change to the effect segments, back-to-front so the
        // earlier windows' positions stay valid as the timeline stretches.
        if configuration.speedPercent != 100 {
            for window in scaledWindows.reversed() {
                let newDuration = CMTimeMultiplyByFloat64(
                    window.duration,
                    multiplier: 1 / configuration.speedMultiplier
                )
                composition.scaleTimeRange(window, toDuration: newDuration)
            }
        }

        return composition
    }

    // MARK: Export

    private static func export(
        composition: AVMutableComposition,
        quality: ExportQuality,
        progress: @escaping @Sendable (Double) -> Void
    ) async throws -> URL {
        guard let session = AVAssetExportSession(
            asset: composition,
            presetName: quality.exportPreset
        ) else {
            throw ProcessorError.exportFailed
        }

        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("export-\(UUID().uuidString).mp4")
        session.outputURL = outputURL
        session.outputFileType = .mp4
        session.shouldOptimizeForNetworkUse = true
        session.audioTimePitchAlgorithm = .spectral

        let progressTask = Task {
            while !Task.isCancelled {
                progress(Double(session.progress))
                try await Task.sleep(nanoseconds: 200_000_000)
            }
        }
        defer { progressTask.cancel() }

        await withCheckedContinuation { continuation in
            session.exportAsynchronously {
                continuation.resume()
            }
        }

        guard session.status == .completed else {
            throw session.error ?? ProcessorError.exportFailed
        }
        progress(1)
        return outputURL
    }
}
