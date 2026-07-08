import SwiftUI
import Photos

/// Save-to-Photos and share actions for a finished video.
struct SaveAndShareBar: View {
    let videoURL: URL

    private enum SaveState {
        case idle, saving, saved, failed
    }

    @State private var saveState: SaveState = .idle

    var body: some View {
        HStack(spacing: 12) {
            Button {
                save()
            } label: {
                Label {
                    saveLabel
                } icon: {
                    Image(systemName: saveState == .saved ? "checkmark" : "square.and.arrow.down")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .disabled(saveState == .saving || saveState == .saved)

            ShareLink(item: videoURL) {
                Label {
                    Text("Share", comment: "Share the finished video")
                } icon: {
                    Image(systemName: "square.and.arrow.up")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 6)
            }
            .buttonStyle(.bordered)
        }
        .alert(Text("Couldn't save", comment: "Alert title when saving to Photos fails"),
               isPresented: saveFailedBinding) {
            Button(role: .cancel) {} label: {
                Text("OK", comment: "Alert dismiss button")
            }
        } message: {
            Text("Allow photo library access in Settings to save videos.",
                 comment: "Alert message when saving to Photos fails")
        }
    }

    @ViewBuilder
    private var saveLabel: some View {
        switch saveState {
        case .saved:
            Text("Saved", comment: "Video was saved to Photos")
        case .saving:
            Text("Saving…", comment: "Video is being saved to Photos")
        default:
            Text("Save to Photos", comment: "Save the finished video to the photo library")
        }
    }

    private var saveFailedBinding: Binding<Bool> {
        Binding(
            get: { saveState == .failed },
            set: { failed in
                if !failed { saveState = .idle }
            }
        )
    }

    private func save() {
        saveState = .saving
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
            guard status == .authorized || status == .limited else {
                DispatchQueue.main.async { saveState = .failed }
                return
            }
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: videoURL)
            } completionHandler: { success, _ in
                DispatchQueue.main.async {
                    saveState = success ? .saved : .failed
                }
            }
        }
    }
}
