import SwiftUI
import AVKit

/// Runs the processing pipeline with a progress ring, then shows the result
/// with save and share actions.
struct ExportView: View {
    let sourceURL: URL
    let configuration: EditorConfiguration

    @EnvironmentObject private var store: RecentProjectsStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage(AppStorageKey.hasFinishedFirstVideo) private var hasFinishedFirstVideo = false

    private enum Phase {
        case working(Double)
        case done(URL)
        case failed
    }

    @State private var phase: Phase = .working(0)
    @State private var resultPlayer: AVPlayer?

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .working(let fraction):
                    workingView(fraction: fraction)
                case .done(let url):
                    resultView(url: url)
                case .failed:
                    failedView
                }
            }
            .navigationTitle(Text("Your Video", comment: "Export screen title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        resultPlayer?.pause()
                        dismiss()
                    } label: {
                        Text(doneButtonTitle)
                    }
                }
            }
        }
        .task {
            await run()
        }
        .promptsReviewAfterFirstVideo(finished: isDone)
    }

    private var isDone: Bool {
        if case .done = phase { return true }
        return false
    }

    private var doneButtonTitle: String {
        if case .working = phase {
            String(localized: "Cancel", comment: "Cancel the running export")
        } else {
            String(localized: "Done", comment: "Close the export screen")
        }
    }

    // MARK: Phases

    private func workingView(fraction: Double) -> some View {
        VStack(spacing: 24) {
            ZStack {
                Circle()
                    .stroke(Color(.systemFill), lineWidth: 10)
                Circle()
                    .trim(from: 0, to: fraction)
                    .stroke(Color.accentColor, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.2), value: fraction)
                Text(fraction, format: .percent.precision(.fractionLength(0)))
                    .font(.title2.bold())
                    .monospacedDigit()
            }
            .frame(width: 140, height: 140)

            Text("Reversing your video…", comment: "Export progress message")
                .font(.headline)
            Text("This can take a moment for long clips.", comment: "Export progress hint")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    private func resultView(url: URL) -> some View {
        VStack(spacing: 16) {
            VideoPlayer(player: resultPlayer)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)

            SaveAndShareBar(videoURL: url)
                .padding(.horizontal)
                .padding(.bottom)
        }
        .onAppear {
            let player = AVPlayer(url: url)
            resultPlayer = player
            player.play()
        }
    }

    private var failedView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundStyle(.orange)
            Text("Something went wrong", comment: "Export failure title")
                .font(.headline)
            Text("The video couldn't be processed. Please try again.",
                 comment: "Export failure message")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
    }

    // MARK: Processing

    private func run() async {
        do {
            let url = try await VideoProcessor.process(
                sourceURL: sourceURL,
                configuration: configuration
            ) { fraction in
                Task { @MainActor in
                    if case .working(let current) = phase, fraction > current {
                        phase = .working(fraction)
                    }
                }
            }
            await store.add(exportedVideo: url, mode: configuration.mode)
            phase = .done(url)
            hasFinishedFirstVideo = true
        } catch is CancellationError {
            // User dismissed while exporting; nothing to show.
        } catch {
            phase = .failed
        }
    }
}
