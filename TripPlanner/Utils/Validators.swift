import Foundation

// MARK: - Validation Errors

enum ValidationError: LocalizedError, Equatable {
    case emptyName
    case nameTooLong(max: Int)
    case invalidEmail
    case invalidAmount
    case amountTooSmall
    case amountTooLarge
    case invalidDate
    case dateInPast
    case endDateBeforeStart
    case noParticipantsSelected
    case noTripSelected
    case noPayerSelected

    var errorDescription: String? {
        switch self {
        case .emptyName:
            return "Имя не может быть пустым"
        case .nameTooLong(let max):
            return "Имя не может быть длиннее \(max) символов"
        case .invalidEmail:
            return "Некорректный email адрес"
        case .invalidAmount:
            return "Сумма должна быть числом"
        case .amountTooSmall:
            return "Сумма должна быть больше нуля"
        case .amountTooLarge:
            return "Сумма слишком большая (макс 999 999)"
        case .invalidDate:
            return "Дата некорректна"
        case .dateInPast:
            return "Дата не может быть в прошлом"
        case .endDateBeforeStart:
            return "Дата окончания должна быть после даты начала"
        case .noParticipantsSelected:
            return "Выбери хотя бы одного участника для разделения расхода"
        case .noTripSelected:
            return "Выбери поездку"
        case .noPayerSelected:
            return "Укажи, кто оплатил расход"
        }
    }
}

// MARK: - Validators

struct Validators {
    static func validateName(_ name: String, maxLength: Int = 100) throws {
        let trimmed = name.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            throw ValidationError.emptyName
        }

        if trimmed.count > maxLength {
            throw ValidationError.nameTooLong(max: maxLength)
        }
    }

    static func validateEmail(_ email: String) throws {
        let trimmed = email.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            throw ValidationError.invalidEmail
        }
        let emailPattern = "^[A-Z0-9a-z._%+-]+@[A-Za-z0-9.-]+\\.[A-Za-z]{2,}$"
        let regex = try NSRegularExpression(pattern: emailPattern)
        let range = NSRange(trimmed.startIndex..., in: trimmed)

        if regex.firstMatch(in: trimmed, range: range) == nil {
            throw ValidationError.invalidEmail
        }
    }

    static func validateAmount(_ amountString: String) throws -> Decimal {
        let trimmed = amountString.trimmingCharacters(in: .whitespaces)

        guard let amount = Decimal(string: trimmed) else {
            throw ValidationError.invalidAmount
        }

        if amount <= 0 {
            throw ValidationError.amountTooSmall
        }

        if amount > 999999 {
            throw ValidationError.amountTooLarge
        }

        return amount
    }

    static func validateDateNotInPast(_ date: Date) throws {
        let now = Date()
        let calendar = Calendar.current

        let dateOnly = calendar.startOfDay(for: date)
        let nowOnly = calendar.startOfDay(for: now)

        if dateOnly < nowOnly {
            throw ValidationError.dateInPast
        }
    }
    static func validateDateRange(start: Date, end: Date) throws {
        if end < start {
            throw ValidationError.endDateBeforeStart
        }
    }
    static func validateReasonableAmount(_ amount: Decimal, maxDaily: Decimal = 50000) throws {
        if amount > maxDaily {
            throw ValidationError.amountTooLarge
        }
    }
}

// MARK: - Helper for UI validation

extension String {
    /// Проверяет, это ли пустая строка после удаления пробелов
    var isEmptyOrWhitespace: Bool {
        trimmingCharacters(in: .whitespaces).isEmpty
    }
}
