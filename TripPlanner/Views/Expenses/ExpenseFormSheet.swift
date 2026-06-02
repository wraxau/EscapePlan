import SwiftUI
import CoreData

// MARK: - Mode

enum ExpenseFormMode {
    case add(
        trips: [Trip],
        onSave: (String, Trip, Participant, [Participant], ExpenseCategory, Decimal, String, Date) -> Void
    )
    case edit(expense: Expense, trip: Trip, onSave: () -> Void)
}

// MARK: - ExpenseFormSheet

struct ExpenseFormSheet: View {

    @Environment(\.dismiss) private var dismiss

    let mode: ExpenseFormMode

    // MARK: - Fields

    @State private var name: String
    @State private var amount: String
    @State private var currency: String
    @State private var selectedDate: Date
    @State private var selectedCategory: ExpenseCategory
    @State private var selectedPaidBy: Participant?
    @State private var selectedSharedWith: [Participant]
    @State private var isPersonalExpense: Bool

    // Sheet toggles
    @State private var showTripSheet      = false
    @State private var showPaidBySheet    = false
    @State private var showSharedWithSheet = false
    @State private var showCategorySheet  = false

    // Add-mode only
    @State private var selectedTrip: Trip?
    @State private var availableParticipants: [Participant] = []

    @State private var validationError: ValidationError?

    // MARK: - Init

    init(mode: ExpenseFormMode) {
        self.mode = mode

        switch mode {
        case .add:
            _name               = State(initialValue: "")
            _amount             = State(initialValue: "")
            _currency           = State(initialValue: "USD")
            _selectedDate       = State(initialValue: Date())
            _selectedCategory   = State(initialValue: .cafe)
            _selectedPaidBy     = State(initialValue: nil)
            _selectedSharedWith = State(initialValue: [])
            _isPersonalExpense  = State(initialValue: false)

        case .edit(let expense, let trip, _):
            _name             = State(initialValue: expense.descriptionText ?? "")
            _amount           = State(initialValue: (expense.amount as Decimal?).map { "\($0)" } ?? "")
            _currency         = State(initialValue: expense.currency ?? "USD")
            _selectedDate     = State(initialValue: expense.date ?? Date())
            _selectedCategory = State(initialValue: ExpenseCategory(rawValue: expense.category ?? "") ?? .cafe)
            _selectedPaidBy   = State(initialValue: expense.paidBy)
            _isPersonalExpense = State(initialValue: !expense.isShared)

            let parts = (trip.participants as? Set<Participant>) ?? []
            let sharedIDs = expense.sharedWithParticipantIDs as? [UUID] ?? []
            let shared = parts.filter { p in sharedIDs.contains(where: { $0 == p.id }) }
            _selectedSharedWith = State(initialValue: Array(shared))
            _selectedTrip = State(initialValue: trip)
        }
    }

    // MARK: - Derived

    private var currentTrip: Trip? {
        switch mode {
        case .add:          return selectedTrip
        case .edit(_, let trip, _): return trip
        }
    }

    private var participants: [Participant] {
        switch mode {
        case .add:    return availableParticipants
        case .edit(_, let trip, _):
            return (trip.participants as? Set<Participant>).map { Array($0) } ?? []
        }
    }

    private var trips: [Trip] {
        if case .add(let trips, _) = mode { return trips }
        return []
    }

    private var navigationTitle: String {
        switch mode {
        case .add:  return "Расходы"
        case .edit: return "Редактировать расход"
        }
    }

    private var isValid: Bool {
        guard !name.isEmptyOrWhitespace,
              currentTrip != nil,
              (isPersonalExpense || selectedPaidBy != nil),
              (isPersonalExpense || !selectedSharedWith.isEmpty),
              !amount.isEmpty,
              (try? Validators.validateAmount(amount)) != nil
        else { return false }
        return true
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    // Название
                    formSection(title: "Название") {
                        AppTextField(placeholder: "Например: Ужин в ресторане", text: $name)
                    }

                    if case .add = mode {
                        formSection(title: "Поездка") {
                            SelectField(
                                label: "Выберите поездку",
                                value: selectedTrip?.name,
                                icon: "airplane"
                            ) { showTripSheet = true }
                        }
                    }

                    if currentTrip != nil {

                        if !isPersonalExpense {
                            formSection(title: "Кто платил") {
                                SelectField(
                                    label: "Выберите участника",
                                    value: selectedPaidBy?.name,
                                    icon: "person.fill"
                                ) { showPaidBySheet = true }
                            }
                        }

                        // Тип расхода
                        formSection(title: "Тип расхода") {
                            HStack(spacing: Spacing.md) {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("Только мой расход")
                                        .font(AppFont.body)
                                        .foregroundColor(.textPrimary)
                                    Text("Не делить с остальными участниками")
                                        .font(AppFont.caption)
                                        .foregroundColor(.textSecondary)
                                }
                                Spacer()
                                Toggle("", isOn: $isPersonalExpense)
                                    .tint(.primaryAccent)
                                    .onChange(of: isPersonalExpense) { newValue in
                                        if newValue { selectedSharedWith = [] }
                                    }
                            }
                            .padding(Spacing.md)
                            .background(Color.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }

                        // На кого делим
                        if !isPersonalExpense {
                            formSection(title: "На кого делим") {
                                SelectField(
                                    label: "Выберите участников",
                                    value: selectedSharedWith.isEmpty
                                        ? "Не выбрано"
                                        : "\(selectedSharedWith.count) выбрано",
                                    icon: "person.2.fill"
                                ) { showSharedWithSheet = true }
                            }
                        }

                        // Категория
                        formSection(title: "Категория") {
                            SelectField(
                                label: "Выберите категорию",
                                value: selectedCategory.title,
                                icon: selectedCategory.icon
                            ) { showCategorySheet = true }
                        }

                        // Сумма
                        formSection(title: "Валюта траты") {
                            AmountInput(
                                amount: $amount,
                                currency: $currency,
                                currencies: getCurrencies()
                            )
                        }

                        // Дата
                        formSection(title: "Дата") {
                            DatePicker("Выберите дату", selection: $selectedDate, displayedComponents: .date)
                                .datePickerStyle(.graphical)
                                .tint(.primaryAccent)
                                .padding(Spacing.md)
                                .background(Color.inputBackground)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        }
                    }

                    // Ошибка валидации
                    if let error = validationError {
                        validationBanner(error: error)
                    }

                    // Сохранить
                    PrimaryButton(title: "Сохранить", icon: "checkmark") {
                        saveExpense()
                    }
                    .disabled(!isValid)
                    .opacity(isValid ? 1 : 0.5)
                    .padding(.horizontal, Spacing.buttonHorizontalPadding)
                    .padding(.bottom, Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)
            }
            .screenBackground()
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .appNavBar()
            .onAppear(perform: onAppear)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { NavBarIconButton(icon: "xmark") }
                }
            }

            // Sheets
            .sheet(isPresented: $showTripSheet) {
                SelectSheet(
                    title: "Выберите поездку",
                    items: trips,
                    itemLabel: { $0.name ?? "Без названия" },
                    selection: $selectedTrip
                )
            }
            .onChange(of: selectedTrip) { _ in
                selectedPaidBy = nil
                selectedSharedWith = []
                updateAvailableParticipants()
            }
            .sheet(isPresented: $showPaidBySheet) {
                SelectSheet(
                    title: "Кто платил",
                    items: participants,
                    itemLabel: { $0.name ?? "Без имени" },
                    selection: $selectedPaidBy
                )
            }
            .sheet(isPresented: $showSharedWithSheet) {
                MultiSelectSheet(
                    title: "На кого делим",
                    items: participants,
                    itemLabel: { $0.name ?? "Без имени" },
                    selection: $selectedSharedWith
                )
            }
            .sheet(isPresented: $showCategorySheet) {
                NavigationStack {
                    List {
                        Section("Категория расхода") {
                            Picker("Категория", selection: $selectedCategory) {
                                ForEach(ExpenseCategory.allCases, id: \.self) { category in
                                    HStack {
                                        Image(systemName: category.icon)
                                        Text(category.title)
                                    }
                                    .tag(category)
                                }
                            }
                            .pickerStyle(.inline)
                        }
                    }
                    .navigationTitle("Выберите категорию")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Готово") { showCategorySheet = false }
                                .buttonStyle(NavBarTextButtonStyle())
                        }
                    }
                }
            }
        }
    }

    // MARK: - Helpers

    private func onAppear() {
        guard case .add(let trips, _) = mode,
              trips.count == 1,
              selectedTrip == nil
        else { return }

        selectedTrip = trips.first
        updateAvailableParticipants()
        if selectedSharedWith.isEmpty {
            selectedSharedWith = availableParticipants
        }
    }

    private func updateAvailableParticipants() {
        availableParticipants = (selectedTrip?.participants as? Set<Participant>)
            .map { Array($0) } ?? []
    }

    private func getCurrencies() -> [String] {
        var currencies = getAllCurrencies()
        if let tripCurrency = currentTrip?.currencyCode {
            currencies.removeAll { $0 == tripCurrency }
            currencies.insert(tripCurrency, at: 0)
        }
        return currencies
    }

    @ViewBuilder
    private func formSection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(AppFont.caption)
                .foregroundColor(.textSecondary)
            content()
        }
    }

    @ViewBuilder
    private func validationBanner(error: ValidationError) -> some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "exclamationmark.circle.fill")
                .foregroundColor(.red)
                .font(.system(size: 16))
            VStack(alignment: .leading, spacing: 2) {
                Text("Ошибка")
                    .font(AppFont.caption)
                    .foregroundColor(.red)
                Text(error.errorDescription ?? "Неизвестная ошибка")
                    .font(AppFont.tiny)
                    .foregroundColor(.textSecondary)
                    .lineLimit(2)
            }
            Spacer()
        }
        .padding(Spacing.md)
        .background(Color.red.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Save

    private func saveExpense() {
        do {
            try Validators.validateName(name)
            let amountDecimal = try Validators.validateAmount(amount)

            guard let trip = currentTrip else {
                validationError = .noTripSelected; return
            }

            let resolvedPaidBy: Participant?
            if isPersonalExpense {
                let parts = (trip.participants as? Set<Participant>) ?? []
                resolvedPaidBy = parts.first(where: { $0.isOwner }) ?? parts.first
            } else {
                resolvedPaidBy = selectedPaidBy
            }

            guard let paidBy = resolvedPaidBy else {
                validationError = .noPayerSelected; return
            }

            let sharedWith = isPersonalExpense ? [paidBy] : selectedSharedWith
            if !isPersonalExpense && sharedWith.isEmpty {
                validationError = .noParticipantsSelected; return
            }

            switch mode {
            case .add(_, let onSave):
                onSave(
                    name.trimmingCharacters(in: .whitespaces),
                    trip, paidBy, sharedWith,
                    selectedCategory, amountDecimal,
                    currency, selectedDate
                )

            case .edit(let expense, _, let onSave):
                expense.descriptionText = name.trimmingCharacters(in: .whitespaces)
                expense.amount          = amountDecimal as NSDecimalNumber
                expense.date            = selectedDate
                expense.currency        = currency
                expense.category        = selectedCategory.rawValue
                expense.paidBy          = paidBy
                expense.isShared        = !isPersonalExpense
                expense.sharedWithParticipantIDs = isPersonalExpense
                    ? (paidBy.id.map { [$0] } ?? [])
                    : sharedWith.compactMap { $0.id }
                expense.updatedAt = Date()
                expense.isSynced  = false
                try? expense.managedObjectContext?.save()
                Task { await SyncService.shared.uploadExpense(expense) }
                onSave()
            }

            dismiss()

        } catch let error as ValidationError {
            validationError = error
        } catch {
            validationError = .invalidAmount
        }
    }
}

// MARK: - Preview

#Preview("Добавление") {
    let ctx = PersistenceController.preview.container.viewContext

    let trip = Trip(context: ctx)
    trip.id = UUID(); trip.name = "Турция 2026"; trip.currencyCode = "TRY"

    let p1 = Participant(context: ctx); p1.id = UUID(); p1.name = "Нина"; p1.trip = trip
    let p2 = Participant(context: ctx); p2.id = UUID(); p2.name = "Паша"; p2.trip = trip
    trip.addToParticipants(p1); trip.addToParticipants(p2)

    return ExpenseFormSheet(mode: .add(trips: [trip]) { name, trip, paidBy, sharedWith, category, amount, currency, date in
        print("Saved: \(name), \(amount) \(currency)")
    })
    .environment(\.managedObjectContext, ctx)
}
