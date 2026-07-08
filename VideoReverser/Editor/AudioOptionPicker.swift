import SwiftUI

/// Circular icon buttons choosing what happens to the audio track.
struct AudioOptionPicker: View {
    @Binding var audio: AudioOption

    var body: some View {
        HStack(spacing: 24) {
            ForEach(AudioOption.allCases) { candidate in
                let selected = candidate == audio
                Button {
                    audio = candidate
                } label: {
                    VStack(spacing: 6) {
                        Image(systemName: candidate.symbolName)
                            .font(.title3)
                            .frame(width: 54, height: 54)
                            .background(
                                Circle().fill(selected ? Color.accentColor : Color(.secondarySystemBackground))
                            )
                            .foregroundStyle(selected ? Color.white : Color.primary)
                        Text(candidate.title)
                            .font(.caption)
                            .foregroundStyle(selected ? Color.primary : Color.secondary)
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .sensoryFeedback(.selection, trigger: audio)
    }
}

#Preview {
    struct Host: View {
        @State var audio = AudioOption.keep
        var body: some View {
            AudioOptionPicker(audio: $audio)
        }
    }
    return Host()
}
