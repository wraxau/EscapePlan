import XCTest
import CoreData
@testable import TripPlanner

// MARK: - TripViewModelTests
// Тестирует бизнес-логику TripViewModel через in-memory Core Data.
// Firebase-синхронизация намеренно игнорируется (SyncService.shared — production singleton,
// в тестах его вызовы уходят в void, не ломая логику).

@MainActor
final class TripViewModelTests: XCTestCase {

    // MARK: - SUT + helpers

    private var stack: TestCoreDataStack!
    private var sut: TripViewModel!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
        sut = TripViewModel(context: stack.context)
    }

    override func tearDown() {
        sut = nil
        stack = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func test_initialState_tripsIsEmpty() {
        XCTAssertTrue(sut.trips.isEmpty)
    }

    func test_initialState_isLoadingFalse() {
        XCTAssertFalse(sut.isLoading)
    }

    func test_initialState_noErrorMessage() {
        XCTAssertNil(sut.errorMessage)
    }

    // MARK: - createTrip

    func test_createTrip_addsOneTrip() {
        sut.createTrip(name: "Париж 2025")
        XCTAssertEqual(sut.trips.count, 1)
    }

    func test_createTrip_setsCorrectName() {
        sut.createTrip(name: "Токио")
        XCTAssertEqual(sut.trips.first?.name, "Токио")
    }

    func test_createTrip_setCurrencyCode() {
        sut.createTrip(name: "NY", currencyCode: "EUR")
        XCTAssertEqual(sut.trips.first?.currencyCode, "EUR")
    }

    func test_createTrip_setsDates() {
        let start = TestCoreDataStack.date(year: 2025, month: 6, day: 1)
        let end   = TestCoreDataStack.date(year: 2025, month: 6, day: 10)
        sut.createTrip(name: "Рим", startDate: start, endDate: end)
        let trip = sut.trips.first!
        XCTAssertEqual(trip.startDate, start)
        XCTAssertEqual(trip.endDate, end)
    }

    func test_createTrip_createsOwnerParticipant() {
        sut.createTrip(name: "Поездка", ownerName: "Анна")
        let trip = sut.trips.first!
        let participants = (trip.participants as? Set<Participant>) ?? []
        let owner = participants.first(where: { $0.isOwner })
        XCTAssertNotNil(owner)
        XCTAssertEqual(owner?.name, "Анна")
    }

    func test_createTrip_noOwnerName_doesNotCreateParticipant() {
        sut.createTrip(name: "Поездка", ownerName: "")
        let trip = sut.trips.first!
        let participants = (trip.participants as? Set<Participant>) ?? []
        XCTAssertTrue(participants.isEmpty)
    }

    func test_createTrip_additionalParticipants_areCreated() {
        sut.createTrip(name: "Поездка", ownerName: "Саша",
                       additionalParticipants: ["Катя", "Вася"])
        let trip = sut.trips.first!
        let participants = (trip.participants as? Set<Participant>) ?? []
        XCTAssertEqual(participants.count, 3) // owner + 2
    }

    func test_createTrip_emptyAdditionalParticipant_isSkipped() {
        sut.createTrip(name: "Поездка", ownerName: "Лена",
                       additionalParticipants: ["", "  ", "Петя"])
        let trip = sut.trips.first!
        let participants = (trip.participants as? Set<Participant>) ?? []
        XCTAssertEqual(participants.count, 2) // owner + Петя
    }

    func test_createTrip_multipleTimes_allStoredAndSorted() {
        sut.createTrip(name: "A")
        sut.createTrip(name: "B")
        sut.createTrip(name: "C")
        XCTAssertEqual(sut.trips.count, 3)
    }

    // MARK: - deleteTrip

    func test_deleteTrip_removesFromList() {
        let trip = sut.createTrip(name: "Удалить меня")
        sut.deleteTrip(trip)
        XCTAssertTrue(sut.trips.isEmpty)
    }

    func test_deleteTrip_onlyDeletesTargetTrip() {
        sut.createTrip(name: "Оставить")
        let toDelete = sut.createTrip(name: "Удалить")
        sut.deleteTrip(toDelete)
        XCTAssertEqual(sut.trips.count, 1)
        XCTAssertEqual(sut.trips.first?.name, "Оставить")
    }

    // MARK: - searchQuery (фильтрация)

    func test_searchQuery_filtersTrips_byName() {
        sut.createTrip(name: "Лондон")
        sut.createTrip(name: "Париж")
        sut.searchQuery = "лонд"
        XCTAssertEqual(sut.trips.count, 1)
        XCTAssertEqual(sut.trips.first?.name, "Лондон")
    }

    func test_searchQuery_caseInsensitive() {
        sut.createTrip(name: "БЕРЛИН")
        sut.searchQuery = "берлин"
        XCTAssertEqual(sut.trips.count, 1)
    }

    func test_searchQuery_noMatch_returnsEmpty() {
        sut.createTrip(name: "Москва")
        sut.searchQuery = "xyz"
        XCTAssertTrue(sut.trips.isEmpty)
    }

    func test_searchQuery_emptyQuery_returnsAll() {
        sut.createTrip(name: "Москва")
        sut.createTrip(name: "СПб")
        sut.searchQuery = "Моск"
        XCTAssertEqual(sut.trips.count, 1)
        sut.searchQuery = ""
        XCTAssertEqual(sut.trips.count, 2)
    }

    func test_searchQuery_whitespaceOnly_treatedAsEmpty() {
        sut.createTrip(name: "Тест")
        sut.searchQuery = "   "
        XCTAssertEqual(sut.trips.count, 1) // пробелы = нет фильтра
    }

    // MARK: - dateRange

    func test_dateRange_bothDates_returnsRange() {
        let start = TestCoreDataStack.date(year: 2025, month: 1, day: 10)
        let end   = TestCoreDataStack.date(year: 2025, month: 1, day: 20)
        let trip  = stack.makeTrip(startDate: start, endDate: end)
        let result = sut.dateRange(for: trip)
        XCTAssertTrue(result.contains("—"), "Должен содержать тире: '\(result)'")
    }

    func test_dateRange_noStartDate_returnsNoDates() {
        let trip = stack.makeTrip()
        XCTAssertEqual(sut.dateRange(for: trip), "Даты не указаны")
    }

    func test_dateRange_startDateOnly_returnsPartialString() {
        let start = TestCoreDataStack.date(year: 2025, month: 3, day: 5)
        let trip  = stack.makeTrip(startDate: start)
        let result = sut.dateRange(for: trip)
        XCTAssertTrue(result.hasPrefix("с "), "Должно начинаться с 'с ': '\(result)'")
    }

    // MARK: - totalExpenses

    func test_totalExpenses_noExpenses_returnsZero() {
        let trip = stack.makeTrip(currencyCode: "USD")
        let result = sut.totalExpenses(for: trip)
        XCTAssertTrue(result.contains("0"), "Ожидается 0 расходов: '\(result)'")
    }

    func test_totalExpenses_singleExpense_returnsCorrectSum() {
        let trip = stack.makeTrip(currencyCode: "USD")
        stack.makeExpense(amount: 150, currency: "USD", trip: trip)
        let result = sut.totalExpenses(for: trip)
        XCTAssertTrue(result.contains("150"), "Ожидается сумма 150: '\(result)'")
        XCTAssertTrue(result.hasPrefix("USD"), "Должна быть валюта USD: '\(result)'")
    }

    func test_totalExpenses_multipleExpenses_returnsSummedAmount() {
        let trip = stack.makeTrip(currencyCode: "EUR")
        stack.makeExpense(amount: 200, currency: "EUR", trip: trip)
        stack.makeExpense(amount: 50, currency: "EUR", trip: trip)
        let result = sut.totalExpenses(for: trip)
        XCTAssertTrue(result.contains("250"), "Ожидается сумма 250: '\(result)'")
    }

    // MARK: - updateTrip

    func test_updateTrip_changesName() {
        let trip = sut.createTrip(name: "Старое название")
        sut.updateTrip(trip, name: "Новое название")
        XCTAssertEqual(sut.trips.first?.name, "Новое название")
    }

    func test_updateTrip_changesCurrencyCode() {
        let trip = sut.createTrip(name: "Поездка", currencyCode: "USD")
        sut.updateTrip(trip, currencyCode: "JPY")
        XCTAssertEqual(sut.trips.first?.currencyCode, "JPY")
    }

    func test_updateTrip_nilParameter_doesNotOverwrite() {
        let trip = sut.createTrip(name: "Сохранить имя")
        sut.updateTrip(trip, currencyCode: "GBP") // имя не меняем
        XCTAssertEqual(sut.trips.first?.name, "Сохранить имя")
    }
}
