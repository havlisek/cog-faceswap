import SwiftUI

/// Chip row selecting the effect: Reverse all / Replay part / Boomerang.
struct ModePicker: View {
    @Binding var mode: EffectMode

    var body: some View {
        HStack(spacing: 8) {
            ForEach(EffectMode.allCases) { candidate in
                let selected = candidate == mode
                Button {
                    mode = candidate
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: candidate.symbolName)
                            .font(.subheadline)
                        Text(candidate.title)
                            .font(.subheadline.bold())
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 9)
                    .background(
                        Capsule().fill(selected ? Color.accentColor : Color(.secondarySystemBackground))
                    )
                    .foregroundStyle(selected ? Color.white : Color.primary)
                }
                .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
        .sensoryFeedback(.selection, trigger: mode)
    }
}

#Preview {
    struct Host: View {
        @State var mode = EffectMode.replayPart
        var body: some View {
            ModePicker(mode: $mode)
        }
    }
    return Host()
}
