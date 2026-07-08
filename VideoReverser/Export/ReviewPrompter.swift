import SwiftUI
import StoreKit

/// Asks for an App Store review once, shortly after the user's first video
/// finishes — the moment they're happiest with the app.
private struct FirstVideoReviewPrompt: ViewModifier {
    let finished: Bool

    @Environment(\.requestReview) private var requestReview
    @AppStorage(AppStorageKey.hasRequestedReview) private var hasRequestedReview = false

    func body(content: Content) -> some View {
        content.onChange(of: finished) { _, isFinished in
            guard isFinished, !hasRequestedReview else { return }
            hasRequestedReview = true
            Task {
                // Let the result screen settle before the system alert.
                try? await Task.sleep(for: .seconds(1.5))
                requestReview()
            }
        }
    }
}

extension View {
    func promptsReviewAfterFirstVideo(finished: Bool) -> some View {
        modifier(FirstVideoReviewPrompt(finished: finished))
    }
}
