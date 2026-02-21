import Foundation
import StoreKit

/// Manages when to prompt the user for an App Store rating.
///
/// Strategy: prompt after the 3rd, 10th, and 25th completed game —
/// then respect Apple's 365-day system cap (no explicit throttle needed).
final class AppRatingManager {

    static let shared = AppRatingManager()
    private init() {}

    private let defaults = UserDefaults.standard

    // MARK: - Storage Keys

    private enum Key {
        static let gamesCompleted = "qeidplus.rating.gamesCompleted"
    }

    // MARK: - Public

    /// Call this every time a game ends (winner declared).
    @MainActor
    func recordGameCompleted() {
        let count = defaults.integer(forKey: Key.gamesCompleted) + 1
        defaults.set(count, forKey: Key.gamesCompleted)

        // Prompt at game 3, 10, and 25. Apple enforces a 365-day hard cap
        // across all requestReview() calls — so we don't need to track dates.
        let promptMilestones: Set<Int> = [3, 10, 25]
        if promptMilestones.contains(count) {
            requestReview()
        }
    }

    // MARK: - Private

    @MainActor
    private func requestReview() {
        guard let scene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene })
            .first(where: { $0.activationState == .foregroundActive })
        else { return }
        SKStoreReviewController.requestReview(in: scene)
    }
}
