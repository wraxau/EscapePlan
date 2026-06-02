import SwiftUI
import CoreData
import Combine

@MainActor
final class TripViewModel: ObservableObject {

    // MARK: - Published state
    @Published var trips: [Trip] = []
    @Published var searchQuery: String = "" {
        didSet { applyFilter() }
    }
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil

    // MARK: - Context

    let viewContext: NSManagedObjectContext

    // MARK: - Private
    private var allTrips: [Trip] = []
    private var syncTasks: Set<Task<Void, Never>> = []

    // MARK: - Current user UID

    private(set) var currentOwnerUID: String? = nil

    // MARK: - Init

    init(context: NSManagedObjectContext) {
        self.viewContext = context
        // Не загружаем данные до авторизации — вызов fetch(ownerUID:) из TripPlannerApp
    }

    // MARK: - Fetch

    func fetch(ownerUID: String? = nil) {
        // Обновляем UID, если передан новый
        if let uid = ownerUID {
            currentOwnerUID = uid
        }

        guard let uid = currentOwnerUID, !uid.isEmpty else {
            // Нет авторизованного пользователя — показываем пустой список
            allTrips = []
            applyFilter()
            return
        }

        let request: NSFetchRequest<Trip> = Trip.fetchRequest()
        request.sortDescriptors = [
            NSSortDescriptor(keyPath: \Trip.createdAt, ascending: false)
        ]
        request.predicate = NSCompoundPredicate(orPredicateWithSubpredicates: [
            NSPredicate(format: "ownerFirebaseUID == %@", uid),
            NSPredicate(format: "ANY participants.firebaseUID == %@", uid)
        ])
        do {
            allTrips = try viewContext.fetch(request)
            applyFilter()
        } catch {
            errorMessage = "Не удалось загрузить поездки"
        }
    }

    // MARK: - Create

    @discardableResult
    func createTrip(
        name: String,
        ownerName: String = "",
        ownerFirebaseUID: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        currencyCode: String = "USD",
        peopleNumber: Int32 = 1,
        additionalParticipants: [String] = []
    ) -> Trip {
        let trip = Trip(context: viewContext)
        trip.id = UUID()
        trip.name = name
        trip.startDate = startDate
        trip.endDate = endDate
        trip.currencyCode = currencyCode
        trip.peopleNumber = peopleNumber
        trip.createdAt = Date()
        trip.updatedAt = Date()
        trip.isSynced = false
        trip.ownerFirebaseUID = ownerFirebaseUID

        // Создаём владельца
        if !ownerName.trimmingCharacters(in: .whitespaces).isEmpty {
            let owner = Participant(context: viewContext)
            owner.id = UUID()
            owner.name = ownerName.trimmingCharacters(in: .whitespaces)
            owner.isOwner = true
            owner.isSynced = false
            owner.firebaseUID = ownerFirebaseUID
            owner.trip = trip
        }

        // Создаём дополнительных участников
        for participantName in additionalParticipants {
            let trimmed = participantName.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }
            let p = Participant(context: viewContext)
            p.id = UUID()
            p.name = trimmed
            p.isOwner = false
            p.isSynced = false
            p.trip = trip
        }

        save()
        fetch()
        HapticFeedback.success()
        ReviewManager.triggerAfterTripCreated()

        enqueueSync { await SyncService.shared.uploadTrip(trip) }
        return trip
    }

    // MARK: - Update

    func updateTrip(
        _ trip: Trip,
        name: String? = nil,
        startDate: Date? = nil,
        endDate: Date? = nil,
        currencyCode: String? = nil,
        peopleNumber: Int32? = nil
    ) {
        if let name { trip.name = name }
        if let startDate { trip.startDate = startDate }
        if let endDate { trip.endDate = endDate }
        if let currencyCode { trip.currencyCode = currencyCode }
        if let peopleNumber { trip.peopleNumber = peopleNumber }
        trip.updatedAt = Date()
        trip.isSynced = false
        save()
        fetch()
        enqueueSync { await SyncService.shared.uploadTrip(trip) }
    }

    // MARK: - Delete

    func deleteTrip(_ trip: Trip) {
        let tripId = trip.id?.uuidString
        viewContext.delete(trip)
        save()
        fetch()
        // Удаляем из Firestore
        if let id = tripId {
            enqueueSync { await SyncService.shared.deleteTrip(id) }
        }
    }

    func deleteTrips(at offsets: IndexSet) {
        let ids = offsets.map { trips[$0].id?.uuidString }
        offsets.map { trips[$0] }.forEach(viewContext.delete)
        save()
        fetch()
        for id in ids.compactMap({ $0 }) {
            enqueueSync { await SyncService.shared.deleteTrip(id) }
        }
    }

    // MARK: - Helpers
    func totalExpenses(for trip: Trip) -> String {
        let expenses = (trip.expenses as? Set<Expense>) ?? []
        let total = expenses.reduce(Decimal(0)) {
            $0 + (($1.amount as Decimal?) ?? 0)
        }
        let code = trip.currencyCode ?? "USD"
        return "\(code) \(total.ceiledString)"
    }

    /// Диапазон дат поездки
    func dateRange(for trip: Trip) -> String {
        guard let start = trip.startDate else { return "Даты не указаны" }
        let startStr = start.formattedDateAbbreviated()
        guard let end = trip.endDate else { return "с \(startStr)" }
        return "\(startStr) — \(end.formattedDateAbbreviated())"
    }

    // MARK: - Private

    private func applyFilter() {
        if searchQuery.trimmingCharacters(in: .whitespaces).isEmpty {
            trips = allTrips
        } else {
            trips = allTrips.filter {
                ($0.name ?? "").localizedCaseInsensitiveContains(searchQuery)
            }
        }
    }

    private func enqueueSync(_ operation: @escaping () async -> Void) {
        var task: Task<Void, Never>?
        task = Task {
            await operation()
            if let t = task { syncTasks.remove(t) }
        }
        if let t = task { syncTasks.insert(t) }
    }

    private func save() {
        do {
            try viewContext.save()
        } catch {
            errorMessage = "Не удалось сохранить изменения"
        }
    }
}
