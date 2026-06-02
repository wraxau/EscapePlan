import CoreData
import Foundation
@testable import TripPlanner

// MARK: - In-Memory Core Data Stack для тестов

/// Создаёт изолированный in-memory контейнер — каждый тест начинает с чистого листа.
/// Используется как синглтон внутри одного теста:
///   let stack = TestCoreDataStack()
///   let context = stack.context
final class TestCoreDataStack {

    // MARK: - Container

    let container: NSPersistentContainer

    /// Основной контекст (mainQueueConcurrencyType)
    var context: NSManagedObjectContext { container.viewContext }

    // MARK: - Init

    init(modelName: String = "TripPlanner") {
        container = NSPersistentContainer(name: modelName)

        // Заменяем постоянное хранилище на in-memory
        let description = NSPersistentStoreDescription()
        description.type = NSInMemoryStoreType
        description.shouldAddStoreAsynchronously = false
        container.persistentStoreDescriptions = [description]

        container.loadPersistentStores { _, error in
            if let error {
                fatalError("TestCoreDataStack: не удалось загрузить хранилище: \(error)")
            }
        }

        container.viewContext.automaticallyMergesChangesFromParent = true
    }

    // MARK: - Helpers

    /// Создаёт Trip с минимально необходимыми полями
    @discardableResult
    func makeTrip(
        name: String = "Test Trip",
        startDate: Date? = nil,
        endDate: Date? = nil,
        currencyCode: String = "USD",
        peopleNumber: Int32 = 1
    ) -> Trip {
        let trip = Trip(context: context)
        trip.id = UUID()
        trip.name = name
        trip.startDate = startDate
        trip.endDate = endDate
        trip.currencyCode = currencyCode
        trip.peopleNumber = peopleNumber
        trip.createdAt = Date()
        trip.updatedAt = Date()
        trip.isSynced = false
        try? context.save()
        return trip
    }

    /// Создаёт Participant привязанного к поездке
    @discardableResult
    func makeParticipant(
        name: String = "Alice",
        isOwner: Bool = false,
        trip: Trip
    ) -> Participant {
        let p = Participant(context: context)
        p.id = UUID()
        p.name = name
        p.isOwner = isOwner
        p.isSynced = false
        p.trip = trip
        try? context.save()
        return p
    }

    /// Создаёт Expense привязанный к поездке и участнику
    @discardableResult
    func makeExpense(
        amount: Decimal = 100,
        category: String = ExpenseCategory.food.rawValue,
        currency: String = "USD",
        date: Date = Date(),
        isShared: Bool = false,
        paidBy: Participant? = nil,
        trip: Trip
    ) -> Expense {
        let expense = Expense(context: context)
        expense.id = UUID()
        expense.amount = NSDecimalNumber(decimal: amount)
        expense.category = category
        expense.currency = currency
        expense.date = date
        expense.isShared = isShared
        expense.paidBy = paidBy
        expense.trip = trip
        expense.isSynced = false
        expense.debtStatus = "pending"
        expense.updatedAt = Date()
        try? context.save()
        return expense
    }

    /// Создаёт DayPlan привязанный к поездке
    @discardableResult
    func makeDayPlan(date: Date, trip: Trip) -> DayPlan {
        let day = DayPlan(context: context)
        day.id = UUID()
        day.date = date
        day.trip = trip
        day.isSynced = false
        try? context.save()
        return day
    }

    // MARK: - Date helpers

    /// Возвращает Date из компонентов (год, месяц, день) в текущем календаре
    static func date(year: Int, month: Int, day: Int) -> Date {
        var comps = DateComponents()
        comps.year = year
        comps.month = month
        comps.day = day
        return Calendar.current.date(from: comps)!
    }
}
