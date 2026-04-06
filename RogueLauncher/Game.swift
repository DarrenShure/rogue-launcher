import Foundation
import AppKit

enum GameType: String, Codable {
    case moonlight
    case local
    case console
    case rom
}

struct Game: Identifiable, Codable, Hashable {
    var id: UUID = UUID()
    var name: String
    var description: String
    var genre: String
    var releaseYear: String
    var appName: String          // Moonlight: App-Name; Local: Bundle-ID oder .app-Pfad
    var coverImagePath: String?
    var backgroundImagePath: String?
    var lastPlayedAt: Date?
    var type: GameType = .moonlight
    var ageRating: String = ""
    var steamAppID: String = ""
    var igdbID: Int? = nil
    var consoleType: String = ""  // "ps5", "switch", "xbox" etc.
    var romPath: String? = nil    // Pfad zur ROM-Datei für Emulatoren
    var romSystem: String = ""    // "nes", "snes", "n64", "gba", "ps1" etc.

    init(id: UUID = UUID(), name: String, description: String = "", genre: String = "",
         releaseYear: String = "", appName: String = "", coverImagePath: String? = nil,
         backgroundImagePath: String? = nil, lastPlayedAt: Date? = nil,
         type: GameType = .moonlight, ageRating: String = "") {
        self.id = id; self.name = name; self.description = description
        self.genre = genre; self.releaseYear = releaseYear; self.appName = appName
        self.coverImagePath = coverImagePath; self.backgroundImagePath = backgroundImagePath
        self.lastPlayedAt = lastPlayedAt; self.type = type; self.ageRating = ageRating
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        description = try c.decodeIfPresent(String.self, forKey: .description) ?? ""
        genre = try c.decodeIfPresent(String.self, forKey: .genre) ?? ""
        releaseYear = try c.decodeIfPresent(String.self, forKey: .releaseYear) ?? ""
        appName = try c.decodeIfPresent(String.self, forKey: .appName) ?? ""
        coverImagePath = try c.decodeIfPresent(String.self, forKey: .coverImagePath)
        backgroundImagePath = try c.decodeIfPresent(String.self, forKey: .backgroundImagePath)
        lastPlayedAt = try c.decodeIfPresent(Date.self, forKey: .lastPlayedAt)
        type = try c.decodeIfPresent(GameType.self, forKey: .type) ?? .moonlight
        ageRating = try c.decodeIfPresent(String.self, forKey: .ageRating) ?? ""
        igdbID = try c.decodeIfPresent(Int.self, forKey: .igdbID)
        consoleType = try c.decodeIfPresent(String.self, forKey: .consoleType) ?? ""
    }

    enum CodingKeys: String, CodingKey {
        case id, name, description, genre, releaseYear, appName
        case coverImagePath, backgroundImagePath, lastPlayedAt, type, ageRating, igdbID, consoleType
        case romPath, romSystem
    }

    var backgroundImage: NSImage? {
        guard let path = backgroundImagePath else { return nil }
        return NSImage(contentsOfFile: path)
    }

    var coverImage: NSImage? {
        guard let path = coverImagePath else { return nil }
        return NSImage(contentsOfFile: path)
    }

    // App-Icon für lokale Apps
    var localAppIcon: NSImage? {
        guard type == .local else { return nil }
        // Versuche über Bundle-ID
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appName) {
            return NSWorkspace.shared.icon(forFile: url.path)
        }
        // Versuche direkt als Pfad
        if FileManager.default.fileExists(atPath: appName) {
            return NSWorkspace.shared.icon(forFile: appName)
        }
        return nil
    }

    static func == (lhs: Game, rhs: Game) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
