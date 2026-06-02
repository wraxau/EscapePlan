import SwiftUI
import Combine
import Photos
import UserNotifications

// MARK: - Permission type

enum AppPermission {
    case photos
    case camera
    case notifications
    case location

    var icon: String {
        switch self {
        case .photos:        return "photo.on.rectangle"
        case .camera:        return "camera.fill"
        case .notifications: return "bell.badge.fill"
        case .location:      return "location.fill"
        }
    }

    var title: String {
        switch self {
        case .photos:        return "Доступ к галерее"
        case .camera:        return "Доступ к камере"
        case .notifications: return "Уведомления"
        case .location:      return "Геолокация"
        }
    }

    var description: String {
        switch self {
        case .photos:
            return "Чтобы добавлять фото воспоминаний из поездок и фото профиля, разрешите доступ к галерее."
        case .camera:
            return "Чтобы делать фото прямо во время поездки, разрешите доступ к камере."
        case .notifications:
            return "Чтобы вовремя напоминать об активностях и событиях в поездке, разрешите уведомления."
        case .location:
            return "Чтобы найти места рядом с вами и построить маршрут на карте, разрешите доступ к геолокации."
        }
    }

    var allowButtonTitle: String { "Разрешить" }
    var denyButtonTitle: String  { "Не сейчас" }
}

// MARK: - PermissionManager

@MainActor
final class PermissionManager: ObservableObject {

    static let shared = PermissionManager()

    @Published var pendingPermission: AppPermission? = nil
    @Published var onAllow: (() -> Void)? = nil
    @Published var onDeny: (() -> Void)? = nil

    private static let shownKeyPrefix = "permission_prompt_shown_"

    private init() {}

    // MARK: - Contextual request

    func requestIfNeeded(_ permission: AppPermission,
                         onAllow: @escaping () -> Void = {},
                         onDeny: @escaping () -> Void = {}) {
        if wasPromptShown(for: permission) || isAlreadyGranted(permission) {
            onAllow()
        } else {
            request(permission, onAllow: onAllow, onDeny: onDeny)
        }
    }

    func request(_ permission: AppPermission,
                 onAllow: @escaping () -> Void = {},
                 onDeny: @escaping () -> Void = {}) {
        self.onAllow = onAllow
        self.onDeny  = onDeny
        self.pendingPermission = permission
    }

    func wasShown(_ permission: AppPermission) -> Bool {
        wasPromptShown(for: permission)
    }

    // MARK: - Handlers

    func handleAllow() {
        guard let permission = pendingPermission else { return }
        pendingPermission = nil
        markPromptShown(for: permission)

        switch permission {
        case .photos:
            PHPhotoLibrary.requestAuthorization(for: .readWrite) { _ in }

        case .camera:
            break

        case .notifications:
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .sound, .badge]
            ) { _, _ in }

        case .location:
            break
        }

        onAllow?()
        onAllow = nil
    }

    func handleDeny() {
        if let permission = pendingPermission {
            markPromptShown(for: permission)
        }
        pendingPermission = nil
        onDeny?()
        onDeny = nil
    }

    // MARK: - Private helpers

    private func wasPromptShown(for permission: AppPermission) -> Bool {
        UserDefaults.standard.bool(forKey: Self.shownKeyPrefix + permission.id)
    }

    private func markPromptShown(for permission: AppPermission) {
        UserDefaults.standard.set(true, forKey: Self.shownKeyPrefix + permission.id)
    }

    private func isAlreadyGranted(_ permission: AppPermission) -> Bool {
        switch permission {
        case .photos:
            return PHPhotoLibrary.authorizationStatus(for: .readWrite) == .authorized
        case .notifications:
            return false
        case .camera, .location:
            return false
        }
    }
}

// MARK: - Pre-permission Sheet

struct PermissionRequestSheet: View {

    let permission: AppPermission
    let onAllow: () -> Void
    let onDeny: () -> Void

    var body: some View {
        VStack(spacing: Spacing.xl) {

            Spacer()

            // Иконка
            ZStack {
                Circle()
                    .fill(Color.primaryAccent.opacity(0.12))
                    .frame(width: 96, height: 96)
                Image(systemName: permission.icon)
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.primaryAccent)
            }

            // Текст
            VStack(spacing: Spacing.sm) {
                Text(permission.title)
                    .font(AppFont.display(22))
                    .foregroundColor(.textPrimary)
                    .multilineTextAlignment(.center)

                Text(permission.description)
                    .font(AppFont.body)
                    .foregroundColor(.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Spacing.xl)
            }

            Spacer()

            // Кнопки
            VStack(spacing: Spacing.sm) {
                PrimaryButton(title: permission.allowButtonTitle) {
                    onAllow()
                }
                .padding(.horizontal, Spacing.buttonHorizontalPadding)

                Button(permission.denyButtonTitle) {
                    onDeny()
                }
                .font(AppFont.body)
                .foregroundColor(.textSecondary)
            }
            .padding(.bottom, Spacing.xl)
        }
        .background(Color.appBackground.ignoresSafeArea())
    }
}

// MARK: - ViewModifier для автоматического показа диалога

struct PermissionRequestModifier: ViewModifier {

    @ObservedObject var manager = PermissionManager.shared

    func body(content: Content) -> some View {
        content
            .sheet(item: $manager.pendingPermission) { permission in
                PermissionRequestSheet(
                    permission: permission,
                    onAllow: { manager.handleAllow() },
                    onDeny:  { manager.handleDeny()  }
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
    }
}

extension View {
    func permissionRequests() -> some View {
        modifier(PermissionRequestModifier())
    }
}

// MARK: - AppPermission: Identifiable (для .sheet(item:))

extension AppPermission: Identifiable {
    var id: String { title }
}
