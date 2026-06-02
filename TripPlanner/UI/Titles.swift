import SwiftUI

// MARK: - Screen Title

struct ScreenTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.display(20))
            .foregroundColor(.primaryAccent)
            .frame(maxWidth: .infinity, alignment: .center)
    }
}

// MARK: - Section Title

struct SectionTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.headline)
            .foregroundColor(.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Card Title

struct CardTitle: View {
    let text: String

    var body: some View {
        Text(text)
            .font(AppFont.cardTitle)
            .foregroundColor(.textPrimary)
            .lineLimit(1)
    }
}

// MARK: - Preview

#Preview {
    VStack(alignment: .leading, spacing: Spacing.lg) {
        ScreenTitle(text: "Вход")
        ScreenTitle(text: "Создать аккаунт")
        Divider()
        SectionTitle(text: "Участники поездки")
        SectionTitle(text: "Расходы за день")
        Divider()
        CardTitle(text: "Барселона 2026")
        CardTitle(text: "Токио — мечта")
    }
    .padding(Spacing.md)
}
