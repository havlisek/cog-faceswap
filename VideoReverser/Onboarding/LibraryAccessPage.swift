import SwiftUI
import Photos

/// Onboarding page that explains and requests add-only photo library access.
/// The app can pick videos without any permission (PhotosPicker), so add-only
/// is all it ever needs — and onboarding continues whatever the user decides.
struct LibraryAccessPage: View {
    @State private var status = PHPhotoLibrary.authorizationStatus(for: .addOnly)

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "photo.stack")
                .font(.system(size: 72))
                .foregroundStyle(Color.accentColor.gradient)
                .symbolRenderingMode(.hierarchical)

            switch status {
            case .authorized, .limited:
                Label {
                    Text("Access granted", comment: "Library permission granted confirmation")
                } icon: {
                    Image(systemName: "checkmark.circle.fill")
                }
                .font(.headline)
                .foregroundStyle(.green)
            case .denied, .restricted:
                Text("You can enable saving later in Settings.",
                     comment: "Shown when library permission was denied")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            default:
                Button {
                    requestAccess()
                } label: {
                    Text("Allow Saving to Photos", comment: "Button requesting add-only library permission")
                        .font(.headline)
                }
                .buttonStyle(.bordered)
            }
        }
    }

    private func requestAccess() {
        PHPhotoLibrary.requestAuthorization(for: .addOnly) { newStatus in
            DispatchQueue.main.async {
                status = newStatus
            }
        }
    }
}

#Preview {
    LibraryAccessPage()
        .frame(height: 320)
}
