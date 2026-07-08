import SwiftUI
import PhotosUI
import UniformTypeIdentifiers

/// Home screen: pick a video to edit, and browse recent finished videos.
struct HomeView: View {
    @StateObject private var store = RecentProjectsStore()
    @State private var pickerItem: PhotosPickerItem?
    @State private var editingVideo: PickedVideo?
    @State private var isLoadingVideo = false
    @State private var loadFailed = false
    @State private var selectedProject: RecentProject?

    private let columns = [GridItem(.adaptive(minimum: 150), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    pickCard

                    if !store.projects.isEmpty {
                        Text("Recent", comment: "Home section header for recent projects")
                            .font(.title3.bold())

                        LazyVGrid(columns: columns, spacing: 12) {
                            ForEach(store.projects) { project in
                                RecentProjectCell(project: project, store: store)
                                    .onTapGesture { selectedProject = project }
                                    .contextMenu {
                                        Button(role: .destructive) {
                                            store.delete(project)
                                        } label: {
                                            Label {
                                                Text("Delete", comment: "Delete a recent project")
                                            } icon: {
                                                Image(systemName: "trash")
                                            }
                                        }
                                    }
                            }
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(Text("Video Reverser", comment: "App name shown as home title"))
        }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            loadVideo(from: item)
        }
        .fullScreenCover(item: $editingVideo) { video in
            EditorView(videoURL: video.url)
                .environmentObject(store)
        }
        .sheet(item: $selectedProject) { project in
            ProjectDetailView(project: project, store: store)
        }
        .alert(Text("Couldn't load that video", comment: "Alert title when the picked video fails to load"),
               isPresented: $loadFailed) {
            Button(role: .cancel) {} label: {
                Text("OK", comment: "Alert dismiss button")
            }
        }
    }

    private var pickCard: some View {
        PhotosPicker(selection: $pickerItem, matching: .videos) {
            VStack(spacing: 12) {
                if isLoadingVideo {
                    ProgressView()
                        .controlSize(.large)
                } else {
                    Image(systemName: "video.badge.plus")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical)
                }
                Text("Select a Video", comment: "Home button to pick a video")
                    .font(.headline)
                Text("Reverse it, replay a moment, or make a boomerang.",
                     comment: "Home button subtitle")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 40)
            .background(
                RoundedRectangle(cornerRadius: 24)
                    .fill(Color.accentColor.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 24)
                            .strokeBorder(Color.accentColor.opacity(0.35), style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                    )
            )
        }
        .disabled(isLoadingVideo)
    }

    private func loadVideo(from item: PhotosPickerItem) {
        isLoadingVideo = true
        Task {
            defer {
                isLoadingVideo = false
                pickerItem = nil
            }
            do {
                if let video = try await item.loadTransferable(type: PickedVideo.self) {
                    editingVideo = video
                } else {
                    loadFailed = true
                }
            } catch {
                loadFailed = true
            }
        }
    }
}

/// The picked video, copied into a temporary file the app owns.
struct PickedVideo: Identifiable, Transferable {
    let url: URL
    var id: URL { url }

    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(contentType: .movie) { video in
            SentTransferredFile(video.url)
        } importing: { received in
            let ext = received.file.pathExtension.isEmpty ? "mov" : received.file.pathExtension
            let copy = FileManager.default.temporaryDirectory
                .appendingPathComponent("picked-\(UUID().uuidString).\(ext)")
            try FileManager.default.copyItem(at: received.file, to: copy)
            return PickedVideo(url: copy)
        }
    }
}

#Preview {
    HomeView()
}
