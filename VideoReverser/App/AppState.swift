import Foundation

enum AppStorageKey {
    static let hasOnboarded = "hasOnboarded"
    static let hasFinishedFirstVideo = "hasFinishedFirstVideo"
    static let hasRequestedReview = "hasRequestedReview"
}

/// What the editor does with the picked video.
enum EffectMode: String, CaseIterable, Identifiable, Codable {
    case reverseAll
    case replayPart
    case boomerang

    var id: String { rawValue }

    var title: String {
        switch self {
        case .reverseAll: String(localized: "Reverse", comment: "Effect mode: reverse the whole video")
        case .replayPart: String(localized: "Replay", comment: "Effect mode: reverse a selected part")
        case .boomerang: String(localized: "Boomerang", comment: "Effect mode: forward then backward")
        }
    }

    var symbolName: String {
        switch self {
        case .reverseAll: "backward.fill"
        case .replayPart: "arrow.uturn.backward.circle"
        case .boomerang: "arrow.left.arrow.right"
        }
    }

    /// Replay is the only mode where the user picks a sub-range of the video.
    var usesRangeSelection: Bool { self == .replayPart }
}

/// What happens to the original audio track in the exported video.
enum AudioOption: String, CaseIterable, Identifiable, Codable {
    case keep
    case mute
    case reverse

    var id: String { rawValue }

    var title: String {
        switch self {
        case .keep: String(localized: "Keep", comment: "Audio option: keep original audio")
        case .mute: String(localized: "Mute", comment: "Audio option: remove audio")
        case .reverse: String(localized: "Reverse", comment: "Audio option: reverse audio")
        }
    }

    var symbolName: String {
        switch self {
        case .keep: "speaker.wave.2.fill"
        case .mute: "speaker.slash.fill"
        case .reverse: "waveform"
        }
    }
}

/// Output resolution for the exported video.
enum ExportQuality: String, CaseIterable, Identifiable, Codable {
    case hd720
    case hd1080
    case original

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hd720: String(localized: "720p", comment: "Export quality option")
        case .hd1080: String(localized: "1080p", comment: "Export quality option")
        case .original: String(localized: "Original", comment: "Export quality option: keep source resolution")
        }
    }

}

/// Everything the user configured in the editor, handed to the processing engine.
struct EditorConfiguration {
    var mode: EffectMode = .replayPart
    /// Playback speed of the effect, in percent (100 = normal).
    var speedPercent: Int = 100
    /// Selected sub-range in seconds (used when `mode.usesRangeSelection`).
    var rangeStart: Double = 0
    var rangeEnd: Double = 0
    var audio: AudioOption = .keep
    var quality: ExportQuality = .hd1080

    var speedMultiplier: Double { Double(speedPercent) / 100 }
}
