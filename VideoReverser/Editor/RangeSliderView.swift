import SwiftUI

/// Selection overlay for the filmstrip: a bright-bordered range with grab
/// handles on both edges and a live duration badge. Times are in seconds.
struct RangeSliderView: View {
    @Binding var start: Double
    @Binding var end: Double
    let duration: Double
    var minimumLength: Double = 0.5

    private let handleWidth: CGFloat = 18

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let safeDuration = max(duration, 0.001)
            let startX = width * start / safeDuration
            let endX = width * end / safeDuration

            ZStack(alignment: .leading) {
                // Dim the frames outside the selection.
                Rectangle()
                    .fill(.black.opacity(0.5))
                    .frame(width: max(startX, 0))
                    .allowsHitTesting(false)
                Rectangle()
                    .fill(.black.opacity(0.5))
                    .frame(width: max(width - endX, 0))
                    .offset(x: endX)
                    .allowsHitTesting(false)

                // Selection border.
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .frame(width: max(endX - startX, handleWidth))
                    .offset(x: startX)
                    .allowsHitTesting(false)

                handle(edge: .leading)
                    .position(x: startX + handleWidth / 2, y: geo.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let time = value.location.x / width * safeDuration
                                start = min(max(time, 0), end - minimumLength)
                            }
                    )

                handle(edge: .trailing)
                    .position(x: endX - handleWidth / 2, y: geo.size.height / 2)
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let time = value.location.x / width * safeDuration
                                end = max(min(time, safeDuration), start + minimumLength)
                            }
                    )

                // Live duration badge above the selection.
                Text((end - start).shortDurationBadge)
                    .font(.caption.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(.black.opacity(0.75), in: RoundedRectangle(cornerRadius: 6))
                    .position(x: (startX + endX) / 2, y: geo.size.height / 2)
                    .allowsHitTesting(false)
            }
        }
    }

    private func handle(edge: HorizontalEdge) -> some View {
        UnevenRoundedRectangle(
            topLeadingRadius: edge == .leading ? 8 : 0,
            bottomLeadingRadius: edge == .leading ? 8 : 0,
            bottomTrailingRadius: edge == .trailing ? 8 : 0,
            topTrailingRadius: edge == .trailing ? 8 : 0
        )
        .fill(Color.accentColor)
        .frame(width: handleWidth)
        .overlay(
            Image(systemName: "chevron.compact.\(edge == .leading ? "left" : "right")")
                .font(.caption.bold())
                .foregroundStyle(.white)
        )
        // Generous invisible hit area for comfortable dragging.
        .contentShape(Rectangle().inset(by: -14))
    }
}
