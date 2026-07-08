import SwiftUI
import AVKit

/// Grid cell for a finished video on the home screen.
struct RecentProjectCell: View {
    let project: RecentProject
    @ObservedObject var store: RecentProjectsStore

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ZStack(alignment: .bottomTrailing) {
                thumbnail
                    .frame(height: 110)
                    .frame(maxWidth: .infinity)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                Text(project.duration.playerTimeLabel)
                    .font(.caption2.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.6), in: Capsule())
                    .padding(6)
            }

            HStack(spacing: 4) {
                Image(systemName: project.mode.symbolName)
                    .font(.caption2)
                    .foregroundStyle(Color.accentColor)
                Text(project.mode.title)
                    .font(.caption.bold())
                Spacer()
                Text(project.createdAt, format: .dateTime.day().month())
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)
        }
    }

    @ViewBuilder
    private var thumbnail: some View {
        if let image = store.thumbnail(for: project) {
            Image(uiImage: image)
                .resizable()
                .aspectRatio(contentMode: .fill)
        } else {
            ZStack {
                Color(.secondarySystemBackground)
                Image(systemName: "film")
                    .font(.title2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Sheet showing a finished video with save and share actions.
struct ProjectDetailView: View {
    let project: RecentProject
    @ObservedObject var store: RecentProjectsStore
    @Environment(\.dismiss) private var dismiss
    @State private var player: AVPlayer?

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                VideoPlayer(player: player)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)

                SaveAndShareBar(videoURL: store.videoURL(for: project))
                    .padding(.horizontal)
                    .padding(.bottom)
            }
            .navigationTitle(project.mode.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        dismiss()
                    } label: {
                        Text("Done", comment: "Close the project detail sheet")
                    }
                }
            }
        }
        .onAppear {
            let player = AVPlayer(url: store.videoURL(for: project))
            self.player = player
            player.play()
        }
        .onDisappear {
            player?.pause()
        }
    }
}
