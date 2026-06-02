import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import CoreData
import os.log

// MARK: - Sync State

enum SyncState: Equatable {
    case idle
    case syncing
    case error(String)
    case success
}

// MARK: - Invitation model

struct TripInvitation: Identifiable {
    let id: String          // = tripId
    let tripId: String
    let tripName: String
    let ownerName: String
    let ownerUID: String
    let invitedAt: Date
    var status: String      // "pending" | "accepted" | "declined"
}

// MARK: - SyncService

@MainActor
final class SyncService: ObservableObject {

    static let shared = SyncService()

    private let db = Firestore.firestore()
    private let networkMonitor = NetworkMonitor.shared
    private let logger = Logger(subsystem: "com.tripplanner.sync", category: "SyncService")

    @Published var pendingInvitations: [TripInvitation] = []
    @Published var isLoading = false
    @Published var errorMessage: String? = nil
    @Published var syncState: SyncState = .idle

    private let syncQueue = DispatchQueue(label: "com.tripplanner.sync.queue")
    private var activeSyncOperations: Set<String> = []

    private init() {
        self.logger.debug("SyncService initialized")
    }

    // MARK: - Helper Methods

    private func retryWithBackoff<T>(
        maxRetries: Int = 3,
        baseDelay: TimeInterval = 1.0,
        operation: () async throws -> T
    ) async throws -> T {
        var lastError: Error?

        for attempt in 0..<maxRetries {
            do {
                return try await operation()
            } catch {
                lastError = error
                self.logger.debug("Operation failed on attempt \(attempt + 1)/\(maxRetries): \(error.localizedDescription)")

                if !isNetworkError(error) {
                    self.logger.error("Non-network error, not retrying: \(error.localizedDescription)")
                    throw error
                }

                if !networkMonitor.isConnected {
                    self.logger.warning("No internet connection, waiting for recovery...")
                    await waitForNetworkRecovery()
                    self.logger.info("Network recovered, retrying operation")
                    continue
                }

                if attempt < maxRetries - 1 {
                    let delaySeconds = baseDelay * pow(2, Double(attempt))
                    self.logger.debug("Retrying in \(delaySeconds) seconds...")
                    try await Task.sleep(nanoseconds: UInt64(delaySeconds * 1_000_000_000))
                }
            }
        }

        let finalError = lastError ?? NSError(domain: "SyncService", code: -1, userInfo: [NSLocalizedDescriptionKey: "Max retries exceeded"])
        self.logger.error("Max retries exceeded: \(finalError.localizedDescription)")
        throw finalError
    }
    
    private func waitForNetworkRecovery() async {
        self.logger.info("Waiting for network connection to be restored...")
        while !networkMonitor.isConnected {
            try? await Task.sleep(nanoseconds: 500_000_000)
        }
        try? await Task.sleep(nanoseconds: 500_000_000)
        self.logger.info("Network connection restored: \(self.networkMonitor.statusDescription)")
    }


    private func isNetworkError(_ error: Error) -> Bool {
        let nsError = error as NSError
        // Firestore network errors
        if nsError.domain == "FIRFirestoreErrorDomain" {
            return [17, 14, 4, 1].contains(nsError.code)
        }
        // URL session errors
        if nsError.domain == NSURLErrorDomain {
            return [-1000, -1001, -1003, -1004, -1200].contains(nsError.code)
        }
        return false
    }

    private func shouldSkipSyncOperation(for tripId: String) -> Bool {
        var shouldSkip = false
        syncQueue.sync {
            shouldSkip = activeSyncOperations.contains(tripId)
        }
        return shouldSkip
    }

    /// Регистрирует начало операции синхронизации
    private func beginSyncOperation(for tripId: String) {
        syncQueue.async {
            self.activeSyncOperations.insert(tripId)
        }
    }

    /// Регистрирует завершение операции синхронизации
    private func endSyncOperation(for tripId: String) {
        syncQueue.async {
            self.activeSyncOperations.remove(tripId)
        }
    }

    // MARK: - Upload Trip
    @discardableResult
    func uploadTrip(_ trip: Trip) async -> Bool {
        guard let tripId = trip.id?.uuidString else {
            self.logger.warning("uploadTrip: trip.id is nil")
            return false
        }

        self.logger.info("Uploading trip: \(trip.name ?? "Unknown") (\(tripId))")

        var data: [String: Any] = [
            "id":           tripId,
            "name":         trip.name ?? "",
            "ownerUID":     trip.ownerFirebaseUID ?? "",
            "currencyCode": trip.currencyCode ?? "USD",
            "createdAt":    Timestamp(date: trip.createdAt ?? Date())
        ]
        if let start = trip.startDate { data["startDate"] = Timestamp(date: start) }
        if let end   = trip.endDate   { data["endDate"]   = Timestamp(date: end) }

        do {
            try await db.collection("trips").document(tripId).setData(data)
            self.logger.info("Trip uploaded successfully: \(tripId)")
            trip.isSynced = true
            try? trip.managedObjectContext?.save()

            let participants = (trip.participants as? Set<Participant>) ?? []
            self.logger.debug("Uploading \(participants.count) participants for trip \(tripId)")
            for p in participants {
                try await uploadParticipant(p, tripId: tripId)
            }
            self.logger.info("All participants uploaded for trip: \(tripId)")
            return true
        } catch {
            self.logger.error("Failed to upload trip: \(error.localizedDescription)")
            errorMessage = "Ошибка синхронизации поездки: \(error.localizedDescription)"
            return false
        }
    }

    func uploadParticipant(_ participant: Participant, tripId: String) async throws {
        guard let pId = participant.id?.uuidString else {
            self.logger.warning("uploadParticipant: participant.id is nil for trip \(tripId)")
            return
        }

        self.logger.debug("Uploading participant: \(participant.name ?? "Unknown") to trip \(tripId)")
        let data: [String: Any] = [
            "id":          pId,
            "name":        participant.name ?? "",
            "email":       participant.email ?? "",
            "isOwner":     participant.isOwner,
            "firebaseUID": participant.firebaseUID ?? ""
        ]
        try await db
            .collection("trips").document(tripId)
            .collection("participants").document(pId)
            .setData(data)
        self.logger.debug("Participant uploaded: \(pId)")
    }

    @discardableResult
    func uploadExpense(_ expense: Expense) async -> Bool {
        guard let expId = expense.id?.uuidString,
              let tripId = expense.trip?.id?.uuidString else {
            self.logger.warning("uploadExpense: expense or trip id is nil")
            return false
        }

        self.logger.info("Uploading expense: \(expense.descriptionText ?? "Unknown") (\(expId))")

        let sharedWith = (expense.sharedWithParticipantIDs as? [UUID])?.map { $0.uuidString } ?? []
        let data: [String: Any] = [
            "id":                      expId,
            "amount":                  (expense.amount as Decimal?)?.doubleValue ?? 0,
            "currency":                expense.currency ?? "USD",
            "category":                expense.category ?? "",
            "date":                    Timestamp(date: expense.date ?? Date()),
            "description":             expense.descriptionText ?? "",
            "paidByParticipantId":     expense.paidBy?.id?.uuidString ?? "",
            "isShared":                expense.isShared,
            "sharedWithParticipantIDs": sharedWith,
            "debtStatus":              expense.debtStatus ?? "pending"
        ]

        do {
            try await retryWithBackoff {
                try await self.db
                    .collection("trips").document(tripId)
                    .collection("expenses").document(expId)
                    .setData(data)
            }
            self.logger.info("Expense uploaded successfully: \(expId)")
            expense.isSynced = true
            try? expense.managedObjectContext?.save()
            syncState = .success
            return true
        } catch {
            self.logger.error("Failed to upload expense: \(error.localizedDescription)")
            syncState = .error("Ошибка синхронизации: \(error.localizedDescription)")
            errorMessage = "Ошибка синхронизации расхода"
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                if case .error = self.syncState { self.syncState = .idle }
            }
            return false
        }
    }

    // MARK: - Delete

    func deleteTrip(_ tripId: String) async {
        self.logger.info("Deleting trip and all subcollections: \(tripId)")
        let tripRef = db.collection("trips").document(tripId)

        do {
            let subcollections = ["participants", "expenses", "places"]
            for name in subcollections {
                let snapshot = try await tripRef.collection(name).getDocuments()
                for doc in snapshot.documents {
                    try await doc.reference.delete()
                }
                self.logger.debug("Deleted \(snapshot.documents.count) docs from \(name)")
            }

            let dayPlansSnapshot = try await tripRef.collection("dayPlans").getDocuments()
            for dayDoc in dayPlansSnapshot.documents {
                let activitiesSnapshot = try await dayDoc.reference.collection("activities").getDocuments()
                for actDoc in activitiesSnapshot.documents {
                    try await actDoc.reference.delete()
                }
                try await dayDoc.reference.delete()
            }
            self.logger.debug("Deleted \(dayPlansSnapshot.documents.count) dayPlans with activities")

            try await tripRef.delete()
            self.logger.info("Trip deleted successfully: \(tripId)")
        } catch {
            self.logger.error("Failed to delete trip: \(error.localizedDescription)")
            errorMessage = "Ошибка удаления поездки: \(error.localizedDescription)"
        }
    }
    
    func deleteExpense(_ expense: Expense) async {
        guard let expId = expense.id?.uuidString,
              let tripId = expense.trip?.id?.uuidString else {
            self.logger.warning("deleteExpense: expense or trip id is nil")
            return
        }

        self.logger.info("Deleting expense: \(expId) from trip: \(tripId)")
        do {
            try await db
                .collection("trips").document(tripId)
                .collection("expenses").document(expId)
                .delete()
            self.logger.info("Expense deleted successfully: \(expId)")
        } catch {
            self.logger.error("Failed to delete expense: \(error.localizedDescription)")
            errorMessage = "Ошибка удаления расхода: \(error.localizedDescription)"
        }
    }

    // MARK: - Invitations
    func sendInvitation(
        toEmail email: String,
        trip: Trip,
        ownerName: String
    ) async -> Bool {
        guard let tripId = trip.id?.uuidString,
              !email.trimmingCharacters(in: .whitespaces).isEmpty else {
            self.logger.warning("sendInvitation: invalid email or trip id")
            return false
        }

        self.logger.info("Sending invitation to \(email) for trip \(trip.name ?? "Unknown")")

        let encodedEmail = encodeEmail(email)

        let data: [String: Any] = [
            "tripId":    tripId,
            "tripName":  trip.name ?? "Поездка",
            "ownerName": ownerName,
            "ownerUID":  Auth.auth().currentUser?.uid ?? "",
            "invitedAt": Timestamp(date: Date()),
            "status":    "pending"
        ]

        do {
            try await db
                .collection("invitations")
                .document(encodedEmail)
                .collection("pending")
                .document(tripId)
                .setData(data)

            self.logger.debug("Invitation record created for \(email)")

            await uploadTrip(trip)
            self.logger.info("Invitation sent successfully to \(email)")
            return true
        } catch {
            self.logger.error("Failed to send invitation: \(error.localizedDescription)")
            errorMessage = "Не удалось отправить приглашение: \(error.localizedDescription)"
            return false
        }
    }

    // MARK: - Fetch Pending Invitations

    func fetchPendingInvitations() async {
        guard let email = Auth.auth().currentUser?.email else {
            self.logger.warning("fetchPendingInvitations: currentUser.email is nil")
            return
        }

        self.logger.info("Fetching pending invitations for \(email)")
        let encodedEmail = encodeEmail(email)

        isLoading = true
        defer { isLoading = false }

        do {
            let snapshot = try await db
                .collection("invitations")
                .document(encodedEmail)
                .collection("pending")
                .whereField("status", isEqualTo: "pending")
                .getDocuments()

            pendingInvitations = snapshot.documents.compactMap { doc in
                let d = doc.data()
                guard let tripId   = d["tripId"]   as? String,
                      let tripName = d["tripName"]  as? String,
                      let ownerUID = d["ownerUID"]  as? String else { return nil }
                let ownerName = d["ownerName"] as? String ?? "Владелец"
                let ts = d["invitedAt"] as? Timestamp
                return TripInvitation(
                    id:        tripId,
                    tripId:    tripId,
                    tripName:  tripName,
                    ownerName: ownerName,
                    ownerUID:  ownerUID,
                    invitedAt: ts?.dateValue() ?? Date(),
                    status:    "pending"
                )
            }

            self.logger.info("Fetched \(self.pendingInvitations.count) pending invitations")
        } catch {
            self.logger.error("Failed to fetch pending invitations: \(error.localizedDescription)")
            errorMessage = "Ошибка загрузки приглашений: \(error.localizedDescription)"
        }
    }

    // MARK: - Accept Invitation

    func acceptInvitation(
        _ invitation: TripInvitation,
        context: NSManagedObjectContext
    ) async {
        self.logger.info("Accepting invitation for trip: \(invitation.tripName) (\(invitation.tripId))")

        if shouldSkipSyncOperation(for: invitation.tripId) {
            self.logger.warning("Invitation for trip \(invitation.tripId) is already being accepted")
            return
        }

        beginSyncOperation(for: invitation.tripId)
        isLoading = true

        defer {
            endSyncOperation(for: invitation.tripId)
            isLoading = false
        }

        do {
            let tripDoc = try await db
                .collection("trips")
                .document(invitation.tripId)
                .getDocument()

            guard let tripData = tripDoc.data() else {
                self.logger.error("Trip not found in Firestore: \(invitation.tripId)")
                errorMessage = "Поездка не найдена"
                isLoading = false
                return
            }

            self.logger.debug("Trip data downloaded: \(invitation.tripId)")

            let fetchRequest: NSFetchRequest<Trip> = Trip.fetchRequest()
            if let tripUUID = UUID(uuidString: invitation.tripId) {
                fetchRequest.predicate = NSPredicate(format: "id == %@", tripUUID as CVarArg)
            } else {
                fetchRequest.predicate = NSPredicate(value: false)
            }
            if let existing = try? context.fetch(fetchRequest), let existingTrip = existing.first {
                let currentUID   = Auth.auth().currentUser?.uid ?? ""
                let currentEmail = Auth.auth().currentUser?.email ?? ""
                let alreadyAdded = (existingTrip.participants as? Set<Participant>)?
                    .contains { $0.firebaseUID == currentUID } ?? false

                if !alreadyAdded {
                    let savedName   = UserDefaults.standard.string(forKey: "profile_name")?.trimmingCharacters(in: .whitespaces)
                    let firebaseName = Auth.auth().currentUser?.displayName?.trimmingCharacters(in: .whitespaces)
                    let emailPrefix = currentEmail.components(separatedBy: "@").first ?? currentEmail
                    let me = Participant(context: context)
                    me.id          = UUID()
                    me.name        = (savedName?.isEmpty == false) ? savedName!
                                   : (firebaseName?.isEmpty == false) ? firebaseName!
                                   : emailPrefix
                    me.email       = currentEmail
                    me.firebaseUID = currentUID
                    me.isOwner     = false
                    me.isSynced    = false
                    me.trip        = existingTrip
                    try? context.save()
                    if let tripId = existingTrip.id?.uuidString {
                        try? await uploadParticipant(me, tripId: tripId)
                    }
                }

                await fetchDayPlans(for: existingTrip, context: context)
                await syncExpenses(for: existingTrip, context: context)
                await markInvitationAccepted(invitation)
                pendingInvitations.removeAll { $0.id == invitation.id }
                return
            }

            let trip = Trip(context: context)
            trip.id           = UUID(uuidString: invitation.tripId)
            trip.name         = tripData["name"] as? String ?? invitation.tripName
            trip.currencyCode = tripData["currencyCode"] as? String ?? "USD"
            trip.ownerFirebaseUID = tripData["ownerUID"] as? String
            trip.createdAt    = (tripData["createdAt"] as? Timestamp)?.dateValue() ?? Date()
            trip.updatedAt    = Date()
            trip.isSynced     = true

            if let ts = tripData["startDate"] as? Timestamp { trip.startDate = ts.dateValue() }
            if let ts = tripData["endDate"]   as? Timestamp { trip.endDate   = ts.dateValue() }

            let participantsSnap = try await db
                .collection("trips").document(invitation.tripId)
                .collection("participants").getDocuments()

            for doc in participantsSnap.documents {
                let pd = doc.data()
                let p = Participant(context: context)
                p.id          = UUID(uuidString: pd["id"] as? String ?? "") ?? UUID()
                p.name        = pd["name"]        as? String ?? ""
                p.email       = pd["email"]       as? String
                p.isOwner     = pd["isOwner"]     as? Bool ?? false
                p.firebaseUID = pd["firebaseUID"] as? String
                p.isSynced    = true
                p.trip        = trip
            }

            let currentEmail = Auth.auth().currentUser?.email ?? ""
            let currentUID   = Auth.auth().currentUser?.uid ?? ""
            let alreadyAdded = (trip.participants as? Set<Participant>)?
                .contains { $0.firebaseUID == currentUID } ?? false

            if !alreadyAdded {
                let me = Participant(context: context)
                me.id          = UUID()

                let savedProfileName = UserDefaults.standard.string(forKey: "profile_name")?
                    .trimmingCharacters(in: .whitespaces)
                let firebaseName = Auth.auth().currentUser?.displayName?
                    .trimmingCharacters(in: .whitespaces)
                let emailPrefix = currentEmail.components(separatedBy: "@").first ?? currentEmail
                me.name        = (savedProfileName?.isEmpty == false) ? savedProfileName!
                               : (firebaseName?.isEmpty == false)     ? firebaseName!
                               : emailPrefix
                me.email       = currentEmail
                me.firebaseUID = currentUID
                me.isOwner     = false
                me.isSynced    = false
                me.trip        = trip

                // Синхронизируем себя на сервере
                if let tripId = trip.id?.uuidString {
                    try? await uploadParticipant(me, tripId: tripId)
                }
            }

            try context.save()
            self.logger.debug("Trip saved to CoreData")
            await fetchDayPlans(for: trip, context: context)
            await markInvitationAccepted(invitation)
            pendingInvitations.removeAll { $0.id == invitation.id }

            self.logger.info("Invitation accepted successfully for trip: \(invitation.tripId)")

        } catch {
            self.logger.error("Failed to accept invitation: \(error.localizedDescription)")
            errorMessage = "Ошибка принятия приглашения: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync Participants (Firestore to CoreData)

    func fetchParticipants(for trip: Trip, context: NSManagedObjectContext) async {
        guard let tripId = trip.id?.uuidString else {
            self.logger.warning("fetchParticipants: trip.id is nil")
            return
        }

        self.logger.info("Fetching participants for trip: \(tripId)")

        do {
            let snapshot = try await db
                .collection("trips").document(tripId)
                .collection("participants")
                .getDocuments()

            let existingParticipants = (trip.participants as? Set<Participant>) ?? []
            var newParticipantsCount = 0

            for doc in snapshot.documents {
                let pd = doc.data()
                guard let idString = pd["id"] as? String,
                      let participantUUID = UUID(uuidString: idString) else { continue }
                let alreadyExists = existingParticipants.contains { $0.id == participantUUID }
                if alreadyExists { continue }

                let p = Participant(context: context)
                p.id          = participantUUID
                p.name        = pd["name"]        as? String ?? ""
                p.email       = pd["email"]       as? String
                p.isOwner     = pd["isOwner"]     as? Bool ?? false
                p.firebaseUID = pd["firebaseUID"] as? String
                p.isSynced    = true
                p.trip        = trip
                newParticipantsCount += 1
            }

            try context.save()
            self.logger.info("Fetched \(newParticipantsCount) new participants for trip: \(tripId)")
        } catch {
            self.logger.error("Failed to fetch participants: \(error.localizedDescription)")
            errorMessage = "Ошибка синхронизации участников: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync Places (CoreData / Firestore)
    @discardableResult
    func uploadPlace(_ place: Place) async -> Bool {
        guard let placeId = place.id?.uuidString,
              let tripId  = place.trip?.id?.uuidString else {
            self.logger.warning("uploadPlace: place or trip id is nil")
            return false
        }

        self.logger.info("Uploading place: \(place.name ?? "Unknown") (\(placeId))")

        var data: [String: Any] = [
            "id":      placeId,
            "name":    place.name ?? "",
            "type":    place.type ?? "attraction",
            "lat":     place.latitude,
            "lon":     place.longitude,
            "address": place.address ?? ""
        ]
        if let checkIn  = place.checkInDate  { data["checkInDate"]  = Timestamp(date: checkIn) }
        if let checkOut = place.checkOutDate { data["checkOutDate"] = Timestamp(date: checkOut) }

        do {
            try await db
                .collection("trips").document(tripId)
                .collection("places").document(placeId)
                .setData(data)
            self.logger.info("Place uploaded successfully: \(placeId)")
            place.isSynced = true
            try? place.managedObjectContext?.save()
            return true
        } catch {
            self.logger.error("Failed to upload place: \(error.localizedDescription)")
            errorMessage = "Ошибка синхронизации места: \(error.localizedDescription)"
            return false
        }
    }

    func deleteActivity(_ activity: Activity) async {
        guard let activityId = activity.id?.uuidString,
              let dayPlanId  = activity.dayPlan?.id?.uuidString,
              let tripId     = activity.trip?.id?.uuidString else {
            self.logger.warning("deleteActivity: activity, dayPlan or trip id is nil")
            return
        }

        self.logger.info("Deleting activity: \(activityId)")
        do {
            try await db
                .collection("trips").document(tripId)
                .collection("dayPlans").document(dayPlanId)
                .collection("activities").document(activityId)
                .delete()
            self.logger.info("Activity deleted successfully: \(activityId)")
        } catch {
            self.logger.error("Failed to delete activity: \(error.localizedDescription)")
            errorMessage = "Ошибка удаления активности: \(error.localizedDescription)"
        }
    }

    func deletePlace(_ place: Place) async {
        guard let placeId = place.id?.uuidString,
              let tripId  = place.trip?.id?.uuidString else {
            self.logger.warning("deletePlace: place or trip id is nil")
            return
        }

        self.logger.info("Deleting place: \(placeId)")
        do {
            try await db
                .collection("trips").document(tripId)
                .collection("places").document(placeId)
                .delete()
            self.logger.info("Place deleted successfully: \(placeId)")
        } catch {
            self.logger.error("Failed to delete place: \(error.localizedDescription)")
            errorMessage = "Ошибка удаления места: \(error.localizedDescription)"
        }
    }

    @discardableResult
    func uploadDayPlan(_ dayPlan: DayPlan) async -> Bool {
        guard let dayId  = dayPlan.id?.uuidString,
              let tripId = dayPlan.trip?.id?.uuidString else {
            self.logger.warning("uploadDayPlan: dayPlan or trip id is nil")
            return false
        }

        self.logger.info("Uploading day plan: \(dayId)")

        var data: [String: Any] = [
            "id":    dayId,
            "notes": dayPlan.notes ?? ""
        ]
        if let date = dayPlan.date {
            data["date"] = Timestamp(date: date)
        }

        do {
            try await db
                .collection("trips").document(tripId)
                .collection("dayPlans").document(dayId)
                .setData(data)
            self.logger.info("Day plan uploaded successfully: \(dayId)")
            dayPlan.isSynced = true
            try? dayPlan.managedObjectContext?.save()
            return true
        } catch {
            self.logger.error("Failed to upload day plan: \(error.localizedDescription)")
            errorMessage = "Ошибка синхронизации дня: \(error.localizedDescription)"
            return false
        }
    }

    func fetchDayPlans(for trip: Trip, context: NSManagedObjectContext) async {
        guard let tripId = trip.id?.uuidString else {
            self.logger.warning("fetchDayPlans: trip.id is nil")
            return
        }

        self.logger.info("Fetching day plans for trip: \(tripId)")

        do {
            let snapshot = try await db
                .collection("trips").document(tripId)
                .collection("dayPlans")
                .getDocuments()

            var dayCount = 0
            for doc in snapshot.documents {
                let d = doc.data()
                guard let idString = d["id"] as? String,
                      let dayUUID  = UUID(uuidString: idString) else { continue }

                // Ищем уже существующий день в CoreData
                let request: NSFetchRequest<DayPlan> = DayPlan.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", dayUUID as CVarArg)
                let existing = (try? context.fetch(request))?.first

                let day    = existing ?? DayPlan(context: context)
                day.id     = dayUUID
                day.notes  = d["notes"] as? String
                day.isSynced = true
                day.trip   = trip

                if let ts = d["date"] as? Timestamp {
                    day.date = ts.dateValue()
                }
                dayCount += 1
            }

            try context.save()
            self.logger.info("Fetched and saved \(dayCount) day plans for trip: \(tripId)")
        } catch {
            self.logger.error("Failed to fetch day plans: \(error.localizedDescription)")
            errorMessage = "Ошибка загрузки дней: \(error.localizedDescription)"
        }
    }

    // MARK: - Activities Sync

    @discardableResult
    func uploadActivity(_ activity: Activity) async -> Bool {
        guard let activityId = activity.id?.uuidString,
              let dayPlanId = activity.dayPlan?.id?.uuidString,
              let tripId = activity.trip?.id?.uuidString else {
            self.logger.warning("uploadActivity: activity, dayPlan or trip id is nil")
            return false
        }

        self.logger.info("Uploading activity: \(activity.title ?? "Unknown") (\(activityId))")

        var data: [String: Any] = [
            "id": activityId,
            "title": activity.title ?? "",
            "categoryName": activity.categoryName ?? "",
            "categoryColor": activity.categoryColor ?? "#FF4B8B",
            "note": activity.note ?? "",
            "reminderEnabled": activity.reminderEnabled
        ]

        if let startTime = activity.startTime {
            data["startTime"] = Timestamp(date: startTime)
        }
        if let endTime = activity.endTime {
            data["endTime"] = Timestamp(date: endTime)
        }
        if let budget = activity.budget {
            data["budget"] = budget.doubleValue
        }
        if activity.latitude != 0 {
            data["latitude"] = activity.latitude
        }
        if activity.longitude != 0 {
            data["longitude"] = activity.longitude
        }

        do {
            try await db
                .collection("trips").document(tripId)
                .collection("dayPlans").document(dayPlanId)
                .collection("activities").document(activityId)
                .setData(data, merge: true)
            self.logger.info("Activity uploaded successfully: \(activityId)")
            activity.isSynced = true
            try? activity.managedObjectContext?.save()
            return true
        } catch {
            self.logger.error("Failed to upload activity: \(error.localizedDescription)")
            errorMessage = "Ошибка синхронизации активности: \(error.localizedDescription)"
            return false
        }
    }

    func fetchActivities(for dayPlan: DayPlan, trip: Trip, context: NSManagedObjectContext) async {
        guard let dayPlanId = dayPlan.id?.uuidString,
              let tripId = trip.id?.uuidString else {
            self.logger.warning("fetchActivities: dayPlan or trip id is nil")
            return
        }

        self.logger.info("Fetching activities for day: \(dayPlanId)")

        do {
            let snapshot = try await db
                .collection("trips").document(tripId)
                .collection("dayPlans").document(dayPlanId)
                .collection("activities")
                .getDocuments()

            var activityCount = 0
            for doc in snapshot.documents {
                let d = doc.data()
                guard let idString = d["id"] as? String,
                      let activityUUID = UUID(uuidString: idString) else { continue }

                let request: NSFetchRequest<Activity> = Activity.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", activityUUID as CVarArg)
                let existing = (try? context.fetch(request))?.first

                let activity = existing ?? Activity(context: context)
                activity.id = activityUUID
                activity.title = d["title"] as? String
                activity.categoryName = d["categoryName"] as? String
                activity.categoryColor = d["categoryColor"] as? String
                activity.note = d["note"] as? String
                activity.reminderEnabled = d["reminderEnabled"] as? Bool ?? false

                if let startTs = d["startTime"] as? Timestamp {
                    activity.startTime = startTs.dateValue()
                }
                if let endTs = d["endTime"] as? Timestamp {
                    activity.endTime = endTs.dateValue()
                }
                if let budgetDouble = d["budget"] as? Double {
                    activity.budget = NSDecimalNumber(value: budgetDouble)
                }

                activity.latitude = d["latitude"] as? Double ?? 0
                activity.longitude = d["longitude"] as? Double ?? 0
                activity.isSynced = true
                activity.dayPlan = dayPlan
                activity.trip = trip
                activityCount += 1
            }

            try context.save()

            self.logger.info("Fetched and saved \(activityCount) activities for day: \(dayPlanId)")
        } catch {
            self.logger.error("Failed to fetch activities: \(error.localizedDescription)")
            errorMessage = "Ошибка загрузки активностей: \(error.localizedDescription)"
        }
    }

    func fetchPlaces(for trip: Trip, context: NSManagedObjectContext) async {
        guard let tripId = trip.id?.uuidString else {
            self.logger.warning("fetchPlaces: trip.id is nil")
            return
        }

        self.logger.info("Fetching places for trip: \(tripId)")

        do {
            let snapshot = try await db
                .collection("trips").document(tripId)
                .collection("places")
                .getDocuments()

            var placeCount = 0
            for doc in snapshot.documents {
                let d = doc.data()
                guard let idString = d["id"] as? String,
                      let placeUUID = UUID(uuidString: idString) else { continue }

                let request: NSFetchRequest<Place> = Place.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", placeUUID as CVarArg)
                let existing = (try? context.fetch(request))?.first

                let place = existing ?? Place(context: context)
                place.id        = placeUUID
                place.name      = d["name"]    as? String ?? ""
                place.type      = d["type"]    as? String ?? "attraction"
                place.latitude  = d["lat"]     as? Double ?? 0
                place.longitude = d["lon"]     as? Double ?? 0
                place.address   = d["address"] as? String
                place.isSynced  = true
                place.trip      = trip

                if let ts = d["checkInDate"]  as? Timestamp { place.checkInDate  = ts.dateValue() }
                if let ts = d["checkOutDate"] as? Timestamp { place.checkOutDate = ts.dateValue() }
                placeCount += 1
            }

            try context.save()
            self.logger.info("Fetched and saved \(placeCount) places for trip: \(tripId)")
        } catch {
            self.logger.error("Failed to fetch places: \(error.localizedDescription)")
            errorMessage = "Ошибка загрузки мест: \(error.localizedDescription)"
        }
    }

    // MARK: - Sync Expenses (Firestore to CoreData)

    func syncExpenses(for trip: Trip, context: NSManagedObjectContext) async {
        guard let tripId = trip.id?.uuidString else {
            self.logger.warning("syncExpenses: trip.id is nil")
            return
        }

        self.logger.info("Syncing expenses for trip: \(tripId)")

        do {
            let snapshot = try await db
                .collection("trips").document(tripId)
                .collection("expenses")
                .getDocuments()

            let participants = (trip.participants as? Set<Participant>) ?? []
            var expenseCount = 0

            for doc in snapshot.documents {
                let d = doc.data()
                guard let idString = d["id"] as? String,
                      let expenseUUID = UUID(uuidString: idString) else { continue }

                let request: NSFetchRequest<Expense> = Expense.fetchRequest()
                request.predicate = NSPredicate(format: "id == %@", expenseUUID as CVarArg)
                let existing = (try? context.fetch(request))?.first

                let expense = existing ?? Expense(context: context)
                expense.id              = expenseUUID
                expense.amount          = NSDecimalNumber(value: d["amount"] as? Double ?? 0)
                expense.currency        = d["currency"] as? String ?? "USD"
                expense.category        = d["category"] as? String
                expense.descriptionText = d["description"] as? String
                expense.isShared        = d["isShared"] as? Bool ?? false
                expense.debtStatus      = d["debtStatus"] as? String ?? "pending"
                expense.isSynced        = true
                expense.trip            = trip

                if let ts = d["date"] as? Timestamp {
                    expense.date = ts.dateValue()
                }

                // Связываем paidBy с локальным Participant по UUID
                if let paidByIdStr = d["paidByParticipantId"] as? String,
                   let paidByUUID  = UUID(uuidString: paidByIdStr) {
                    expense.paidBy = participants.first { $0.id == paidByUUID }
                }

                // Массив UUID участников, между которыми делится расход
                if let sharedIds = d["sharedWithParticipantIDs"] as? [String] {
                    expense.sharedWithParticipantIDs = sharedIds.compactMap { UUID(uuidString: $0) }
                }
                expenseCount += 1
            }

            try context.save()
            self.logger.info("Synced \(expenseCount) expenses for trip: \(tripId)")
        } catch {
            self.logger.error("Failed to sync expenses: \(error.localizedDescription)")
            errorMessage = "Ошибка синхронизации расходов: \(error.localizedDescription)"
        }
    }

    // MARK: - Decline Invitation

    func declineInvitation(_ invitation: TripInvitation) async {
        guard let email = Auth.auth().currentUser?.email else { return }
        let encodedEmail = encodeEmail(email)
        do {
            try await db
                .collection("invitations")
                .document(encodedEmail)
                .collection("pending")
                .document(invitation.tripId)
                .updateData(["status": "declined"])
            pendingInvitations.removeAll { $0.id == invitation.id }
        } catch {
            errorMessage = "Ошибка отклонения приглашения"
        }
    }

    // MARK: - Pending Data Sync
    func syncPendingData(context: NSManagedObjectContext) async {
        guard networkMonitor.isConnected else {
            self.logger.info("syncPendingData: skipped — no network")
            return
        }
        guard Auth.auth().currentUser != nil else {
            self.logger.info("syncPendingData: skipped — not authenticated")
            return
        }

        self.logger.info("syncPendingData: starting...")
        syncState = .syncing

        do {
            // 1. Поездки
            let tripReq: NSFetchRequest<Trip> = Trip.fetchRequest()
            tripReq.predicate = NSPredicate(format: "isSynced == false")
            let unsyncedTrips = try context.fetch(tripReq)
            self.logger.info("syncPendingData: \(unsyncedTrips.count) unsynced trips")
            for trip in unsyncedTrips {
                if await uploadTrip(trip) { trip.isSynced = true }
            }

            let expReq: NSFetchRequest<Expense> = Expense.fetchRequest()
            expReq.predicate = NSPredicate(format: "isSynced == false")
            let unsyncedExpenses = try context.fetch(expReq)
            self.logger.info("syncPendingData: \(unsyncedExpenses.count) unsynced expenses")
            for expense in unsyncedExpenses {
                if await uploadExpense(expense) { expense.isSynced = true }
            }

            let dayReq: NSFetchRequest<DayPlan> = DayPlan.fetchRequest()
            dayReq.predicate = NSPredicate(format: "isSynced == false")
            let unsyncedDays = try context.fetch(dayReq)
            self.logger.info("syncPendingData: \(unsyncedDays.count) unsynced day plans")
            for day in unsyncedDays {
                if await uploadDayPlan(day) { day.isSynced = true }
            }

            let actReq: NSFetchRequest<Activity> = Activity.fetchRequest()
            actReq.predicate = NSPredicate(format: "isSynced == false")
            let unsyncedActivities = try context.fetch(actReq)
            self.logger.info("syncPendingData: \(unsyncedActivities.count) unsynced activities")
            for activity in unsyncedActivities {
                if await uploadActivity(activity) { activity.isSynced = true }
            }

            let placeReq: NSFetchRequest<Place> = Place.fetchRequest()
            placeReq.predicate = NSPredicate(format: "isSynced == false")
            let unsyncedPlaces = try context.fetch(placeReq)
            self.logger.info("syncPendingData: \(unsyncedPlaces.count) unsynced places")
            for place in unsyncedPlaces {
                if await uploadPlace(place) { place.isSynced = true }
            }

            let partReq: NSFetchRequest<Participant> = Participant.fetchRequest()
            partReq.predicate = NSPredicate(format: "isSynced == false")
            let unsyncedParticipants = try context.fetch(partReq)
            self.logger.info("syncPendingData: \(unsyncedParticipants.count) unsynced participants")
            for participant in unsyncedParticipants {
                guard let tripId = participant.trip?.id?.uuidString else { continue }
                if let _ = try? await uploadParticipant(participant, tripId: tripId) {
                    participant.isSynced = true
                }
            }

            try context.save()
            self.logger.info("syncPendingData: completed successfully")
            syncState = .success

        } catch {
            self.logger.error("syncPendingData failed: \(error.localizedDescription)")
            syncState = .error("Ошибка синхронизации: \(error.localizedDescription)")
        }
    }

    // MARK: - Private helpers

    private func markInvitationAccepted(_ invitation: TripInvitation) async {
        guard let email = Auth.auth().currentUser?.email else { return }
        let encodedEmail = encodeEmail(email)
        try? await db
            .collection("invitations")
            .document(encodedEmail)
            .collection("pending")
            .document(invitation.tripId)
            .updateData(["status": "accepted"])
    }

    private func encodeEmail(_ email: String) -> String {
        guard let data = email.lowercased().data(using: .utf8) else {

            return email
                .lowercased()
                .replacingOccurrences(of: ".", with: ",")
                .replacingOccurrences(of: "@", with: "_")
        }

        return data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .trimmingCharacters(in: CharacterSet(charactersIn: "="))
    }

    private func decodeEmail(_ encoded: String) -> String? {
        let padded = encoded + String(repeating: "=", count: (4 - encoded.count % 4) % 4)

        let replaced = padded
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")

        guard let data = Data(base64Encoded: replaced) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}

// MARK: - Decimal helper

private extension Decimal {
    var doubleValue: Double {
        return NSDecimalNumber(decimal: self).doubleValue
    }
}
