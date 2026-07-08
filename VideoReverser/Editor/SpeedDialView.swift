import SwiftUI

/// Ruler-style speed picker: percentage stops laid out horizontally over tick
/// marks, the selected one circled. Tap a value or drag across the ruler to
/// snap between stops, with a haptic tick per change.
struct SpeedDialView: View {
    @Binding var speedPercent: Int

    static let stops = [50, 75, 100, 125, 150, 200]

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            VStack(spacing: 10) {
                HStack(spacing: 0) {
                    ForEach(Self.stops, id: \.self) { stop in
                        Text("\(stop)")
                            .font(.system(size: 20, weight: stop == speedPercent ? .bold : .regular, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(stop == speedPercent ? Color.primary : Color.secondary)
                            .frame(maxWidth: .infinity)
                            .overlay(
                                Circle()
                                    .strokeBorder(Color.accentColor, lineWidth: 2.5)
                                    .frame(width: 56, height: 56)
                                    .opacity(stop == speedPercent ? 1 : 0)
                            )
                            .contentShape(Rectangle())
                            .onTapGesture {
                                speedPercent = stop
                            }
                    }
                }
                .frame(maxHeight: .infinity)

                HStack(spacing: 0) {
                    ForEach(Self.stops, id: \.self) { stop in
                        Rectangle()
                            .fill(stop == speedPercent ? Color.accentColor : Color(.systemFill))
                            .frame(width: 2.5, height: stop == speedPercent ? 26 : 16)
                            .frame(maxWidth: .infinity)
                    }
                }
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 8)
                    .onChanged { value in
                        let slot = Int((value.location.x / width * CGFloat(Self.stops.count))
                            .rounded(.down))
                        let clamped = min(max(slot, 0), Self.stops.count - 1)
                        speedPercent = Self.stops[clamped]
                    }
            )
        }
        .frame(height: 92)
        .animation(.snappy(duration: 0.2), value: speedPercent)
        .sensoryFeedback(.selection, trigger: speedPercent)
    }
}

#Preview {
    struct Host: View {
        @State var speed = 100
        var body: some View {
            SpeedDialView(speedPercent: $speed)
                .padding()
        }
    }
    return Host()
}
