import SwiftUI
import Combine
import CoreData
import FirebaseAuth

// MARK: - Auth Errors

enum AuthError: LocalizedError {
    case invalidCredentials
    case emailAlreadyExists
    case weakPassword
    case networkError
    case unknown(String)

    var errorDescription: String? {
        switch self {
        case .invalidCredentials:
            return "Неверный email или пароль"
        case .emailAlreadyExists:
            return "Этот email уже зарегистрирован"
        case .weakPassword:
            return "Пароль должен быть не менее 6 символов"
        case .networkError:
            return "Нет соединения. Проверь интернет"
        case .unknown(let msg):
            return msg
        }
    }

    static func from(_ error: Error) -> AuthError {
        let code = AuthErrorCode(rawValue: (error as NSError).code)
        switch code {
        case .wrongPassword, .invalidEmail, .userNotFound, .invalidCredential:
            return .invalidCredentials
        case .emailAlreadyInUse:
            return .emailAlreadyExists
        case .weakPassword:
            return .weakPassword
        case .networkError:
            return .networkError
        default:
            return .unknown(error.localizedDescription)
        }
    }
}

// MARK: - AuthViewModel

@MainActor
final class AuthViewModel: ObservableObject {

    // MARK: - Published state

    /// true = пользователь авторизован, показываем ContentView
    @Published var isAuthenticated: Bool = false
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var currentUserUID: String? = nil

    // MARK: - Private
    private var authStateHandle: AuthStateDidChangeListenerHandle?

    // MARK: - Init

    init() {
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            guard let self else { return }
            Task { @MainActor in
                self.currentUserUID = user?.uid
                self.isAuthenticated = (user != nil)
            }
        }
    }

    deinit {
        if let handle = authStateHandle {
            Auth.auth().removeStateDidChangeListener(handle)
        }
    }

    // MARK: - Login

    func login(email: String, password: String) async {
        guard validate(email: email, password: password) else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = AuthError.from(error).errorDescription
        }

        isLoading = false
    }

    // MARK: - Register

    func register(email: String, password: String) async {
        guard validate(email: email, password: password) else { return }

        isLoading = true
        errorMessage = nil

        do {
            try await Auth.auth().createUser(withEmail: email, password: password)
        } catch {
            errorMessage = AuthError.from(error).errorDescription
        }

        isLoading = false
    }

    // MARK: - Logout

    func logout() {
        do {
            try Auth.auth().signOut()
            clearLocalData()
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось выйти: \(error.localizedDescription)"
        }
    }

    // MARK: - Clear local CoreData

    private func clearLocalData() {
        // Core Data
        let context = PersistenceController.shared.container.viewContext
        let entities = ["Trip", "Expense", "DayPlan", "Place", "Participant", "Activity"]
        for entity in entities {
            let fetch = NSFetchRequest<NSFetchRequestResult>(entityName: entity)
            let deleteRequest = NSBatchDeleteRequest(fetchRequest: fetch)
            try? context.execute(deleteRequest)
        }
        context.reset()

        // UserDefaults: данные, привязанные к аккаунту
        let accountKeys = [
            "profile_name",
            "profile_phone",
            "profile_avatar_jpeg",
            "map_visited_countries",
            "map_memories",
            "totalExpensesAdded",
            "totalTripsCreated"
        ]
        accountKeys.forEach { UserDefaults.standard.removeObject(forKey: $0) }

        let allKeys = UserDefaults.standard.dictionaryRepresentation().keys
        allKeys.filter { $0.hasPrefix("settled_debts_") }
               .forEach { UserDefaults.standard.removeObject(forKey: $0) }

        if let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            let imageExtensions = ["jpg", "jpeg", "png", "heic"]
            let files = (try? FileManager.default.contentsOfDirectory(atPath: docs.path)) ?? []
            files.filter { file in imageExtensions.contains((file as NSString).pathExtension.lowercased()) }
                 .forEach { try? FileManager.default.removeItem(at: docs.appendingPathComponent($0)) }
        }
    }
    func deleteAccount() async {
        isLoading = true
        do {
            try await Auth.auth().currentUser?.delete()
            clearLocalData()
            errorMessage = nil
        } catch {
            errorMessage = "Не удалось удалить аккаунт: \(error.localizedDescription)"
        }
        isLoading = false
    }

    // MARK: - Reset Password

    func resetPassword(email: String) async {
        guard !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            errorMessage = "Введи email для сброса пароля"
            return
        }
        isLoading = true
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            errorMessage = nil
        } catch {
            errorMessage = AuthError.from(error).errorDescription
        }
        isLoading = false
    }

    // MARK: - Validation

    private func validate(email: String, password: String) -> Bool {
        let trimmedEmail = email.trimmingCharacters(in: .whitespaces)
        guard !trimmedEmail.isEmpty else {
            errorMessage = "Введи email"
            return false
        }
        guard trimmedEmail.contains("@"), trimmedEmail.contains(".") else {
            errorMessage = "Некорректный адрес почты"
            return false
        }
        guard password.count >= 6 else {
            errorMessage = "Пароль должен быть не менее 6 символов"
            return false
        }
        return true
    }
}
