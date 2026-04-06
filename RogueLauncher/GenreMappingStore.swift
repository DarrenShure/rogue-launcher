import Foundation
import Combine

/// Persistenter Store für benutzerdefinierte Genre-Varianten
class GenreMappingStore: ObservableObject {
    static let shared = GenreMappingStore()

    // [Kanonischer Name: [Varianten]] — user-defined additions
    @Published var customVariants: [String: [String]] = [:]

    private let key = "genreCustomVariants"

    private init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([String: [String]].self, from: data) {
            customVariants = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(customVariants) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func variants(for canonical: String) -> [String] {
        let builtin = genreMapping.first(where: { $0.canonical == canonical })?.variants ?? []
        let custom = customVariants[canonical] ?? []
        return Array(Set(builtin + custom)).sorted()
    }

    func addVariant(_ variant: String, to canonical: String) {
        var existing = customVariants[canonical] ?? []
        let lower = variant.lowercased().trimmingCharacters(in: .whitespaces)
        if !lower.isEmpty && !existing.contains(lower) {
            existing.append(lower)
            customVariants[canonical] = existing
            save()
        }
    }

    func removeVariant(_ variant: String, from canonical: String) {
        // Nur custom Varianten können entfernt werden
        var existing = customVariants[canonical] ?? []
        existing.removeAll { $0 == variant }
        customVariants[canonical] = existing
        save()
    }

    /// Gibt alle Genre-Begriffe zurück, die in Spielen vorkommen aber keinem Genre zugeordnet sind
    func unassignedTags(from store: GameStore) -> [String] {
        var allRaw = Set<String>()
        for game in store.games {
            for raw in game.genre.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces).lowercased() }) {
                if !raw.isEmpty { allRaw.insert(raw) }
            }
        }
        // Filtere alle die bereits einem Genre zugeordnet sind
        let assigned = genreMapping.flatMap { entry in
            entry.variants + (customVariants[entry.canonical] ?? [])
        }.map { $0.lowercased() }
        let assignedSet = Set(assigned)
        return allRaw.filter { !assignedSet.contains($0) }.sorted()
    }
}

/// Erweiterte Normalisierung die auch Custom-Varianten berücksichtigt
func normalizeGenreWithCustom(_ raw: String) -> String {
    let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
    let store = GenreMappingStore.shared
    // Custom Varianten zuerst prüfen
    for entry in genreMapping {
        let custom = store.customVariants[entry.canonical] ?? []
        if custom.contains(where: { lower.contains($0) }) {
            return entry.canonical
        }
    }
    // Dann Standard-Mapping
    return normalizeGenre(raw)
}
