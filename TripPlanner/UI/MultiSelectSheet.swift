import SwiftUI

// MARK: - Multi Select Sheet

struct MultiSelectSheet<Item: Identifiable & Equatable>: View {
    let title: String
    let items: [Item]
    let itemLabel: (Item) -> String
    @Binding var selection: [Item]
    @Environment(\.dismiss) private var dismiss

    private var allSelected: Bool { selection.count == items.count }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Шапка: кол-во выбранных + кнопка «Все / Снять»
                selectionHeader

                ScrollView {
                    VStack(spacing: Spacing.sm) {
                        ForEach(items, id: \.id) { item in
                            participantRow(item)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                    .padding(.bottom, Spacing.md)
                }

                // Нижняя кнопка
                VStack(spacing: 0) {
                    Divider()
                    PrimaryButton(
                        title: selection.isEmpty ? "Выберите участников" : "Готово (\(selection.count))",
                        icon: "checkmark"
                    ) {
                        dismiss()
                    }
                    .disabled(selection.isEmpty)
                    .opacity(selection.isEmpty ? 0.5 : 1.0)
                    .padding(.horizontal, Spacing.buttonHorizontalPadding)
                    .padding(.vertical, Spacing.md)
                }
            }
            .screenBackground()
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .appNavBar()
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        NavBarIconButton(icon: "xmark")
                    }
                }
            }
        }
    }

    // MARK: - Selection Header

    private var selectionHeader: some View {
        HStack {
            Text(selection.isEmpty
                 ? "Никто не выбран"
                 : "Выбрано: \(selection.count) из \(items.count)")
                .font(AppFont.caption)
                .foregroundColor(.textSecondary)

            Spacer()

            Button(allSelected ? "Снять все" : "Выбрать всех") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if allSelected {
                        selection = []
                    } else {
                        selection = items
                    }
                }
            }
            .font(AppFont.caption.weight(.semibold))
            .foregroundColor(.primaryAccent)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.vertical, Spacing.sm)
        .background(Color(.systemGroupedBackground))
    }

    // MARK: - Participant Row

    @ViewBuilder
    private func participantRow(_ item: Item) -> some View {
        let isSelected = selection.contains(item)
        let label = itemLabel(item)

        Button(action: {
            withAnimation(.easeInOut(duration: 0.15)) {
                if isSelected {
                    selection.removeAll { $0 == item }
                } else {
                    selection.append(item)
                }
            }
        }) {
            HStack(spacing: Spacing.md) {

                // Аватарка с инициалами
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.primaryAccent : Color.primaryAccent.opacity(0.12))
                        .frame(width: 46, height: 46)

                    if isSelected {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.white)
                    } else {
                        Text(initials(from: label))
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primaryAccent)
                    }
                }

                // Имя участника
                Text(label)
                    .font(AppFont.body)
                    .foregroundColor(.textPrimary)

                Spacer()

                // Индикатор справа
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 22))
                    .foregroundColor(isSelected ? .primaryAccent : Color(.systemGray4))
            }
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.sm)
            .background(
                RoundedRectangle(cornerRadius: Radius.md)
                    .fill(isSelected
                          ? Color.primaryAccent.opacity(0.08)
                          : Color.inputBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md)
                    .stroke(isSelected ? Color.primaryAccent.opacity(0.4) : Color.clear, lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.15), value: isSelected)
    }

    // MARK: - Helpers

    private func initials(from name: String) -> String {
        let parts = name.split(separator: " ")
        if parts.count >= 2 {
            return String(parts[0].prefix(1)) + String(parts[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Preview

private struct MockItem: Identifiable, Equatable {
    let id: Int
    let name: String
}

#Preview {
    @State var selectedItems: [MockItem] = [MockItem(id: 1, name: "Анна Карлова")]

    let items = [
        MockItem(id: 1, name: "Анна Карлова"),
        MockItem(id: 2, name: "Паша Иванов"),
        MockItem(id: 3, name: "Катя"),
        MockItem(id: 4, name: "Дима Петров")
    ]

    MultiSelectSheet(
        title: "На кого делим",
        items: items,
        itemLabel: { $0.name },
        selection: $selectedItems
    )
}
