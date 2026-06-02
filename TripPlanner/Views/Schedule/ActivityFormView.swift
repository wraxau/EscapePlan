import SwiftUI
import UserNotifications

// MARK: - Mode

enum ActivityFormMode {
    case create(dayDate: Date)
    case edit(activity: Activity)
}

// MARK: - ActivityFormView

struct ActivityFormView: View {

    @ObservedObject var vm: ActivityViewModel
    @Environment(\.dismiss) private var dismiss

    let mode: ActivityFormMode
    let tripName: String?

    // MARK: - Fields

    @State private var title: String = ""
    @State private var selectedCategory: ExpenseCategory = .cafe
    @State private var showCategorySheet = false

    @State private var startTime: Date
    @State private var endTime: Date

    @State private var reminderEnabled: Bool = false
    @State private var budgetText: String = ""
    @State private var note: String = ""

    // Карта
    @State private var showMapPicker = false
    @State private var activityLat: Double = 0
    @State private var activityLng: Double = 0
    @State private var activityLocationName: String = ""

    // MARK: - Init

    init(vm: ActivityViewModel, mode: ActivityFormMode, tripName: String? = nil) {
        self.vm = vm
        self.mode = mode
        self.tripName = tripName

        switch mode {
        case .create(let dayDate):
            let cal = Calendar.current
            var comps = cal.dateComponents([.year, .month, .day], from: dayDate)
            comps.hour = 10; comps.minute = 0
            let start = cal.date(from: comps) ?? dayDate
            comps.hour = 11
            let end = cal.date(from: comps) ?? dayDate
            _startTime = State(initialValue: start)
            _endTime   = State(initialValue: end)

        case .edit(let activity):
            _title            = State(initialValue: activity.title ?? "")
            _startTime        = State(initialValue: activity.startTime ?? Date())
            _endTime          = State(initialValue: activity.endTime ?? Date())
            _reminderEnabled  = State(initialValue: activity.reminderEnabled)
            _note             = State(initialValue: activity.note ?? "")
            _activityLat      = State(initialValue: activity.latitude)
            _activityLng      = State(initialValue: activity.longitude)

            if let categoryRaw = activity.categoryName,
               let category = ExpenseCategory.allCases.first(where: { $0.title == categoryRaw }) {
                _selectedCategory = State(initialValue: category)
            }
            if let budget = activity.budget {
                _budgetText = State(initialValue: "\(budget)")
            }
            if !activity.latitude.isZero || !activity.longitude.isZero {
                _activityLocationName = State(initialValue: activity.locationName ?? "Место на карте")
            }
        }
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()

                ScrollView {
                    VStack(spacing: Spacing.sm) {

                        // Название
                        fieldRow {
                            TextField("Название", text: $title)
                                .font(AppFont.body)
                                .foregroundColor(.textPrimary)
                        }

                        // Категория
                        categoryRow

                        // Начало / Конец
                        dateRow(label: "Начало", date: $startTime)
                        dateRow(label: "Конец",  date: $endTime)

                        // Напоминание
                        reminderRow

                        // Бюджет
                        fieldRow {
                            HStack {
                                Text("Бюджет")
                                    .font(AppFont.body)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                TextField("0", text: $budgetText)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(AppFont.body)
                                    .foregroundColor(.primaryAccent)
                                    .frame(width: 100)
                            }
                        }

                        // Заметка
                        fieldRow {
                            TextField("Добавить заметку", text: $note, axis: .vertical)
                                .font(AppFont.body)
                                .foregroundColor(.textPrimary)
                                .lineLimit(2...4)
                        }

                        // Место на карте
                        mapRow
                    }
                    .padding(.horizontal, Spacing.md)
                    .padding(.top, Spacing.md)
                    .padding(.bottom, Spacing.xl)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(navigationTitle)
            .navigationBarTitleDisplayMode(.inline)
            .appNavBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: { NavBarIconButton(icon: "xmark") }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { save() } label: { NavBarIconButton(icon: "checkmark") }
                        .disabled(!canSave)
                        .opacity(canSave ? 1 : 0.4)
                }
            }
            .sheet(isPresented: $showMapPicker) {
                MapPlacePickerView(tripLocation: tripName) { lat, lng, name, _ in
                    activityLat = lat
                    activityLng = lng
                    activityLocationName = name
                }
            }
            .onAppear {
                UNUserNotificationCenter.current().getNotificationSettings { settings in
                    guard settings.authorizationStatus == .notDetermined else { return }
                    Task { @MainActor in
                        PermissionManager.shared.request(.notifications) {
                            vm.requestNotificationPermission()
                        }
                    }
                }
            }
        }
    }

    // MARK: - Navigation title

    private var navigationTitle: String {
        switch mode {
        case .create: return "Создать план на день"
        case .edit:   return "Редактировать план на день"
        }
    }

    // MARK: - Category Row

    private var categoryRow: some View {
        SelectField(
            label: "Выберите категорию",
            value: selectedCategory.title,
            icon: selectedCategory.icon
        ) {
            showCategorySheet = true
        }
        .sheet(isPresented: $showCategorySheet) {
            NavigationStack {
                VStack {
                    Section("Категория плана") {
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

    // MARK: - Date Row

    private func dateRow(label: String, date: Binding<Date>) -> some View {
        fieldRow {
            HStack {
                Text(label)
                    .font(AppFont.body)
                    .foregroundColor(.textPrimary)
                Spacer()
                DatePicker("", selection: date, displayedComponents: [.date, .hourAndMinute])
                    .labelsHidden()
                    .tint(.primaryAccent)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
            }
        }
    }

    // MARK: - Reminder Row

    private var reminderRow: some View {
        fieldRow {
            HStack {
                Text("Напоминание")
                    .font(AppFont.body)
                    .foregroundColor(.textPrimary)
                Spacer()
                Toggle("", isOn: $reminderEnabled)
                    .tint(.primaryAccent)
                    .labelsHidden()
            }
        }
    }

    // MARK: - Map Row

    private var mapRow: some View {
        fieldRow {
            Button {
                showMapPicker = true
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "map")
                        .font(.system(size: 15))
                        .foregroundColor(.primaryAccent)
                    Text(activityLocationName.isEmpty ? "Найти на карте" : activityLocationName)
                        .font(AppFont.body)
                        .foregroundColor(activityLocationName.isEmpty ? Color(.systemGray3) : .textPrimary)
                        .lineLimit(1)
                    Spacer()
                    if !activityLocationName.isEmpty {
                        Button {
                            activityLat = 0
                            activityLng = 0
                            activityLocationName = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(Color(.systemGray3))
                                .font(.system(size: 16))
                        }
                        .buttonStyle(.plain)
                    } else {
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.neutralGray)
                    }
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private var canSave: Bool {
        !title.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func fieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .tint(.primaryAccent)
            .padding(Spacing.md)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))
    }

    // MARK: - Save

    private func save() {
        let budget = Decimal(string: budgetText.replacingOccurrences(of: ",", with: "."))
        let trimmedTitle = title.trimmingCharacters(in: .whitespaces)

        let locationNameToSave = activityLocationName.isEmpty ? nil : activityLocationName

        switch mode {
        case .create:
            vm.addActivity(
                title:           trimmedTitle,
                categoryName:    selectedCategory.title,
                categoryColor:   selectedCategory.color.hexString,
                startTime:       startTime,
                endTime:         endTime,
                reminderEnabled: reminderEnabled,
                budget:          budget,
                note:            note,
                latitude:        activityLat,
                longitude:       activityLng,
                locationName:    locationNameToSave
            )

        case .edit(let activity):
            vm.updateActivity(
                activity,
                title:           trimmedTitle,
                categoryName:    selectedCategory.title,
                categoryColor:   selectedCategory.color.hexString,
                startTime:       startTime,
                endTime:         endTime,
                reminderEnabled: reminderEnabled,
                budget:          budget,
                note:            note,
                latitude:        activityLat,
                longitude:       activityLng,
                locationName:    locationNameToSave
            )
        }

        dismiss()
    }
}
