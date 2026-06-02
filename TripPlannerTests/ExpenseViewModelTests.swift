import XCTest
import CoreData
@testable import TripPlanner

// MARK: - ExpenseViewModelTests

@MainActor
final class ExpenseViewModelTests: XCTestCase {

    // MARK: - SUT + helpers

    private var stack: TestCoreDataStack!
    private var trip: Trip!
    private var sut: ExpenseViewModel!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        trip  = stack.makeTrip(name: "Тест-трип", currencyCode: "USD")
        sut   = ExpenseViewModel(trip: trip, context: stack.context)
    }

    override func tearDown() {
        sut   = nil
        trip  = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_expensesIsEmpty() {
        XCTAssertTrue(sut.expenses.isEmpty)
    }

    func test_initialState_totalAmountIsZero() {
        XCTAssertEqual(sut.totalAmount, 0)
    }

    // MARK: - addExpense

    func test_addExpense_addsOneExpense() {
        sut.addExpense(amount: 100, category: .cafe)
        XCTAssertEqual(sut.expenses.count, 1)
    }

    func test_addExpense_setsAmountCorrectly() {
        sut.addExpense(amount: 250, category: .transport)
        XCTAssertEqual(sut.expenses.first?.amount as Decimal?, 250)
    }

    func test_addExpense_setsCategoryCorrectly() {
        sut.addExpense(amount: 50, category: .housing)
        XCTAssertEqual(sut.expenses.first?.category, ExpenseCategory.housing.rawValue)
    }

    func test_addExpense_setsCurrencyCorrectly() {
        sut.addExpense(amount: 80, category: .cafe, currency: "EUR")
        XCTAssertEqual(sut.expenses.first?.currency, "EUR")
    }

    func test_addExpense_multipleExpenses_allAdded() {
        sut.addExpense(amount: 10, category: .cafe)
        sut.addExpense(amount: 20, category: .transport)
        sut.addExpense(amount: 30, category: .excursion)
        XCTAssertEqual(sut.expenses.count, 3)
    }

    func test_addExpense_defaultCurrency_isUSD() {
        sut.addExpense(amount: 100, category: .cafe)
        XCTAssertEqual(sut.expenses.first?.currency, "USD")
    }

    // MARK: - deleteExpense

    func test_deleteExpense_removesFromList() {
        sut.addExpense(amount: 100, category: .cafe)
        let expense = sut.expenses.first!
        sut.deleteExpense(expense)
        XCTAssertTrue(sut.expenses.isEmpty)
    }

    func test_deleteExpense_onlyDeletesTarget() {
        sut.addExpense(amount: 100, category: .cafe)
        sut.addExpense(amount: 200, category: .transport)
        let toDelete = sut.expenses.first!
        sut.deleteExpense(toDelete)
        XCTAssertEqual(sut.expenses.count, 1)
    }

    // MARK: - totalAmount

    func test_totalAmount_singleExpense() {
        sut.addExpense(amount: 123, category: .cafe)
        XCTAssertEqual(sut.totalAmount, 123)
    }

    func test_totalAmount_multipleExpenses_sumsCorrectly() {
        sut.addExpense(amount: 100, category: .cafe)
        sut.addExpense(amount: 55,  category: .transport)
        sut.addExpense(amount: 45,  category: .excursion)
        XCTAssertEqual(sut.totalAmount, 200)
    }

    func test_totalAmount_afterDelete_updatesCorrectly() {
        sut.addExpense(amount: 300, category: .cafe)
        sut.addExpense(amount: 100, category: .transport)
        let toDelete = sut.expenses.first { $0.amount as Decimal? == 100 }!
        sut.deleteExpense(toDelete)
        XCTAssertEqual(sut.totalAmount, 300)
    }

    // MARK: - amountByCategory

    func test_amountByCategory_groupsCorrectly() {
        sut.addExpense(amount: 100, category: .cafe)
        sut.addExpense(amount: 50,  category: .cafe)
        sut.addExpense(amount: 200, category: .transport)
        let byCategory = sut.amountByCategory
        XCTAssertEqual(byCategory[ExpenseCategory.cafe.rawValue], 150)
        XCTAssertEqual(byCategory[ExpenseCategory.transport.rawValue], 200)
    }

    func test_amountByCategory_emptyExpenses_returnsEmptyDict() {
        XCTAssertTrue(sut.amountByCategory.isEmpty)
    }

    func test_amountByCategory_singleCategory_onlyOneKey() {
        sut.addExpense(amount: 10, category: .cafe)
        sut.addExpense(amount: 20, category: .cafe)
        XCTAssertEqual(sut.amountByCategory.count, 1)
    }

    // MARK: - expensesByDay

    func test_expensesByDay_sameDay_groupedTogether() {
        let today = Calendar.current.startOfDay(for: Date())
        sut.addExpense(amount: 10, category: .cafe, date: today)
        sut.addExpense(amount: 20, category: .cafe, date: today.addingTimeInterval(3600)) // +1 ч
        let groups = sut.expensesByDay
        XCTAssertEqual(groups.count, 1)
        XCTAssertEqual(groups.first?.expenses.count, 2)
    }

    func test_expensesByDay_differentDays_separatedIntoGroups() {
        let today     = Calendar.current.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(-86400)
        sut.addExpense(amount: 10, category: .cafe, date: today)
        sut.addExpense(amount: 20, category: .cafe, date: yesterday)
        let groups = sut.expensesByDay
        XCTAssertEqual(groups.count, 2)
    }

    func test_expensesByDay_sortedNewestFirst() {
        let today     = Calendar.current.startOfDay(for: Date())
        let yesterday = today.addingTimeInterval(-86400)
        sut.addExpense(amount: 10, category: .cafe, date: yesterday)
        sut.addExpense(amount: 20, category: .cafe, date: today)
        let groups = sut.expensesByDay
        XCTAssertTrue(groups.first!.date >= groups.last!.date)
    }

    // MARK: - calculateDebts

    // Алиса платит 100, делит с Бобом — Боб должен 50 Алисе
    func test_calculateDebts_twoParticipants_onePayerShared() {
        let alice = stack.makeParticipant(name: "Alice", trip: trip)
        let bob   = stack.makeParticipant(name: "Bob",   trip: trip)

        sut.addExpense(
            amount: 100,
            category: .cafe,
            isShared: true,
            paidBy: alice,
            sharedWith: [alice, bob]
        )
        sut.fetch()

        let debts = sut.calculateDebts(participants: [alice, bob])
        XCTAssertEqual(debts.count, 1)
        let debt = debts.first!
        XCTAssertEqual(debt.from.name, "Bob")
        XCTAssertEqual(debt.to.name,   "Alice")
        XCTAssertEqual(debt.amount, 50)
    }

    // Три участника, Алиса платит 90 за всех — каждый должен по 30
    func test_calculateDebts_threeParticipants_evenSplit() {
        let alice   = stack.makeParticipant(name: "Alice",   trip: trip)
        let bob     = stack.makeParticipant(name: "Bob",     trip: trip)
        let charlie = stack.makeParticipant(name: "Charlie", trip: trip)

        sut.addExpense(
            amount: 90,
            category: .cafe,
            isShared: true,
            paidBy: alice,
            sharedWith: [alice, bob, charlie]
        )
        sut.fetch()

        let debts = sut.calculateDebts(participants: [alice, bob, charlie])
        let totalOwed = debts.reduce(Decimal(0)) { $0 + $1.amount }
        // Алиса отдала 90, заплатила 30 за себя — ей должны 60 = 30+30
        XCTAssertEqual(totalOwed, 60)
    }

    // Нет совместных расходов — долгов нет
    func test_calculateDebts_noSharedExpenses_returnsEmpty() {
        let alice = stack.makeParticipant(name: "Alice", trip: trip)
        let bob   = stack.makeParticipant(name: "Bob",   trip: trip)

        sut.addExpense(amount: 50, category: .cafe, isShared: false, paidBy: alice)
        sut.fetch()

        let debts = sut.calculateDebts(participants: [alice, bob])
        XCTAssertTrue(debts.isEmpty)
    }

    // Взаимные долги упрощаются:
    // Алиса платит 100 за всех, Боб платит 60 за всех — итого Боб должен 20
    func test_calculateDebts_mutualDebts_areSimplified() {
        let alice = stack.makeParticipant(name: "Alice", trip: trip)
        let bob   = stack.makeParticipant(name: "Bob",   trip: trip)

        sut.addExpense(
            amount: 100,
            category: .cafe,
            isShared: true,
            paidBy: alice,
            sharedWith: [alice, bob]  // каждый по 50
        )
        sut.addExpense(
            amount: 60,
            category: .transport,
            isShared: true,
            paidBy: bob,
            sharedWith: [alice, bob]  // каждый по 30
        )
        sut.fetch()

        // alice: заплатила 100, должна получить 50 от bob; должна 30 bob — нетто +20
        // bob: заплатил 60, должен 50 alice; получит 30 от alice — нетто -20
        let debts = sut.calculateDebts(participants: [alice, bob])
        XCTAssertEqual(debts.count, 1)
        XCTAssertEqual(debts.first?.amount, 20)
        XCTAssertEqual(debts.first?.from.name, "Bob")
        XCTAssertEqual(debts.first?.to.name,   "Alice")
    }

    // Пустой список участников — нет долгов
    func test_calculateDebts_emptyParticipants_returnsEmpty() {
        sut.addExpense(amount: 100, category: .cafe, isShared: true)
        sut.fetch()
        let debts = sut.calculateDebts(participants: [])
        XCTAssertTrue(debts.isEmpty)
    }

    // Нет расходов — нет долгов
    func test_calculateDebts_noExpenses_returnsEmpty() {
        let alice = stack.makeParticipant(name: "Alice", trip: trip)
        let bob   = stack.makeParticipant(name: "Bob",   trip: trip)
        let debts = sut.calculateDebts(participants: [alice, bob])
        XCTAssertTrue(debts.isEmpty)
    }

    // MARK: - getAllCurrencies

    func test_getAllCurrencies_containsUSD() {
        XCTAssertTrue(getAllCurrencies().contains("USD"))
    }

    func test_getAllCurrencies_containsEUR() {
        XCTAssertTrue(getAllCurrencies().contains("EUR"))
    }

    func test_getAllCurrencies_hasAtLeast10Currencies() {
        XCTAssertGreaterThanOrEqual(getAllCurrencies().count, 10)
    }

    func test_getAllCurrencies_noDuplicates() {
        let currencies = getAllCurrencies()
        let unique = Set(currencies)
        XCTAssertEqual(currencies.count, unique.count)
    }
}
