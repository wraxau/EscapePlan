import SwiftUI
import CoreData
import FirebaseAuth

struct DebtsView: View {

    @Environment(\.managedObjectContext) private var context
    @EnvironmentObject var tripVM: TripViewModel

    @StateObject private var currencyService = CurrencyService.shared

    @State private var selectedTrip: Trip? = nil
    @State private var debts: [DebtSummary] = []
    @State private var participants: [Participant] = []
    @State private var displayCurrency: String = "EUR"   // Валюта отображения
    @State private var settledKeys: Set<String> = []     // Ключи оплаченных долгов

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                tripPickerSection
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)

                if selectedTrip != nil {
                    currencyPickerSection
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                }

                if selectedTrip == nil {
                    noTripState
                } else if debts.isEmpty || unpaidDebts.isEmpty && debts.allSatisfy({ settledKeys.contains(debtKey($0)) }) {
                    emptyState
                } else {
                    debtsList
                }
            }
            .navigationTitle("Долги")
            .navigationBarTitleDisplayMode(.large)
            .appNavBar()
            .screenBackground()
            .onAppear {
                if selectedTrip == nil {
                    selectedTrip = tripVM.trips.first
                    displayCurrency = selectedTrip?.currencyCode ?? "EUR"
                    recalculate()
                }
                loadSettledKeys()
                Task { await currencyService.fetchIfNeeded() }
            }
        }
    }

    // MARK: - Currency Picker

    private var currencyPickerSection: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Spacing.sm) {
                ForEach(CurrencyService.popularCurrencies, id: \.self) { code in
                    FilterChip(label: code, isSelected: displayCurrency == code) {
                        displayCurrency = code
                    }
                }
            }
            .padding(.horizontal, Spacing.xs)
        }
    }

    // MARK: - Trip Picker

    private var tripPickerSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text("Поездка")
                .font(AppFont.caption)
                .foregroundColor(.textSecondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Spacing.sm) {
                    ForEach(tripVM.trips, id: \.id) { trip in
                        FilterChip(
                            label: trip.name ?? "Поездка",
                            icon: "suitcase",
                            isSelected: selectedTrip?.id == trip.id
                        ) {
                            selectedTrip = trip
                            recalculate()
                        }
                    }
                }
                .padding(.horizontal, Spacing.xs)
            }
        }
    }

    // MARK: - Debts List

    private var debtsList: some View {
        let currentUID  = Auth.auth().currentUser?.uid
        let currentPart = participants.first { $0.firebaseUID == currentUID }
        let iOwe   = unpaidDebts.filter { $0.from.id == currentPart?.id }
        let owedMe = unpaidDebts.filter { $0.to.id   == currentPart?.id }
        let others = unpaidDebts.filter {
            $0.from.id != currentPart?.id && $0.to.id != currentPart?.id
        }

        return List {
            // Сводная карточка
            Section {
                summaryCard(iOwe: iOwe, owedMe: owedMe)
                    .listRowInsets(.init(top: Spacing.md, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                    .listRowSeparator(.hidden)
                    .listRowBackground(Color.clear)
            }

            // Я должна
            if !iOwe.isEmpty {
                Section {
                    ForEach(iOwe, id: \.id) { debt in
                        debtCard(debt)
                            .listRowInsets(.init(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    HStack {
                        Text("Я должна")
                            .font(AppFont.caption).foregroundColor(.redAccent)
                        Spacer()
                        Button("Рассчитаться всё") { settleAll(iOwe) }
                            .font(AppFont.caption.weight(.semibold))
                            .foregroundColor(.primaryAccent)
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.sm)
                }
            }

            if !owedMe.isEmpty {
                Section {
                    ForEach(owedMe, id: \.id) { debt in
                        debtCard(debt)
                            .listRowInsets(.init(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Мне должны")
                        .font(AppFont.caption).foregroundColor(.greenPrimary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                }
            }

            // Остальные долги между другими участниками
            if !others.isEmpty {
                Section {
                    ForEach(others, id: \.id) { debt in
                        debtCard(debt)
                            .listRowInsets(.init(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                            .listRowSeparator(.hidden)
                            .listRowBackground(Color.clear)
                    }
                } header: {
                    Text("Между участниками")
                        .font(AppFont.caption).foregroundColor(.textSecondary)
                        .padding(.horizontal, Spacing.md)
                        .padding(.top, Spacing.sm)
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
    }

    // MARK: - Summary Card

    private func summaryCard(iOwe: [DebtSummary], owedMe: [DebtSummary]) -> some View {
        let currency = selectedTrip?.currencyCode ?? "USD"
        let totalIOwe   = iOwe.reduce(Decimal(0))   { $0 + $1.amount }
        let totalOwedMe = owedMe.reduce(Decimal(0))  { $0 + $1.amount }

        return AppCard {
            HStack(spacing: 0) {

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Я должна")
                        .font(AppFont.tiny)
                        .foregroundColor(.textSecondary)
                    Text("\(currency) \(totalIOwe.ceiledString)")
                        .font(AppFont.headline)
                        .foregroundColor(totalIOwe > 0 ? .redAccent : .greenPrimary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 36).padding(.horizontal, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Мне должны")
                        .font(AppFont.tiny)
                        .foregroundColor(.textSecondary)
                    Text("\(currency) \(totalOwedMe.ceiledString)")
                        .font(AppFont.headline)
                        .foregroundColor(totalOwedMe > 0 ? .greenPrimary : .textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Divider().frame(height: 36).padding(.horizontal, Spacing.sm)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text("Участников")
                        .font(AppFont.tiny)
                        .foregroundColor(.textSecondary)
                    Text("\(participants.count)")
                        .font(AppFont.headline)
                        .foregroundColor(.primaryAccent)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Debt Card

    @ViewBuilder
    private func debtCard(_ debt: DebtSummary) -> some View {
        let isSettled = settledKeys.contains(debtKey(debt))

        AppCard {
            HStack(spacing: Spacing.md) {

                // Должник
                participantLabel(
                    name: debt.from.name ?? "?",
                    tintColor: isSettled ? .greenPrimary : .redAccent
                )

                // Стрелка + сумма + статус
                VStack(spacing: Spacing.xxs) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(isSettled ? .greenPrimary : .textSecondary)
                    let origCode = selectedTrip?.currencyCode ?? "EUR"
                    let converted = currencyService.convert(debt.amount, from: origCode, to: displayCurrency)
                    Text(currencyService.formatted(converted, in: displayCurrency))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(isSettled ? .greenPrimary : .primaryAccent)
                    if currencyService.isLoading {
                        ProgressView().scaleEffect(0.6)
                    }
                    AppTag(
                        text: isSettled ? "Оплачено" : "Ожидает",
                        color: isSettled ? .greenPrimary : .redAccent
                    )
                }
                .frame(maxWidth: .infinity)

                // Кредитор
                participantLabel(
                    name: debt.to.name ?? "?",
                    tintColor: isSettled ? .greenPrimary : .primaryAccent
                )
            }
        }
        .swipeActions(edge: .leading) {
            if isSettled {
                Button {
                    unsettle(debt)
                } label: {
                    Label("Отменить", systemImage: "clock.fill")
                }
                .tint(.redAccent)
            } else {
                Button {
                    settle(debt)
                } label: {
                    Label("Оплачено", systemImage: "checkmark.circle.fill")
                }
                .tint(.greenPrimary)
            }
        }
    }

    @ViewBuilder
    private func participantLabel(name: String, tintColor: Color) -> some View {
        VStack(spacing: Spacing.xs) {
            ParticipantAvatar(name: name, size: 44, tintColor: tintColor)
            Text(name.components(separatedBy: " ").first ?? name)
                .font(AppFont.tiny)
                .foregroundColor(.textPrimary)
                .lineLimit(1)
        }
        .frame(minWidth: 60)
    }

    // MARK: - States

    private var noTripState: some View {
        EmptyStateView(
            icon: "suitcase",
            title: "Нет поездок",
            subtitle: "Создай первую поездку, чтобы видеть расчёты"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "checkmark.seal.fill",
            title: "Все расчитались!",
            subtitle: "В этой поездке нет долгов между участниками"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Settled debts helpers

    private var unpaidDebts: [DebtSummary] {
        debts.filter { !settledKeys.contains(debtKey($0)) }
    }

    private func debtKey(_ debt: DebtSummary) -> String {
        let tripId = selectedTrip?.id?.uuidString ?? "unknown"
        let fromId = debt.from.id?.uuidString ?? "?"
        let toId   = debt.to.id?.uuidString   ?? "?"
        return "\(tripId)_\(fromId)_\(toId)"
    }

    private func settle(_ debt: DebtSummary) {
        HapticFeedback.success()
        settledKeys.insert(debtKey(debt))
        saveSettledKeys()
    }

    private func unsettle(_ debt: DebtSummary) {
        HapticFeedback.medium()
        settledKeys.remove(debtKey(debt))
        saveSettledKeys()
    }

    private func settleAll(_ debts: [DebtSummary]) {
        debts.forEach { settledKeys.insert(debtKey($0)) }
        saveSettledKeys()

        guard let trip = selectedTrip else { return }
        let currentUID = Auth.auth().currentUser?.uid
        let currentPart = participants.first { $0.firebaseUID == currentUID }
        guard let pid = currentPart?.id else { return }

        let vm = ExpenseViewModel(trip: trip, context: context)
        for expense in vm.expenses where expense.isShared {
            if let sharedIDs = expense.sharedWithParticipantIDs as? [UUID],
               sharedIDs.contains(pid),
               (expense.debtStatus ?? "pending") == "pending" {
                expense.debtStatus = "paid"
                expense.updatedAt = Date()
            }
        }
        try? context.save()
        recalculate()
    }

    private func userDefaultsKey() -> String {
        "settledDebts_\(selectedTrip?.id?.uuidString ?? "global")"
    }

    private func saveSettledKeys() {
        UserDefaults.standard.set(Array(settledKeys), forKey: userDefaultsKey())
    }

    private func loadSettledKeys() {
        let saved = UserDefaults.standard.stringArray(forKey: userDefaultsKey()) ?? []
        settledKeys = Set(saved)
    }

    // MARK: - Recalculate

    private func recalculate() {
        guard let trip = selectedTrip else {
            debts = []
            participants = []
            return
        }

        participants = ((trip.participants as? Set<Participant>) ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }

        let vm = ExpenseViewModel(trip: trip, context: context)

        let currentUID = Auth.auth().currentUser?.uid
        let currentParticipant = participants.first { $0.firebaseUID == currentUID }
        debts = vm.calculateDebts(
            participants: participants,
            baseCurrency: trip.currencyCode ?? "USD",
            currentParticipantID: currentParticipant?.id
        )
        loadSettledKeys()
    }
}

// MARK: - Preview

#Preview {
    DebtsView()
        .environmentObject(TripViewModel(context: PersistenceController.preview.container.viewContext))
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
