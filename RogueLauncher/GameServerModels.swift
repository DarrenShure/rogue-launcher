import Foundation

// MARK: - Server Models

struct CraftyServer: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    var serverID: String = ""  // Crafty interne Server-ID
}

struct NitradoServer: Codable, Identifiable {
    var id: String = UUID().uuidString
    var name: String = ""
    var serverID: String = ""  // Nitrado Service-ID
}

// MARK: - Server Status

enum ServerStatus {
    case online, offline, starting, stopping, unknown
    var color: String { // als String für einfache Verwendung
        switch self {
        case .online: return "green"
        case .offline: return "red"
        case .starting, .stopping: return "orange"
        case .unknown: return "gray"
        }
    }
    var label: String {
        switch self {
        case .online: return "Online"
        case .offline: return "Offline"
        case .starting: return "Startet..."
        case .stopping: return "Stoppt..."
        case .unknown: return "Unbekannt"
        }
    }
}
