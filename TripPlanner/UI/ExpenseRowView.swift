import SwiftUI

// MARK: - ExpenseRowView

struct ExpenseRowView: View {

    let expense: Expense
    var currencyCode: String = "USD"
    var myDebt: Decimal? = nil
    let onEdit: () -> Void
    let onToggle: () -> Void

    private var isPaid: Bool {
        !expense.isShared || (expense.debtStatus ?? "pending") == "paid"
    }

    var body: some View {
        AppCard {
            HStack(spacing: Spacing.md) {

                // Бейдж категории
                if let raw = expense.category,
                   let category = ExpenseCategory(rawValue: raw) {
                    CategoryBadge(category: category)
                }

                // Основная информация
                VStack(alignment: .leading, spacing: Spacing.xs) {

                    // Название + сумма
                    HStack {
                        Text(expense.descriptionText ?? "Расход")
                            .font(AppFont.body)
                            .foregroundColor(.textPrimary)

                        Spacer()

                        HStack(spacing: Spacing.xs) {
                            Text(((expense.amount as Decimal?) ?? 0).ceiledString)
                                .font(AppFont.headline)
                                .foregroundColor(.primaryAccent)
                            Text(currencyCode)
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    // Кто платил
                    if let paidBy = expense.paidBy?.name {
                        Text("\(paidBy) потратил")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                    }

                    // Мой долг (только в detailed-режиме)
                    if let debt = myDebt {
                        HStack {
                            Text("Мой долг: \(debt.ceiledString) \(currencyCode)")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                            Spacer()
                            debtStatusBadge
                        }
                    } else {
                        // Compact: просто тег статуса
                        HStack {
                            AppTag(
                                text: isPaid ? "Оплачено" : "Ожидает",
                                color: isPaid ? .greenPrimary : .redAccent
                            )
                            Spacer()
                        }
                    }
                }
            }
        }
        .onTapGesture { onEdit() }
        .swipeActions(edge: .trailing) {
            Button {
                HapticFeedback.success()
                onToggle()
            } label: {
                Label(
                    isPaid ? "Отменить" : "Оплачено",
                    systemImage: isPaid ? "clock.fill" : "checkmark.circle.fill"
                )
            }
            .tint(isPaid ? .redAccent : .greenPrimary)
        }
        .swipeActions(edge: .leading) {
            Button {
                HapticFeedback.light()
                onEdit()
            } label: {
                Label("Изменить", systemImage: "pencil")
            }
            .tint(.primaryAccent)
        }
    }

    // MARK: - Debt status badge (для detailed-режима)

    @ViewBuilder
    private var debtStatusBadge: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: isPaid ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .font(.system(size: 12))
            Text(isPaid ? "Готово" : "Оплата")
                .font(AppFont.caption)
        }
        .foregroundColor(isPaid ? .greenPrimary : .redAccent)
    }
}
