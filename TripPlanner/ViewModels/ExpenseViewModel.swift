import SwiftUI
import CoreData
import Combine

// MARK: - Модель долга

/// Кто, кому и сколько должен.
struct DebtSummary: Identifiable {
    let id = UUID()
    let from: Participant   // кто должен
    let to: Participant     // кому должен
    let amount: Decimal
}

// MARK: - Полный список валют

func getAllCurrencies() -> [String] {
    [
        "USD", "EUR", "GBP", "JPY", "CHF",
        "CAD", "AUD", "NZD", "CNY", "INR",
        "RUB", "TRY", "BRL", "MXN", "SGD",
        "HKD", "SEK", "NOK", "DKK", "ZAR",
        "MYR", "THB", "IDR", "PHP", "VND"
    ]
}

// MARK: - ViewModel

@MainActor
final class ExpenseViewModel: ObservableObject {

    // MARK: - Published state

    @Published var expenses: [Expense] = []
    @Published var selectedCategory: String? = nil   // nil = все категории
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let context: NSManagedObjectContext
    private var trip: Trip
    /// Для отслеживания активных операций синхронизации
    private var syncTasks: Set<Task<Void, Never>> = []

    // MARK: - Init

    init(trip: Trip, context: NSManagedObjectContext) {
        self.trip = trip
        self.context = context
        fetch()
    }

    // MARK: - Change trip
    func changeTrip(_ newTrip: Trip) {
        trip = newTrip
        selectedCategory = nil
        fetch()
    }

    // MARK: - Fetch
    func fetch() {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        var predicates: [NSPredicate] = [NSPredicate(format: "trip == %@", trip)]
        if let category = selectedCategory {
            predicates.append(NSPredicate(format: "category == %@", category))
        }
        request.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: predicates)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        expenses = (try? context.fetch(request)) ?? []
    }

    func fetchAll() {
        let request: NSFetchRequest<Expense> = Expense.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(keyPath: \Expense.date, ascending: false)]
        expenses = (try? context.fetch(request)) ?? []
    }

    // MARK: - Create

    func addExpense(
        amount: Decimal,
        category: ExpenseCategory,
        date: Date = Date(),
        currency: String = "USD",
        description: String? = nil,
        paidBy: Participant? = nil,
        isShared: Bool = false,
        sharedWith: [Participant] = [],
        dayPlan: DayPlan? = nil,
        currentUserId: UUID? = nil
    ) {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = amount as NSDecimalNumber
        expense.category = category.rawValue
        expense.currency = currency
        expense.date = date
        expense.descriptionText = description
        expense.paidBy = paidBy
        expense.isShared = isShared
        expense.sharedWithParticipantIDs = sharedWith.compactMap { $0.id }
        expense.dayPlan = dayPlan
        expense.trip = trip
        expense.isSynced = false
        expense.debtStatus = "pending"  // по умолчанию — ещё не оплачено
        expense.updatedAt = Date()

        // Рассчитываем мой долг
        if let userId = currentUserId,
           sharedWith.contains(where: { $0.id == userId }) {
            expense.myDebtAmount = NSDecimalNumber(decimal: amount / Decimal(sharedWith.count))
        } else {
            expense.myDebtAmount = nil
        }

        // Автоматически привязываем расход к дню поездки по дате
        let dayRequest: NSFetchRequest<DayPlan> = DayPlan.fetchRequest()
        let startOfDay = Calendar.current.startOfDay(for: date)
        let endOfDay   = Calendar.current.date(byAdding: .day, value: 1, to: startOfDay) ?? date
        dayRequest.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "trip == %@", trip),
            NSPredicate(format: "date >= %@ AND date < %@", startOfDay as CVarArg, endOfDay as CVarArg)
        ])
        if let matchingDay = (try? context.fetch(dayRequest))?.first {
            expense.dayPlan = matchingDay
        }

        save()
        fetch()
        HapticFeedback.success()
        ReviewManager.triggerAfterExpenseAdded()

        enqueueSync { await SyncService.shared.uploadExpense(expense) }
    }

    // MARK: - Delete

    func deleteExpense(_ expense: Expense) {
        enqueueSync { await SyncService.shared.deleteExpense(expense) }
        context.delete(expense)
        save()
        fetch()
    }

    // MARK: - Analytics

    var totalAmount: Decimal {
        expenses.reduce(Decimal(0)) { $0 + (($1.amount as Decimal?) ?? 0) }
    }

    var amountByCategory: [String: Decimal] {
        Dictionary(grouping: expenses.compactMap { expense -> (String, Expense)? in
            guard let category = expense.category else { return nil }
            return (category, expense)
        }, by: { $0.0 })
            .mapValues { list in
                list.reduce(Decimal(0)) { $0 + (($1.1.amount as Decimal?) ?? 0) }
            }
    }

    var expensesByDay: [(date: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: expenses) { expense -> Date in
            calendar.startOfDay(for: expense.date ?? Date())
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, expenses: $0.value) }
    }

    // MARK: - Debt calculation
    func calculateDebts(
        participants: [Participant],
        baseCurrency: String = "USD",
        currentParticipantID: UUID? = nil
    ) -> [DebtSummary] {
        let currencyService = CurrencyService.shared
        var balance: [UUID: Decimal] = [:]
        participants.compactMap { $0.id }.forEach { balance[$0] = 0 }

        for expense in expenses {
            guard expense.isShared,
                  let payerID = expense.paidBy?.id,
                  let rawAmount = expense.amount as Decimal? else { continue }
            let expenseCurrency = expense.currency ?? baseCurrency
            let amount = currencyService.convert(rawAmount, from: expenseCurrency, to: baseCurrency)

            var sharedIDs: [UUID]
            if let ids = expense.sharedWithParticipantIDs as? [UUID], !ids.isEmpty {
                sharedIDs = ids
            } else {
                sharedIDs = participants.compactMap { $0.id }
            }

            if let pid = currentParticipantID,
               (expense.debtStatus ?? "pending") == "paid",
               sharedIDs.contains(pid) {
                sharedIDs.removeAll { $0 == pid }
            }

            guard !sharedIDs.isEmpty else { continue }
            let perPerson = amount / Decimal(sharedIDs.count)

            balance[payerID, default: 0] += amount
            sharedIDs.forEach { balance[$0, default: 0] -= perPerson }
        }

        var debts: [DebtSummary] = []
        var creditors = balance.filter { $0.value > 0 }.sorted { $0.value > $1.value }
        var debtors  = balance.filter { $0.value < 0 }.sorted { $0.value < $1.value }

        var ci = 0
        var di = 0
        while ci < creditors.count && di < debtors.count {
            let creditorID = creditors[ci].key
            let debtorID   = debtors[di].key
            let credAmt    = creditors[ci].value
            let debtAmt    = abs(debtors[di].value)
            let settled    = min(credAmt, debtAmt)

            guard let creditor = participants.first(where: { $0.id == creditorID }),
                  let debtor   = participants.first(where: { $0.id == debtorID }) else {
                ci += 1; continue
            }

            debts.append(DebtSummary(from: debtor, to: creditor, amount: settled))
            creditors[ci] = (creditorID, credAmt - settled)
            debtors[di]   = (debtorID, -(debtAmt - settled))

            if creditors[ci].value <= 0 { ci += 1 }
            if abs(debtors[di].value) <= 0 { di += 1 }
        }
        return debts
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
            errorMessage = "Не удалось сохранить расход"
        }
    }
}
