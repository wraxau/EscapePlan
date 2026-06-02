import SwiftUI
import CoreData

// MARK: - App Tab

enum AppTab: CaseIterable {
    case map, trips, assistant, expenses, profile

    var title: String {
        switch self {
        case .map:       return "Карта"
        case .trips:     return "Поездки"
        case .assistant: return "Ассистент"
        case .expenses:  return "Расходы"
        case .profile:   return "Профиль"
        }
    }
    var icon: String {
        switch self {
        case .map:       return "mappin.and.ellipse"
        case .trips:     return "suitcase"
        case .assistant: return "hare.fill"
        case .expenses:  return "building.columns" 
        case .profile:   return "person"
        }
    }
}

// MARK: - Content View

struct ContentView: View {

    @EnvironmentObject var tripVM: TripViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @StateObject private var syncService = SyncService.shared

    @State private var selectedTab: AppTab = .trips
    @State private var showInvitations = false
    @State private var isKeyboardVisible = false

    var body: some View {
        VStack(spacing: 0) {
            OfflineIndicatorView()

            tabContent
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .hideKeyboardOnTap()
            .safeAreaInset(edge: .bottom, spacing: 0) {
                if !isKeyboardVisible {
                    CustomTabBar(selectedTab: $selectedTab)
                }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillShowNotification)
            ) { _ in
                withAnimation(.easeInOut(duration: 0.25)) { isKeyboardVisible = true }
            }
            .onReceive(
                NotificationCenter.default.publisher(
                    for: UIResponder.keyboardWillHideNotification)
            ) { _ in
                withAnimation(.easeInOut(duration: 0.25)) { isKeyboardVisible = false }
            }
        .task {
            await syncService.fetchPendingInvitations()
        }
        .onChange(of: syncService.pendingInvitations.count) { count in
            if count > 0 { showInvitations = true }
        }
        .sheet(isPresented: $showInvitations, onDismiss: {
            tripVM.fetch()
        }) {
            InvitationsView()
                .environment(\.managedObjectContext,
                              PersistenceController.shared.container.viewContext)
                .environmentObject(tripVM)
        }
    }

    // MARK: - Tab content

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .map:
            MapContainerView()
        case .trips:
            TripListView()
                .environmentObject(tripVM)
                .environmentObject(authVM)
        case .assistant:
            AIAssistantView()
        case .expenses:
            ExpenseListView()
                .environmentObject(tripVM)
                .environmentObject(authVM)
        case .profile:
            ProfileView()
                .environmentObject(authVM)
                .environmentObject(tripVM)
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {

    @Binding var selectedTab: AppTab

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.self) { tab in
                tabButton(tab)
            }
        }
        .padding(.horizontal, Spacing.sm)
        .padding(.top, Spacing.sm)
        .padding(.bottom, Spacing.sm)
        .background(Color(.systemBackground).ignoresSafeArea(edges: .bottom))
    }

    // MARK: - Отдельная кнопка вкладки

    @ViewBuilder
    private func tabButton(_ tab: AppTab) -> some View {
        let isActive = selectedTab == tab

        Button {
            withAnimation(AppAnimation.quick) {
                selectedTab = tab
            }
        } label: {
            VStack(spacing: 4) {
                Image(systemName: tab.icon)
                    .font(.system(size: 22, weight: isActive ? .semibold : .regular))
                    .frame(height: 26)

                Text(tab.title)
                    .font(.system(size: 10, weight: isActive ? .semibold : .regular))
            }
            .foregroundColor(isActive ? .primaryAccent : Color(.label))
            .frame(maxWidth: .infinity)
            .padding(.vertical, Spacing.sm)
            .background(
                isActive
                    ? Color(.systemGray5)
                    : Color.clear
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Placeholders

struct AIAssistantPlaceholderView: View {
    var body: some View {
        NavigationStack {
            EmptyStateView(
                icon: "hare.fill",
                title: "AI Ассистент",
                subtitle: "Задавай вопросы о поездке — следующий этап"
            )
            .screenBackground()
            .navigationTitle("Ассистент")
        }
    }
}

struct ProfilePlaceholderView: View {
    @EnvironmentObject var authVM: AuthViewModel

    var body: some View {
        NavigationStack {
            VStack {
                EmptyStateView(
                    icon: "person.circle",
                    title: "Профиль",
                    subtitle: "Настройки — следующий этап"
                )
                SecondaryButton(
                    title: "Выйти из аккаунта",
                    icon: "rectangle.portrait.and.arrow.right"
                ) {
                    authVM.logout()
                }
                .padding(.horizontal, Spacing.buttonHorizontalPadding)
                .padding(.bottom, Spacing.xl)
            }
            .screenBackground()
            .navigationTitle("Профиль")
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(TripViewModel(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AuthViewModel())
}
