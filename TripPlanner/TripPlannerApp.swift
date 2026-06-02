import SwiftUI
import CoreData
import FirebaseCore
import UserNotifications
import Combine

@main
struct TripPlannerApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var tripViewModel = TripViewModel(
        context: PersistenceController.shared.container.viewContext
    )
    @StateObject private var currencyService = CurrencyService.shared
    @StateObject private var networkMonitor = NetworkMonitor.shared

    let persistenceController = PersistenceController.shared

    // MARK: - App state machine

    private enum AppState { case launching, onboarding, ready }

    @State private var appState: AppState = .launching
    @AppStorage("hasSeenOnboarding") private var hasSeenOnboarding = false

    @State private var isSyncingPending = false

    init() {
        FirebaseApp.configure()
        NavigationAppearance.apply()
        TabBarAppearance.apply()
        UITextField.appearance().tintColor = UIColor(Color.primaryAccent)

        #if DEBUG
        let startupStartTime = Date()
        print("_TripPlannerApp.init() started at \(startupStartTime)")

        for family in UIFont.familyNames {
            for name in UIFont.fontNames(forFamilyName: family) where name.lowercased().contains("delago") {
                print("Delago font found: \(name)")
            }
        }

        let totalStartupTime = Date().timeIntervalSince(startupStartTime)
        print("TripPlannerApp init complete in \(String(format: "%.3f", totalStartupTime * 1000)) ms")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ZStack {
                switch appState {

                case .launching:
                    LaunchScreenView()
                        .transition(.opacity)
                        .onAppear {
                            DispatchQueue.main.asyncAfter(deadline: .now() + 1.4) {
                                withAnimation(AppAnimation.slow) {
                                    appState = hasSeenOnboarding ? .ready : .onboarding
                                }
                            }
                        }

                case .onboarding:
                    OnboardingView {
                        hasSeenOnboarding = true
                        withAnimation(AppAnimation.standard) {
                            appState = .ready
                        }
                    }
                    .transition(.opacity)

                case .ready:
                    Group {
                        if authViewModel.isAuthenticated {
                            ContentView()
                                .environment(\.managedObjectContext,
                                              persistenceController.container.viewContext)
                                .environmentObject(authViewModel)
                                .environmentObject(tripViewModel)
                                .transition(.opacity)
                        } else {
                            AuthView()
                                .environmentObject(authViewModel)
                                .transition(.opacity)
                        }
                    }
                    .animation(AppAnimation.standard, value: authViewModel.isAuthenticated)
                    .onReceive(authViewModel.$currentUserUID) { uid in
                        tripViewModel.fetch(ownerUID: uid)
                        if uid != nil {
                            triggerPendingSync()
                        }
                    }
                    .onReceive(networkMonitor.$isConnected.filter { $0 }.dropFirst()) { _ in
                        triggerPendingSync()
                    }
                }
            }
            .animation(AppAnimation.slow, value: appState)
            .permissionRequests()
            .task {
                await currencyService.fetchIfNeeded()
            }
        }
    }

    // MARK: - Pending Sync

    private func triggerPendingSync() {
        guard !isSyncingPending else { return }
        isSyncingPending = true
        let context = persistenceController.container.viewContext
        Task {
            await SyncService.shared.syncPendingData(context: context)
            isSyncingPending = false
        }
    }
}
