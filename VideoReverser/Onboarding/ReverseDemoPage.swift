import SwiftUI

/// Looping animation demonstrating the reverse effect: a ball flies across a
/// mock video frame, then the whole motion runs backwards under a rewind badge.
struct ReverseDemoPage: View {
    /// Seconds for one direction of travel.
    private let legDuration = 1.8

    var body: some View {
        TimelineView(.animation) { context in
            let cycle = context.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: legDuration * 2)
            let reversing = cycle >= legDuration
            // 0→1 while playing forward, 1→0 while rewinding.
            let progress = reversing
                ? 1 - (cycle - legDuration) / legDuration
                : cycle / legDuration

            DemoVideoFrame(badge: reversing ? .rewind : .play) {
                GeometryReader { geo in
                    let x = geo.size.width * (0.12 + 0.76 * progress)
                    // Parabolic arc: highest mid-flight.
                    let y = geo.size.height * (0.75 - 0.5 * sin(progress * .pi))
                    Circle()
                        .fill(Color.accentColor.gradient)
                        .frame(width: 36, height: 36)
                        .position(x: x, y: y)
                        .shadow(color: .accentColor.opacity(0.4), radius: 8, y: 4)
                }
            }
        }
        .padding(.horizontal, 40)
    }
}

/// Rounded "video player" frame shared by the onboarding demos.
struct DemoVideoFrame<Content: View>: View {
    enum Badge {
        case play, rewind

        var symbolName: String {
            switch self {
            case .play: "play.fill"
            case .rewind: "backward.fill"
            }
        }

        var label: String {
            switch self {
            case .play: String(localized: "Playing", comment: "Onboarding demo badge")
            case .rewind: String(localized: "Rewinding", comment: "Onboarding demo badge")
            }
        }
    }

    let badge: Badge
    let content: Content

    init(badge: Badge, @ViewBuilder content: () -> Content) {
        self.badge = badge
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 24)
                .fill(Color(.secondarySystemBackground))

            content
                .clipShape(RoundedRectangle(cornerRadius: 24))

            HStack(spacing: 6) {
                Image(systemName: badge.symbolName)
                Text(badge.label)
            }
            .font(.caption.bold())
            .foregroundStyle(badge == .rewind ? Color.accentColor : Color.secondary)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .padding(12)
        }
    }
}

#Preview {
    ReverseDemoPage()
        .frame(height: 320)
}
