import Foundation
import SwiftUI
import Combine

// MARK: - Map Mode

enum MapMode: Equatable {
    case view, colorCountry, addPin, addNote

    var jsString: String {
        switch self {
        case .view:         return "view"
        case .colorCountry: return "color"
        case .addPin:       return "pin"
        case .addNote:      return "note"
        }
    }

    var hint: String {
        switch self {
        case .view:         return ""
        case .colorCountry: return "Нажми на страну, чтобы закрасить"
        case .addPin:       return "Нажми на карту, чтобы добавить точку"
        case .addNote:      return "Нажми на карту, чтобы добавить заметку"
        }
    }
}

// MARK: - MapMemory

struct MapMemory: Codable, Identifiable {
    var id: UUID = UUID()
    var latitude: Double
    var longitude: Double
    var caption: String
    var photoFileNames: [String]
    var isNote: Bool = false
    var createdAt: Date = Date()

    var photoURLs: [URL] {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return photoFileNames.compactMap { name in
            let url = docs.appendingPathComponent(name)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
    }
}

// MARK: - MapViewModel

@MainActor
final class MapViewModel: ObservableObject {

    // MARK: - State

    @Published var visitedCountries: [String] = [] {
        didSet { UserDefaults.standard.set(visitedCountries, forKey: "map_visited_countries") }
    }

    @Published var memories: [MapMemory] = [] {
        didSet { saveMemories() }
    }

    @Published var mapMode: MapMode = .view
    @Published var selectedMemory: MapMemory? = nil
    @Published var showAddMemory: Bool = false
    @Published var showAddNote: Bool = false
    @Published var pendingLocation: (Double, Double)? = nil

    // MARK: - Init

    init() {
        visitedCountries = UserDefaults.standard.stringArray(forKey: "map_visited_countries") ?? []
        loadMemories()
    }

    // MARK: - Actions

    func addMemory(lat: Double, lng: Double, caption: String, images: [UIImage], isNote: Bool = false) {
        var fileNames: [String] = []
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        for img in images {
            let name = "mem_\(UUID().uuidString).jpg"
            if let data = img.jpegData(compressionQuality: 0.8) {
                try? data.write(to: docs.appendingPathComponent(name))
                fileNames.append(name)
            }
        }
        let memory = MapMemory(
            latitude: lat,
            longitude: lng,
            caption: caption,
            photoFileNames: fileNames,
            isNote: isNote
        )
        memories.append(memory)
    }

    func deleteMemory(_ memory: MapMemory) {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        for name in memory.photoFileNames {
            try? FileManager.default.removeItem(at: docs.appendingPathComponent(name))
        }
        memories.removeAll { $0.id == memory.id }
        if selectedMemory?.id == memory.id { selectedMemory = nil }
    }

    // MARK: - Persistence

    private func saveMemories() {
        if let data = try? JSONEncoder().encode(memories) {
            UserDefaults.standard.set(data, forKey: "map_memories")
        }
    }

    private func loadMemories() {
        guard let data = UserDefaults.standard.data(forKey: "map_memories"),
              let decoded = try? JSONDecoder().decode([MapMemory].self, from: data) else { return }
        memories = decoded
    }
}
