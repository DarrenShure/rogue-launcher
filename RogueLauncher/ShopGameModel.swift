import Foundation
import AppKit
import Combine

// MARK: - Key Normalization

private func normalizeGameKey(_ name: String) -> String {
    // Unicode normalisieren: Ü→U, é→e, etc.
    var s = name.folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
    s = s.lowercased()
    // Gedankenstriche/Bindestriche durch Leerzeichen ersetzen
    s = s.replacingOccurrences(of: "–", with: " ")
    s = s.replacingOccurrences(of: "—", with: " ")
    s = s.replacingOccurrences(of: "-", with: " ")
    // Satzzeichen entfernen
    let remove = CharacterSet.punctuationCharacters.union(.symbols).subtracting(CharacterSet(charactersIn: " "))
    s = s.components(separatedBy: remove).joined()
    // Mehrfache Leerzeichen
    while s.contains("  ") { s = s.replacingOccurrences(of: "  ", with: " ") }
    // Artikel am Anfang ignorieren
    for article in ["the ", "a ", "an ", "der ", "die ", "das "] {
        if s.hasPrefix(article) { s = String(s.dropFirst(article.count)) }
    }
    return s.trimmingCharacters(in: .whitespaces)
}

// MARK: - Unified Shop Game

struct ShopGame: Identifiable {
    let id: String          // normalized name as key
    let name: String
    var genre: String = ""
    var coverURL: String?
    var backgroundURL: String?
    var coverImagePath: String?

    // Verfügbare Quellen
    var steamAppID: Int?
    var nasGame: BackupGame?
    var epicAppID: String?

    var isInstalled: Bool   // mind. eine Quelle meldet installed
    var installedVia: String = ""  // "steam", "epic", "gog", "nas"

    // GOG source in ShopGame
    var gogAppID: String?

    var sources: [InstallSource] {
        var s: [InstallSource] = []
        if nasGame != nil          { s.append(.nas) }
        if let id = steamAppID     { s.append(.steam(appID: id)) }
        if let id = epicAppID      { s.append(.epic(appID: id)) }
        if let id = gogAppID       { s.append(.gog(appID: id)) }
        return s
    }

    var coverImageURL: URL? {
        if let p = coverImagePath { return URL(fileURLWithPath: p) }
        if let u = coverURL       { return URL(string: u) }
        if let id = steamAppID {
            return URL(string: "https://cdn.akamai.steamstatic.com/steam/apps/\(id)/library_600x900.jpg")
        }
        return nil
    }

    var bannerImageURL: URL? {
        // 1. IGDB Artwork (kuratiert, beste Qualität)
        if let u = backgroundURL { return URL(string: u) }
        // 2. Steam library_hero als Fallback
        if let id = steamAppID {
            return URL(string: "https://cdn.akamai.steamstatic.com/steam/apps/\(id)/library_hero.jpg")
        }
        return coverImageURL
    }

    enum InstallSource {
        case nas
        case steam(appID: Int)
        case epic(appID: String)
        case gog(appID: String)

        var label: String {
            switch self {
            case .nas:       return "NAS"
            case .steam:     return "Steam"
            case .epic:      return "Epic Games"
            case .gog:       return "GOG"
            }
        }
        var icon: String {
            switch self {
            case .nas:       return "internaldrive"
            case .steam:     return "gamecontroller.fill"
            case .epic:      return "gamecontroller.fill"
            case .gog:       return "gamecontroller.fill"
            }
        }
    }
}

// MARK: - Shop Store

class ShopStore: ObservableObject {
    static let shared = ShopStore()

    @Published var games: [ShopGame] = []
    @Published var isLoading = false
    @Published var genreUpdateCount = 0  // inkrementiert wenn Genres nachladen

    private var genreCache: [String: String] = [:]  // name → genre
    private var metaFetchQueue: Set<String> = []

    private init() {}

    // MARK: - Load

    func load() {
        guard !isLoading else { return }
        isLoading = true

        let nasPath = AppSettings.shared.backupPath

        if !nasPath.isEmpty {
            if !FileManager.default.fileExists(atPath: nasPath) {
                tryMount(path: nasPath)
            }
            BackupStore.shared.scan(path: nasPath)
            waitForScanAndLoad()
        } else {
            loadGames()
        }
    }

    private func waitForScanAndLoad() {
        if BackupStore.shared.isScanning {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
                self?.waitForScanAndLoad()
            }
        } else {
            loadGames()
        }
    }

    private func tryMount(path: String) {
        // /Volumes/sharename → versuche via `open` zu mounten
        // macOS mountet bekannte Shares automatisch wenn man auf den Pfad zugreift
        DispatchQueue.global(qos: .background).async {
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
            proc.arguments = [path]
            try? proc.run()
            proc.waitUntilExit()
        }
    }

    private func loadGames() {
        var map: [String: ShopGame] = [:]

        // 1) NAS
        for g in BackupStore.shared.games {
            let key = g.displayName.lowercased()
            var sg = ShopGame(id: key, name: g.displayName, isInstalled: false)
            sg.nasGame = g
            sg.coverImagePath = g.coverImagePath
            map[key] = sg
        }

        // 2) Steam via Helper
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/steam/library") else {
            finalize(map: map)
            return
        }

        HelperAPI.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { self.loadEpic(map: map); return }

            var m = map
            for dict in arr {
                let name = dict["name"] as? String ?? ""; guard !name.isEmpty else { continue }
                guard !self.isSteamSystemEntry(name) else { continue }
                guard !self.isDLC(name) else { continue }
                let key = normalizeGameKey(name)
                let appid: Int
                if let i = dict["appid"] as? Int { appid = i }
                else if let s = dict["appid"] as? String, let i = Int(s) { appid = i }
                else { continue }
                let installed: Bool
                if let b = dict["installed"] as? Bool { installed = b }
                else if let i = dict["installed"] as? Int { installed = i != 0 }
                else { installed = false }

                if var existing = m[key] {
                    existing.steamAppID = appid
                    if installed { existing.isInstalled = true; existing.installedVia = "steam" }
                    m[key] = existing
                } else {
                    var sg = ShopGame(id: key, name: name, isInstalled: installed)
                    sg.steamAppID = appid
                    if installed { sg.installedVia = "steam" }
                    m[key] = sg
                }
            }
            self.loadEpic(map: m)
        }.resume()
    }

    private func loadEpic(map: [String: ShopGame]) {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/epic/library") else {
            loadGOG(map: map); return
        }
        HelperAPI.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { self.loadGOG(map: map); return }

            var m = map
            for dict in arr {
                let name = dict["name"] as? String ?? ""; guard !name.isEmpty else { continue }
                let appid = dict["appid"] as? String ?? ""; guard !appid.isEmpty else { continue }
                guard !self.isDLC(name) else { continue }
                let installed: Bool
                if let b = dict["installed"] as? Bool { installed = b }
                else if let i = dict["installed"] as? Int { installed = i != 0 }
                else { installed = false }
                let key = normalizeGameKey(name)

                if var existing = m[key] {
                    existing.epicAppID = appid
                    if installed { existing.isInstalled = true; existing.installedVia = "epic" }
                    m[key] = existing
                } else {
                    var sg = ShopGame(id: key, name: name, isInstalled: installed)
                    sg.epicAppID = appid
                    if installed { sg.installedVia = "epic" }
                    m[key] = sg
                }
            }
            self.loadGOG(map: m)
        }.resume()
    }

    private func loadGOG(map: [String: ShopGame]) {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/gog/library") else {
            finalize(map: map); return
        }
        HelperAPI.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
            else { self.finalize(map: map); return }

            var m = map
            for dict in arr {
                let name = dict["name"] as? String ?? ""; guard !name.isEmpty else { continue }
                let appid = dict["appid"] as? String ?? ""; guard !appid.isEmpty else { continue }
                let installed: Bool
                if let b = dict["installed"] as? Bool { installed = b }
                else if let i = dict["installed"] as? Int { installed = i != 0 }
                else { installed = false }
                let key = normalizeGameKey(name)

                if var existing = m[key] {
                    existing.gogAppID = appid
                    if installed { existing.isInstalled = true; existing.installedVia = "gog" }
                    m[key] = existing
                } else {
                    var sg = ShopGame(id: key, name: name, isInstalled: installed)
                    sg.gogAppID = appid
                    if installed { sg.installedVia = "gog" }
                    m[key] = sg
                }
            }
            self.loadUbisoft(map: m)
        }.resume()
    }

    private func loadUbisoft(map: [String: ShopGame]) {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/sunshine/apps/scan?source=ubisoft") else {
            finalize(map: map); return
        }
        HelperAPI.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data else { self.finalize(map: map); return }
            let arr: [[String: Any]]
            if let a = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { arr = a }
            else if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let a = j["apps"] as? [[String: Any]] ?? j["games"] as? [[String: Any]] { arr = a }
            else { self.finalize(map: map); return }

            var m = map
            for dict in arr {
                let name = dict["name"] as? String ?? ""; guard !name.isEmpty else { continue }
                guard !self.isDLC(name) else { continue }
                let key = normalizeGameKey(name)
                if m[key] == nil {
                    var sg = ShopGame(id: key, name: name, isInstalled: true)
                    sg.installedVia = "ubisoft"
                    m[key] = sg
                } else if var existing = m[key] {
                    if !existing.isInstalled { existing.isInstalled = true; existing.installedVia = "ubisoft" }
                    m[key] = existing
                }
            }
            self.loadEA(map: m)
        }.resume()
    }

    private func loadLauncher(source: String, via: String, map: [String: ShopGame], next: @escaping ([String: ShopGame]) -> Void) {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/sunshine/apps/scan?source=\(source)") else {
            next(map); return
        }
        HelperAPI.shared.dataTask(with: req) { [weak self] data, _, _ in
            guard let self = self else { return }
            guard let data = data else { next(map); return }
            let arr: [[String: Any]]
            if let a = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { arr = a }
            else if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let a = j["apps"] as? [[String: Any]] ?? j["games"] as? [[String: Any]] { arr = a }
            else { next(map); return }
            var m = map
            for dict in arr {
                let name = dict["name"] as? String ?? ""; guard !name.isEmpty else { continue }
                guard !self.isDLC(name) else { continue }
                let installed = dict["installed"] as? Bool ?? true
                let key = normalizeGameKey(name)
                if m[key] == nil {
                    var sg = ShopGame(id: key, name: name, isInstalled: installed)
                    sg.installedVia = installed ? via : ""
                    m[key] = sg
                } else if var existing = m[key], installed, !existing.isInstalled {
                    existing.isInstalled = true; existing.installedVia = via
                    m[key] = existing
                }
            }
            next(m)
        }.resume()
    }

    private func loadEA(map: [String: ShopGame]) {
        loadLauncher(source: "ea", via: "ea", map: map) { [weak self] m in
            self?.loadAmazon(map: m)
        }
    }

    private func loadAmazon(map: [String: ShopGame]) {
        loadLauncher(source: "amazon", via: "amazon", map: map) { [weak self] m in
            self?.loadItchio(map: m)
        }
    }

    private func loadItchio(map: [String: ShopGame]) {
        loadLauncher(source: "itchio", via: "itchio", map: map) { [weak self] m in
            self?.finalize(map: m)
        }
    }

    private let steamSystemEntries: Set<String> = [
        "steamworks common redistributables", "steam linux runtime",
        "steamvr", "steam vr", "steam controller configs", "steam input",
        "directx", "physx", "dxsetup", "vcredist", "vc redist", "dotnet"
    ]

    private func isDLC(_ name: String) -> Bool {
        let n = name.lowercased()
        let dlcKeywords = [" - dlc", " dlc", " expansion", " season pass", " soundtrack",
                           " bundle", " pack", " content", " booster", " cosmetic",
                           " skin pack", " weapon pack", " map pack", " mission pack",
                           " upgrade", " bonus", ": dlc", "artbook", "art book",
                           "official soundtrack", "digital art", "digital book"]
        return dlcKeywords.contains { n.contains($0) }
    }

    private func isSteamSystemEntry(_ name: String) -> Bool {
        let n = name.lowercased()
        if steamSystemEntries.contains(where: { n.contains($0) }) { return true }
        if n.hasPrefix("proton") { return true }
        return false
    }

    private func finalize(map: [String: ShopGame]) {
        let all = map.values.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        DispatchQueue.main.async {
            self.games = all.filter { !$0.isInstalled }
            self.installedGames = all.filter { $0.isInstalled }
            self.isLoading = false
            self.fetchMissingGenres()
        }
    }

    // MARK: - Uninstall

    func uninstall(_ game: ShopGame, completion: @escaping (Bool, String) -> Void) {
        // Epic
        if game.installedVia == "epic", let appID = game.epicAppID {
            guard let req = HelperAPI.shared.request("/uninstall/epic", method: "POST",
                                                      body: ["app_name": appID]) else {
                completion(false, "Helper nicht erreichbar"); return
            }
            HelperAPI.shared.dataTask(with: req) { [weak self] _, resp, _ in
                DispatchQueue.main.async {
                    let ok = (resp as? HTTPURLResponse)?.statusCode == 200
                    if ok { self?.load() }
                    completion(ok, ok ? "✓ Deinstalliert" : "✗ Fehler")
                }
            }.resume()
            return
        }
        // GOG
        if game.installedVia == "gog", let appID = game.gogAppID {
            guard let req = HelperAPI.shared.request("/gog/uninstall", method: "POST",
                                                      body: ["app_name": appID]) else {
                completion(false, "Helper nicht erreichbar"); return
            }
            HelperAPI.shared.dataTask(with: req) { [weak self] _, resp, _ in
                DispatchQueue.main.async {
                    let ok = (resp as? HTTPURLResponse)?.statusCode == 200
                    if ok { self?.load() }
                    completion(ok, ok ? "✓ Deinstalliert" : "✗ Fehler")
                }
            }.resume()
            return
        }
        completion(false, "Kein unterstützter Store für Deinstallation")
    }

    // MARK: - Genre via IGDB

    private func fetchMissingGenres() {
        let needsMeta = games.filter {
            ($0.genre.isEmpty || $0.coverImagePath == nil && $0.coverURL == nil && $0.steamAppID == nil)
            && !metaFetchQueue.contains($0.id)
        }
        for game in needsMeta.prefix(150) {
            metaFetchQueue.insert(game.id)
            GameMetadataService.fetch(for: game.name) { [weak self] meta in
                guard let self = self, let meta = meta else { return }
                DispatchQueue.main.async {
                    if let i = self.games.firstIndex(where: { $0.id == game.id }) {
                        // Genre
                        if self.games[i].genre.isEmpty {
                            self.games[i].genre = normalizeGenre(meta.genre.split(separator: ",").first.map(String.init) ?? meta.genre)
                            self.genreUpdateCount += 1
                        }
                        // IGDB Artwork als Banner (besser als Steam library_hero)
                        if let bg = meta.backgroundURL, self.games[i].backgroundURL == nil {
                            self.games[i].backgroundURL = bg
                        }
                        // Cover direkt als URL setzen — kein lokaler Download nötig
                        if self.games[i].coverImagePath == nil,
                           self.games[i].coverURL == nil,
                           let url = meta.coverURL {
                            self.games[i].coverURL = url
                            self.genreUpdateCount += 1  // Trigger UI refresh
                        }
                    }
                }
            }
        }
    }

    private func fetchCover(url: String, for game: ShopGame) {
        GameMetadataService.downloadCover(from: url, for: game.name) { [weak self] path in
            guard let path = path, let self = self else { return }
            DispatchQueue.main.async {
                if let i = self.games.firstIndex(where: { $0.id == game.id }) {
                    self.games[i].coverImagePath = path
                }
            }
        }
    }

    // MARK: - Helpers

    var notInstalled: [ShopGame] { games.filter { !$0.isInstalled } }
    @Published var installedGames: [ShopGame] = []

    func gamesForGenre(_ genre: String) -> [ShopGame] {
        games.filter { normalizeGenre($0.genre) == genre }
    }

    var availableGenres: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for g in games {
            let genre = normalizeGenre(g.genre)
            if !genre.isEmpty && !seen.contains(genre) {
                seen.insert(genre)
                result.append(genre)
            }
        }
        return result.sorted()
    }
}
