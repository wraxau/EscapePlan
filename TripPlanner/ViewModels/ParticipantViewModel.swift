import SwiftUI
import CoreData
import Combine

@MainActor
final class ParticipantViewModel: ObservableObject {

    // MARK: - Published state

    @Published var participants: [Participant] = []
    @Published var errorMessage: String? = nil

    // MARK: - Private

    private let context: NSManagedObjectContext
    private let trip: Trip

    // MARK: - Init

    init(trip: Trip, context: NSManagedObjectContext) {
        self.trip = trip
        self.context = context
        fetch()
    }

    // MARK: - Fetch

    func fetch() {
        let request: NSFetchRequest<Participant> = Participant.fetchRequest()
        request.predicate = NSPredicate(format: "trip == %@", trip)
        request.sortDescriptors = [
            // Владелец всегда первый
            NSSortDescriptor(keyPath: \Participant.isOwner, ascending: false),
            NSSortDescriptor(keyPath: \Participant.name, ascending: true)
        ]
        participants = (try? context.fetch(request)) ?? []
    }

    // MARK: - Create

    func addParticipant(name: String, email: String? = nil, number: String? = nil, isOwner: Bool = false) {
        let p = Participant(context: context)
        p.id = UUID()
        p.name = name
        p.email = email
        p.number = number
        p.isOwner = isOwner
        p.trip = trip
        p.isSynced = false
        save()
        fetch()
    }

    // MARK: - Update

    func updateParticipant(_ participant: Participant, name: String? = nil, email: String? = nil, number: String? = nil) {
        if let name { participant.name = name }
        if let email { participant.email = email }
        if let number { participant.number = number }
        participant.isSynced = false
        save()
        fetch()
    }

    // MARK: - Delete

    func deleteParticipant(_ participant: Participant) {
        context.delete(participant)
        save()
        fetch()
    }

    // MARK: - Owner management

    var owner: Participant? {
        participants.first { $0.isOwner }
    }

    func transferOwnership(to participant: Participant) {
        participants.forEach { $0.isOwner = false }
        participant.isOwner = true
        save()
        fetch()
    }

    // MARK: - Helpers
    var participantNames: String {
        let names = participants.compactMap { $0.name }
        return names.isEmpty ? "Нет участников" : names.joined(separator: ", ")
    }

    // MARK: - Private

    private func save() {
        do {
            try context.save()
        } catch {
            errorMessage = "Не удалось сохранить участника"
        }
    }
}
