import XCTest
@testable import TripPlanner

// MARK: - ValidatorsTests
// Чистая логика — Firebase/CoreData не нужны

final class ValidatorsTests: XCTestCase {

    // MARK: - validateName

    func test_validateName_validName_doesNotThrow() {
        XCTAssertNoThrow(try Validators.validateName("Мой Отпуск"))
    }

    func test_validateName_emptyString_throwsEmptyName() {
        XCTAssertThrowsError(try Validators.validateName("")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName)
        }
    }

    func test_validateName_whitespaceOnly_throwsEmptyName() {
        XCTAssertThrowsError(try Validators.validateName("   ")) { error in
            XCTAssertEqual(error as? ValidationError, .emptyName)
        }
    }

    func test_validateName_exactlyMaxLength_doesNotThrow() {
        let name = String(repeating: "A", count: 100)
        XCTAssertNoThrow(try Validators.validateName(name))
    }

    func test_validateName_exceedsMaxLength_throwsNameTooLong() {
        let name = String(repeating: "A", count: 101)
        XCTAssertThrowsError(try Validators.validateName(name)) { error in
            XCTAssertEqual(error as? ValidationError, .nameTooLong(max: 100))
        }
    }

    func test_validateName_customMaxLength_respected() {
        XCTAssertThrowsError(try Validators.validateName("Hello", maxLength: 3)) { error in
            XCTAssertEqual(error as? ValidationError, .nameTooLong(max: 3))
        }
    }

    // MARK: - validateEmail

    func test_validateEmail_validEmail_doesNotThrow() {
        XCTAssertNoThrow(try Validators.validateEmail("user@example.com"))
    }

    func test_validateEmail_validEmailWithPlus_doesNotThrow() {
        XCTAssertNoThrow(try Validators.validateEmail("user+tag@mail.co"))
    }

    func test_validateEmail_emptyString_throwsInvalidEmail() {
        XCTAssertThrowsError(try Validators.validateEmail("")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidEmail)
        }
    }

    func test_validateEmail_noAtSign_throwsInvalidEmail() {
        XCTAssertThrowsError(try Validators.validateEmail("userexample.com")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidEmail)
        }
    }

    func test_validateEmail_noDomain_throwsInvalidEmail() {
        XCTAssertThrowsError(try Validators.validateEmail("user@")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidEmail)
        }
    }

    func test_validateEmail_noTLD_throwsInvalidEmail() {
        XCTAssertThrowsError(try Validators.validateEmail("user@example")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidEmail)
        }
    }

    func test_validateEmail_whitespaceAround_doesNotThrow() {
        // Validators trim перед проверкой
        XCTAssertNoThrow(try Validators.validateEmail("  user@example.com  "))
    }

    // MARK: - validateAmount

    func test_validateAmount_validAmount_returnsDecimal() throws {
        let result = try Validators.validateAmount("123.45")
        XCTAssertEqual(result, Decimal(string: "123.45"))
    }

    func test_validateAmount_integerString_returnsDecimal() throws {
        let result = try Validators.validateAmount("500")
        XCTAssertEqual(result, 500)
    }

    func test_validateAmount_zero_throwsAmountTooSmall() {
        XCTAssertThrowsError(try Validators.validateAmount("0")) { error in
            XCTAssertEqual(error as? ValidationError, .amountTooSmall)
        }
    }

    func test_validateAmount_negative_throwsAmountTooSmall() {
        XCTAssertThrowsError(try Validators.validateAmount("-10")) { error in
            XCTAssertEqual(error as? ValidationError, .amountTooSmall)
        }
    }

    func test_validateAmount_tooLarge_throwsAmountTooLarge() {
        XCTAssertThrowsError(try Validators.validateAmount("1000000")) { error in
            XCTAssertEqual(error as? ValidationError, .amountTooLarge)
        }
    }

    func test_validateAmount_maxAllowed_doesNotThrow() throws {
        let result = try Validators.validateAmount("999999")
        XCTAssertEqual(result, 999999)
    }

    func test_validateAmount_notANumber_throwsInvalidAmount() {
        XCTAssertThrowsError(try Validators.validateAmount("abc")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidAmount)
        }
    }

    func test_validateAmount_whitespace_throwsInvalidAmount() {
        XCTAssertThrowsError(try Validators.validateAmount("   ")) { error in
            XCTAssertEqual(error as? ValidationError, .invalidAmount)
        }
    }

    // MARK: - validateDateRange

    func test_validateDateRange_startBeforeEnd_doesNotThrow() {
        let start = Date()
        let end = start.addingTimeInterval(86400) // +1 день
        XCTAssertNoThrow(try Validators.validateDateRange(start: start, end: end))
    }

    func test_validateDateRange_sameDate_doesNotThrow() {
        let date = Date()
        XCTAssertNoThrow(try Validators.validateDateRange(start: date, end: date))
    }

    func test_validateDateRange_endBeforeStart_throwsEndDateBeforeStart() {
        let start = Date()
        let end = start.addingTimeInterval(-86400) // -1 день
        XCTAssertThrowsError(try Validators.validateDateRange(start: start, end: end)) { error in
            XCTAssertEqual(error as? ValidationError, .endDateBeforeStart)
        }
    }

    // MARK: - validateDateNotInPast

    func test_validateDateNotInPast_today_doesNotThrow() {
        XCTAssertNoThrow(try Validators.validateDateNotInPast(Date()))
    }

    func test_validateDateNotInPast_tomorrow_doesNotThrow() {
        let tomorrow = Date().addingTimeInterval(86400)
        XCTAssertNoThrow(try Validators.validateDateNotInPast(tomorrow))
    }

    func test_validateDateNotInPast_yesterday_throwsDateInPast() {
        let yesterday = Date().addingTimeInterval(-86400)
        XCTAssertThrowsError(try Validators.validateDateNotInPast(yesterday)) { error in
            XCTAssertEqual(error as? ValidationError, .dateInPast)
        }
    }

    // MARK: - String.isEmptyOrWhitespace

    func test_isEmptyOrWhitespace_emptyString_returnsTrue() {
        XCTAssertTrue("".isEmptyOrWhitespace)
    }

    func test_isEmptyOrWhitespace_whitespaceString_returnsTrue() {
        XCTAssertTrue("   ".isEmptyOrWhitespace)
    }

    func test_isEmptyOrWhitespace_normalString_returnsFalse() {
        XCTAssertFalse("Hello".isEmptyOrWhitespace)
    }

    // MARK: - ValidationError messages

    func test_validationError_descriptions_areNotEmpty() {
        let errors: [ValidationError] = [
            .emptyName,
            .nameTooLong(max: 50),
            .invalidEmail,
            .invalidAmount,
            .amountTooSmall,
            .amountTooLarge,
            .invalidDate,
            .dateInPast,
            .endDateBeforeStart
        ]
        for error in errors {
            XCTAssertFalse(
                error.errorDescription?.isEmpty ?? true,
                "У \(error) нет описания"
            )
        }
    }
}
