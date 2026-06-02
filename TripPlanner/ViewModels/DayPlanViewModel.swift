import SwiftUI
import CoreData
import Combine

@MainActor
final class DayPlanViewModel: ObservableObject {

    // MARK: - Published state

    @Published var dayPlans: [DayPlan] = []
    @Published var errorMessage: String? = nil

    @Published private var expensesCacheByDay: [UUID: ExpensesSummary] = [:]

    // MARK: - Private

    private let context: NSManagedObjectContext
    private let trip: Trip
    private var syncTasks: Set<Task<Void, Never>> = []

    // MARK: - Models

    struct ExpensesSummary {
        let totalByFurrency: [String: Decimal]
        let primaryCurrency: String
        let primaryTotal: Decimal
        let formattedString: String
    }

    // MARK: - Init

    init(trip: Trip, context: NSManagedObjectContext) {
        self.trip = trip
        self.context = context
        fetch()
    }

    // MARK: - Fetch

    func fetch() {
        let request: NSFetchRequest<DayPlan> = DayPlan.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DayPlan.date, ascending: true)]
        dayPlans = (try? context.fetch(request)) ?? []
        clearExpensesCache()

        #if DEBUG
        print("Fetch Day Plans - Count: \(dayPlans.count)")
        #endif
    }

    // MARK: - Create

    func addDayPlan(date: Date, notes: String? = nil) {
        let day = DayPlan(context: context)
        day.id = UUID()
        day.date = date
        day.notes = notes
        day.trip = trip
        day.isSynced = false
        save()
        fetch()
        enqueueSync { await SyncService.shared.uploadDayPlan(day) }
    }

    func generateDaysFromTripDates() {
        guard let start = trip.startDate, let end = trip.endDate else { return }
        guard start <= end else { return }

        var current = start
        let calendar = Calendar.current
        var createdDays: [DayPlan] = []
        while current <= end {
            // Не создаём дубликаты
            let exists = dayPlans.contains {
                calendar.isDate($0.date ?? .distantPast, inSameDayAs: current)
            }
            if !exists {
                let day = DayPlan(context: context)
                day.id = UUID()
                day.date = current
                day.trip = trip
                day.isSynced = false
                createdDays.append(day)
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? end.addingTimeInterval(1)
        }
        if !createdDays.isEmpty {
            save()
            fetch()

            for day in createdDays {
                enqueueSync { await SyncService.shared.uploadDayPlan(day) }
            }

            #if DEBUG
            print("Generate Days - Created: \(createdDays.count)")
            #endif
        }
    }

    // MARK: - Delete

    func deleteDayPlan(_ day: DayPlan) {
        context.delete(day)
        save()
        fetch()
    }

    func deleteDayPlans(at offsets: IndexSet) {
        offsets.map { dayPlans[$0] }.forEach(context.delete)
        save()
        fetch()
    }

    // MARK: - Helpers

    func dayNumber(for day: DayPlan) -> Int {
        guard let date = day.date, let start = trip.startDate else { return 1 }
        let diff = Calendar.current.dateComponents([.day], from: start, to: date).day ?? 0
        return diff + 1
    }

    func totalExpenses(for day: DayPlan) -> String {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.predicate = NSPredicate(format: "dayPlan == %@", day)
        let expenses = (try? context.fetch(request)) ?? []

        // Группируем по валютам
        var amountByCurrency: [String: Decimal] = [:]
        for expense in expenses {
            let currency = expense.currency ?? "USD"
            let amount = (expense.amount as Decimal?) ?? 0
            amountByCurrency[currency, default: 0] += amount
        }

        let primaryCurrency = amountByCurrency.keys.first ?? (trip.currencyCode ?? "USD")
        let primaryAmount = amountByCurrency[primaryCurrency] ?? 0
        let formattedString = amountByCurrency.isEmpty ? "\(trip.currencyCode ?? "USD") 0" : "\(primaryCurrency) \(primaryAmount)"

        return formattedString
    }

    func placesCount(for day: DayPlan) -> Int {
        (day.activities as? Set<Activity>)?.count ?? 0
    }

    // MARK: - Cache Management

    func invalidateExpensesCache(for day: DayPlan) {
        guard let dayId = day.id else { return }
        expensesCacheByDay.removeValue(forKey: dayId)
    }

    private func clearExpensesCache() {
        expensesCacheByDay.removeAll()
    }

    // MARK: - Private

    private func enqueueSync(_ operation: @escaping () async -> Void) {
        var task: Task<Void, Never>?
        task = Task {
            await operation()
            if let t = task { syncTasks.remove(t) }
        }
        if let t = task { syncTasks.insert(t) }
    }

    private func save() {
        do {
            try context.save()
        } catch {
            errorMessage = "Не удалось сохранить день"
        }
    }
}
