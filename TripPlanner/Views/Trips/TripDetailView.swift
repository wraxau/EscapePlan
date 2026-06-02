import SwiftUI
import CoreData
import Foundation

// MARK: - Tab enum

enum TripDetailTab: Int, CaseIterable {
    case days, expenses, places, participants

    var title: String {
        switch self {
        case .days:         return "Дни"
        case .expenses:     return "Расходы"
        case .places:       return "Места"
        case .participants: return "Участники"
        }
    }

    var icon: String {
        switch self {
        case .days:         return "calendar"
        case .expenses:     return "creditcard"
        case .places:       return "mappin.and.ellipse"
        case .participants: return "person.2"
        }
    }
}

// MARK: - TripDetailView

struct TripDetailView: View {

    let trip: Trip

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var dayPlanVM: DayPlanViewModel
    @StateObject private var participantVM: ParticipantViewModel
    @StateObject private var expenseVM: ExpenseViewModel

    @State private var selectedTab: TripDetailTab = .days
    @State private var showSchedule = false
    @State private var showEditTrip = false
    @State private var syncTimer: Timer?
    @State private var syncError: String? = nil

    init(trip: Trip, context: NSManagedObjectContext) {
        self.trip = trip
        _dayPlanVM      = StateObject(wrappedValue: DayPlanViewModel(trip: trip, context: context))
        _participantVM  = StateObject(wrappedValue: ParticipantViewModel(trip: trip, context: context))
        _expenseVM      = StateObject(wrappedValue: ExpenseViewModel(trip: trip, context: context))
    }

    var body: some View {
        Color.appBackground
            .ignoresSafeArea()
            .overlay(
                VStack(spacing: 0) {
                    tripHeader
                    if case .syncing = SyncService.shared.syncState {
                        SyncStatusView(
                            syncState: SyncService.shared.syncState,
                            onRetry: { Task { await syncAllData() } }
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                    } else if case .error = SyncService.shared.syncState {
                        SyncStatusView(
                            syncState: SyncService.shared.syncState,
                            onRetry: { Task { await syncAllData() } }
                        )
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.xs)
                    }
                    tabBar
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.sm)
                        .background(Color.appBackground)
                    tabContent
                }
            )
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showEditTrip = true } label: {
                    NavBarIconButton(icon: "pencil")
                }
            }
        }
        .task {

            await syncAllData()
            syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [self] _ in
                Task {
                    await self.syncAllData()
                }
            }
        }
        .onChange(of: scenePhase) { newPhase in
            if newPhase == .background {

                syncTimer?.invalidate()
                syncTimer = nil
            } else if newPhase == .active {
                Task {
                    await self.syncAllData()
                }
                syncTimer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [self] _ in
                    Task {
                        await self.syncAllData()
                    }
                }
            }
        }
        .onDisappear {
            syncTimer?.invalidate()
            syncTimer = nil
        }
        .errorToast(message: $syncError)
        .onReceive(SyncService.shared.$errorMessage) { msg in
            guard let msg else { return }
            syncError = msg
        }
        .sheet(isPresented: $showEditTrip) {
            EditTripSheet(trip: trip, context: context)
        }
        .navigationDestination(isPresented: $showSchedule) {
            DayScheduleView(trip: trip, dayPlanVM: dayPlanVM, context: context)
                .navigationTitle("Расписание по дням")
                .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Header

    private var tripHeader: some View {
        VStack(spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                Group {
                    if let data = trip.coverImageData, let img = UIImage(data: data) {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        LinearGradient(
                            colors: [.primaryAccent, .secondaryAccent],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .clipped()

                // Затемнение снизу
                LinearGradient(
                    colors: [.clear, .black.opacity(0.55)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 200)

                VStack(alignment: .leading, spacing: Spacing.xs) {
                    Text(trip.name ?? "Поездка")
                        .font(AppFont.title)
                        .foregroundColor(.white)

                    HStack {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "calendar")
                                .font(.system(size: 12))
                            Text(dateRange)
                                .font(AppFont.caption)
                        }
                        .foregroundColor(.white.opacity(0.85))

                        Spacer()

                        let names = participantVM.participants.compactMap { $0.name }
                        if !names.isEmpty {
                            AvatarStack(names: names, maxVisible: 4, size: 28)
                        }
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.bottom, Spacing.md)
            }
            Button {
                showSchedule = true
            } label: {
                HStack(spacing: Spacing.xs) {
                    Image(systemName: "calendar.day.timeline.left")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Расписание по дням")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundColor(.primaryAccent)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color(.systemBackground))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 4) {
            ForEach(TripDetailTab.allCases, id: \.rawValue) { tab in
                tabChip(tab)
            }
        }
        .padding(4)
        .background(Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    @ViewBuilder
    private func tabChip(_ tab: TripDetailTab) -> some View {
        let isSelected = selectedTab == tab
        Button {
            withAnimation(AppAnimation.quick) { selectedTab = tab }
        } label: {
            Text(tab.title)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(1)
                .foregroundColor(isSelected ? .buttonText : .textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(isSelected ? Color.primaryAccent : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: Radius.sm))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .days:
            DaysTab(dayPlanVM: dayPlanVM, trip: trip, showSchedule: $showSchedule)
        case .expenses:
            ExpensesTab(expenseVM: expenseVM, trip: trip)
        case .places:
            PlacesTab(trip: trip, context: context)
        case .participants:
            ParticipantsTab(participantVM: participantVM, trip: trip)
        }
    }

    // MARK: - Sync Helper

    /// Синхронизирует все данные поездки из Firestore
    private func syncAllData() async {
        async let expenseSync: ()     = SyncService.shared.syncExpenses(for: trip, context: context)
        async let participantSync: () = SyncService.shared.fetchParticipants(for: trip, context: context)
        async let placeSync: ()       = SyncService.shared.fetchPlaces(for: trip, context: context)
        async let dayPlanSync: ()     = SyncService.shared.fetchDayPlans(for: trip, context: context)
        _ = await (expenseSync, participantSync, placeSync, dayPlanSync)

        for day in dayPlanVM.dayPlans {
            await SyncService.shared.fetchActivities(for: day, trip: trip, context: context)
        }

        // Обновляем UI
        expenseVM.fetch()
        participantVM.fetch()
        dayPlanVM.fetch()
    }

    // MARK: - Helpers

    private var dateRange: String {
        guard let start = trip.startDate else { return "Даты не указаны" }
        let startStr = start.formattedDateAbbreviated()
        guard let end = trip.endDate else { return "с \(startStr)" }
        return "\(startStr) — \(end.formattedDateAbbreviated())"
    }
}

// MARK: - Days Tab

private struct DaysTab: View {

    @ObservedObject var dayPlanVM: DayPlanViewModel
    let trip: Trip
    @Binding var showSchedule: Bool

    @State private var showAddDay = false
    @State private var newDayDate = Date()
    @State private var newDayNotes = ""

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            ScrollView {
                if dayPlanVM.dayPlans.isEmpty {
                    emptyDaysState
                } else {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(dayPlanVM.dayPlans, id: \.id) { day in
                            Button {
                                showSchedule = true
                            } label: {
                                DayPlanCard(
                                    dayNumber: dayPlanVM.dayNumber(for: day),
                                    date: day.date ?? Date(),
                                    placesCount: dayPlanVM.placesCount(for: day)
                                )
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button(role: .destructive) {
                                    dayPlanVM.deleteDayPlan(day)
                                } label: {
                                    Label("Удалить день", systemImage: "trash")
                                }
                            }
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABButton(icon: "plus") {
                        newDayDate = Date()
                        newDayNotes = ""
                        showAddDay = true
                    }
                    .padding(.trailing, Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        }
        .sheet(isPresented: $showAddDay) {
            AddDaySheet(
                trip: trip,
                dayPlanVM: dayPlanVM,
                selectedDate: $newDayDate,
                notes: $newDayNotes
            )
            .presentationDetents([.medium])
        }
    }

    private var emptyDaysState: some View {
        VStack(spacing: Spacing.lg) {
            Spacer(minLength: 40)

            EmptyStateView(
                icon: "calendar.badge.plus",
                title: "Дни не добавлены",
                subtitle: trip.startDate != nil
                    ? "Нажми «Создать по датам» и дни появятся автоматически"
                    : "Добавь день вручную или укажи даты поездки"
            )

            if trip.startDate != nil {
                PrimaryButton(title: "Создать по датам", icon: "wand.and.stars") {
                    dayPlanVM.generateDaysFromTripDates()
                }
                .padding(.horizontal, Spacing.buttonHorizontalPadding)
            }

            Spacer(minLength: 60)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Add Day Sheet

private struct AddDaySheet: View {

    let trip: Trip
    @ObservedObject var dayPlanVM: DayPlanViewModel
    @Binding var selectedDate: Date
    @Binding var notes: String
    @Environment(\.dismiss) private var dismiss

    private func formattedDate(_ date: Date) -> String {
        date.formattedDateWithWeekday()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    // Иконка
                    ZStack {
                        Circle()
                            .fill(Color.primaryAccent.opacity(0.12))
                            .frame(width: 64, height: 64)
                        Image(systemName: "calendar.badge.plus")
                            .font(.system(size: 28))
                            .foregroundColor(.primaryAccent)
                    }
                    .padding(.top, Spacing.sm)

                    // Дата
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Дата")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        HStack {
                            Image(systemName: "calendar")
                                .foregroundColor(.primaryAccent)
                                .font(.system(size: 16))

                            DatePicker(
                                "",
                                selection: $selectedDate,
                                displayedComponents: .date
                            )
                            .datePickerStyle(.compact)
                            .tint(.primaryAccent)
                            .labelsHidden()
                            .environment(\.locale, Locale(identifier: "ru_RU"))

                            Spacer()

                            Text(formattedDate(selectedDate))
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                                .lineLimit(1)
                        }
                        .padding(Spacing.md)
                        .background(Color.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .padding(.horizontal, Spacing.md)

                    // Заметки на день
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Заметки (необязательно)")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        ZStack(alignment: .topLeading) {
                            if notes.isEmpty {
                                Text("Планы на день, напоминания...")
                                    .font(AppFont.body)
                                    .foregroundColor(.textSecondary.opacity(0.6))
                                    .padding(.horizontal, Spacing.md)
                                    .padding(.top, Spacing.md)
                            }
                            TextEditor(text: $notes)
                                .font(AppFont.body)
                                .foregroundColor(.textPrimary)
                                .tint(.primaryAccent)
                                .frame(minHeight: 80, maxHeight: 120)
                                .padding(.horizontal, Spacing.sm)
                                .padding(.vertical, Spacing.xs)
                                .scrollContentBackground(.hidden)
                        }
                        .background(Color.inputBackground)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                    }
                    .padding(.horizontal, Spacing.md)

                    PrimaryButton(title: "Добавить день", icon: "plus") {
                        let trimmedNotes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
                        dayPlanVM.addDayPlan(
                            date: selectedDate,
                            notes: trimmedNotes.isEmpty ? nil : trimmedNotes
                        )
                        dismiss()
                    }
                    .padding(.horizontal, Spacing.buttonHorizontalPadding)
                    .padding(.bottom, Spacing.xl)
                }
                .padding(.top, Spacing.sm)
            }
            .screenBackground()
            .navigationTitle("Новый день")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        NavBarIconButton(icon: "xmark")
                    }
                }
            }
        }
    }
}

// MARK: - Expenses Tab

private struct ExpensesTab: View {

    @ObservedObject var expenseVM: ExpenseViewModel
    let trip: Trip

    @State private var showAddExpense = false
    @State private var expenseToEdit: Expense? = nil
    @State private var selectedParticipant: Participant? = nil

    private var participants: [Participant] {
        ((trip.participants as? Set<Participant>) ?? [])
            .sorted { ($0.name ?? "") < ($1.name ?? "") }
    }

    private var filteredExpenses: [Expense] {
        guard let p = selectedParticipant else { return expenseVM.expenses }
        return expenseVM.expenses.filter { expense in
            expense.paidBy?.id == p.id ||
            (expense.sharedWithParticipantIDs as? [UUID])?.contains(p.id ?? UUID()) == true
        }
    }

    // MARK: - Статистика

    private var avgPerDay: String {
        guard let start = trip.startDate, let end = trip.endDate else { return "—" }
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
        let total = filteredExpenses.reduce(Decimal(0)) { $0 + (($1.amount as Decimal?) ?? 0) }
        return (total / Decimal(days)).ceiledString
    }

    private var topCategory: String {
        let grouped = Dictionary(grouping: filteredExpenses) { $0.category ?? "" }
            .mapValues { $0.reduce(Decimal(0)) { $0 + (($1.amount as Decimal?) ?? 0) } }
        guard let top = grouped.max(by: { $0.value < $1.value }),
              let cat = ExpenseCategory(rawValue: top.key) else { return "—" }
        return cat.title
    }

    private var totalSpent: String {
        let total = filteredExpenses.reduce(Decimal(0)) { $0 + (($1.amount as Decimal?) ?? 0) }
        return total.ceiledString
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            if expenseVM.expenses.isEmpty {
                EmptyStateView(
                    icon: "creditcard",
                    title: "Нет расходов",
                    subtitle: "Нажми + чтобы добавить первый расход"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List {
                    // Статистика
                    Section {
                        AppCard {
                            HStack(spacing: 0) {
                                statCell(label: "Итого", value: "\(trip.currencyCode ?? "USD") \(totalSpent)")
                                Divider().frame(height: 32).padding(.horizontal, Spacing.sm)
                                statCell(label: "В день", value: "\(trip.currencyCode ?? "USD") \(avgPerDay)")
                                Divider().frame(height: 32).padding(.horizontal, Spacing.sm)
                                statCell(label: "Топ категория", value: topCategory)
                            }
                        }
                        .listRowInsets(.init(top: Spacing.sm, leading: Spacing.md, bottom: 0, trailing: Spacing.md))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    // Фильтр по участнику
                    Section {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                FilterChip(label: "Все", isSelected: selectedParticipant == nil) {
                                    selectedParticipant = nil
                                }
                                ForEach(participants, id: \.id) { p in
                                    FilterChip(
                                        label: p.name ?? "?",
                                        icon: "person.fill",
                                        isSelected: selectedParticipant?.id == p.id
                                    ) { selectedParticipant = p }
                                }
                            }
                            .padding(.horizontal, Spacing.xs)
                        }
                        .listRowInsets(.init(top: Spacing.sm, leading: Spacing.md, bottom: Spacing.sm, trailing: Spacing.md))
                        .listRowSeparator(.hidden)
                        .listRowBackground(Color.clear)
                    }

                    // Список расходов
                    Section {
                        if filteredExpenses.isEmpty {
                            Text("Нет расходов для выбранного участника")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                        } else {
                            ForEach(filteredExpenses, id: \.id) { expense in
                                ExpenseRowView(
                                    expense: expense,
                                    currencyCode: trip.currencyCode ?? "USD",
                                    onEdit: { expenseToEdit = expense },
                                    onToggle: {
                                        let newStatus = ((expense.debtStatus ?? "pending") == "pending") ? "paid" : "pending"
                                        expense.debtStatus = newStatus
                                        expense.updatedAt = Date()
                                        try? expense.managedObjectContext?.save()
                                        expenseVM.fetch()
                                    }
                                )
                                .listRowInsets(.init(top: Spacing.xs, leading: Spacing.md, bottom: Spacing.xs, trailing: Spacing.md))
                                .listRowSeparator(.hidden)
                                .listRowBackground(Color.clear)
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
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
        .sheet(isPresented: $showAddExpense) {
            ExpenseFormSheet(mode: .add(trips: [trip]) { name, trip, paidBy, sharedWith, category, amount, currency, date in
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
            })
        }
        .sheet(item: $expenseToEdit) { expense in
            ExpenseFormSheet(mode: .edit(expense: expense, trip: trip) {
                expenseVM.fetch()
            })
        }
        .onReceive(NotificationCenter.default.publisher(for: NSManagedObjectContext.didSaveObjectsNotification)) { _ in
            expenseVM.fetch()
        }
    }

    @ViewBuilder
    private func statCell(label: String, value: String) -> some View {
        VStack(spacing: Spacing.xxs) {
            Text(label)
                .font(AppFont.tiny)
                .foregroundColor(.textSecondary)
            Text(value)
                .font(AppFont.caption.weight(.semibold))
                .foregroundColor(.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }

}

// MARK: - Participants Tab

private struct ParticipantsTab: View {

    @ObservedObject var participantVM: ParticipantViewModel
    let trip: Trip

    @State private var showAddParticipant = false
    @State private var showInviteByEmail = false
    @State private var newName = ""
    @State private var inviteEmail = ""
    @State private var isSendingInvite = false
    @State private var showInviteSuccess = false
    @State private var showInviteError = false
    @State private var inviteErrorText = ""

    private var ownerName: String {
        participantVM.participants.first { $0.isOwner }?.name ?? "Владелец"
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            if participantVM.participants.isEmpty {
                EmptyStateView(
                    icon: "person.badge.plus",
                    title: "Нет участников",
                    subtitle: "Добавь участников поездки"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                participantList
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABButton(icon: "person.badge.plus") {
                        showAddParticipant = true
                    }
                    .padding(.trailing, Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        }

        .sheet(isPresented: $showAddParticipant, onDismiss: { newName = "" }) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: Spacing.lg) {

                        // Добавить по имени
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Добавить по имени")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                            AppTextField(
                                placeholder: "Имя участника",
                                text: $newName,
                                icon: "person.fill"
                            )
                        }
                        .padding(.horizontal, Spacing.md)

                        PrimaryButton(title: "Добавить", icon: "checkmark") {
                            let trimmed = newName.trimmingCharacters(in: .whitespaces)
                            guard !trimmed.isEmpty else { return }
                            participantVM.addParticipant(name: trimmed)
                            showAddParticipant = false
                        }
                        .disabled(newName.trimmingCharacters(in: .whitespaces).isEmpty)
                        .opacity(newName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
                        .padding(.horizontal, Spacing.buttonHorizontalPadding)

                        // Разделитель
                        HStack {
                            Rectangle().fill(Color.textSecondary.opacity(0.2)).frame(height: 1)
                            Text("или")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                                .padding(.horizontal, Spacing.sm)
                            Rectangle().fill(Color.textSecondary.opacity(0.2)).frame(height: 1)
                        }
                        .padding(.horizontal, Spacing.md)

                        // Пригласить по email
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Пригласить по email")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                            AppTextField(
                                placeholder: "Email друга",
                                text: $inviteEmail,
                                icon: "envelope",
                                keyboardType: .emailAddress
                            )
                            .autocorrectionDisabled()
                            .textInputAutocapitalization(.never)
                        }
                        .padding(.horizontal, Spacing.md)

                        PrimaryButton(title: isSendingInvite ? "Отправка..." : "Отправить приглашение") {
                            sendInvite()
                        }
                        .disabled(!inviteEmail.contains("@") || isSendingInvite)
                        .padding(.horizontal, Spacing.md)
                        .padding(.bottom, Spacing.xl)
                    }
                    .padding(.top, Spacing.lg)
                }
                .screenBackground()
                .navigationTitle("Добавить участника")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(action: { showAddParticipant = false }) {
                            NavBarIconButton(icon: "xmark")
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .alert("Приглашение отправлено", isPresented: $showInviteSuccess) {
                Button("Готово", role: .cancel) { showAddParticipant = false }
            } message: {
                Text("Приглашение на \(inviteEmail) отправлено. Друг увидит его при входе в приложение.")
            }
            .alert("Ошибка", isPresented: $showInviteError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(inviteErrorText)
            }
        }
    }

    private func sendInvite() {
        let email = inviteEmail.trimmingCharacters(in: .whitespaces)
        guard email.contains("@") else { return }
        isSendingInvite = true
        Task {
            let success = await SyncService.shared.sendInvitation(
                toEmail: email,
                trip: trip,
                ownerName: ownerName
            )
            isSendingInvite = false
            if success {
                showInviteSuccess = true
            } else {
                inviteErrorText = SyncService.shared.errorMessage ?? "Не удалось отправить приглашение"
                showInviteError = true
            }
        }
    }

    private var participantList: some View {
        ScrollView {
            LazyVStack(spacing: Spacing.sm) {
                ForEach(participantVM.participants, id: \.id) { participant in
                    participantRow(participant)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
        }
        .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
    }

    @ViewBuilder
    private func participantRow(_ participant: Participant) -> some View {
        AppCard {
            HStack(spacing: Spacing.md) {

                ParticipantAvatar(
                    name: participant.name ?? "?",
                    size: 44,
                    isOwner: participant.isOwner
                )

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(participant.name ?? "Без имени")
                        .font(AppFont.headline)
                        .foregroundColor(.textPrimary)

                    if participant.isOwner {
                        Text("Владелец поездки")
                            .font(AppFont.tiny)
                            .foregroundColor(.primaryAccent)
                    } else if let email = participant.email, !email.isEmpty {
                        Text(email)
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                    }
                }

                Spacer()

                Menu {
                    if !participant.isOwner {
                        Button {
                            participantVM.transferOwnership(to: participant)
                        } label: {
                            Label("Назначить владельцем", systemImage: "crown")
                        }
                    }

                    Divider()

                    Button(role: .destructive) {
                        participantVM.deleteParticipant(participant)
                    } label: {
                        Label("Удалить", systemImage: "trash")
                    }
                } label: {
                    IconButton(icon: "ellipsis", color: .textSecondary) {}
                }
            }
        }
    }
}

// MARK: - Places Tab

private struct PlacesTab: View {

    let trip: Trip
    let context: NSManagedObjectContext

    @State private var places: [Place] = []
    @State private var dayPlans: [DayPlan] = []
    @State private var showAddPlace = false
    @State private var showEditPlace = false
    @State private var selectedPlaceToEdit: Place? = nil
    @State private var showMapPicker = false
    @State private var newPlaceName = ""
    @State private var newPlaceAddress = ""
    @State private var newPlaceType = "attraction"
    @State private var newPlaceLat: Double = 0
    @State private var newPlaceLng: Double = 0
    @State private var newPlaceDayPlan: DayPlan? = nil
    @State private var attachToAllDays = false

    private let placeTypes = ["attraction", "hotel", "restaurant", "museum", "park", "other"]

    private func placeIcon(_ type: String) -> String {
        switch type {
        case "hotel":      return "bed.double.fill"
        case "restaurant": return "fork.knife"
        case "museum":     return "building.columns.fill"
        case "park":       return "leaf.fill"
        case "other":      return "mappin.and.ellipse"
        default:           return "star.fill"
        }
    }

    private func placeTypeTitle(_ type: String) -> String {
        switch type {
        case "hotel":      return "Отель"
        case "restaurant": return "Ресторан"
        case "museum":     return "Музей"
        case "park":       return "Парк"
        case "other":      return "Другое"
        default:           return "Достопримечательность"
        }
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {

            if places.isEmpty {
                EmptyStateView(
                    icon: "mappin.circle",
                    title: "Нет мест",
                    subtitle: "Добавь интересные места поездки"
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: Spacing.sm) {
                        ForEach(places, id: \.id) { place in
                            placeRow(place)
                        }
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 100) }
            }

            VStack {
                Spacer()
                HStack {
                    Spacer()
                    FABButton(icon: "plus") {
                        showAddPlace = true
                    }
                    .padding(.trailing, Spacing.lg)
                }
            }
            .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
        }
        .onAppear {
            fetchPlaces()
            fetchDayPlans()
        }
        .sheet(isPresented: $showAddPlace, onDismiss: { resetForm() }) {
            addPlaceSheet
        }
        .sheet(isPresented: $showEditPlace, onDismiss: { resetForm() }) {
            editPlaceSheet
        }
    }

    @ViewBuilder
    private func placeRow(_ place: Place) -> some View {
        AppCard {
            HStack(spacing: Spacing.md) {

                ZStack {
                    Circle()
                        .fill(Color.primaryAccent.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: placeIcon(place.type ?? "attraction"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.primaryAccent)
                }

                VStack(alignment: .leading, spacing: Spacing.xxs) {
                    Text(place.name ?? "Место")
                        .font(AppFont.headline)
                        .foregroundColor(.textPrimary)
                    if let address = place.address, !address.isEmpty {
                        Text(address)
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                            .lineLimit(1)
                    }
                    PlaceTypeBadge(type: PlaceType(rawValue: place.type ?? "attraction") ?? .attraction)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
        }
        .onTapGesture {
            selectedPlaceToEdit = place
            newPlaceName = place.name ?? ""
            newPlaceAddress = place.address ?? ""
            newPlaceType = place.type ?? "attraction"
            newPlaceLat = place.latitude
            newPlaceLng = place.longitude
            newPlaceDayPlan = place.dayPlan
            attachToAllDays = false
            showEditPlace = true
        }
        .swipeActions(edge: .trailing) {
            Button(role: .destructive) {
                deletePlace(place)
            } label: {
                Label("Удалить", systemImage: "trash")
            }
        }
    }

    private var addPlaceSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    AppTextField(placeholder: "Название места", text: $newPlaceName, icon: "mappin.and.ellipse")
                    AppTextField(placeholder: "Адрес (необязательно)", text: $newPlaceAddress, icon: "map")

                    // Кнопка «Найти на карте»
                    OutlineButton(title: "Найти на карте", icon: "map.fill") {
                        showMapPicker = true
                    }

                    if newPlaceLat != 0 || newPlaceLng != 0 {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.greenPrimary)
                                .font(.system(size: 14))
                            Text(String(format: "%.4f°, %.4f°", newPlaceLat, newPlaceLng))
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    // Тип места
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Тип места")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(placeTypes, id: \.self) { type in
                                    FilterChip(
                                        label: placeTypeTitle(type),
                                        icon: placeIcon(type),
                                        isSelected: newPlaceType == type
                                    ) {
                                        newPlaceType = type
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.xs)
                        }
                    }

                    // Привязка к дням поездки
                    if !dayPlans.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Привязать к дням")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)

                            // Toggle для привязки ко всем дням
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("Привязать ко всем дням")
                                        .font(AppFont.body)
                                        .foregroundColor(.textPrimary)
                                    Text("Например для отеля")
                                        .font(AppFont.tiny)
                                        .foregroundColor(.textSecondary)
                                }
                                Spacer()
                                Toggle("", isOn: $attachToAllDays)
                                    .tint(.primaryAccent)
                            }
                            .padding(Spacing.md)
                            .background(Color.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                            // Выбор конкретного дня (если не все дни)
                            if !attachToAllDays {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Spacing.sm) {
                                        FilterChip(label: "Не привязывать", icon: "xmark", isSelected: newPlaceDayPlan == nil) {
                                            newPlaceDayPlan = nil
                                        }
                                        ForEach(dayPlans, id: \.id) { day in
                                            let dayNum = (dayPlans.firstIndex(of: day) ?? 0) + 1
                                            FilterChip(
                                                label: "День \(dayNum)",
                                                icon: "calendar",
                                                isSelected: newPlaceDayPlan == day
                                            ) {
                                                newPlaceDayPlan = day
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Spacing.xs)
                                }
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        SendArrowButton(
                            size: 45
                        ) {
                            addPlace()
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Новое место")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { showAddPlace = false }) {
                        NavBarIconButton(icon: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showMapPicker) {
                MapPlacePickerView { lat, lng, name, address in
                    newPlaceLat = lat
                    newPlaceLng = lng
                    if newPlaceName.trimmingCharacters(in: .whitespaces).isEmpty {
                        newPlaceName = name
                    }
                    if newPlaceAddress.trimmingCharacters(in: .whitespaces).isEmpty {
                        newPlaceAddress = address
                    }
                }
            }
        }
    }

    private var editPlaceSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    AppTextField(placeholder: "Название места", text: $newPlaceName, icon: "mappin.and.ellipse")
                    AppTextField(placeholder: "Адрес (необязательно)", text: $newPlaceAddress, icon: "map")

                    // Кнопка «Найти на карте»
                    OutlineButton(title: "Найти на карте", icon: "map.fill") {
                        showMapPicker = true
                    }

                    if newPlaceLat != 0 || newPlaceLng != 0 {
                        HStack(spacing: Spacing.xs) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.greenPrimary)
                                .font(.system(size: 14))
                            Text(String(format: "%.4f°, %.4f°", newPlaceLat, newPlaceLng))
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)
                        }
                    }

                    // Тип места
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Тип места")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(placeTypes, id: \.self) { type in
                                    FilterChip(
                                        label: placeTypeTitle(type),
                                        icon: placeIcon(type),
                                        isSelected: newPlaceType == type
                                    ) {
                                        newPlaceType = type
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.xs)
                        }
                    }

                    // Привязка к дням поездки
                    if !dayPlans.isEmpty {
                        VStack(alignment: .leading, spacing: Spacing.sm) {
                            Text("Привязать к дням")
                                .font(AppFont.caption)
                                .foregroundColor(.textSecondary)

                            // Toggle для привязки ко всем дням
                            HStack {
                                VStack(alignment: .leading, spacing: Spacing.xxs) {
                                    Text("Привязать ко всем дням")
                                        .font(AppFont.body)
                                        .foregroundColor(.textPrimary)
                                    Text("Например для отеля")
                                        .font(AppFont.tiny)
                                        .foregroundColor(.textSecondary)
                                }
                                Spacer()
                                Toggle("", isOn: $attachToAllDays)
                                    .tint(.primaryAccent)
                            }
                            .padding(Spacing.md)
                            .background(Color.inputBackground)
                            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

                            // Выбор конкретного дня (если не все дни)
                            if !attachToAllDays {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    HStack(spacing: Spacing.sm) {
                                        FilterChip(label: "Не привязывать", icon: "xmark", isSelected: newPlaceDayPlan == nil) {
                                            newPlaceDayPlan = nil
                                        }
                                        ForEach(dayPlans, id: \.id) { day in
                                            let dayNum = (dayPlans.firstIndex(of: day) ?? 0) + 1
                                            FilterChip(
                                                label: "День \(dayNum)",
                                                icon: "calendar",
                                                isSelected: newPlaceDayPlan == day
                                            ) {
                                                newPlaceDayPlan = day
                                            }
                                        }
                                    }
                                    .padding(.horizontal, Spacing.xs)
                                }
                            }
                        }
                    }

                    HStack {
                        Spacer()
                        SendArrowButton(
                            size: 45
                        ) {
                            updatePlace()
                        }
                        .padding(.horizontal, Spacing.md)
                    }
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Редактировать место")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { showEditPlace = false }) {
                        NavBarIconButton(icon: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showMapPicker) {
                MapPlacePickerView { lat, lng, name, address in
                    newPlaceLat = lat
                    newPlaceLng = lng
                    if newPlaceName.trimmingCharacters(in: .whitespaces).isEmpty {
                        newPlaceName = name
                    }
                    if newPlaceAddress.trimmingCharacters(in: .whitespaces).isEmpty {
                        newPlaceAddress = address
                    }
                }
            }
        }
    }

    private func fetchPlaces() {
        let request: NSFetchRequest<Place> = Place.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]
        places = (try? context.fetch(request)) ?? []
    }

    private func fetchDayPlans() {
        let request: NSFetchRequest<DayPlan> = DayPlan.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [NSSortDescriptor(keyPath: \DayPlan.date, ascending: true)]
        dayPlans = (try? context.fetch(request)) ?? []
    }

    private func addPlace() {
        let trimmed = newPlaceName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        let place = Place(context: context)
        place.id = UUID()
        place.name = trimmed
        place.address = newPlaceAddress.trimmingCharacters(in: .whitespaces)
        place.type = newPlaceType
        place.latitude = newPlaceLat
        place.longitude = newPlaceLng
        place.isSynced = false
        place.trip = trip

        if attachToAllDays {
            place.dayPlan = nil
        } else {
            place.dayPlan = newPlaceDayPlan
        }

        try? context.save()

        Task { await SyncService.shared.uploadPlace(place) }

        fetchPlaces()
        showAddPlace = false
    }

    private func updatePlace() {
        guard let place = selectedPlaceToEdit else { return }
        let trimmed = newPlaceName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        place.name = trimmed
        place.address = newPlaceAddress.trimmingCharacters(in: .whitespaces)
        place.type = newPlaceType
        place.latitude = newPlaceLat
        place.longitude = newPlaceLng
        place.isSynced = false

        if attachToAllDays {
            place.dayPlan = nil
        } else {
            place.dayPlan = newPlaceDayPlan
        }

        try? context.save()

        Task { await SyncService.shared.uploadPlace(place) }

        fetchPlaces()
        showEditPlace = false
    }

    private func deletePlace(_ place: Place) {
        Task { await SyncService.shared.deletePlace(place) }
        context.delete(place)
        try? context.save()
        fetchPlaces()
    }

    private func resetForm() {
        newPlaceName = ""
        newPlaceAddress = ""
        newPlaceType = "attraction"
        newPlaceLat = 0
        newPlaceLng = 0
        newPlaceDayPlan = nil
        attachToAllDays = false
        selectedPlaceToEdit = nil
    }

}

// MARK: - Edit Trip Sheet

private struct EditTripSheet: View {

    let trip: Trip
    let context: NSManagedObjectContext
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var currencyCode: String
    @State private var hasStartDate: Bool
    @State private var hasEndDate: Bool

    private let currencies = ["USD", "EUR", "RUB", "GBP", "JPY", "CNY", "TRY", "AED", "THB"]

    init(trip: Trip, context: NSManagedObjectContext) {
        self.trip = trip
        self.context = context
        _name = State(initialValue: trip.name ?? "")
        _startDate = State(initialValue: trip.startDate ?? Date())
        _endDate = State(initialValue: trip.endDate ?? Date().addingTimeInterval(86400 * 7))
        _currencyCode = State(initialValue: trip.currencyCode ?? "USD")
        _hasStartDate = State(initialValue: trip.startDate != nil)
        _hasEndDate = State(initialValue: trip.endDate != nil)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    // Название
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Название поездки")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                        AppTextField(placeholder: "Например, Барселона 2026", text: $name, icon: "suitcase")
                    }

                    // Даты
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Даты")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        AppCard {
                            VStack(spacing: Spacing.sm) {
                                Toggle("Дата начала", isOn: $hasStartDate)
                                    .font(AppFont.body)
                                    .tint(.primaryAccent)
                                if hasStartDate {
                                    DatePicker("", selection: $startDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(.primaryAccent)
                                        .environment(\.locale, Locale(identifier: "ru_RU"))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }

                                Divider()

                                Toggle("Дата окончания", isOn: $hasEndDate)
                                    .font(AppFont.body)
                                    .tint(.primaryAccent)
                                if hasEndDate {
                                    DatePicker("", selection: $endDate, displayedComponents: .date)
                                        .datePickerStyle(.compact)
                                        .labelsHidden()
                                        .tint(.primaryAccent)
                                        .environment(\.locale, Locale(identifier: "ru_RU"))
                                        .frame(maxWidth: .infinity, alignment: .trailing)
                                }
                            }
                        }
                    }

                    // Валюта
                    VStack(alignment: .leading, spacing: Spacing.sm) {
                        Text("Валюта")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)

                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Spacing.sm) {
                                ForEach(currencies, id: \.self) { code in
                                    FilterChip(label: code, isSelected: currencyCode == code) {
                                        currencyCode = code
                                    }
                                }
                            }
                            .padding(.horizontal, Spacing.xs)
                        }
                    }

                    PrimaryButton(title: "Сохранить", icon: "checkmark") {
                        saveChanges()
                    }
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .padding(.horizontal, Spacing.buttonHorizontalPadding)
                    .padding(.bottom, Spacing.xl)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Редактировать поездку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        NavBarIconButton(icon: "xmark")
                    }
                }
            }
        }
    }

    private func saveChanges() {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }

        trip.name = trimmed
        trip.startDate = hasStartDate ? startDate : nil
        trip.endDate = hasEndDate ? endDate : nil
        trip.currencyCode = currencyCode
        trip.updatedAt = Date()
        trip.isSynced = false

        try? context.save()
        Task { await SyncService.shared.uploadTrip(trip) }
        dismiss()
    }
}

// MARK: - Preview

#Preview {
    let ctx = PersistenceController.preview.container.viewContext
    let trip = Trip(context: ctx)
    trip.id = UUID()
    trip.name = "Барселона 2026"
    trip.startDate = Calendar.current.date(byAdding: .day, value: 5, to: Date())
    trip.endDate   = Calendar.current.date(byAdding: .day, value: 12, to: Date())
    trip.currencyCode = "EUR"
    trip.createdAt = Date()

    let p = Participant(context: ctx)
    p.id = UUID()
    p.name = "Нина"
    p.isOwner = true
    p.trip = trip

    return NavigationStack {
        TripDetailView(trip: trip, context: ctx)
    }
    .environmentObject(AuthViewModel())
}
