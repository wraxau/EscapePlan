import SwiftUI
import CoreData
import Foundation
import FirebaseAuth

struct ExpenseListView: View {

    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var tripVM: TripViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @StateObject private var expenseVM: ExpenseViewModel
    @State private var selectedTrip: Trip?
    @State private var showAddExpense = false
    @State private var showDebts = false
    @State private var expenseToEdit: Expense? = nil
    @State private var currentUserUID: String = ""

    // MARK: - Filters

    @State private var startDate = Calendar.current.date(byAdding: .month, value: -1, to: Date()) ?? Date()
    @State private var endDate = Date()
    @State private var selectedCategoryFilter: ExpenseCategory? = nil
    @State private var showOnlyUnpaid = false  // Toggle "Нужно отдать"
    @State private var selectedTripFilter: Trip? = nil
    @State private var syncError: String? = nil
    @State private var searchText: String = ""

    init(trip: Trip? = nil) {
        let ctx = PersistenceController.shared.container.viewContext
        let placeholder: Trip
        if let trip = trip {
            placeholder = trip
        } else {
            let entity = NSEntityDescription.entity(forEntityName: "Trip", in: ctx)!
            let dummy = Trip(entity: entity, insertInto: nil)
            dummy.id = UUID()
            placeholder = dummy
        }

        _selectedTrip = State(initialValue: trip)
        _expenseVM = StateObject(wrappedValue: ExpenseViewModel(trip: placeholder, context: ctx))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {

                if expenseVM.expenses.isEmpty {
                    emptyState
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
                } else {
                    mainContent
                        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 88) }
                }

                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FABButton(icon: "plus") {
                            showAddExpense = true
                        }
                        .padding(.trailing, Spacing.lg)
                    }
                }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
            }
            .navigationTitle("Мои расходы")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Поиск по расходам")
            .appNavBar()
            .toolbar { toolbarContent }
            .safeAreaInset(edge: .top, spacing: 0) {
                syncBanner
            }
            .sheet(isPresented: $showAddExpense) {
                ExpenseFormSheet(mode: .add(trips: tripVM.trips) { name, savedTrip, paidBy, sharedWith, category, amount, currency, date in
                    selectedTrip = savedTrip
                    expenseVM.changeTrip(savedTrip)
                    expenseVM.addExpense(
                        amount: amount,
                        category: category,
                        date: date,
                        currency: currency,
                        description: name,
                        paidBy: paidBy,
                        isShared: !sharedWith.isEmpty,
                        sharedWith: sharedWith
                    )

                    expenseVM.fetchAll()
                })
            }
            .sheet(isPresented: $showDebts) {
                DebtsView()
                    .environmentObject(tripVM)
                    .environment(\.managedObjectContext, context)
            }
            .sheet(item: $expenseToEdit) { expense in
                if let trip = expense.trip {
                    ExpenseFormSheet(mode: .edit(expense: expense, trip: trip) {
                        expenseVM.fetchAll()
                    })
                }
            }
            .task {
                for trip in tripVM.trips {
                    await SyncService.shared.syncExpenses(for: trip, context: context)
                }
                expenseVM.fetchAll()
            }
            .onAppear {
                currentUserUID = authVM.currentUserUID ?? ""
                expenseVM.fetchAll()
            }
            .onReceive(authVM.$currentUserUID) { uid in
                currentUserUID = uid ?? ""
            }
            .onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectsNotification)) { _ in
                expenseVM.fetchAll()
            }
            .errorToast(message: $syncError)
            .onReceive(SyncService.shared.$errorMessage) { msg in
                guard let msg else { return }
                syncError = msg
            }
        }
    }

    // MARK: - Main content

    private var mainContent: some View {
        let groupedExpenses = groupExpensesByDay(filteredExpenses)

        return List {

            // Pie Chart
            Section {
                pieChartSection
                    .listRowInsets(.init(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } header: {
                SectionHeader(title: "Распределение")
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            // Фильтры
            Section {
                filtersSection
                    .listRowInsets(.init(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            } header: {
                SectionHeader(title: "Фильтры")
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            // Расходы
            Section {
                if groupedExpenses.isEmpty {
                    Text("Нет расходов")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                }
            } header: {
                SectionHeader(title: "Расходы")
                    .listRowInsets(.init(top: 0, leading: 0, bottom: 0, trailing: 0))
            }

            ForEach(groupedExpenses, id: \.date) { day in
                Section {
                    ForEach(day.expenses, id: \.id) { expense in
                        ExpenseRowView(
                            expense: expense,
                            currencyCode: expense.trip?.currencyCode ?? selectedTrip?.currencyCode ?? "USD",
                            myDebt: calculateMyDebt(for: expense),
                            onEdit: { expenseToEdit = expense },
                            onToggle: { toggleDebtStatus(for: expense) }
                        )
                        .listRowInsets(.init(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }
                } header: {
                    Text(dayHeader(day.date))
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                        .padding(.horizontal, Spacing.md)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .screenBackground()
    }

    // MARK: - Pie Chart Section

    private var pieChartSection: some View {
        AppCard {
            VStack(spacing: Spacing.md) {
                Text("Распределение расходов")
                    .font(AppFont.headline)
                    .foregroundColor(.textPrimary)

                SimpleExpensePieChart(
                    data: expenseVM.amountByCategory,
                    height: 180
                )

                VStack(spacing: Spacing.sm) {
                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        if let amount = expenseVM.amountByCategory[category.rawValue] {
                            HStack(spacing: Spacing.sm) {
                                Circle()
                                    .fill(category.color)
                                    .frame(width: 12, height: 12)

                                Text(category.title)
                                    .font(AppFont.caption)
                                    .foregroundColor(.textPrimary)

                                Spacer()

                                HStack(spacing: Spacing.xs) {
                                    Text(amount.ceiledString)
                                        .font(AppFont.caption)
                                        .foregroundColor(.textSecondary)
                                    Text(selectedTrip?.currencyCode ?? "USD")
                                        .font(AppFont.tiny)
                                        .foregroundColor(.textSecondary.opacity(0.7))
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Filters Section

    private var filtersSection: some View {
        VStack(spacing: Spacing.md) {

            // Фильтр по датам
            HStack {
                VStack(spacing: Spacing.xs) {
                    Text("Начало")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                    DatePicker("", selection: $startDate, displayedComponents: .date)
                        .labelsHidden()
                        .font(AppFont.body)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }

                Spacer()

                VStack(spacing: Spacing.xs) {
                    Text("Конец")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                    DatePicker("", selection: $endDate, displayedComponents: .date)
                        .labelsHidden()
                        .font(AppFont.body)
                        .environment(\.locale, Locale(identifier: "ru_RU"))
                }
            }
            .padding(Spacing.md)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            // Toggle "Нужно отдать"
            HStack(spacing: Spacing.md) {
                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Нужно отдать")
                        .font(AppFont.body)
                        .foregroundColor(.textPrimary)
                    Text("Показать только мои долги")
                        .font(AppFont.caption)
                        .foregroundColor(.textSecondary)
                }

                Spacer()

                Toggle("", isOn: $showOnlyUnpaid)
                    .tint(.primaryAccent)
            }
            .padding(Spacing.md)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            // Фильтр по категории
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    Button {
                        selectedCategoryFilter = nil
                    } label: {
                        Text("Все")
                            .font(AppFont.caption)
                            .foregroundColor(selectedCategoryFilter == nil ? .buttonText : .textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedCategoryFilter == nil ? Color.primaryAccent : Color.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                    }

                    ForEach(ExpenseCategory.allCases, id: \.self) { category in
                        Button {
                            selectedCategoryFilter = selectedCategoryFilter == category ? nil : category
                        } label: {
                            HStack(spacing: Spacing.xs) {
                                Image(systemName: category.icon)
                                Text(category.title)
                            }
                            .font(AppFont.caption)
                            .foregroundColor(selectedCategoryFilter == category ? .buttonText : .textSecondary)
                            .padding(.horizontal, Spacing.md)
                            .padding(.vertical, Spacing.sm)
                            .background(selectedCategoryFilter == category ? Color.primaryAccent : Color.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.pill))
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }


    // MARK: - Filtering logic

    private var filteredExpenses: [Expense] {
        var result = expenseVM.expenses

        let cal = Calendar.current
        let dayStart = cal.startOfDay(for: startDate)
        let dayEnd   = cal.date(bySettingHour: 23, minute: 59, second: 59, of: endDate) ?? endDate

        result = result.filter { expense in
            guard let date = expense.date else { return false }
            return date >= dayStart && date <= dayEnd
        }

        // Фильтр по категории
        if let categoryFilter = selectedCategoryFilter {
            result = result.filter { expense in
                expense.category == categoryFilter.rawValue
            }
        }

        if showOnlyUnpaid {
            result = result.filter { expense in
                (expense.debtStatus ?? "pending") == "pending"
            }
        }

        if !searchText.trimmingCharacters(in: .whitespaces).isEmpty {
            let query = searchText.lowercased()
            result = result.filter { expense in
                (expense.descriptionText ?? "").lowercased().contains(query)
            }
        }

        return result
    }

    /// Группируем расходы по дням
    private func groupExpensesByDay(_ expenses: [Expense]) -> [(date: Date, expenses: [Expense])] {
        let calendar = Calendar.current
        let grouped = Dictionary(grouping: expenses) { expense -> Date in
            guard let date = expense.date else { return Date.distantPast }
            return calendar.startOfDay(for: date)
        }
        return grouped
            .sorted { $0.key > $1.key }
            .map { (date: $0.key, expenses: $0.value) }
    }



    // MARK: - Helpers
    private func calculateMyDebt(for expense: Expense) -> Decimal? {
        guard !currentUserUID.isEmpty else { return nil }

        if (expense.debtStatus ?? "pending") == "paid" { return nil }

        if let payerUID = expense.paidBy?.firebaseUID, payerUID == currentUserUID {
            return nil
        }

        if let sharedWithIDs = expense.sharedWithParticipantIDs as? [UUID] {
            // Ищем участника с моим firebaseUID среди sharedWith
            let participants = (expense.trip?.participants as? Set<Participant>) ?? []
            let myParticipant = participants.first { $0.firebaseUID == currentUserUID }

            guard let myID = myParticipant?.id,
                  sharedWithIDs.contains(myID) else { return nil }

            let amount = (expense.amount as Decimal?) ?? 0
            let count = sharedWithIDs.count
            guard count > 0 else { return nil }
            return (amount / Decimal(count)).ceiled
        }

        return nil
    }

    private func toggleDebtStatus(for expense: Expense) {
        let newStatus = ((expense.debtStatus ?? "pending") == "pending") ? "paid" : "pending"
        expense.debtStatus = newStatus
        expense.updatedAt = Date()

        do {
            try context.save()
        } catch {
            #if DEBUG
            print("Error saving debt status: \(error)")
            #endif
        }

        expenseVM.fetchAll()
    }

    // MARK: - Sync Banner

    @ViewBuilder
    private var syncBanner: some View {
        let state = SyncService.shared.syncState
        if case .syncing = state {
            SyncStatusView(syncState: state, onRetry: nil)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.appBackground)
        } else if case .error = state {
            SyncStatusView(syncState: state, onRetry: {
                expenseVM.fetchAll()
            })
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.appBackground)
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        EmptyStateView(
            icon: "creditcard",
            title: "Нет расходов",
            subtitle: "Нажми + чтобы добавить первый расход"
        )
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                showDebts = true
            } label: {
                NavBarIconButton(icon: "arrow.left.arrow.right.circle")
            }
        }
    }

    // MARK: - Helpers

    private func dayHeader(_ date: Date) -> String {
        date.formattedDate()
    }
}

// MARK: - Simple Pie Chart

struct SimpleExpensePieChart: View {
    let data: [String: Decimal]
    let height: CGFloat

    var body: some View {
        if data.isEmpty {
            VStack {
                Text("Нет данных")
                    .font(AppFont.caption)
                    .foregroundColor(.textSecondary)
            }
            .frame(height: height)
        } else {
            Canvas { context, size in
                let total = data.values.reduce(0, +)
                guard total > 0 else { return }

                let center = CGPoint(x: size.width / 2, y: size.height / 2)
                let radius = min(size.width, size.height) / 2 - 10

                var currentAngle: Double = -90

                for category in ExpenseCategory.allCases {
                    guard let amount = data[category.rawValue] else { continue }

                    let slice = Double(truncating: amount as NSDecimalNumber) / Double(truncating: total as NSDecimalNumber)
                    let angle = slice * 360

                    var path = Path()
                    path.move(to: center)
                    path.addArc(
                        center: center,
                        radius: radius,
                        startAngle: .degrees(currentAngle),
                        endAngle: .degrees(currentAngle + angle),
                        clockwise: false
                    )
                    path.closeSubpath()

                    context.fill(path, with: .color(category.color))
                    currentAngle += angle
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Preview

#Preview {
    
    ExpenseListView()
        .environmentObject(TripViewModel(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AuthViewModel())
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
