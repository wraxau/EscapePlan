import SwiftUI
import CoreData

struct InvitationsView: View {

    @Environment(\.managedObjectContext) private var context
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var tripVM: TripViewModel
    @StateObject private var syncService = SyncService.shared

    var body: some View {
        NavigationStack {
            Group {
                if syncService.isLoading && syncService.pendingInvitations.isEmpty {
                    loadingState
                } else if syncService.pendingInvitations.isEmpty {
                    emptyState
                } else {
                    invitationsList
                }
            }
            .navigationTitle("Приглашения")
            .navigationBarTitleDisplayMode(.large)
            .appNavBar()
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Готово") { dismiss() }
                        .buttonStyle(NavBarTextButtonStyle())
                }
            }
        }
        .task {
            await syncService.fetchPendingInvitations()
        }
    }

    // MARK: - List

    private var invitationsList: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(syncService.pendingInvitations, id: \.id) { invitation in
                    invitationCard(invitation)
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
        }
        .screenBackground()
    }

    @ViewBuilder
    private func invitationCard(_ invitation: TripInvitation) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: Spacing.md) {

                // Иконка + название поездки
                HStack(spacing: Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(Color.primaryAccent.opacity(0.12))
                            .frame(width: 48, height: 48)
                        Image(systemName: "airplane")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.primaryAccent)
                    }

                    VStack(alignment: .leading, spacing: Spacing.xxs) {
                        Text(invitation.tripName)
                            .font(AppFont.headline)
                            .foregroundColor(.textPrimary)
                        Text("Приглашает: \(invitation.ownerName)")
                            .font(AppFont.caption)
                            .foregroundColor(.textSecondary)
                        Text(invitation.invitedAt.formatted(date: .abbreviated, time: .omitted))
                            .font(AppFont.tiny)
                            .foregroundColor(.textSecondary.opacity(0.7))
                    }

                    Spacer()
                }

                // Кнопки принять / отклонить
                HStack(spacing: Spacing.sm) {
                    PrimaryButton(
                        title: "Принять",
                        icon: "checkmark",
                        isLoading: syncService.isLoading
                    ) {
                        Task {
                            await syncService.acceptInvitation(invitation, context: context)
                            tripVM.fetch()
                            if syncService.pendingInvitations.isEmpty { dismiss() }
                        }
                    }
                    .disabled(syncService.isLoading)

                    DestructiveButton(title: "Отклонить", icon: "xmark") {
                        Task { await syncService.declineInvitation(invitation) }
                    }
                    .disabled(syncService.isLoading)
                }
            }
        }
    }

    // MARK: - States

    private var loadingState: some View {
        VStack(spacing: Spacing.md) {
            ProgressView()
                .scaleEffect(1.3)
                .tint(.primaryAccent)
            Text("Проверяем приглашения...")
                .font(AppFont.caption)
                .foregroundColor(.textSecondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }

    private var emptyState: some View {
        EmptyStateView(
            icon: "envelope.badge.fill",
            title: "Нет приглашений",
            subtitle: "Когда кто-то пригласит тебя в поездку — ты увидишь это здесь"
        )
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .screenBackground()
    }
}

// MARK: - Preview

#Preview {
    InvitationsView()
        .environment(\.managedObjectContext, PersistenceController.preview.container.viewContext)
}
