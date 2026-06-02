import SwiftUI

// MARK: - Section Header
struct SectionHeader: View {
    let title: String
    var actionTitle: String? = nil
    var action: (() -> Void)? = nil

    var body: some View {
        HStack {
            SectionTitle(text: title)
            if let actionTitle, let action {
                Spacer()
                Button(action: action) {
                    Text(actionTitle)
                        .font(AppFont.caption)
                        .foregroundColor(.primaryAccent)
                }
            }
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.sm)
    }
}

// MARK: - Info Row

struct InfoRow: View {
    let icon: String
    let label: String
    var value: String? = nil
    var iconColor: Color = .primaryAccent

    var body: some View {
        HStack(spacing: Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .medium))
                .foregroundColor(iconColor)
                .frame(width: 22)

            Text(label)
                .font(AppFont.body)
                .foregroundColor(.textPrimary)

            Spacer()

            if let value {
                Text(value)
                    .font(AppFont.body)
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - Card Divider

struct CardDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 22 + Spacing.md)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.lg) {
        SectionHeader(title: "Участники")
        SectionHeader(title: "Расходы", actionTitle: "Все") {}

        AppCard {
            VStack(spacing: Spacing.md) {
                InfoRow(icon: "calendar", label: "Дата заезда", value: "15 июля")
                CardDivider()
                InfoRow(icon: "calendar", label: "Дата выезда", value: "22 июля")
                CardDivider()
                InfoRow(icon: "person.fill", label: "Оплатил", value: "Нина")
                CardDivider()
                InfoRow(icon: "creditcard", label: "Сумма", value: "€ 240")
            }
        }
        .padding(.horizontal, Spacing.md)
    }
    .padding(.vertical, Spacing.md)
}
