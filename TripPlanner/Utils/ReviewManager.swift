import StoreKit

// MARK: - ReviewManager
@MainActor
enum ReviewManager {

    private static let promptCountKey = "reviewPromptCount"
    private static let lastPromptDateKey = "reviewLastPromptDate"
    static func triggerAfterExpenseAdded() {
        let totalExpenses = (UserDefaults.standard.integer(forKey: "totalExpensesAdded")) + 1
        UserDefaults.standard.set(totalExpenses, forKey: "totalExpensesAdded")
        if totalExpenses == 3 { requestReview() }
    }

    static func triggerAfterTripCreated() {
        let totalTrips = (UserDefaults.standard.integer(forKey: "totalTripsCreated")) + 1
        UserDefaults.standard.set(totalTrips, forKey: "totalTripsCreated")
        if totalTrips == 2 { requestReview() }
    }

    // MARK: - Private

    private static func requestReview() {
        if let last = UserDefaults.standard.object(forKey: lastPromptDateKey) as? Date {
            let daysSince = Calendar.current.dateComponents([.day], from: last, to: Date()).day ?? 0
            guard daysSince >= 60 else { return }
        }

        guard let scene = UIApplication.shared.connectedScenes
            .first(where: { $0.activationState == .foregroundActive }) as? UIWindowScene
        else { return }

        SKStoreReviewController.requestReview(in: scene)
        UserDefaults.standard.set(Date(), forKey: lastPromptDateKey)
    }
}
