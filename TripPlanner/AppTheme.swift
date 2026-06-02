import SwiftUI

// MARK: - Colors

extension Color {

    // MARK: Системные цвета
    /// проживание, отели
    static let greenPrimary   = Color(.systemGreen)
    ///развлечения, достопримечательности
    static let pinkPrimary    = Color(.systemPink)

    // MARK: Семантические цвета
    static let textOnDark     = Color.white
    /// Основной текст
    static let textPrimary    = Color.primary
    /// Вторичный текст (серый)
    static let textSecondary  = Color.secondary
    /// Разделитель / граница
    static let separator      = Color(.systemGray5)
    /// Фон карточки (белый / системный grouped)
    static let cardBackground = Color(.systemBackground)
    /// Фон экрана (светло-серый)
    static let appBackground  = Color(.systemGray6)

}

// MARK: - Typography

enum AppFont {

    private static let customFontName = "Delago"

    static func display(_ size: CGFloat) -> Font {
        Font.custom(customFontName, size: size)
    }

    // MARK: Заголовки
    /// Экранный заголовок: название поездки на обложке
    static let largeTitle = display(34)
    /// Заголовок экрана (NavigationTitle)
    static let title      = display(26)
    /// Заголовок карточки
    static let cardTitle  = display(20)

    // MARK: Системные стили
    /// Жирный подзаголовок секции
    static let headline   = Font.system(size: 17, weight: .semibold, design: .rounded)
    /// Основной текст
    static let body       = Font.system(size: 15, weight: .regular)
    /// Подпись под основным текстом
    static let subheadline = Font.system(size: 13, weight: .regular)
    /// Бейдж / метка категории
    static let caption    = Font.system(size: 12, weight: .medium)
    /// Самый маленький текст (даты, время)
    static let tiny       = Font.system(size: 11, weight: .regular)
}

// MARK: - Spacing

enum Spacing {
    static let xxs: CGFloat =  2
    static let xs:  CGFloat =  4
    static let sm:  CGFloat =  8
    static let md:  CGFloat = 16
    static let lg:  CGFloat = 24
    static let xl:  CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64
    static let buttonHorizontalPadding: CGFloat = 20
}

// MARK: - Corner Radius

enum Radius {
    static let sm:   CGFloat =  8
    static let md:   CGFloat = 12
    static let lg:   CGFloat = 16
    static let xl:   CGFloat = 20
    static let xxl:  CGFloat = 28
    static let pill: CGFloat = 100   // для кнопок-таблеток и бейджей
}

// MARK: - Shadows

struct AppShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat

    static let card = AppShadow(color: .black.opacity(0.07), radius: 10, x: 0, y: 3)
    static let elevated = AppShadow(color: .black.opacity(0.12), radius: 20, x: 0, y: 6)
    static let fab = AppShadow(color: .primaryAccent.opacity(0.35), radius: 14, x: 0, y: 6)
}

extension View {
    func appShadow(_ shadow: AppShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }
}

// MARK: - Animation

enum AppAnimation {
    static let standard = Animation.spring(response: 0.35, dampingFraction: 0.75)
    static let quick    = Animation.easeInOut(duration: 0.18)
    static let slow     = Animation.easeOut(duration: 0.45)
}

// MARK: - Color(hex:) extension

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8)  & 0xFF) / 255
        let b = Double(int         & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }

    var hexString: String {
        let ui = UIColor(self)
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        ui.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }
}

// MARK: - Expense Categories

enum ExpenseCategory: String, CaseIterable, Identifiable {
    case cafe       = "cafe"
    case housing    = "housing"
    case transport  = "transport"
    case sport      = "sport"
    case excursion  = "excursion"
    case museum     = "museum"
    case shopping   = "shopping"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .cafe:      return "Кафе/Рестораны"
        case .housing:   return "Жильё"
        case .transport: return "Транспорт"
        case .sport:     return "Спорт"
        case .excursion: return "Экскурсия"
        case .museum:    return "Музей"
        case .shopping:  return "Магазин"
        }
    }

    var icon: String {
        switch self {
        case .cafe:      return "fork.knife"
        case .housing:   return "house.fill"
        case .transport: return "tram.fill"
        case .sport:     return "figure.run"
        case .excursion: return "binoculars.fill"
        case .museum:    return "building.columns.fill"
        case .shopping:  return "bag.fill"
        }
    }

    var color: Color {
        switch self {
        case .cafe:      return Color(hex: "#FF6B6B")
        case .housing:   return Color(hex: "#4ECDC4")
        case .transport: return Color(hex: "#45B7D1")
        case .sport:     return Color(hex: "#96CEB4")
        case .excursion: return Color(hex: "#F0A500")
        case .museum:    return Color(hex: "#DDA0DD")
        case .shopping:  return Color(hex: "#FF8C69")
        }
    }
}

// MARK: - Date Formatting

extension Date {
    func formattedTime() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        return formatter.string(from: self)
    }
    func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM"
        return formatter.string(from: self)
    }

    func formattedDateFull() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM yyyy"
        return formatter.string(from: self)
    }

    func formattedDateShort() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "dd.MM.yyyy"
        return formatter.string(from: self)
    }

    func formattedDateAbbreviated() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMM"
        return formatter.string(from: self)
    }

    func formattedDateWithWeekday() -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ru_RU")
        formatter.dateFormat = "d MMMM, EEEE"
        return formatter.string(from: self)
    }
}

// MARK: - Place Types

enum PlaceType: String, CaseIterable, Identifiable {
    case hotel       = "hotel"
    case restaurant  = "restaurant"
    case attraction  = "attraction"
    case transport   = "transport"
    case other       = "other"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .hotel:      return "Отель"
        case .restaurant: return "Ресторан"
        case .attraction: return "Достопримечательность"
        case .transport:  return "Транспорт"
        case .other:      return "Другое"
        }
    }

    var icon: String {
        switch self {
        case .hotel:      return "bed.double.fill"
        case .restaurant: return "fork.knife"
        case .attraction: return "camera.fill"
        case .transport:  return "airplane"
        case .other:      return "mappin.and.ellipse"
        }
    }

    var color: Color {
        switch self {
        case .hotel:      return Color.greenPrimary
        case .restaurant: return Color.orangeAccent
        case .attraction: return Color.pinkPrimary
        case .transport:  return Color.blueAccent
        case .other:      return Color.neutralGray
        }
    }
}
