import SwiftUI

struct OnboardingView: View {
    @AppStorage(AppStorageKey.hasOnboarded) private var hasOnboarded = false
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                OnboardingPage(
                    title: String(localized: "Play it backwards", comment: "Onboarding page 1 title"),
                    subtitle: String(localized: "Turn any video from your library into a reversed clip with one tap.", comment: "Onboarding page 1 subtitle")
                ) {
                    ReverseDemoPage()
                }
                .tag(0)

                OnboardingPage(
                    title: String(localized: "Replay the best part", comment: "Onboarding page 2 title"),
                    subtitle: String(localized: "Pick a moment on the timeline and watch it rewind — like a sports replay.", comment: "Onboarding page 2 subtitle")
                ) {
                    ReplayDemoPage()
                }
                .tag(1)

                OnboardingPage(
                    title: String(localized: "Your videos stay yours", comment: "Onboarding page 3 title"),
                    subtitle: String(localized: "Video Reverser only needs permission to save finished videos back to your library.", comment: "Onboarding page 3 subtitle")
                ) {
                    LibraryAccessPage()
                }
                .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.snappy, value: page)

            pageDots
                .padding(.bottom, 24)

            Button(action: advance) {
                Text(page == 2
                     ? String(localized: "Get Started", comment: "Onboarding final button")
                     : String(localized: "Continue", comment: "Onboarding next-page button"))
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 32)
            .padding(.bottom, 16)
        }
        .background(Color(.systemBackground))
    }

    private var pageDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(index == page ? Color.accentColor : Color(.systemFill))
                    .frame(width: 8, height: 8)
            }
        }
    }

    private func advance() {
        if page < 2 {
            page += 1
        } else {
            hasOnboarded = true
        }
    }
}

/// Shared layout for one onboarding page: demo on top, title + subtitle below.
struct OnboardingPage<Demo: View>: View {
    let title: String
    let subtitle: String
    let demo: Demo

    init(title: String, subtitle: String, @ViewBuilder demo: () -> Demo) {
        self.title = title
        self.subtitle = subtitle
        self.demo = demo()
    }

    var body: some View {
        VStack(spacing: 32) {
            Spacer(minLength: 24)

            demo
                .frame(maxWidth: .infinity)
                .frame(height: 320)

            VStack(spacing: 12) {
                Text(title)
                    .font(.title.bold())
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 32)

            Spacer(minLength: 12)
        }
    }
}

#Preview {
    OnboardingView()
}
