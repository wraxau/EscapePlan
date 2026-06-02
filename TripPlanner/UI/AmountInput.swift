import SwiftUI

// MARK: - Amount Input

struct AmountInput: View {
    @Binding var amount: String
    @Binding var currency: String
    let currencies: [String]

    @State private var showCurrencySheet = false
    private var currencyItemBinding: Binding<CurrencyItem?> {
        Binding(
            get: {
                CurrencyItem(code: currency)
            },
            set: { newValue in
                if let newValue = newValue {
                    currency = newValue.code
                }
            }
        )
    }

    var body: some View {
        HStack(spacing: Spacing.sm) {
            // Сумма
            TextField("0", text: $amount)
                .font(AppFont.body)
                .foregroundColor(.textPrimary)
                .keyboardType(.decimalPad)
                .frame(maxWidth: .infinity)

            Divider()
                .frame(height: 24)

            // Валюта (кнопка)
            Button(action: { showCurrencySheet = true }) {
                Text(currency)
                    .font(AppFont.headline)
                    .foregroundColor(.primaryAccent)
                    .frame(width: 50)
            }
            .buttonStyle(.plain)
        }
        .padding(Spacing.md)
        .background(Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .sheet(isPresented: $showCurrencySheet) {
            if #available(iOS 17.0, *) {
                SelectSheet(
                    title: "Выберите валюту",
                    items: currencies.map { CurrencyItem(code: $0) },
                    itemLabel: { $0.code },
                    selection: currencyItemBinding
                )
                .onChange(of: currencyItemBinding.wrappedValue) { _, _ in
                    showCurrencySheet = false
                }
            } else {
            }
        }
    }
}

// MARK: - Helper

private struct CurrencyItem: Identifiable, Equatable {
    let code: String

    var id: String { code }

    static func == (lhs: CurrencyItem, rhs: CurrencyItem) -> Bool {
        lhs.code == rhs.code
    }
}

// MARK: - Preview

#Preview {
    @State var amount = "2000"
    @State var currency = "TRY"

    return VStack(spacing: Spacing.md) {
        Text("Валюта траты")
            .font(AppFont.caption)
            .foregroundColor(.textSecondary)
            .frame(maxWidth: .infinity, alignment: .leading)

        AmountInput(
            amount: $amount,
            currency: $currency,
            currencies: ["USD", "EUR", "TRY", "RUB", "GBP"]
        )
    }
    .padding(Spacing.md)
}
