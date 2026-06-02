import SwiftUI

// MARK: - Category Badge

struct CategoryBadge: View {
    let category: ExpenseCategory

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: category.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(category.title)
                .font(AppFont.caption)
        }
        .foregroundColor(category.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(category.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

// MARK: - Place Type Badge

struct PlaceTypeBadge: View {
    let type: PlaceType

    var body: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: type.icon)
                .font(.system(size: 10, weight: .semibold))
            Text(type.title)
                .font(AppFont.caption)
        }
        .foregroundColor(type.color)
        .padding(.horizontal, Spacing.sm)
        .padding(.vertical, Spacing.xs)
        .background(type.color.opacity(0.12))
        .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

// MARK: - App Tag

struct AppTag: View {
    let text: String
    var color: Color = .primaryAccent

    var body: some View {
        Text(text)
            .font(AppFont.caption)
            .foregroundColor(color)
            .padding(.horizontal, Spacing.sm)
            .padding(.vertical, Spacing.xs)
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: Spacing.md) {
        HStack(spacing: Spacing.sm) {
            ForEach(ExpenseCategory.allCases, id: \.self) { CategoryBadge(category: $0) }
        }
        HStack(spacing: Spacing.sm) {
            ForEach(PlaceType.allCases, id: \.self) { PlaceTypeBadge(type: $0) }
        }
        HStack(spacing: Spacing.sm) {
            AppTag(text: "Синхронизировано")
            AppTag(text: "Оффлайн", color: .neutralGray)
            AppTag(text: "Новое", color: .orangeAccent)
        }
    }
    .padding(Spacing.md)
}
