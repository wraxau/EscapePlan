import XCTest
import CoreData
@testable import TripPlanner

// MARK: - DayPlanViewModelTests

@MainActor
final class DayPlanViewModelTests: XCTestCase {

    // MARK: - SUT + helpers

    private var stack: TestCoreDataStack!
    private var trip: Trip!
    private var sut: DayPlanViewModel!

    override func setUp() {
        super.setUp()
        stack = TestCoreDataStack()
    }

    override func tearDown() {
        sut   = nil
        trip  = nil
        stack = nil
        super.tearDown()
    }

    /// Создаёт trip с указанными датами и инициализирует sut
    private func makeSUT(startDate: Date? = nil, endDate: Date? = nil) {
        trip = stack.makeTrip(startDate: startDate, endDate: endDate)
        sut  = DayPlanViewModel(trip: trip, context: stack.context)
    }

    // MARK: - Initial state

    func test_initialState_dayPlansIsEmpty() {
        makeSUT()
        XCTAssertTrue(sut.dayPlans.isEmpty)
    }

    // MARK: - addDayPlan

    func test_addDayPlan_addsOnePlan() {
        makeSUT()
        sut.addDayPlan(date: Date())
        XCTAssertEqual(sut.dayPlans.count, 1)
    }

    func test_addDayPlan_setsDateCorrectly() {
        makeSUT()
        let date = TestCoreDataStack.date(year: 2025, month: 8, day: 15)
        sut.addDayPlan(date: date)
        XCTAssertEqual(
            Calendar.current.startOfDay(for: sut.dayPlans.first!.date!),
            Calendar.current.startOfDay(for: date)
        )
    }

    func test_addDayPlan_withNotes_setsNotesCorrectly() {
        makeSUT()
        sut.addDayPlan(date: Date(), notes: "Экскурсия")
        XCTAssertEqual(sut.dayPlans.first?.notes, "Экскурсия")
    }

    func test_addDayPlan_multipleDays_sortedAscending() {
        makeSUT()
        let d1 = TestCoreDataStack.date(year: 2025, month: 5, day: 3)
        let d2 = TestCoreDataStack.date(year: 2025, month: 5, day: 1)
        let d3 = TestCoreDataStack.date(year: 2025, month: 5, day: 2)
        sut.addDayPlan(date: d1)
        sut.addDayPlan(date: d2)
        sut.addDayPlan(date: d3)
        let dates = sut.dayPlans.compactMap { $0.date }
        XCTAssertEqual(dates, dates.sorted())
    }

    // MARK: - generateDaysFromTripDates

    func test_generateDays_3DayTrip_creates3Days() {
        let start = TestCoreDataStack.date(year: 2025, month: 7, day: 10)
        let end   = TestCoreDataStack.date(year: 2025, month: 7, day: 12)
        makeSUT(startDate: start, endDate: end)
        sut.generateDaysFromTripDates()
        XCTAssertEqual(sut.dayPlans.count, 3)
    }

    func test_generateDays_singleDayTrip_creates1Day() {
        let date = TestCoreDataStack.date(year: 2025, month: 9, day: 1)
        makeSUT(startDate: date, endDate: date)
        sut.generateDaysFromTripDates()
        XCTAssertEqual(sut.dayPlans.count, 1)
    }

    func test_generateDays_noDates_createsNoDays() {
        makeSUT() // без дат
        sut.generateDaysFromTripDates()
        XCTAssertTrue(sut.dayPlans.isEmpty)
    }

    func test_generateDays_noDuplicates_calledTwice() {
        let start = TestCoreDataStack.date(year: 2025, month: 6, day: 1)
        let end   = TestCoreDataStack.date(year: 2025, month: 6, day: 5)
        makeSUT(startDate: start, endDate: end)
        sut.generateDaysFromTripDates()
        sut.generateDaysFromTripDates() // второй вызов не должен создавать дубли
        XCTAssertEqual(sut.dayPlans.count, 5)
    }

    func test_generateDays_datesAreConsecutive() {
        let start = TestCoreDataStack.date(year: 2025, month: 4, day: 1)
        let end   = TestCoreDataStack.date(year: 2025, month: 4, day: 4)
        makeSUT(startDate: start, endDate: end)
        sut.generateDaysFromTripDates()
        let dates = sut.dayPlans.compactMap { Calendar.current.startOfDay(for: $0.date!) }
        for i in 0..<(dates.count - 1) {
            let diff = Calendar.current.dateComponents([.day], from: dates[i], to: dates[i + 1]).day
            XCTAssertEqual(diff, 1, "Дни должны идти подряд")
        }
    }

    func test_generateDays_10DayTrip_creates10Days() {
        let start = TestCoreDataStack.date(year: 2025, month: 8, day: 1)
        let end   = TestCoreDataStack.date(year: 2025, month: 8, day: 10)
        makeSUT(startDate: start, endDate: end)
        sut.generateDaysFromTripDates()
        XCTAssertEqual(sut.dayPlans.count, 10)
    }

    // MARK: - deleteDayPlan

    func test_deleteDayPlan_removesFromList() {
        makeSUT()
        sut.addDayPlan(date: Date())
        let day = sut.dayPlans.first!
        sut.deleteDayPlan(day)
        XCTAssertTrue(sut.dayPlans.isEmpty)
    }

    func test_deleteDayPlan_onlyDeletesTarget() {
        makeSUT()
        let d1 = TestCoreDataStack.date(year: 2025, month: 1, day: 1)
        let d2 = TestCoreDataStack.date(year: 2025, month: 1, day: 2)
        sut.addDayPlan(date: d1)
        sut.addDayPlan(date: d2)
        let toDelete = sut.dayPlans.first!
        sut.deleteDayPlan(toDelete)
        XCTAssertEqual(sut.dayPlans.count, 1)
    }

    // MARK: - dayNumber

    func test_dayNumber_firstDay_returnsOne() {
        let start = TestCoreDataStack.date(year: 2025, month: 6, day: 1)
        let end   = TestCoreDataStack.date(year: 2025, month: 6, day: 5)
        makeSUT(startDate: start, endDate: end)
        sut.generateDaysFromTripDates()
        let firstDay = sut.dayPlans.first!
        XCTAssertEqual(sut.dayNumber(for: firstDay), 1)
    }

    func test_dayNumber_lastDayOf5DayTrip_returnsFive() {
        let start = TestCoreDataStack.date(year: 2025, month: 6, day: 1)
        let end   = TestCoreDataStack.date(year: 2025, month: 6, day: 5)
        makeSUT(startDate: start, endDate: end)
        sut.generateDaysFromTripDates()
        let lastDay = sut.dayPlans.last!
        XCTAssertEqual(sut.dayNumber(for: lastDay), 5)
    }

    func test_dayNumber_middleDay_returnsCorrectNumber() {
        let start = TestCoreDataStack.date(year: 2025, month: 3, day: 10)
        let end   = TestCoreDataStack.date(year: 2025, month: 3, day: 17)
        makeSUT(startDate: start, endDate: end)
        sut.generateDaysFromTripDates()
        // День с датой 15 марта = 6-й день (10,11,12,13,14,15)
        let day15 = sut.dayPlans.first {
            Calendar.current.component(.day, from: $0.date!) == 15
        }!
        XCTAssertEqual(sut.dayNumber(for: day15), 6)
    }

    func test_dayNumber_noTripStartDate_returnsOne() {
        makeSUT() // без дат
        let orphanDay = stack.makeDayPlan(date: Date(), trip: trip)
        sut.fetch()
        XCTAssertEqual(sut.dayNumber(for: orphanDay), 1)
    }

    // MARK: - placesCount

    func test_placesCount_noActivities_returnsZero() {
        makeSUT()
        let day = stack.makeDayPlan(date: Date(), trip: trip)
        sut.fetch()
        XCTAssertEqual(sut.placesCount(for: day), 0)
    }
}
