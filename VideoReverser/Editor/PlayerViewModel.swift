import AVFoundation
import UIKit
import SwiftUI

/// Wraps an `AVPlayer` for the editor: looping preview, current-time tracking,
/// and filmstrip thumbnails.
@MainActor
final class PlayerViewModel: ObservableObject {
    let player = AVPlayer()

    @Published private(set) var isPlaying = false
    @Published private(set) var currentTime: Double = 0
    @Published private(set) var duration: Double = 0
    @Published private(set) var thumbnails: [UIImage] = []
    @Published private(set) var isReady = false

    /// Preview playback rate (mirrors the speed dial).
    var previewRate: Float = 1 {
        didSet {
            if isPlaying { player.rate = previewRate }
        }
    }

    private var timeObserver: Any?
    private var endObserver: NSObjectProtocol?

    func load(url: URL) async {
        let asset = AVURLAsset(url: url)
        duration = (try? await asset.load(.duration).seconds) ?? 0
        player.replaceCurrentItem(with: AVPlayerItem(asset: asset))
        player.actionAtItemEnd = .none

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(value: 1, timescale: 30),
            queue: .main
        ) { [weak self] time in
            Task { @MainActor [weak self] in
                self?.currentTime = time.seconds
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.loopBackToStart()
            }
        }

        isReady = true
        play()
        await generateThumbnails(for: asset)
    }

    func togglePlayback() {
        isPlaying ? pause() : play()
    }

    func play() {
        player.playImmediately(atRate: previewRate)
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
    }

    func seek(to seconds: Double) {
        let clamped = min(max(seconds, 0), duration)
        currentTime = clamped
        player.seek(
            to: CMTime(seconds: clamped, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
    }

    func step(by seconds: Double) {
        pause()
        seek(to: currentTime + seconds)
    }

    private func loopBackToStart() {
        player.seek(to: .zero, toleranceBefore: .zero, toleranceAfter: .zero)
        if isPlaying { player.rate = previewRate }
    }

    private func generateThumbnails(for asset: AVAsset) async {
        guard duration > 0 else { return }
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 160, height: 160)
        generator.requestedTimeToleranceBefore = .positiveInfinity
        generator.requestedTimeToleranceAfter = .positiveInfinity

        let count = 10
        let times = (0..<count).map { index in
            CMTime(seconds: duration * (Double(index) + 0.5) / Double(count), preferredTimescale: 600)
        }

        var images: [UIImage] = []
        for await result in generator.images(for: times) {
            if let cgImage = try? result.image {
                images.append(UIImage(cgImage: cgImage))
            }
        }
        thumbnails = images
    }

    func tearDown() {
        pause()
        if let timeObserver {
            player.removeTimeObserver(timeObserver)
            self.timeObserver = nil
        }
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
            self.endObserver = nil
        }
        player.replaceCurrentItem(with: nil)
    }
}

/// Bare `AVPlayerLayer` host — no system playback controls, unlike `VideoPlayer`.
struct PlayerLayerView: UIViewRepresentable {
    let player: AVPlayer

    final class LayerHostView: UIView {
        override static var layerClass: AnyClass { AVPlayerLayer.self }
        var playerLayer: AVPlayerLayer { layer as! AVPlayerLayer }
    }

    func makeUIView(context: Context) -> LayerHostView {
        let view = LayerHostView()
        view.playerLayer.player = player
        view.playerLayer.videoGravity = .resizeAspect
        return view
    }

    func updateUIView(_ uiView: LayerHostView, context: Context) {
        uiView.playerLayer.player = player
    }
}
