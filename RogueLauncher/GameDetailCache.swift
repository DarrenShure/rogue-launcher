import Foundation

/// Persisted per-game metadata cache (UserDefaults, keyed by normalised game name)
struct CachedGameDetail: Codable {
    var description: String
    var genre: String
    var releaseYear: String
    var ageRating: String
    var rating: Double?
    var screenshotURLs: [String]
    var youtubeVideoIDs: [String]   // only IDs – titles fetched separately
    var youtubeTitles: [String]
    var fetchedAt: Date
}

final class GameDetailCache {
    static let shared = GameDetailCache()
    private let defaults = UserDefaults.standard
    private let keyPrefix = "gdcache_"
    private let maxAge: TimeInterval = 60 * 60 * 24 * 3   // 3 days

    private func key(_ name: String) -> String {
        keyPrefix + name.lowercased().trimmingCharacters(in: .whitespaces)
    }

    func load(for name: String) -> CachedGameDetail? {
        guard let data = defaults.data(forKey: key(name)),
              let cached = try? JSONDecoder().decode(CachedGameDetail.self, from: data)
        else { return nil }
        guard Date().timeIntervalSince(cached.fetchedAt) < maxAge else { return nil }
        return cached
    }

    func save(_ detail: CachedGameDetail, for name: String) {
        guard let data = try? JSONEncoder().encode(detail) else { return }
        defaults.set(data, forKey: key(name))
    }

    func clear(for name: String) {
        defaults.removeObject(forKey: key(name))
    }
}
