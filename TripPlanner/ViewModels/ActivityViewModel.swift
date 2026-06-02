import SwiftUI
import CoreData
import Combine
import UserNotifications

@MainActor
final class ActivityViewModel: ObservableObject {

    // MARK: - Published

    @Published var activities: [Activity] = []

    // MARK: - Private

    private let context: NSManagedObjectContext
    let dayPlan: DayPlan
    /// Для отслеживания активных операций синхронизации
    private var syncTasks: Set<Task<Void, Never>> = []

    // MARK: - Init

    init(dayPlan: DayPlan, context: NSManagedObjectContext) {
        self.dayPlan = dayPlan
        self.context = context
        fetch()
    }

    // MARK: - Fetch

    func fetch() {
        let request: NSFetchRequest<Activity> = Activity.fetchRequest()
        request.predicate = NSPredicate(format: "dayPlan == %@", dayPlan)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Activity.startTime, ascending: true)]
        activities = (try? context.fetch(request)) ?? []
    }

    // MARK: - Create

    func addActivity(
        title: String,
        categoryName: String,
        categoryColor: String,
        startTime: Date,
        endTime: Date,
        reminderEnabled: Bool,
        budget: Decimal?,
        note: String,
        latitude: Double = 0,
        longitude: Double = 0,
        locationName: String? = nil
    ) {

        let act = Activity(context: context)
        act.id           = UUID()
        act.title        = title
        act.categoryName = categoryName
        act.categoryColor = categoryColor
        act.startTime    = startTime
        act.endTime      = endTime
        act.reminderEnabled = reminderEnabled
        act.reminderDate = reminderEnabled ? startTime : nil
        act.budget       = budget.map { NSDecimalNumber(decimal: $0) }
        act.note         = note.isEmpty ? nil : note
        act.createdAt    = Date()
        act.isSynced     = false
        act.dayPlan      = dayPlan
        act.trip         = dayPlan.trip
        act.latitude     = latitude
        act.longitude    = longitude
        act.locationName = locationName

        save()
        fetch()

        if reminderEnabled {
            scheduleNotification(for: act)
        }

        enqueueSync { await SyncService.shared.uploadActivity(act) }
    }

    // MARK: - Update

    func updateActivity(
        _ activity: Activity,
        title: String,
        categoryName: String,
        categoryColor: String,
        startTime: Date,
        endTime: Date,
        reminderEnabled: Bool,
        budget: Decimal?,
        note: String,
        latitude: Double = 0,
        longitude: Double = 0,
        locationName: String? = nil
    ) {

        activity.title        = title
        activity.categoryName = categoryName
        activity.categoryColor = categoryColor
        activity.startTime    = startTime
        activity.endTime      = endTime
        activity.reminderEnabled = reminderEnabled
        activity.reminderDate = reminderEnabled ? startTime : nil
        activity.budget       = budget.map { NSDecimalNumber(decimal: $0) }
        activity.note         = note.isEmpty ? nil : note
        activity.latitude     = latitude
        activity.longitude    = longitude
        activity.locationName = locationName
        activity.isSynced     = false

        save()
        fetch()

        cancelNotification(for: activity)
        if reminderEnabled {
            scheduleNotification(for: activity)
        }

        enqueueSync { await SyncService.shared.uploadActivity(activity) }
    }

    // MARK: - Delete

    func deleteActivity(_ act: Activity) {
        cancelNotification(for: act)
        enqueueSync { await SyncService.shared.deleteActivity(act) }
        context.delete(act)
        save()
        fetch()
    }

    // MARK: - Helpers

    func activitiesCount() -> Int { activities.count }

    func formattedTime(_ date: Date?) -> String {
        guard let date else { return "--:--" }
        return date.formattedTime()
    }

    func color(for act: Activity) -> Color {
        Color(hex: act.categoryColor ?? "#FF4B8B") ?? .primaryAccent
    }

    // MARK: - Notifications

    func requestNotificationPermission() {
        Task { @MainActor in
            PermissionManager.shared.request(.notifications)
        }
    }

    private func scheduleNotification(for act: Activity) {
        guard let fireDate = act.reminderDate, fireDate > Date() else { return }

        let content = UNMutableNotificationContent()
        content.title = "Напоминание о поездке"
        content.body  = act.title ?? ""
        content.sound = .default

        let comps = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
        let request = UNNotificationRequest(
            identifier: act.id?.uuidString ?? UUID().uuidString,
            content: content,
            trigger: trigger
        )
        UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
    }

    private func cancelNotification(for act: Activity) {
        guard let id = act.id?.uuidString else { return }
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [id])
    }

    // MARK: - Save

    private func save() {
        try? context.save()
    }

    private func enqueueSync(_ operation: @escaping () async -> Void) {
        var task: Task<Void, Never>?
        task = Task {
            await operation()
            if let t = task { syncTasks.remove(t) }
        }
        if let t = task { syncTasks.insert(t) }
    }
}


