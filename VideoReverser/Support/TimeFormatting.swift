import Foundation

extension Double {
    /// "5.0s" — short duration badge used on the timeline selection.
    var shortDurationBadge: String {
        String(localized: "\(self, specifier: "%.1f")s", comment: "Duration badge in seconds, e.g. 5.0s")
    }

    /// "1:23" — minutes:seconds for player time labels.
    var playerTimeLabel: String {
        let total = Int(self.rounded())
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}
