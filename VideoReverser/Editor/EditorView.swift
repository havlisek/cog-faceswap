import SwiftUI
import AVFoundation

/// The editor: immersive preview with floating controls and filmstrip on top,
/// light control panel (speed dial, mode chips, audio, quality) below.
struct EditorView: View {
    let videoURL: URL

    @EnvironmentObject private var store: RecentProjectsStore
    @Environment(\.dismiss) private var dismiss
    @StateObject private var playerModel = PlayerViewModel()
    @State private var config = EditorConfiguration()
    @State private var showExport = false

    var body: some View {
        VStack(spacing: 0) {
            previewZone
            controlPanel
        }
        .background(Color(.systemBackground))
        .task {
            await playerModel.load(url: videoURL)
            // Default replay selection: the middle third of the video.
            if config.rangeEnd == 0 {
                config.rangeStart = playerModel.duration * 0.33
                config.rangeEnd = playerModel.duration * 0.66
            }
        }
        .onChange(of: config.speedPercent) { _, _ in
            playerModel.previewRate = Float(config.speedMultiplier)
        }
        .onDisappear {
            playerModel.tearDown()
        }
        .sheet(isPresented: $showExport) {
            ExportView(sourceURL: videoURL, configuration: config)
                .environmentObject(store)
                .interactiveDismissDisabled()
        }
    }

    // MARK: Preview zone

    private var previewZone: some View {
        ZStack {
            Color.black

            PlayerLayerView(player: playerModel.player)
                .padding(.bottom, 92)

            // Big play/pause; fades away while playing, whole preview toggles.
            Button {
                playerModel.togglePlayback()
            } label: {
                Image(systemName: playerModel.isPlaying ? "pause.fill" : "play.fill")
                    .font(.title)
                    .foregroundStyle(.white)
                    .frame(width: 72, height: 72)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .opacity(playerModel.isPlaying ? 0 : 1)
            .animation(.easeOut(duration: 0.25), value: playerModel.isPlaying)

            VStack {
                topBar
                Spacer()
                timelineArea
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            playerModel.togglePlayback()
        }
        .frame(maxHeight: .infinity)
    }

    private var topBar: some View {
        HStack {
            GlassCircleButton(systemName: "chevron.left",
                              label: String(localized: "Back", comment: "Editor back button accessibility label")) {
                dismiss()
            }
            Spacer()
            GlassCircleButton(systemName: "arrow.down.to.line",
                              label: String(localized: "Export", comment: "Editor export button accessibility label")) {
                playerModel.pause()
                showExport = true
            }
        }
        .padding(16)
    }

    private var timelineArea: some View {
        VStack(spacing: 8) {
            FilmstripView(
                playerModel: playerModel,
                rangeStart: $config.rangeStart,
                rangeEnd: $config.rangeEnd,
                showsRange: config.mode.usesRangeSelection
            )
            .frame(height: 56)
            .padding(.horizontal, 16)

            HStack {
                Button {
                    playerModel.step(by: -1)
                } label: {
                    Image(systemName: "backward.fill")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(Text("Step back", comment: "Seek one second back"))

                Spacer()

                Text(playerModel.currentTime.playerTimeLabel)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.8))

                Spacer()

                Button {
                    playerModel.step(by: 1)
                } label: {
                    Image(systemName: "forward.fill")
                        .foregroundStyle(.white)
                }
                .accessibilityLabel(Text("Step forward", comment: "Seek one second forward"))
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
    }

    // MARK: Control panel

    private var controlPanel: some View {
        VStack(spacing: 20) {
            VStack(spacing: 4) {
                Text(speedTitle)
                    .font(.headline)
                SpeedDialView(speedPercent: $config.speedPercent)
                    .padding(.horizontal, 8)
            }

            ModePicker(mode: $config.mode)

            HStack(alignment: .top, spacing: 28) {
                AudioOptionPicker(audio: $config.audio)
                qualityButton
            }

            Button {
                playerModel.pause()
                showExport = true
            } label: {
                Text("Create Video", comment: "Primary editor button starting the export")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
        }
        .padding(.top, 20)
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }

    private var speedTitle: String {
        switch config.mode {
        case .reverseAll:
            String(localized: "Reverse playback speed %", comment: "Speed dial title in reverse mode")
        case .replayPart:
            String(localized: "Replay playback speed %", comment: "Speed dial title in replay mode")
        case .boomerang:
            String(localized: "Boomerang playback speed %", comment: "Speed dial title in boomerang mode")
        }
    }

    private var qualityButton: some View {
        Menu {
            ForEach(ExportQuality.allCases) { quality in
                Button {
                    config.quality = quality
                } label: {
                    if quality == config.quality {
                        Label(quality.title, systemImage: "checkmark")
                    } else {
                        Text(quality.title)
                    }
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: "4k.tv")
                    .font(.title3)
                    .frame(width: 54, height: 54)
                    .background(Circle().fill(Color(.secondarySystemBackground)))
                    .foregroundStyle(Color.primary)
                Text(config.quality.title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

/// Translucent circular button floating over the video preview.
struct GlassCircleButton: View {
    let systemName: String
    let label: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemName)
                .font(.headline)
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(.ultraThinMaterial, in: Circle())
        }
        .accessibilityLabel(label)
    }
}
