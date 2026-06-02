import SwiftUI


struct AuthView: View {
    @EnvironmentObject var authVM: AuthViewModel
    @State private var isLogin: Bool = true

    var body: some View {
        Group {
            if isLogin {
                LoginView(onSwitchToRegister: {
                    withAnimation(AppAnimation.standard) { isLogin = false }
                })
            } else {
                RegisterView(onSwitchToLogin: {
                    withAnimation(AppAnimation.standard) { isLogin = true }
                })
            }
        }
        .environmentObject(authVM)
    }
}

// MARK: - Экран входа

struct LoginView: View {
    @EnvironmentObject var authVM: AuthViewModel
    var onSwitchToRegister: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""

    // MARK: - Reset password state
    @State private var showResetAlert = false
    @State private var resetEmail: String = ""
    @State private var showResetSuccessAlert = false

    @StateObject private var network = NetworkMonitor.shared

    var body: some View {
        VStack(spacing: 0) {

            // Офлайн-баннер
            if !network.isConnected {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "wifi.slash")
                        .font(.system(size: 13, weight: .semibold))
                    Text("Для входа необходимо подключение к интернету")
                        .font(AppFont.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(Spacing.sm)
                .background(Color.neutralGray)
                .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            ScreenTitle(text: "Вход")
                .padding(.bottom, Spacing.xl)

            VStack(spacing: Spacing.lg) {
                UnderlineTextField(placeholder: "Почта", text: $email)
                UnderlineTextField(placeholder: "Пароль", text: $password, isSecure: true)
            }
            .padding(.horizontal, Spacing.buttonHorizontalPadding)

            // Ошибка валидации
            if let error = authVM.errorMessage {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundColor(.redAccent)
                    .padding(.top, Spacing.sm)
            }

            Button {
                resetEmail = email
                showResetAlert = true
            } label: {
                Text("Забыли пароль?")
                    .font(AppFont.subheadline)
                    .foregroundColor(.primaryAccent)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.top, Spacing.md)

            Spacer()

            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Войти", isLoading: authVM.isLoading) {
                    Task { await authVM.login(email: email, password: password) }
                }
                SecondaryButton(title: "Зарегистрироваться") {
                    onSwitchToRegister()
                }
                Button {
                    if let url = URL(string: "https://github.com/wraxau/EscapePlan/blob/main/Privacy%20policy") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Text("Политика конфиденциальности")
                        .font(AppFont.tiny)
                        .foregroundColor(.textSecondary)
                        .underline()
                }
                .padding(.top, Spacing.xs)
            }
            .padding(.horizontal, Spacing.buttonHorizontalPadding)
            .padding(.bottom, Spacing.xl)
        }
        .screenBackground()
        .alert("Восстановление пароля", isPresented: $showResetAlert) {
            TextField("Введите email", text: $resetEmail)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
            Button(role: .none) {
                Task {
                    await authVM.resetPassword(email: resetEmail)
                    if authVM.errorMessage == nil {
                        showResetSuccessAlert = true
                    }
                }
            } label: {
                HStack(spacing: Spacing.sm) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 18, weight: .semibold))
                    Text("Отправить")
                }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Введи свой email — мы отправим ссылку для сброса пароля")
        }
        .alert("Письмо отправлено", isPresented: $showResetSuccessAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Проверь почту \(resetEmail)")
        }
    }
}

// MARK: - Экран регистрации

struct RegisterView: View {
    @EnvironmentObject var authVM: AuthViewModel
    var onSwitchToLogin: () -> Void

    @State private var email: String = ""
    @State private var password: String = ""

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            ScreenTitle(text: "Создать аккаунт")
                .padding(.bottom, Spacing.xl)

            VStack(spacing: Spacing.lg) {
                UnderlineTextField(placeholder: "Почта", text: $email)
                UnderlineTextField(placeholder: "Пароль", text: $password, isSecure: true)
            }
            .padding(.horizontal, Spacing.buttonHorizontalPadding)

            // Ошибка валидации
            if let error = authVM.errorMessage {
                Text(error)
                    .font(AppFont.caption)
                    .foregroundColor(.redAccent)
                    .padding(.top, Spacing.sm)
            }

            Spacer()

            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: "Зарегистрироваться", isLoading: authVM.isLoading) {
                    Task { await authVM.register(email: email, password: password) }
                }
                SecondaryButton(title: "Уже есть аккаунт") {
                    onSwitchToLogin()
                }
            }
            .padding(.horizontal, Spacing.buttonHorizontalPadding)
            .padding(.bottom, Spacing.xl)
        }
        .screenBackground()
    }
}

// MARK: - Preview

#Preview("Вход") {
    LoginView(onSwitchToRegister: {})
        .environmentObject(AuthViewModel())
}

#Preview("Регистрация") {
    RegisterView(onSwitchToLogin: {})
        .environmentObject(AuthViewModel())
}
