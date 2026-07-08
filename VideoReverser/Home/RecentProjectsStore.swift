import Foundation
import AVFoundation
import UIKit

/// A finished export kept on the home screen.
struct RecentProject: Identifiable, Codable {
    let id: UUID
    let createdAt: Date
    let mode: EffectMode
    let duration: Double
    let videoFilename: String
    let thumbnailFilename: String
}

/// Persists finished videos (plus thumbnail and metadata) in Documents so the
/// home screen can show and re-open them. Metadata lives in a single JSON file;
/// media files sit next to it in `RecentProjects/`.
@MainActor
final class RecentProjectsStore: ObservableObject {
    @Published private(set) var projects: [RecentProject] = []

    private let directory: URL
    private let indexURL: URL

    init() {
        let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        directory = documents.appendingPathComponent("RecentProjects", isDirectory: true)
        indexURL = directory.appendingPathComponent("index.json")
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        load()
    }

    func videoURL(for project: RecentProject) -> URL {
        directory.appendingPathComponent(project.videoFilename)
    }

    func thumbnail(for project: RecentProject) -> UIImage? {
        UIImage(contentsOfFile: directory.appendingPathComponent(project.thumbnailFilename).path)
    }

    /// Copies the exported video into the store and generates a thumbnail.
    func add(exportedVideo url: URL, mode: EffectMode) async {
        let id = UUID()
        let videoFilename = "\(id.uuidString).mp4"
        let thumbnailFilename = "\(id.uuidString).jpg"

        do {
            try FileManager.default.copyItem(at: url, to: directory.appendingPathComponent(videoFilename))
        } catch {
            return
        }

        let asset = AVURLAsset(url: directory.appendingPathComponent(videoFilename))
        let duration = (try? await asset.load(.duration).seconds) ?? 0

        if let thumbnail = await generateThumbnail(for: asset),
           let data = thumbnail.jpegData(compressionQuality: 0.8) {
            try? data.write(to: directory.appendingPathComponent(thumbnailFilename))
        }

        projects.insert(
            RecentProject(
                id: id,
                createdAt: .now,
                mode: mode,
                duration: duration,
                videoFilename: videoFilename,
                thumbnailFilename: thumbnailFilename
            ),
            at: 0
        )
        save()
    }

    func delete(_ project: RecentProject) {
        projects.removeAll { $0.id == project.id }
        try? FileManager.default.removeItem(at: videoURL(for: project))
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(project.thumbnailFilename))
        save()
    }

    private func generateThumbnail(for asset: AVAsset) async -> UIImage? {
        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 600, height: 600)
        guard let cgImage = try? await generator.image(at: .zero).image else { return nil }
        return UIImage(cgImage: cgImage)
    }

    private func load() {
        guard let data = try? Data(contentsOf: indexURL),
              let decoded = try? JSONDecoder().decode([RecentProject].self, from: data) else { return }
        projects = decoded
    }

    private func save() {
        guard let data = try? JSONEncoder().encode(projects) else { return }
        try? data.write(to: indexURL)
    }
}
