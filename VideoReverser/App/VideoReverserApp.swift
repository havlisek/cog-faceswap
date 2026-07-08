import SwiftUI

@main
struct VideoReverserApp: App {
    @AppStorage(AppStorageKey.hasOnboarded) private var hasOnboarded = false

    var body: some Scene {
        WindowGroup {
            if hasOnboarded {
                HomeView()
            } else {
                OnboardingView()
            }
        }
    }
}
