import Foundation
import Combine

// MARK: - CurrencyService

@MainActor
final class CurrencyService: ObservableObject {

    static let shared = CurrencyService()

    @Published var rates: [String: Double] = CurrencyService.fallbackRates
    @Published var isLoading = false
    @Published var errorMessage: String? = nil

    private var lastFetched: Date? = nil
    private let cacheTimeout: TimeInterval = 3600  

    private init() {}

    // MARK: - Public API
    func fetchIfNeeded() async {
        if let last = lastFetched, Date().timeIntervalSince(last) < cacheTimeout {
            return
        }
        await fetch()
    }

    func fetch() async {
        isLoading = true
        errorMessage = nil

        do {
            let url = URL(string: "https://api.exchangerate-api.com/v4/latest/EUR")!

            var request = URLRequest(url: url)
            request.timeoutInterval = 10

            let (data, response) = try await URLSession.shared.data(for: request)

            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200 else {
                throw NSError(domain: "CurrencyService", code: -1,
                              userInfo: [NSLocalizedDescriptionKey: "Сервер вернул ошибку"])
            }

            let decoded = try JSONDecoder().decode(ExchangeRateResponse.self, from: data)

            var newRates = Self.fallbackRates
            for (key, value) in decoded.rates {
                newRates[key.uppercased()] = value
            }
            rates = newRates
            lastFetched = Date()

        } catch {
            errorMessage = "Не удалось загрузить курсы: \(error.localizedDescription)"
        }

        isLoading = false
    }

    // MARK: - Конвертация

    func convert(_ amount: Decimal, from: String, to: String) -> Decimal {
        guard from.uppercased() != to.uppercased() else { return amount }

        let fromRate = rates[from.uppercased()] ?? 1.0
        let toRate   = rates[to.uppercased()]   ?? 1.0
        let inEUR  = Double(truncating: amount as NSDecimalNumber) / fromRate
        let result = inEUR * toRate

        return Decimal(result)
    }

    func formatted(_ amount: Decimal, in currency: String) -> String {
        let ceiled = NSDecimalNumber(decimal: amount.ceiled)
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = currency
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        return formatter.string(from: ceiled) ?? "\(currency) \(ceiled.intValue)"
    }

    static let popularCurrencies = [
        "USD", "EUR", "GBP", "RUB", "TRY", "JPY",
        "CNY", "AED", "THB", "CHF", "CAD", "AUD"
    ]

    static let fallbackRates: [String: Double] = [
        "EUR": 1.0,
        "USD": 1.17,
        "GBP": 0.87,
        "RUB": 82.92,
        "TRY": 53.49,
        "JPY": 185.68,
        "CNY": 7.90,
        "AED": 4.28,
        "THB": 37.91,
        "CHF": 0.91,
        "CAD": 1.61,
        "AUD": 1.62,
        "SGD": 1.49,
        "HKD": 9.13,
        "NOK": 10.78,
        "SEK": 10.78,
        "DKK": 7.46,
        "PLN": 4.23,
        "CZK": 24.29,
        "HUF": 353.93,
        "INR": 110.84,
        "KRW": 1755.81,
        "BRL": 5.88,
        "MXN": 20.23,
        "ZAR": 18.91,
        "IDR": 20833.76,
        "MYR": 4.62,
        "PHP": 71.67,
        "VND": 30427.18,
    ]
}

// MARK: - Response model

private struct ExchangeRateResponse: Decodable {
    let base: String
    let rates: [String: Double]
}
