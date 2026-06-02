import XCTest
@testable import TripPlanner

// MARK: - AuthErrorTests
// Тестирует AuthError: описания ошибок и маппинг NSError-кодов

final class AuthErrorTests: XCTestCase {

    // MARK: - errorDescription

    func test_invalidCredentials_hasDescription() {
        let error = AuthError.invalidCredentials
        XCTAssertEqual(error.errorDescription, "Неверный email или пароль")
    }

    func test_emailAlreadyExists_hasDescription() {
        let error = AuthError.emailAlreadyExists
        XCTAssertEqual(error.errorDescription, "Этот email уже зарегистрирован")
    }

    func test_weakPassword_hasDescription() {
        let error = AuthError.weakPassword
        XCTAssertEqual(error.errorDescription, "Пароль должен быть не менее 6 символов")
    }

    func test_networkError_hasDescription() {
        let error = AuthError.networkError
        XCTAssertEqual(error.errorDescription, "Нет соединения. Проверь интернет")
    }

    func test_unknown_containsPassedMessage() {
        let message = "Something unexpected"
        let error = AuthError.unknown(message)
        XCTAssertEqual(error.errorDescription, message)
    }

    func test_allErrors_haveNonEmptyDescriptions() {
        let errors: [AuthError] = [
            .invalidCredentials,
            .emailAlreadyExists,
            .weakPassword,
            .networkError,
            .unknown("test")
        ]
        for error in errors {
            XCTAssertFalse(
                error.errorDescription?.isEmpty ?? true,
                "У \(error) нет описания"
            )
        }
    }

    // MARK: - LocalizedError conformance

    func test_authError_conformsToLocalizedError() {
        let error: Error = AuthError.weakPassword
        XCTAssertNotNil((error as? LocalizedError)?.errorDescription)
    }

    // MARK: - unknown case

    func test_unknown_emptyMessage_returnsEmptyDescription() {
        let error = AuthError.unknown("")
        XCTAssertEqual(error.errorDescription, "")
    }

    func test_unknown_longMessage_preservedUnchanged() {
        let long = String(repeating: "x", count: 500)
        let error = AuthError.unknown(long)
        XCTAssertEqual(error.errorDescription?.count, 500)
    }
}

// MARK: - DebtSummaryTests
// Тестирует модель DebtSummary

final class DebtSummaryTests: XCTestCase {

    func test_debtSummary_hasUniqueID() {
        let stack = TestCoreDataStack()
        let trip  = stack.makeTrip()
        let alice = stack.makeParticipant(name: "Alice", trip: trip)
        let bob   = stack.makeParticipant(name: "Bob",   trip: trip)

        let d1 = DebtSummary(from: alice, to: bob,   amount: 50)
        let d2 = DebtSummary(from: bob,   to: alice, amount: 30)
        XCTAssertNotEqual(d1.id, d2.id)
    }

    func test_debtSummary_storesAmountCorrectly() {
        let stack = TestCoreDataStack()
        let trip  = stack.makeTrip()
        let alice = stack.makeParticipant(name: "Alice", trip: trip)
        let bob   = stack.makeParticipant(name: "Bob",   trip: trip)
        let debt  = DebtSummary(from: bob, to: alice, amount: Decimal(string: "123.45")!)
        XCTAssertEqual(debt.amount, Decimal(string: "123.45"))
    }
}
