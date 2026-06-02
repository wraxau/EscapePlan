import SwiftUI
import PhotosUI
import FirebaseAuth
import CoreData

// MARK: - ProfileView

struct ProfileView: View {

    @EnvironmentObject var authVM: AuthViewModel
    @EnvironmentObject var tripVM: TripViewModel

    // MARK: - Edit mode

    @State private var isEditing = false

    // MARK: - Fields

    @AppStorage("profile_name")  private var name: String = ""
    @AppStorage("profile_phone") private var phone: String = ""
    @State private var email: String = ""

    // MARK: - Avatar

    @State private var avatarItem: PhotosPickerItem? = nil
    @State private var avatarImage: UIImage? = nil
    @State private var showAvatarPicker = false

    private let avatarKey = "profile_avatar_jpeg"

    // MARK: - Save feedback

    @State private var showSavedAlert = false

    // MARK: - Add friend

    @State private var showAddFriendSheet = false

    // MARK: - Delete account

    @State private var showDeleteAccountAlert = false

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    avatarSection
                    fieldsSection
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
                .padding(.bottom, Spacing.xl)
            }
            .screenBackground()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if isEditing {
                    saveButton
                        .padding(.horizontal, Spacing.md)
                        .padding(.vertical, Spacing.md)
                        .background(Color.appBackground)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .navigationTitle("Профиль")
            .navigationBarTitleDisplayMode(.inline)
            .appNavBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        if isEditing {
                            saveProfile()
                        } else {
                            withAnimation(AppAnimation.quick) { isEditing = true }
                        }
                    } label: {
                        NavBarIconButton(icon: isEditing ? "checkmark" : "pencil")
                    }
                }
            }
            .onAppear {

                if email.isEmpty {
                    email = Auth.auth().currentUser?.email ?? ""
                }

                if avatarImage == nil,
                   let data = UserDefaults.standard.data(forKey: avatarKey),
                   let saved = UIImage(data: data) {
                    avatarImage = saved
                }
            }
            .alert("Сохранено", isPresented: $showSavedAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("Данные профиля обновлены")
            }
            .alert("Удалить аккаунт?", isPresented: $showDeleteAccountAlert) {
                Button("Удалить", role: .destructive) {
                    Task { await authVM.deleteAccount() }
                }
                Button("Отмена", role: .cancel) {}
            } message: {
                Text("Все данные аккаунта будут удалены безвозвратно. Данные поездок, сохранённые на устройстве, останутся.")
            }
            .alert("Ошибка", isPresented: .init(
                get: { authVM.errorMessage != nil },
                set: { if !$0 { authVM.errorMessage = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(authVM.errorMessage ?? "")
            }
            .sheet(isPresented: $showAddFriendSheet) {
                AddFriendByEmailSheet(ownerName: name)
                    .environmentObject(tripVM)
            }
        }
    }

    // MARK: - Avatar Section

    private var avatarSection: some View {
        Button {
            PermissionManager.shared.requestIfNeeded(.photos) {
                showAvatarPicker = true
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let image = avatarImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFill()
                    } else {
                        Image(systemName: "person.fill")
                            .resizable()
                            .scaledToFit()
                            .padding(28)
                            .foregroundColor(.primaryAccent.opacity(0.5))
                    }
                }
                .frame(width: 110, height: 110)
                .background(Color.primaryAccent.opacity(0.08))
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.primaryAccent, lineWidth: 3)
                )

                Image(systemName: "camera.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(7)
                    .background(Color.primaryAccent)
                    .clipShape(Circle())
                    .offset(x: 4, y: 4)
            }
        }
        .photosPicker(isPresented: $showAvatarPicker, selection: $avatarItem, matching: .images)
        .onChange(of: avatarItem) { newItem in
            Task {
                if let data = try? await newItem?.loadTransferable(type: Data.self),
                   let uiImage = UIImage(data: data) {
                    let resized = uiImage.resizedToMaxDimension(600)
                    avatarImage = resized

                    if let jpeg = resized.jpegData(compressionQuality: 0.8) {
                        UserDefaults.standard.set(jpeg, forKey: avatarKey)
                    }
                }
            }
        }
    }

    // MARK: - Fields Section

    private var fieldsSection: some View {
        VStack(spacing: Spacing.sm) {
            if isEditing {
                editableFields
            } else {
                readonlyFields
            }

            OutlineButton(title: "Добавить друга", icon: "person.badge.plus") {
                showAddFriendSheet = true
            }
            DestructiveButton(
                title: "Выйти из аккаунта",
                icon: "rectangle.portrait.and.arrow.right"
            ) {
                authVM.logout()
            }
            .padding(.top, Spacing.xs)

            DestructiveButton(
                title: "Удалить аккаунт",
                icon: "person.crop.circle.badge.minus"
            ) {
                showDeleteAccountAlert = true
            }
            .padding(.top, Spacing.xs)

            Button {
                if let url = URL(string: "https://github.com/wraxau/EscapePlan/blob/main/Privacy%20policy") {
                    UIApplication.shared.open(url)
                }
            } label: {
                Text("Политика конфиденциальности")
                    .font(AppFont.caption)
                    .foregroundColor(.textSecondary)
                    .underline()
            }
            .padding(.top, Spacing.sm)
        }
        .animation(AppAnimation.quick, value: isEditing)
    }

    // MARK: - Readonly (InfoRow + CardDivider)

    private var readonlyFields: some View {
        AppCard {
            VStack(spacing: Spacing.md) {
                InfoRow(icon: "person",   label: "Имя",     value: name.isEmpty  ? "—" : name)
                CardDivider()
                InfoRow(icon: "envelope", label: "Email",   value: email.isEmpty ? "—" : email)
                CardDivider()
                InfoRow(icon: "phone",    label: "Телефон", value: phone.isEmpty ? "—" : phone)
            }
        }
    }

    // MARK: - Editable (AppTextField)

    private var editableFields: some View {
        VStack(spacing: Spacing.sm) {
            AppTextField(placeholder: "Имя",     text: $name,  icon: "person",   isEditing: true)
            AppTextField(placeholder: "Email",    text: $email, icon: "envelope", isEditing: true, keyboardType: .emailAddress)
            AppTextField(placeholder: "Телефон",  text: $phone, icon: "phone",    isEditing: true, keyboardType: .phonePad)
        }
    }

    // MARK: - Save Button

    private var saveButton: some View {
        PrimaryButton(title: "Сохранить") { saveProfile() }
    }

    // MARK: - Save Logic

    private func saveProfile() {
        // email обновляем в Firebase Auth если изменился
        let firebaseEmail = Auth.auth().currentUser?.email ?? ""
        if email != firebaseEmail, !email.isEmpty {
            Task {
                try? await Auth.auth().currentUser?.updateEmail(to: email)
            }
        }

        withAnimation(AppAnimation.quick) {
            isEditing = false
        }
        showSavedAlert = true
    }
}

// MARK: - AddFriendByEmailSheet

struct AddFriendByEmailSheet: View {

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tripVM: TripViewModel
    let ownerName: String

    @State private var friendEmail: String = ""
    @State private var selectedTrip: Trip? = nil
    @State private var showTripPicker = false
    @State private var isSending = false
    @State private var showSuccessAlert = false
    @State private var showErrorAlert = false
    @State private var errorText = ""

    private var isValid: Bool {
        let trimmed = friendEmail.trimmingCharacters(in: .whitespaces)
        return trimmed.contains("@") && trimmed.contains(".") && selectedTrip != nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Spacing.lg) {

                    fieldSection(title: "Email друга") {
                        AppTextField(
                            placeholder: "Введите email",
                            text: $friendEmail,
                            icon: "envelope",
                            keyboardType: .emailAddress
                        )
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)
                    }
                    fieldSection(title: "Поездка") {
                        SelectField(
                            label: "Выберите поездку для приглашения",
                            value: selectedTrip?.name,
                            icon: "airplane"
                        ) {
                            showTripPicker = true
                        }
                    }
                    PrimaryButton(
                        title: "Отправить приглашение",
                        icon: "paperplane.fill",
                        isLoading: isSending
                    ) {
                        sendInvitation()
                    }
                    .disabled(!isValid || isSending)
                    .opacity(isValid ? 1.0 : 0.5)
                    .padding(.horizontal, Spacing.buttonHorizontalPadding)
                }
                .padding(.horizontal, Spacing.md)
                .padding(.top, Spacing.lg)
            }
            .screenBackground()
            .navigationTitle("Пригласить в поездку")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { dismiss() }) {
                        NavBarIconButton(icon: "xmark")
                    }
                }
            }
            .sheet(isPresented: $showTripPicker) {
                SelectSheet(
                    title: "Выберите поездку",
                    items: tripVM.trips,
                    itemLabel: { $0.name ?? "Без названия" },
                    selection: $selectedTrip
                )
            }
            .alert("Приглашение отправлено", isPresented: $showSuccessAlert) {
                Button("Готово", role: .cancel) { dismiss() }
            } message: {
                Text("Мы отправили приглашение на \(friendEmail)")
            }
            .alert("Ошибка", isPresented: $showErrorAlert) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorText)
            }
        }
    }

    @ViewBuilder
    private func fieldSection<C: View>(title: String, @ViewBuilder content: () -> C) -> some View {
        VStack(alignment: .leading, spacing: Spacing.sm) {
            Text(title)
                .font(AppFont.caption)
                .foregroundColor(.textSecondary)
            content()
        }
    }

    private func sendInvitation() {
        guard let trip = selectedTrip else { return }
        isSending = true
        Task {
            let success = await SyncService.shared.sendInvitation(
                toEmail: friendEmail.trimmingCharacters(in: .whitespaces),
                trip: trip,
                ownerName: ownerName.isEmpty ? "Владелец" : ownerName
            )
            isSending = false
            if success {
                showSuccessAlert = true
            } else {
                errorText = SyncService.shared.errorMessage ?? "Неизвестная ошибка"
                showErrorAlert = true
            }
        }
    }
}

// MARK: - Preview

#Preview {
    ProfileView()
        .environmentObject(AuthViewModel())
        .environmentObject(TripViewModel(context: PersistenceController.preview.container.viewContext))
}
