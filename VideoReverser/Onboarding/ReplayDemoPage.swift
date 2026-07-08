import SwiftUI

/// Looping animation demonstrating a replay: a playhead travels along a mock
/// filmstrip, then rewinds through the highlighted segment before continuing.
struct ReplayDemoPage: View {
    // Highlighted "replay" segment of the strip, as fractions of its width.
    private let segment: ClosedRange<Double> = 0.35...0.7
    private let cycleDuration = 4.5

    var body: some View {
        TimelineView(.animation) { context in
            let t = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: cycleDuration) / cycleDuration
            let (progress, rewinding) = playheadProgress(at: t)

            VStack(spacing: 28) {
                DemoVideoFrame(badge: rewinding ? .rewind : .play) {
                    GeometryReader { geo in
                        let x = geo.size.width * (0.12 + 0.76 * progress)
                        Circle()
                            .fill(Color.accentColor.gradient)
                            .frame(width: 36, height: 36)
                            .position(x: x, y: geo.size.height * 0.55)
                            .shadow(color: .accentColor.opacity(0.4), radius: 8, y: 4)
                    }
                }

                filmstrip(progress: progress, rewinding: rewinding)
                    .frame(height: 44)
            }
        }
        .padding(.horizontal, 40)
    }

    /// Timeline phases: forward to segment end (0–0.4), rewind through the
    /// segment (0.4–0.7), forward again to the end (0.7–1.0).
    private func playheadProgress(at t: Double) -> (progress: Double, rewinding: Bool) {
        switch t {
        case ..<0.4:
            (t / 0.4 * segment.upperBound, false)
        case ..<0.7:
            (segment.upperBound - (t - 0.4) / 0.3 * (segment.upperBound - segment.lowerBound), true)
        default:
            (segment.lowerBound + (t - 0.7) / 0.3 * (1 - segment.lowerBound), false)
        }
    }

    private func filmstrip(progress: Double, rewinding: Bool) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Frame thumbnails.
                HStack(spacing: 3) {
                    ForEach(0..<8, id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color(.tertiarySystemFill))
                    }
                }

                // Highlighted replay segment.
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color.accentColor, lineWidth: 3)
                    .background(
                        Color.accentColor.opacity(rewinding ? 0.25 : 0.12)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                    )
                    .frame(width: geo.size.width * (segment.upperBound - segment.lowerBound))
                    .offset(x: geo.size.width * segment.lowerBound)

                // Playhead.
                Capsule()
                    .fill(Color.primary)
                    .frame(width: 4)
                    .offset(x: geo.size.width * progress - 2)
            }
        }
    }
}

#Preview {
    ReplayDemoPage()
        .frame(height: 320)
}
