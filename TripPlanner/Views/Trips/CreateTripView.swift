import SwiftUI
import CoreData
import FirebaseAuth

struct CreateTripView: View {

    @EnvironmentObject var tripVM: TripViewModel
    @Environment(\.dismiss) private var dismiss

    // MARK: - Поля формы

    @State private var destination: String = ""
    @State private var daysCount: Int = 6
    @State private var startDate: Date = Date()
    @State private var endDate: Date = Calendar.current.date(byAdding: .day, value: 6, to: Date()) ?? Date()
    @State private var currencyCode: String = "USD"
    @State private var showCurrencySheet = false

    // MARK: - Участники

    @State private var ownerName: String = ""
    @State private var additionalParticipants: [String] = []
    @State private var participantEmails: Set<String> = []
    @State private var newParticipantInput: String = ""

    // MARK: - Валидация

    @State private var showValidationError = false
    @State private var validationMessage = ""

    private var isValid: Bool {
        !destination.trimmingCharacters(in: .whitespaces).isEmpty
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            formContent
                .navigationTitle("Новая поездка")
                .navigationBarTitleDisplayMode(.inline)
                .appNavBar()
                .toolbar { closeToolbarItem }
                .alert("Проверь данные", isPresented: $showValidationError) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text(validationMessage)
                }
        }
    }

    // MARK: - Form content (вынесено для type-checker)

    private var formContent: some View {
        scrollBody
            .background(Color.appBackground.ignoresSafeArea())
            .safeAreaInset(edge: .bottom) {
                saveButton
                    .padding(.horizontal, Spacing.md)
                    .padding(.vertical, Spacing.md)
                    .background(Color.appBackground)
            }
            .onAppear {
            if ownerName.trimmingCharacters(in: .whitespaces).isEmpty {
                let saved = UserDefaults.standard.string(forKey: "profile_name") ?? ""
                if !saved.trimmingCharacters(in: .whitespaces).isEmpty {
                    ownerName = saved
                } else {
                    let displayName = Auth.auth().currentUser?.displayName ?? ""
                    if !displayName.isEmpty {
                        ownerName = displayName
                    } else {
                        let emailPrefix = Auth.auth().currentUser?.email?
                            .components(separatedBy: "@").first ?? ""
                        ownerName = emailPrefix
                    }
                }
            }
        }
        .onChange(of: daysCount) { newValue in
            endDate = Calendar.current.date(
                byAdding: .day, value: newValue - 1, to: startDate
            ) ?? startDate
        }
        .onChange(of: startDate) { newStart in
            endDate = Calendar.current.date(
                byAdding: .day, value: daysCount - 1, to: newStart
            ) ?? newStart
        }
    }

    private var scrollBody: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                destinationField
                daysPickerSection
                datesSection
                currencySection
                participantsSection
                Spacer(minLength: 90)
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
        }
    }

    private var closeToolbarItem: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button { dismiss() } label: {
                NavBarIconButton(icon: "xmark")
            }
        }
    }

    // MARK: - Поле страны

    private var destinationField: some View {
        AppTextField(placeholder: "Введите страну путешествия", text: $destination, icon: "airplane")
    }

    // MARK: - Picker дней

    private var daysPickerSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Количество дней")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryAccent)
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.md)

            Picker("Дней", selection: $daysCount) {
                ForEach(1...60, id: \.self) { day in
                    Text("\(day)").tag(day)
                }
            }
            .pickerStyle(.wheel)
            .frame(height: 160)
            .clipped()
            .padding(.bottom, Spacing.xs)
        }
        .background(Color.primaryAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    }

    // MARK: - Даты

    private var datesSection: some View {
        HStack(spacing: Spacing.md) {

            // Начало
            VStack(alignment: .center, spacing: Spacing.sm) {
                Text("Начало")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)

                DatePicker("", selection: $startDate, displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(.primaryAccent)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
            }
            .frame(maxWidth: .infinity)

            // Конец
            VStack(alignment: .center, spacing: Spacing.sm) {
                Text("Конец")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)

                DatePicker("", selection: $endDate, in: startDate..., displayedComponents: .date)
                    .labelsHidden()
                    .datePickerStyle(.compact)
                    .tint(.primaryAccent)
                    .environment(\.locale, Locale(identifier: "ru_RU"))
            }
            .frame(maxWidth: .infinity)
        }
        .padding(Spacing.md)
        .background(Color.primaryAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
    }

    // MARK: - Валюта

    private var currencySection: some View {
        Button {
            showCurrencySheet = true
        } label: {
            HStack(spacing: Spacing.sm) {
                Image(systemName: "dollarsign.circle.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.primaryAccent)

                Text("Валюта поездки")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.textPrimary)

                Spacer()

                Text(currencyCode)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.primaryAccent)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.textSecondary)
            }
            .padding(Spacing.md)
            .background(Color.primaryAccent.opacity(0.07))
            .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showCurrencySheet) {
            NavigationStack {
                List {
                    ForEach(getAllCurrencies(), id: \.self) { code in
                        Button {
                            currencyCode = code
                            showCurrencySheet = false
                        } label: {
                            HStack {
                                Text(code)
                                    .font(AppFont.body)
                                    .foregroundColor(.textPrimary)
                                Spacer()
                                if currencyCode == code {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.primaryAccent)
                                        .font(.system(size: 14, weight: .semibold))
                                }
                            }
                        }
                    }
                }
                .navigationTitle("Валюта поездки")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Отмена") { showCurrencySheet = false }
                            .buttonStyle(NavBarTextButtonStyle())
                    }
                }
            }
        }
    }

    // MARK: - Участники

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            participantsHeader
            ownerRow
            participantsList
            addParticipantRow
        }
        .background(Color.primaryAccent.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: Radius.xl))
        .animation(AppAnimation.quick, value: additionalParticipants.count)
    }

    private var participantsHeader: some View {
        HStack(spacing: Spacing.xs) {
            Image(systemName: "person.2.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.primaryAccent)
            Text("Участники")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primaryAccent)
        }
        .padding(.horizontal, Spacing.md)
        .padding(.top, Spacing.md)
    }

    private var ownerRow: some View {
        HStack(spacing: Spacing.sm) {
            Image(systemName: "crown.fill")
                .font(.system(size: 14))
                .foregroundColor(.primaryAccent)
                .frame(width: 22)
            TextField("Ваше имя (владелец)", text: $ownerName)
                .font(AppFont.body)
                .foregroundColor(.textPrimary)
                .tint(.primaryAccent)
        }
        .padding(Spacing.md)
        .background(Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Spacing.sm)
    }

    @ViewBuilder
    private var participantsList: some View {
        if !additionalParticipants.isEmpty {
            VStack(spacing: Spacing.xs) {
                ForEach(additionalParticipants.indices, id: \.self) { idx in
                    participantRow(idx: idx)
                }
            }
        }
    }

    private func participantRow(idx: Int) -> some View {
        let entry = additionalParticipants[idx]
        let isEmail = participantEmails.contains(entry)
        return HStack(spacing: Spacing.sm) {
            Image(systemName: isEmail ? "envelope.fill" : "person.fill")
                .font(.system(size: 14))
                .foregroundColor(isEmail ? .primaryAccent : .textSecondary)
                .frame(width: 22)
            VStack(alignment: .leading, spacing: 2) {
                Text(entry)
                    .font(AppFont.body)
                    .foregroundColor(.textPrimary)
                if isEmail {
                    Text("Получит приглашение")
                        .font(AppFont.tiny)
                        .foregroundColor(.primaryAccent.opacity(0.8))
                }
            }
            Spacer()
            Button {
                withAnimation(AppAnimation.quick) {
                    participantEmails.remove(entry)
                    var updated = additionalParticipants
                    updated.remove(at: idx)
                    additionalParticipants = updated
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color.textSecondary.opacity(0.6))
            }
        }
        .padding(Spacing.md)
        .background(Color.inputBackground)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .padding(.horizontal, Spacing.sm)
    }

    private var addParticipantRow: some View {
        let inputIsEmail = newParticipantInput.contains("@")
        return VStack(spacing: Spacing.xs) {
            HStack(spacing: Spacing.sm) {
                Image(systemName: inputIsEmail ? "envelope" : "person.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(Color.primaryAccent.opacity(0.6))
                    .frame(width: 22)
                TextField(
                    inputIsEmail ? "Email для приглашения" : "Имя или email участника",
                    text: $newParticipantInput
                )
                .font(AppFont.body)
                .foregroundColor(.textPrimary)
                .tint(.primaryAccent)
                .keyboardType(.emailAddress)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .submitLabel(.done)
                .onSubmit { addParticipant() }
                if !newParticipantInput.trimmingCharacters(in: .whitespaces).isEmpty {
                    Button(action: addParticipant) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 22))
                            .foregroundColor(.primaryAccent)
                    }
                }
            }
            .padding(Spacing.md)
            .background(Color.inputBackground)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md))

            if inputIsEmail {
                Text("Введи email — пришлём приглашение после создания поездки")
                    .font(AppFont.tiny)
                    .foregroundColor(.primaryAccent.opacity(0.8))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, Spacing.xs)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.bottom, Spacing.md)
    }

    private func addParticipant() {
        let trimmed = newParticipantInput.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        additionalParticipants.append(trimmed)
        if trimmed.contains("@") && trimmed.contains(".") {
            participantEmails.insert(trimmed)
        }
        newParticipantInput = ""
    }

    // MARK: - Кнопка Сохранить

    private var saveButton: some View {
        PrimaryButton(title: "Сохранить") { saveTrip() }
            .disabled(!isValid)
            .opacity(isValid ? 1 : 0.4)
            .animation(AppAnimation.quick, value: isValid)
    }

    // MARK: - Сохранение

    private func saveTrip() {
        let trimmed = destination.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            validationMessage = "Введи страну путешествия"
            showValidationError = true
            return
        }
        let pendingInput = newParticipantInput.trimmingCharacters(in: .whitespaces)
        var allAdditional = additionalParticipants
        var allEmails = participantEmails
        if !pendingInput.isEmpty {
            allAdditional.append(pendingInput)
            if pendingInput.contains("@") { allEmails.insert(pendingInput) }
        }
        let nameParticipants  = allAdditional.filter { !allEmails.contains($0) }
        let emailInvitesList  = Array(allEmails)

        let resolvedOwnerName = ownerName.trimmingCharacters(in: .whitespaces)
        let ownerUID = Auth.auth().currentUser?.uid

        let createdTrip = tripVM.createTrip(
            name:                   trimmed,
            ownerName:              resolvedOwnerName,
            ownerFirebaseUID:       ownerUID,
            startDate:              startDate,
            endDate:                endDate,
            currencyCode:           currencyCode,
            additionalParticipants: nameParticipants
        )
        if !emailInvitesList.isEmpty {
            Task {
                for email in emailInvitesList {
                    _ = await SyncService.shared.sendInvitation(
                        toEmail: email,
                        trip: createdTrip,
                        ownerName: resolvedOwnerName.isEmpty ? "Владелец" : resolvedOwnerName
                    )
                }
            }
        }

        dismiss()
    }
}

// MARK: - Preview

#Preview {
    CreateTripView()
        .environmentObject(TripViewModel(context: PersistenceController.preview.container.viewContext))
}
