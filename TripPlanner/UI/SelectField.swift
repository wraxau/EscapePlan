import SwiftUI

// MARK: - Select Field

struct SelectField: View {
    let label: String
    let value: String?
    var icon: String? = nil
    var valueIcon: String? = nil
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(label)
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)

                    if let valueIcon {
                        // Показываем иконку вместо текста
                        Image(systemName: valueIcon)
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.primaryAccent)
                    } else {
                        Text(value ?? "Не выбрано")
                            .font(AppFont.body)
                            .foregroundColor(value != nil ? .textPrimary : .textSecondary)
                    }
                }

                Spacer()

                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 16))
                        .foregroundColor(.primaryAccent)
                }
            }
            .padding(Spacing.md)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.md) {
        SelectField(label: "Поездка", value: "Турция 2026", icon: "airplane") {}
        SelectField(label: "Кто платил", value: "Нина", icon: "person.fill") {}
        SelectField(label: "Категория", value: nil) {}
    }
    .padding(Spacing.md)
}
