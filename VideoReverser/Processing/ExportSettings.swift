import AVFoundation

extension ExportQuality {
    /// Export-session preset implementing this quality. Presets scale down to
    /// the bounds while preserving aspect ratio; they never upscale.
    var exportPreset: String {
        switch self {
        case .hd720: AVAssetExportPreset1280x720
        case .hd1080: AVAssetExportPreset1920x1080
        case .original: AVAssetExportPresetHighestQuality
        }
    }
}
