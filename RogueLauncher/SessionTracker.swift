import Foundation
import Combine

/// Einfaches Session-Tracking: merkt sich welches Spiel zuletzt gestartet wurde.
class SessionTracker: ObservableObject {
    static let shared = SessionTracker()

    @Published var activeAppName: String? = nil
    @Published var isSwitching: Bool = false

    private let key = "lastLaunchedAppName"

    private init() {
        activeAppName = UserDefaults.standard.string(forKey: key)
    }

    func sessionStarted(appName: String) {
        activeAppName = appName
        isSwitching = false
        UserDefaults.standard.set(appName, forKey: key)
    }

    func switchingStarted() { isSwitching = true }
    func switchingFinished() { isSwitching = false }

    func sessionEnded() {
        activeAppName = nil
        isSwitching = false
        UserDefaults.standard.removeObject(forKey: key)
    }

    var hasActiveSession: Bool { activeAppName != nil }
    var currentAppName: String? { activeAppName }
}
