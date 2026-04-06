import Foundation
import Combine

class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var pcIPAddress: String = ""
    @Published var pcMACAddress: String = ""
    @Published var pcOS: String = "windows"  // "windows" | "linux"
    @Published var moonlightHostOverride: String = ""  // Wenn gesetzt, wird dieser Host für Moonlight-Stream verwendet

    var streamingHost: String {
        moonlightHostOverride.isEmpty ? pcIPAddress : moonlightHostOverride
    }
    @Published var moonlightPort: Int = 47989
    @Published var wakeMethod: WakeMethod = .magicPacket
    @Published var webhookURL: String = ""
    @Published var shutdownMethod: ShutdownMethod = .rogueHelperShutdown
    @Published var shutdownWebhookURL: String = ""
    @Published var rawgAPIKey: String = ""
    @Published var steamGridDBKey: String = ""
    @Published var igdbClientID: String = ""
    @Published var igdbClientSecret: String = ""
    @Published var youtubeAPIKey: String = ""
    @Published var sleepWebhookURL: String = ""
    @Published var sleepMethod: String = "webhook" // "webhook" | "helper"
    @Published var helperHost: String = ""
    @Published var helperPort: String = "9876"
    @Published var helperUser: String = ""
    @Published var helperPassword: String = ""
    @Published var sunshineHost: String = ""
    @Published var sunshinePort: String = "47990"
    @Published var sunshineUser: String = ""
    @Published var sunshinePassword: String = ""
    @Published var sunshineSteamAppName: String = "Steam Big Picture"
    @Published var gameLaunchers: [GameLauncherConfig] = GameLauncherConfig.defaults

    // Game Servers
    @Published var craftyEnabled: Bool = false
    @Published var craftyURL: String = ""
    @Published var craftyAPIKey: String = ""
    @Published var craftyServers: [CraftyServer] = []

    @Published var nitradoEnabled: Bool = false
    @Published var nitradoAPIToken: String = ""
    @Published var nitradoServers: [NitradoServer] = []

    @Published var backupPath: String = ""
    @Published var nasURL: String = ""  // z.B. smb://nas/Spiele
    @Published var nasCacheDir: String = ""
    @Published var epicClaimURL: String = ""
    @Published var epicClaimMode: String = "webview"  // "webview" | "moonlight" | "webhook" | "browser"
    @Published var epicClaimWebhookURL: String = ""
    @Published var epicFreeGamesEnabled: Bool = true
    @Published var consolesEnabled: Bool = false
    @Published var emulatorsEnabled: Bool = false

    // Chat
    @Published var chatEnabledServices: [String: Bool] = [:]   // service.rawValue -> enabled
    @Published var chatServiceMode: [String: String] = [:]      // service.rawValue -> "webview" | "app"
    @Published var retroArchPath: String = "/opt/homebrew/bin/retroarch"
    @Published var hdmiInputMap: [String: String] = [:]  // "17": "PlayStation 5", "18": "Nintendo Switch"
    @Published var macInputNumber: Int = 15  // DDC-Nummer für Mac (USB-C/DP)

    enum WakeMethod: String, CaseIterable {
        case magicPacket = "Magic Package"
        case webhook     = "Webhook"
    }

    enum ShutdownMethod: String, CaseIterable {
        case rogueHelperShutdown = "Herunterfahren"
        case rogueHelperSleep    = "Schlafen"
        case webhook             = "Webhook"
        case disabled            = "Deaktiviert"
    }

    private init() { load() }

    func load() {
        let d = UserDefaults.standard
        // Auto-fill from Moonlight plist if not yet saved
        let plist = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
        if let dict = NSDictionary(contentsOfFile: plist) as? [String: Any] {
            let plistIP  = dict["hosts.1.localaddress"] as? String ?? ""
            let plistMAC = macFromData(dict["hosts.1.mac"])
            pcIPAddress  = d.string(forKey: "pcIPAddress").flatMap { $0.isEmpty ? nil : $0 } ?? plistIP
            pcMACAddress = d.string(forKey: "pcMACAddress") ?? ""
            pcOS         = d.string(forKey: "pcOS") ?? "windows"
        } else {
            pcIPAddress  = d.string(forKey: "pcIPAddress") ?? ""
            pcMACAddress = d.string(forKey: "pcMACAddress") ?? ""
            pcOS         = d.string(forKey: "pcOS") ?? "windows"
        }
        moonlightPort  = d.integer(forKey: "moonlightPort") == 0 ? 47989 : d.integer(forKey: "moonlightPort")
        moonlightHostOverride = d.string(forKey: "moonlightHostOverride") ?? ""
        wakeMethod     = WakeMethod(rawValue: d.string(forKey: "wakeMethod") ?? "") ?? .magicPacket
        webhookURL     = d.string(forKey: "webhookURL") ?? ""
        shutdownMethod = ShutdownMethod(rawValue: d.string(forKey: "shutdownMethod") ?? "") ?? .rogueHelperShutdown
        shutdownWebhookURL = d.string(forKey: "shutdownWebhookURL") ?? ""
        rawgAPIKey     = d.string(forKey: "rawgAPIKey") ?? ""
        steamGridDBKey = d.string(forKey: "steamGridDBKey") ?? ""
        igdbClientID = d.string(forKey: "igdbClientID") ?? ""
        igdbClientSecret = d.string(forKey: "igdbClientSecret") ?? ""
        youtubeAPIKey = d.string(forKey: "youtubeAPIKey") ?? ""
        sleepWebhookURL = d.string(forKey: "sleepWebhookURL") ?? ""
        sleepMethod = d.string(forKey: "sleepMethod") ?? "webhook"
        helperHost = d.string(forKey: "helperHost") ?? ""
        helperPort = d.string(forKey: "helperPort") ?? "9876"
        helperUser = d.string(forKey: "helperUser") ?? ""
        helperPassword = d.string(forKey: "helperPassword") ?? ""
        sunshineHost = d.string(forKey: "sunshineHost") ?? ""
        sunshinePort = d.string(forKey: "sunshinePort") ?? "47990"
        sunshineUser = d.string(forKey: "sunshineUser") ?? ""
        sunshinePassword = d.string(forKey: "sunshinePassword") ?? ""
        sunshineSteamAppName = d.string(forKey: "sunshineSteamAppName") ?? "Steam Big Picture"
        if let data = d.data(forKey: "gameLaunchers"),
           let launchers = try? JSONDecoder().decode([GameLauncherConfig].self, from: data) {
            // Fehlende Defaults ergänzen + Icon/Farbe immer aus Defaults übernehmen
            let existingIDs = Set(launchers.map(\.id))
            let missing = GameLauncherConfig.defaults.filter { !existingIDs.contains($0.id) }
            let defaultsByID = Dictionary(uniqueKeysWithValues: GameLauncherConfig.defaults.map { ($0.id, $0) })
            let updated = launchers.map { launcher -> GameLauncherConfig in
                var l = launcher
                if let def = defaultsByID[launcher.id] {
                    l.iconName  = def.iconName
                    l.colorHex  = def.colorHex
                }
                return l
            }
            gameLaunchers = updated + missing
        }
        craftyEnabled = d.bool(forKey: "craftyEnabled")
        craftyURL = d.string(forKey: "craftyURL") ?? ""
        craftyAPIKey = d.string(forKey: "craftyAPIKey") ?? ""
        if let data = d.data(forKey: "craftyServers"), let decoded = try? JSONDecoder().decode([CraftyServer].self, from: data) { craftyServers = decoded }
        nitradoEnabled = d.bool(forKey: "nitradoEnabled")
        nitradoAPIToken = d.string(forKey: "nitradoAPIToken") ?? ""
        if let data = d.data(forKey: "nitradoServers"), let decoded = try? JSONDecoder().decode([NitradoServer].self, from: data) { nitradoServers = decoded }
        backupPath = d.string(forKey: "backupPath") ?? ""
        nasURL = d.string(forKey: "nasURL") ?? ""
        nasCacheDir = d.string(forKey: "nasCacheDir") ?? ""
        epicClaimURL = d.string(forKey: "epicClaimURL") ?? ""
        epicClaimMode = d.string(forKey: "epicClaimMode") ?? "moonlight"
        epicClaimWebhookURL = d.string(forKey: "epicClaimWebhookURL") ?? ""
        epicFreeGamesEnabled = d.object(forKey: "epicFreeGamesEnabled") as? Bool ?? true
        consolesEnabled = d.object(forKey: "consolesEnabled") as? Bool ?? false
        emulatorsEnabled = d.object(forKey: "emulatorsEnabled") as? Bool ?? false
        retroArchPath = d.string(forKey: "retroArchPath") ?? "/opt/homebrew/bin/retroarch"
        if let map = d.object(forKey: "hdmiInputMap") as? [String: String] { hdmiInputMap = map }
        macInputNumber = d.integer(forKey: "macInputNumber") == 0 ? 15 : d.integer(forKey: "macInputNumber")
    }

    /// Sendet einen POST-Request an die angegebene URL (für HA-Webhooks)
    static func fireWebhook(_ urlString: String) {
        guard !urlString.isEmpty, let url = URL(string: urlString) else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = "{}".data(using: .utf8)
        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error = error {
                print("Webhook error: \(error.localizedDescription)")
            }
        }.resume()
    }

    func save() {
        let d = UserDefaults.standard
        d.set(pcIPAddress,  forKey: "pcIPAddress")
        d.set(pcMACAddress, forKey: "pcMACAddress")
        d.set(pcOS,         forKey: "pcOS")
        d.set(moonlightHostOverride, forKey: "moonlightHostOverride")
        d.set(moonlightPort, forKey: "moonlightPort")
        d.set(wakeMethod.rawValue, forKey: "wakeMethod")
        d.set(webhookURL,   forKey: "webhookURL")
        d.set(shutdownMethod.rawValue, forKey: "shutdownMethod")
        d.set(shutdownWebhookURL, forKey: "shutdownWebhookURL")
        d.set(rawgAPIKey,   forKey: "rawgAPIKey")
        d.set(steamGridDBKey, forKey: "steamGridDBKey")
        d.set(igdbClientID, forKey: "igdbClientID")
        d.set(igdbClientSecret, forKey: "igdbClientSecret")
        d.set(youtubeAPIKey, forKey: "youtubeAPIKey")
        d.set(sleepWebhookURL, forKey: "sleepWebhookURL")
        d.set(sleepMethod, forKey: "sleepMethod")
        d.set(helperHost, forKey: "helperHost")
        d.set(helperPort, forKey: "helperPort")
        d.set(helperUser, forKey: "helperUser")
        d.set(helperPassword, forKey: "helperPassword")
        d.set(sunshineHost, forKey: "sunshineHost")
        d.set(sunshinePort, forKey: "sunshinePort")
        d.set(sunshineUser, forKey: "sunshineUser")
        d.set(sunshinePassword, forKey: "sunshinePassword")
        d.set(sunshineSteamAppName, forKey: "sunshineSteamAppName")
        if let data = try? JSONEncoder().encode(gameLaunchers) {
            d.set(data, forKey: "gameLaunchers")
        }
        d.set(craftyEnabled, forKey: "craftyEnabled")
        d.set(craftyURL, forKey: "craftyURL")
        d.set(craftyAPIKey, forKey: "craftyAPIKey")
        if let data = try? JSONEncoder().encode(craftyServers) { d.set(data, forKey: "craftyServers") }
        d.set(nitradoEnabled, forKey: "nitradoEnabled")
        d.set(nitradoAPIToken, forKey: "nitradoAPIToken")
        if let data = try? JSONEncoder().encode(nitradoServers) { d.set(data, forKey: "nitradoServers") }
        d.set(backupPath, forKey: "backupPath")
        d.set(nasURL, forKey: "nasURL")
        d.set(nasCacheDir, forKey: "nasCacheDir")
        d.set(epicClaimURL, forKey: "epicClaimURL")
        d.set(epicClaimMode, forKey: "epicClaimMode")
        d.set(epicClaimWebhookURL, forKey: "epicClaimWebhookURL")
        d.set(epicFreeGamesEnabled, forKey: "epicFreeGamesEnabled")
        d.set(consolesEnabled, forKey: "consolesEnabled")
        d.set(emulatorsEnabled, forKey: "emulatorsEnabled")
        d.set(chatEnabledServices, forKey: "chatEnabledServices")
        d.set(chatServiceMode, forKey: "chatServiceMode")
        d.set(retroArchPath, forKey: "retroArchPath")
        d.set(hdmiInputMap, forKey: "hdmiInputMap")
        d.set(macInputNumber, forKey: "macInputNumber")
    }

    private func macFromData(_ value: Any?) -> String {
        guard let data = value as? Data, data.count == 6 else { return "" }
        return data.map { String(format: "%02X", $0) }.joined(separator: ":")
    }
}
