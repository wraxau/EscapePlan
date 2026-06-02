import SwiftUI

// MARK: - Select Sheet
struct SelectSheet<Item: Identifiable>: View {
    let title: String
    let items: [Item]
    let itemLabel: (Item) -> String
    @Binding var selection: Item?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if items.isEmpty {
                    emptyState
                } else {
                    ScrollView {
                        VStack(spacing: Spacing.sm) {
                            ForEach(items, id: \.id) { item in
                                selectButton(item)
                            }
                        }
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                    }
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

    private var emptyState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer()
            Image(systemName: "tray")
                .font(.system(size: 48, weight: .light))
                .foregroundColor(.textSecondary.opacity(0.5))
            VStack(spacing: Spacing.xs) {
                Text("Нет доступных вариантов")
                    .font(AppFont.headline)
                    .foregroundColor(.textPrimary)
                Text("Сначала создайте поездку на вкладке «Поездки»")
                    .font(AppFont.caption)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
            }
            Spacer()
        }
        .padding(.horizontal, Spacing.xl)
    }

    @ViewBuilder
    private func selectButton(_ item: Item) -> some View {
        let isSelected = selection?.id == item.id
        Button(action: {
            selection = item
            dismiss()
        }) {
            HStack {
                Text(itemLabel(item))
                    .font(AppFont.body)
                    .foregroundColor(isSelected ? .buttonText : .textPrimary)

                Spacer()

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primaryAccent)
                }
            }
            .padding(Spacing.md)
            .background(isSelected ? Color.primaryAccent : Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Preview Helper

private struct MockTrip: Identifiable {
    let id: Int
    let name: String
}

#Preview {
    @State var selectedTrip: MockTrip? = nil

    let items = [
        MockTrip(id: 1, name: "Поездка 1"),
        MockTrip(id: 2, name: "Поездка 2"),
        MockTrip(id: 3, name: "Поездка 3")
    ]

    SelectSheet(
        title: "Выберите поездку",
        items: items,
        itemLabel: { $0.name },
        selection: $selectedTrip
    )
}
