import SwiftUI
import CoreData
import UIKit

struct TripListView: View {

    @EnvironmentObject var tripVM: TripViewModel
    @EnvironmentObject var authVM: AuthViewModel

    @State private var showCreateTrip = false
    @State private var syncError: String? = nil

    var body: some View {
        NavigationStack {
            ZStack {
                Color.appBackground.ignoresSafeArea()
                Group {
                    if tripVM.trips.isEmpty {
                        emptyState
                    } else {
                        tripList
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                if tripVM.isLoading {
                    LoadingOverlay()
                }
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        FABButton(icon: "plus") {
                            showCreateTrip = true
                        }
                        .disabled(tripVM.isLoading)
                        .padding(.trailing, Spacing.lg)
                    }
                }
                .safeAreaInset(edge: .bottom) { Color.clear.frame(height: 80) }
            }
            .navigationTitle("Мои поездки")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(Color.appBackground, for: .navigationBar)
            .safeAreaInset(edge: .top, spacing: 0) {
                syncBanner
            }
            .sheet(isPresented: $showCreateTrip, onDismiss: { tripVM.fetch() }) {
                CreateTripView()
                    .environmentObject(tripVM)
            }
            .errorToast(message: $syncError)
            .onReceive(SyncService.shared.$errorMessage) { msg in
                guard let msg else { return }
                syncError = msg
            }
        }
    }

    // MARK: - Список поездок

    private var tripList: some View {
        ScrollView {
            VStack(spacing: Spacing.md) {
                ForEach(tripVM.trips, id: \.id) { trip in
                    NavigationLink(
                        destination: TripDetailView(trip: trip, context: tripVM.viewContext)
                    ) {
                        TripCard(
                            name: trip.name ?? "Без названия",
                            dateRange: tripVM.dateRange(for: trip),
                            participantsCount: (trip.participants as? Set<Participant>)?.count ?? 0,
                            totalExpenses: tripVM.totalExpenses(for: trip),
                            coverImage: trip.coverImageData.flatMap { UIImage(data: $0) }
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu { contextMenu(for: trip) }
                }
            }
            .padding(.horizontal, Spacing.md)
            .padding(.top, Spacing.md)
            .padding(.bottom, 100)
        }
    }

    // MARK: - Sync banner

    @ViewBuilder
    private var syncBanner: some View {
        let state = SyncService.shared.syncState
        if case .syncing = state {
            SyncStatusView(syncState: state, onRetry: nil)
                .padding(.horizontal, Spacing.md)
                .padding(.vertical, Spacing.xs)
                .background(Color.appBackground)
        } else if case .error = state {
            SyncStatusView(syncState: state, onRetry: {
                tripVM.fetch()
            })
            .padding(.horizontal, Spacing.md)
            .padding(.vertical, Spacing.xs)
            .background(Color.appBackground)
        }
    }

    // MARK: - Empty state

    private var emptyState: some View {
        EmptyStateView(
            icon: "airplane",
            title: "Нет поездок",
            subtitle: "Нажми + и создай первую поездку",
            buttonTitle: nil
        ) {}
    }

    // MARK: - Context menu

    @ViewBuilder
    private func contextMenu(for trip: Trip) -> some View {
        Button(role: .destructive) {
            tripVM.deleteTrip(trip)
        } label: {
            Label("Удалить", systemImage: "trash")
        }
    }
}

// MARK: - Preview

#Preview {
    TripListView()
        .environmentObject(TripViewModel(context: PersistenceController.preview.container.viewContext))
        .environmentObject(AuthViewModel())
}
