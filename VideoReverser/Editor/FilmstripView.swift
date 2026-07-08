import SwiftUI

/// Thumbnail filmstrip with a draggable playhead and, in replay mode, the
/// range-selection overlay. (Named Filmstrip to avoid SwiftUI.TimelineView.)
struct FilmstripView: View {
    @ObservedObject var playerModel: PlayerViewModel
    @Binding var rangeStart: Double
    @Binding var rangeEnd: Double
    let showsRange: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let duration = max(playerModel.duration, 0.001)
            let playheadX = width * min(playerModel.currentTime / duration, 1)

            ZStack(alignment: .leading) {
                strip
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                playerModel.pause()
                                playerModel.seek(to: value.location.x / width * duration)
                            }
                    )

                if showsRange {
                    RangeSliderView(start: $rangeStart, end: $rangeEnd, duration: duration)
                }

                playhead
                    .position(x: playheadX, y: geo.size.height / 2)
                    .highPriorityGesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                playerModel.pause()
                                playerModel.seek(to: value.location.x / width * duration)
                            }
                    )
            }
        }
    }

    private var strip: some View {
        HStack(spacing: 0) {
            if playerModel.thumbnails.isEmpty {
                Rectangle()
                    .fill(Color(.tertiarySystemFill))
            } else {
                ForEach(Array(playerModel.thumbnails.enumerated()), id: \.offset) { _, image in
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .clipped()
                }
            }
        }
    }

    private var playhead: some View {
        VStack(spacing: 0) {
            Circle()
                .fill(.white)
                .frame(width: 22, height: 22)
                .overlay(
                    Image(systemName: "arrow.left.and.right")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.black)
                )
                .shadow(radius: 2)
            Rectangle()
                .fill(.white)
                .frame(width: 3)
                .shadow(radius: 1)
        }
        .offset(y: -8)
        .contentShape(Rectangle().inset(by: -12))
    }
}
