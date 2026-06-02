import CoreData

struct PersistenceController {
    static let shared = PersistenceController()

    // MARK: Preview с тестовыми данными

    @MainActor
    static let preview: PersistenceController = {
        let result = PersistenceController(inMemory: true)
        let ctx = result.container.viewContext

        // Поездка 1
        let trip1 = Trip(context: ctx)
        trip1.id         = UUID()
        trip1.name       = "Барселона 2026"
        trip1.startDate  = Calendar.current.date(byAdding: .day, value: 30, to: Date())
        trip1.endDate    = Calendar.current.date(byAdding: .day, value: 37, to: Date())
        trip1.currencyCode = "EUR"
        trip1.peopleNumber = 3
        trip1.createdAt  = Date()
        trip1.updatedAt  = Date()
        trip1.isSynced   = false

        // Участники поездки 1
        let p1 = Participant(context: ctx)
        p1.id = UUID(); p1.name = "Нина"; p1.isOwner = true; p1.trip = trip1

        let p2 = Participant(context: ctx)
        p2.id = UUID(); p2.name = "Саша"; p2.trip = trip1

        // DayPlan
        let day1 = DayPlan(context: ctx)
        day1.id   = UUID()
        day1.date = trip1.startDate ?? Date()
        day1.trip = trip1

        // Расход
        let exp1 = Expense(context: ctx)
        exp1.id       = UUID()
        exp1.category = "cafe"
        exp1.amount   = 85.50
        exp1.date     = day1.date ?? Date()
        exp1.isShared = true
        exp1.paidBy   = p1
        exp1.trip     = trip1
        exp1.dayPlan  = day1

        // Место
        let place1 = Place(context: ctx)
        place1.id        = UUID()
        place1.name      = "Sagrada Família"
        place1.type      = "attraction"
        place1.latitude  = 41.4036
        place1.longitude = 2.1744
        place1.dayPlan   = day1
        place1.trip      = trip1

        let trip2 = Trip(context: ctx)
        trip2.id           = UUID()
        trip2.name         = "Токио — мечта"
        trip2.currencyCode = "JPY"
        trip2.peopleNumber = 2
        trip2.createdAt    = Date()
        trip2.updatedAt    = Date()
        trip2.isSynced     = false

        do {
            try ctx.save()
        } catch {
            let nsError = error as NSError
            fatalError("Preview Core Data error: \(nsError), \(nsError.userInfo)")
        }
        return result
    }()

    // MARK: Container

    let container: NSPersistentContainer

    init(inMemory: Bool = false) {
        container = NSPersistentContainer(name: "TripPlanner")

        if let description = container.persistentStoreDescriptions.first {
            if inMemory {
                description.url = URL(fileURLWithPath: "/dev/null")
            }

            description.setOption(true as NSNumber,
                                   forKey: NSMigratePersistentStoresAutomaticallyOption)
            description.setOption(true as NSNumber,
                                   forKey: NSInferMappingModelAutomaticallyOption)
        }

        container.loadPersistentStores { _, error in
            if let error = error as NSError? {
                #if DEBUG
                fatalError("Core Data failed to load: \(error), \(error.userInfo)")
                #else
                print("CoreData load error: \(error). Attempting recovery.")
                #endif
            }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    }
}
