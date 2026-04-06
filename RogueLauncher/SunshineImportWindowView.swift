import SwiftUI

// MARK: - Models

struct ScannedApp: Identifiable {
    let id = UUID()
    let name: String
    let source: String
    let command: String
    let raw: [String: Any]
}

struct SunshineConfigApp: Identifiable {
    let id: Int
    let name: String
    let command: String
}

// MARK: - Main View

struct SunshineImportWindowView: View {
    var store: GameStore? = nil
    @StateObject private var monitor = PCStatusMonitor.shared

    // Spalte 1: Host Apps
    @State private var selectedSource = "steam"
    @State private var searchHost = ""
    @State private var hostApps: [ScannedApp] = []
    @State private var selectedHostIDs = Set<UUID>()
    @State private var importQueue: [ScannedApp] = []
    @State private var importProgress: Double = 0
    @State private var importTotal: Int = 0
    @State private var isImporting = false
    @State private var isScanning = false

    // Spalte 2: Sunshine Apps
    @State private var sunshineApps: [SunshineConfigApp] = []
    @State private var selectedSunshineIDs = Set<Int>()
    @State private var isLoadingSunshine = false

    // Spalte 3: Moonlight Apps
    @State private var moonlightApps: [MoonlightApp] = []
    @State private var selectedMoonlightIDs = Set<UUID>()

    // Spalte 4: Launcher Games
    @State private var launcherGames: [Game] = []
    @State private var selectedLauncherIDs = Set<UUID>()

    // Status
    @State private var statusMessage = ""

    let sources: [(id: String, label: String)] = [
        ("ea",        "EA App"),
        ("epic",      "Epic Games"),
        ("gog",       "GOG"),
        ("heroic",    "Heroic Launcher"),
        ("launcher",  "Launcher"),
        ("linux",     "Linux (Dateisystem)"),
        ("local",     "Lokale Apps (Mac)"),
        ("registry",  "Registry"),
        ("steam",     "Steam"),
        ("ubisoft",   "Ubisoft Connect"),
        ("winstore",  "Windows Store"),
    ]

    var isConnected: Bool { monitor.status == .online }

    var filteredHostApps: [ScannedApp] {
        guard !searchHost.isEmpty else { return hostApps }
        return hostApps.filter { $0.name.localizedCaseInsensitiveContains(searchHost) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if selectedSource == "local" {
                HStack(spacing: 0) {
                    col1_HostApps
                    Divider()
                    col4_LauncherGames
                }
            } else if selectedSource == "winstore" {
                HStack(spacing: 0) {
                    col1_HostApps
                    Divider()
                    col4_LauncherGames
                }
            } else {
                HStack(spacing: 0) {
                    col1_HostApps
                    Divider()
                    col4_LauncherGames
                }
            }
            if !statusMessage.isEmpty {
                Divider()
                HStack {
                    Text(statusMessage)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 12).padding(.vertical, 5)
            }
        }
        .onAppear {
            if HelperAPI.shared.isConfigured {
                scanHostApps(); loadSunshineApps()
            } else {
                statusMessage = "⚠️ Rogue Helper nicht konfiguriert."
            }
            loadMoonlightApps(); loadLauncherGames()
        }
    }

    // MARK: - Toolbar

    var toolbar: some View {
        HStack(spacing: 10) {
            Text("Quelle:").font(.system(size: 13)).foregroundColor(.secondary)
            Picker("", selection: $selectedSource) {
                ForEach(sources, id: \.id) { Text($0.label).tag($0.id) }
            }
            .frame(width: 200)
            .onChange(of: selectedSource) { _, _ in scanHostApps() }
            TextField("Suche…", text: $searchHost)
                .textFieldStyle(.roundedBorder).frame(width: 160)
            Spacer()
            HStack(spacing: 6) {
                Circle().fill(isConnected ? Color.green : Color.gray).frame(width: 8, height: 8)
                Text(isConnected ? "Verbunden" : "Getrennt")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(isConnected ? .green : .secondary)
            }
            Button(action: { scanHostApps(); loadSunshineApps() }) {
                Label(isScanning || isLoadingSunshine ? "Lädt…" : "Aktualisieren",
                      systemImage: "arrow.clockwise").font(.system(size: 12))
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(isScanning || isLoadingSunshine)
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
    }

    // MARK: - Spalte 1: Host Apps

    var col1_HostApps: some View {
        VStack(spacing: 0) {
            colHeader("Host Apps", subtitle: sourceLabel(selectedSource))
            if isScanning {
                Spacer(); ProgressView("Suche…").padding(); Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(filteredHostApps) { app in
                            ImportGameRow(
                                app: app,
                                isInLauncher: launcherGames.contains {
                                    func norm(_ s: String) -> String {
                                        var r = s.lowercased()
                                        r = r.replacingOccurrences(of: "&", with: "and")
                                        r = r.replacingOccurrences(of: "_", with: " ")
                                        r = r.replacingOccurrences(of: ": ", with: " ")
                                        r = r.replacingOccurrences(of: " - ", with: " ")
                                        r = r.replacingOccurrences(of: "™", with: "")
                                        r = r.replacingOccurrences(of: "®", with: "")
                                        r = r.replacingOccurrences(of: "'", with: "")
                                        r = r.replacingOccurrences(of: ":", with: "")
                                        // Römische Zahlen normalisieren
                                        let romanMap = [" ii": " 2", " iii": " 3", " iv": " 4",
                                                        " vi": " 6", " vii": " 7", " viii": " 8", " ix": " 9"]
                                        for (roman, arabic) in romanMap { r = r.replacingOccurrences(of: roman, with: arabic) }
                                        // Launcher-Suffix entfernen (für Minecraft Launcher → Minecraft)
                                        let launcherSuffixes = [" launcher", " app", " client", " desktop", " connect"]
                                        for suffix in launcherSuffixes { if r.hasSuffix(suffix) { r = String(r.dropLast(suffix.count)) } }
                                        // Ziffern die direkt an Buchstaben hängen trennen: "dogs2" → "dogs 2"
                                        var result = ""
                                        for (i, c) in r.enumerated() {
                                            if c.isNumber, let prev = r.dropFirst(i).first.map({ _ in r[r.index(r.startIndex, offsetBy: i > 0 ? i-1 : 0)] }), prev.isLetter {
                                                result += " "
                                            }
                                            result.append(c)
                                        }
                                        return result.components(separatedBy: .whitespaces)
                                            .filter { !$0.isEmpty }.joined(separator: " ")
                                    }
                                    let appN = norm(app.name)
                                    let gameN = norm($0.name)
                                    if gameN == appN { return true }

                                    // Prefix-Check: nur matchen wenn der Suffix ausschließlich Edition-Wörter enthält
                                    let editionWords: Set<String> = ["edition", "definitive", "complete", "extended",
                                                                      "collection", "remastered", "deluxe", "goty",
                                                                      "anniversary", "ultimate", "gold", "platinum",
                                                                      "classic", "enhanced", "hd", "4k"]
                                    func isEditionOnlySuffix(_ suffix: String) -> Bool {
                                        let tokens = suffix.trimmingCharacters(in: .whitespaces)
                                            .components(separatedBy: .whitespaces)
                                            .filter { !$0.isEmpty }
                                        return !tokens.isEmpty && tokens.allSatisfy { editionWords.contains($0) }
                                    }

                                    // appN länger als gameN (z.B. Host="AC Complete Edition", Launcher="AC")
                                    if appN.hasPrefix(gameN + " ") {
                                        let suffix = String(appN.dropFirst(gameN.count + 1))
                                        if isEditionOnlySuffix(suffix) { return true }
                                    }
                                    // gameN länger als appN (z.B. Launcher="AC Complete Edition", Host="AC")
                                    if gameN.hasPrefix(appN + " ") {
                                        let suffix = String(gameN.dropFirst(appN.count + 1))
                                        if isEditionOnlySuffix(suffix) { return true }
                                    }
                                    // Wort-Set-Vergleich: exakt gleiche Kernwörter (inkl. kurze Tokens)
                                    let stopWords = Set(["the", "a", "an", "of", "and", "edition",
                                                         "definitive", "complete", "extended", "collection",
                                                         "remastered", "deluxe", "goty", "game", "year"])
                                    func keywords(_ s: String) -> Set<String> {
                                        Set(s.components(separatedBy: .whitespaces)
                                            .filter { !$0.isEmpty && !stopWords.contains($0) })
                                    }
                                    let appK = keywords(appN)
                                    let gameK = keywords(gameN)
                                    if appK.count >= 2 && appK == gameK { return true }
                                    return false
                                },
                                isSelected: selectedHostIDs.contains(app.id),
                                store: store,
                                onImport: {
                                    if selectedSource == "local" {
                                        if let store = store, !store.games.contains(where: { $0.name == app.name || $0.appName == app.name }) {
                                            store.games.append(Game(name: app.name, appName: app.command, type: .local))
                                            store.save()
                                            loadLauncherGames()
                                            statusMessage = "✓ \(app.name) hinzugefügt"
                                        }
                                    } else {
                                        importDirectToLauncher(app: app)
                                    }
                                },
                                onToggleSelect: {
                                    if selectedHostIDs.contains(app.id) {
                                        selectedHostIDs.remove(app.id)
                                    } else {
                                        selectedHostIDs.insert(app.id)
                                    }
                                }
                            )
                            Divider().padding(.leading, 12)
                        }
                    }
                }
            }
            Divider()
            HStack(spacing: 6) {
                Text("\(filteredHostApps.count) Apps")
                    .font(.system(size: 11)).foregroundColor(.secondary)
                Spacer()
                if isImporting {
                    HStack(spacing: 8) {
                        ProgressView(value: importProgress, total: Double(importTotal))
                            .frame(width: 120)
                        Text("\(Int(importProgress))/\(importTotal)")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                } else if !selectedHostIDs.isEmpty {
                    Button("\(selectedHostIDs.count) → Launcher") {
                        if selectedSource == "local" {
                            importLocalToLauncher()
                        } else {
                            let apps = filteredHostApps.filter { selectedHostIDs.contains($0.id) }
                            startImportQueue(apps: apps)
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(.green).controlSize(.small)
                }
            }.padding(8)
        }
    }

    // MARK: - Spalte 2: Sunshine (nur noch für Verwaltung)

    var col2_SunshineApps: some View {
        VStack(spacing: 0) {
            colHeader("Sunshine Apps", subtitle: "\(sunshineApps.count) Apps")
            if isLoadingSunshine {
                Spacer(); ProgressView("Lädt…").padding(); Spacer()
            } else {
                List(sunshineApps, id: \.id, selection: $selectedSunshineIDs) { app in
                    Text(app.name).font(.system(size: 12))
                }
            }
            Divider()
            HStack(spacing: 6) {
                Button("Löschen") { deleteSunshineApps() }
                    .buttonStyle(.bordered).tint(.red).controlSize(.small)
                    .disabled(selectedSunshineIDs.isEmpty || !isConnected)
                Spacer()
            }.padding(8)
        }
    }

    // MARK: - Spalte 3: Moonlight

    var col3_MoonlightApps: some View {
        VStack(spacing: 0) {
            colHeader("Moonlight Apps", subtitle: "\(moonlightApps.count) Apps")
            List(moonlightApps, id: \.id, selection: $selectedMoonlightIDs) { app in
                Text(app.name).font(.system(size: 12))
            }
            Divider()
            HStack(spacing: 6) {
                Button("Aktualisieren") { loadMoonlightApps() }
                    .buttonStyle(.bordered).controlSize(.small)
                Button("Löschen") { deleteMoonlightApps() }
                    .buttonStyle(.bordered).tint(.red).controlSize(.small)
                    .disabled(selectedMoonlightIDs.isEmpty || !isConnected)
                Spacer()
            }.padding(8)
        }
    }

    // MARK: - Spalte 4: Launcher

    var col4_LauncherGames: some View {
        VStack(spacing: 0) {
            colHeader("Launcher", subtitle: "\(launcherGames.count) Spiele")
            List(launcherGames, id: \.id, selection: $selectedLauncherIDs) { game in
                Text(game.name).font(.system(size: 12))
            }
            Divider()
            HStack(spacing: 6) {
                Button("Entfernen") { removeLauncherGames() }
                    .buttonStyle(.bordered).tint(.red).controlSize(.small)
                    .disabled(selectedLauncherIDs.isEmpty)
                Spacer()
            }.padding(8)
        }
    }

    // MARK: - Import Queue

    private func startImportQueue(apps: [ScannedApp]) {
        guard !apps.isEmpty, !isImporting else { return }
        importQueue = apps
        importTotal = apps.count
        importProgress = 0
        isImporting = true
        selectedHostIDs = []
        processNextInQueue()
    }

    private func processNextInQueue() {
        guard !importQueue.isEmpty else {
            isImporting = false
            statusMessage = "✓ \(importTotal) Spiel(e) importiert"
            loadSunshineApps()
            loadLauncherGames()
            return
        }
        let app = importQueue.removeFirst()
        importDirectToLauncher(app: app) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                self.importProgress += 1
                self.processNextInQueue()
            }
        }
    }

    // MARK: - Direktimport: Host → Sunshine + Launcher in einem Schritt

    private func importDirectToLauncher(app: ScannedApp, completion: (() -> Void)? = nil) {
        guard isConnected else { completion?(); return }
        var d: [String: Any] = ["name": app.name, "cmd": app.command]
        if let wd = app.raw["working_dir"] as? String, !wd.isEmpty { d["working_dir"] = wd }
        if let ip = app.raw["image_path"] as? String, !ip.isEmpty, !ip.lowercased().hasSuffix(".ico") { d["image_path"] = ip }
        guard let url = URL(string: "\(HelperAPI.shared.baseURL)/sunshine/apps/add-batch"),
              let httpBody = try? JSONSerialization.data(withJSONObject: ["apps": [d]]) else {
            completion?(); return
        }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"; req.httpBody = httpBody
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let s = AppSettings.shared
        if !s.helperUser.isEmpty, let creds = "\(s.helperUser):\(s.helperPassword)".data(using: .utf8) {
            req.setValue("Basic \(creds.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        HelperAPI.shared.dataTask(with: req) { [self] _, _, _ in
            DispatchQueue.main.async {
                let launcherOnly = ["steam", "steam big picture", "epic games launcher",
                                    "gog galaxy", "galaxyclient", "ea app", "ea desktop", "origin",
                                    "ubisoft connect", "uplay", "battle.net", "battlenet",
                                    "gogdl", "legendary", "steamwebhelper"]
                let nameLower = app.name.lowercased()
                let isLauncher = launcherOnly.contains { nameLower.contains($0) }

                if !isLauncher, let store = store,
                   !store.games.contains(where: { $0.name == app.name || $0.appName == app.name }) {
                    store.games.append(Game(name: app.name, appName: app.name, type: .moonlight))
                    store.save()
                }
                if completion == nil {
                    // Einzelimport: sofort UI aktualisieren
                    loadLauncherGames()
                    statusMessage = "✓ \(app.name) hinzugefügt"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadSunshineApps() }
                }
                completion?()
            }
        }.resume()
    }

    // MARK: - Header Helper

    private func colHeader(_ title: String, subtitle: String) -> some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title).font(.system(size: 13, weight: .semibold))
                    Text(subtitle).font(.system(size: 10)).foregroundColor(.secondary)
                }
                Spacer()
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            Divider()
        }
    }

    private func sourceLabel(_ id: String) -> String {
        sources.first { $0.id == id }?.label ?? id
    }

    struct MoonlightApp: Identifiable {
        let id = UUID()
        let name: String
        let appID: Int
    }

    // MARK: - Actions

    private func deleteMoonlightApps() {
        // Moonlight-Apps sind Sunshine-Apps — in Sunshine löschen
        let names = moonlightApps.filter { selectedMoonlightIDs.contains($0.id) }.map { $0.name }
        let idsToDelete = sunshineApps.filter { names.contains($0.name) }.map { $0.id }
        guard !idsToDelete.isEmpty,
              let url = URL(string: "\(HelperAPI.shared.baseURL)/sunshine/apps/delete-batch"),
              let httpBody = try? JSONSerialization.data(withJSONObject: ["ids": idsToDelete]) else {
            statusMessage = "⚠️ Apps nicht in Sunshine gefunden."
            return
        }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"; req.httpBody = httpBody
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let s = AppSettings.shared
        if !s.helperUser.isEmpty, let creds = "\(s.helperUser):\(s.helperPassword)".data(using: .utf8) {
            req.setValue("Basic \(creds.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        HelperAPI.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                selectedMoonlightIDs = []
                statusMessage = "\(idsToDelete.count) App(s) aus Sunshine/Moonlight gelöscht."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    loadSunshineApps()
                    loadMoonlightApps()
                }
            }
        }.resume()
    }

    private func importLocalToLauncher() {
        guard let store = store else { statusMessage = "⚠️ Store nicht verfügbar."; return }
        let toImport = filteredHostApps.filter { selectedHostIDs.contains($0.id) }
        for app in toImport {
            if !store.games.contains(where: { $0.name == app.name || $0.appName == app.name }) {
                let game = Game(name: app.name, appName: app.command, type: .local)
                store.games.append(game)
            }
        }
        store.save()
        statusMessage = "✓ \(toImport.count) App(s) zum Launcher hinzugefügt."
        selectedHostIDs = []
        loadLauncherGames()
    }

    private func importHostToSunshine() {
        let toImport = filteredHostApps.filter { selectedHostIDs.contains($0.id) }
        guard !toImport.isEmpty else { return }
        let body = toImport.map { app -> [String: Any] in
            var d: [String: Any] = ["name": app.name, "cmd": app.command]
            if let wd = app.raw["working_dir"] as? String, !wd.isEmpty { d["working_dir"] = wd }
            if let ip = app.raw["image_path"] as? String, !ip.isEmpty, !ip.lowercased().hasSuffix(".ico") { d["image_path"] = ip }
            return d
        }
        guard let url = URL(string: "\(HelperAPI.shared.baseURL)/sunshine/apps/add-batch"),
              let httpBody = try? JSONSerialization.data(withJSONObject: ["apps": body]) else { return }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = "POST"; req.httpBody = httpBody
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let s = AppSettings.shared
        if !s.helperUser.isEmpty, let creds = "\(s.helperUser):\(s.helperPassword)".data(using: .utf8) {
            req.setValue("Basic \(creds.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        statusMessage = "Importiere \(toImport.count) App(s) nach Sunshine…"
        HelperAPI.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                if let error = error { statusMessage = "⚠️ \(error.localizedDescription)"; return }
                let added = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })?["added"] as? Int ?? toImport.count
                statusMessage = "✓ \(added) App(s) zu Sunshine hinzugefügt."
                selectedHostIDs = []
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadSunshineApps() }
            }
        }.resume()
    }

    private func importSunshineToMoonlight() {
        statusMessage = "Moonlight synchronisiert Apps automatisch von Sunshine."
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { loadMoonlightApps() }
    }

    private func importMoonlightToLauncher() {
        guard let store = store else { statusMessage = "⚠️ Store nicht verfügbar."; return }
        let toImport = moonlightApps.filter { selectedMoonlightIDs.contains($0.id) }
        for app in toImport {
            if !store.games.contains(where: { $0.name == app.name || $0.appName == app.name }) {
                let game = Game(name: app.name, appName: app.name, type: .moonlight)
                store.games.append(game)
            }
        }
        store.save()
        statusMessage = "✓ \(toImport.count) Spiel(e) zum Launcher hinzugefügt."
        selectedMoonlightIDs = []
        loadLauncherGames()
    }

    private func removeLauncherGames() {
        guard let store = store else { return }
        let names = launcherGames.filter { selectedLauncherIDs.contains($0.id) }.map { $0.name }
        store.games.removeAll { names.contains($0.name) }
        store.save()
        selectedLauncherIDs = []
        loadLauncherGames()
    }

    private func deleteSunshineApps() {
        let ids = Array(selectedSunshineIDs)
        guard !ids.isEmpty,
              let url = URL(string: "\(HelperAPI.shared.baseURL)/sunshine/apps/delete-batch"),
              let httpBody = try? JSONSerialization.data(withJSONObject: ["ids": ids]) else { return }
        var req = URLRequest(url: url, timeoutInterval: 15)
        req.httpMethod = "POST"; req.httpBody = httpBody
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let s = AppSettings.shared
        if !s.helperUser.isEmpty, let creds = "\(s.helperUser):\(s.helperPassword)".data(using: .utf8) {
            req.setValue("Basic \(creds.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        HelperAPI.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async {
                selectedSunshineIDs = []
                statusMessage = "\(ids.count) App(s) aus Sunshine gelöscht."
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) { loadSunshineApps() }
            }
        }.resume()
    }

    // MARK: - Load

    private func scanHostApps() {
        guard selectedSource != "local" else {
            hostApps = scanLocalMacApps(); return
        }
        guard selectedSource != "launcher" else {
            guard HelperAPI.shared.isConfigured,
                  let req = HelperAPI.shared.request("/launchers") else { return }
            isScanning = true; hostApps = []; selectedHostIDs = []
            HelperAPI.shared.dataTask(with: req) { data, _, _ in
                DispatchQueue.main.async {
                    isScanning = false
                    guard let data = data,
                          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                    else { return }
                    hostApps = arr.compactMap { dict in
                        guard let name = dict["name"] as? String,
                              let cmd  = dict["cmd"]  as? String,
                              !cmd.isEmpty,
                              dict["installed"] as? Bool == true else { return nil }
                        return ScannedApp(name: name, source: "launcher", command: cmd, raw: dict)
                    }
                    statusMessage = "\(hostApps.count) Launcher gefunden."
                }
            }.resume()
            return
        }
        guard selectedSource != "winstore" else {
            guard HelperAPI.shared.isConfigured,
                  let req = HelperAPI.shared.request("/windows-store/apps") else { return }
            isScanning = true; hostApps = []; selectedHostIDs = []
            HelperAPI.shared.dataTask(with: req) { data, _, _ in
                DispatchQueue.main.async {
                    isScanning = false
                    guard let data = data,
                          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                    else { return }
                    hostApps = arr.compactMap { dict in
                        guard let name = dict["name"] as? String,
                              let launch = dict["launch_cmd"] as? String else { return nil }
                        let pfn = dict["package_family_name"] as? String ?? ""
                        return ScannedApp(name: name, source: "winstore", command: launch, raw: ["package_family_name": pfn])
                    }
                    statusMessage = "\(hostApps.count) Apps gefunden."
                }
            }.resume()
            return
        }
        guard selectedSource != "linux" else {
            guard HelperAPI.shared.isConfigured,
                  let req = HelperAPI.shared.request("/linux/library") else { return }
            isScanning = true; hostApps = []; selectedHostIDs = []
            HelperAPI.shared.dataTask(with: req) { data, _, _ in
                DispatchQueue.main.async {
                    isScanning = false
                    guard let data = data,
                          let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                    else { return }
                    hostApps = arr.compactMap { dict in
                        guard let name = dict["name"] as? String,
                              let cmd  = dict["cmd"]  as? String else { return nil }
                        return ScannedApp(name: name, source: "linux", command: cmd, raw: dict)
                    }
                    statusMessage = "\(hostApps.count) Linux-Apps gefunden."
                }
            }.resume()
            return
        }
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/sunshine/apps/scan?source=\(selectedSource)") else { return }
        isScanning = true; hostApps = []; selectedHostIDs = []
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isScanning = false
                guard let data = data else { return }
                let arr: [[String: Any]]
                if let a = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { arr = a }
                else if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let a = j["apps"] as? [[String: Any]] ?? j["games"] as? [[String: Any]] { arr = a }
                else { statusMessage = "⚠️ Format unbekannt."; return }
                hostApps = arr.map { dict in
                    var cmd = dict["cmd"] as? String ?? dict["exe"] as? String ?? dict["command"] as? String ?? ""
                    // Extra-Anführungszeichen entfernen die der Helper manchmal hinzufügt
                    cmd = cmd.trimmingCharacters(in: CharacterSet(charactersIn: "'\""))
                    return ScannedApp(
                        name: dict["name"] as? String ?? "?",
                        source: dict["source"] as? String ?? selectedSource,
                        command: cmd,
                        raw: dict
                    )
                }
                statusMessage = "\(hostApps.count) Einträge geladen."
            }
        }.resume()
    }

    private func scanLocalMacApps() -> [ScannedApp] {
        let dirs = ["/Applications", NSHomeDirectory() + "/Applications"]
        var apps: [ScannedApp] = []
        for dir in dirs {
            let urls = (try? FileManager.default.contentsOfDirectory(
                at: URL(fileURLWithPath: dir), includingPropertiesForKeys: nil)) ?? []
            for url in urls where url.pathExtension == "app" {
                let name = url.deletingPathExtension().lastPathComponent
                apps.append(ScannedApp(name: name, source: "local", command: url.path, raw: [:]))
            }
        }
        return apps.sorted { $0.name < $1.name }
    }

    private func loadSunshineApps() {
        guard HelperAPI.shared.isConfigured, let req = HelperAPI.shared.request("/sunshine/apps") else { return }
        isLoadingSunshine = true
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isLoadingSunshine = false
                guard let data = data else { return }
                let arr: [[String: Any]]
                if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let a = j["apps"] as? [[String: Any]] { arr = a }
                else if let a = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { arr = a }
                else { return }
                sunshineApps = arr.compactMap { dict in
                    let rawId: Int
                    if let i = dict["id"] as? Int { rawId = i }
                    else if let s = dict["id"] as? String, let i = Int(s) { rawId = i }
                    else { rawId = abs((dict["name"] as? String ?? "").hashValue) }
                    let name = dict["title"] as? String ?? dict["name"] as? String ?? "?"
                    let cmd  = dict["cmd"] as? String ?? dict["command"] as? String ?? ""
                    return SunshineConfigApp(id: rawId, name: name, command: cmd)
                }
            }
        }.resume()
    }

    private func loadMoonlightApps() {
        let plist = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
        guard let dict = NSDictionary(contentsOfFile: plist) as? [String: Any] else {
            moonlightApps = sunshineApps.map { MoonlightApp(name: $0.name, appID: $0.id) }
            return
        }
        var apps: [MoonlightApp] = []
        var i = 1
        while let name = dict["hosts.1.apps.\(i).name"] as? String {
            let appID = dict["hosts.1.apps.\(i).id"] as? Int ?? i
            apps.append(MoonlightApp(name: name, appID: appID))
            i += 1
        }
        moonlightApps = apps.sorted { $0.name < $1.name }
    }

    private func loadLauncherGames() {
        launcherGames = (store?.games ?? [])
            .filter { $0.type == .moonlight || $0.type == .local }
            .sorted { $0.name < $1.name }
    }
}

// MARK: - Windows Store Import View

struct WindowsStoreApp: Identifiable {
    let id: String
    let name: String
    let packageFamilyName: String
    let launchCmd: String
}

struct WindowsStoreImportView: View {
    var store: GameStore?
    @State private var apps: [WindowsStoreApp] = []
    @State private var isLoading = false
    @State private var statusMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Installierte Windows Store Apps")
                    .font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary)
                Spacer()
                Button(action: loadApps) {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11))
                }.buttonStyle(.plain).foregroundColor(.secondary)
            }
            .padding(.horizontal, 12).padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            if isLoading {
                VStack { ProgressView().frame(width: 20, height: 20) }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if apps.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "storefront").font(.system(size: 30)).foregroundColor(.secondary)
                    Text("Keine Windows Store Apps gefunden")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                    Text("Stelle sicher dass der Rogue Helper aktuell ist.")
                        .font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
                    Button("Erneut suchen") { loadApps() }.buttonStyle(.bordered).controlSize(.small)
                }
                .padding(20).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(apps) { app in
                            let alreadyIn = (store?.games ?? []).contains {
                                $0.name.localizedCaseInsensitiveCompare(app.name) == .orderedSame ||
                                $0.appName == app.launchCmd
                            }
                            HStack(spacing: 10) {
                                Image(systemName: alreadyIn ? "checkmark.circle.fill" : "circle")
                                    .foregroundColor(alreadyIn ? .green : .secondary)
                                    .font(.system(size: 13))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(app.name).font(.system(size: 13))
                                        .foregroundColor(alreadyIn ? .secondary : .primary)
                                    Text(app.packageFamilyName)
                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                }
                                Spacer()
                                if !alreadyIn {
                                    Button(action: { importApp(app) }) {
                                        Label("Importieren", systemImage: "plus.circle.fill")
                                            .font(.system(size: 11))
                                    }
                                    .buttonStyle(.bordered).controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 12).padding(.vertical, 8)
                            Divider()
                        }
                    }
                }
            }

            if !statusMessage.isEmpty {
                Divider()
                Text(statusMessage)
                    .font(.system(size: 11)).foregroundColor(.secondary)
                    .padding(8)
            }
        }
        .onAppear { loadApps() }
    }

    private func loadApps() {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/windows-store/apps") else { return }
        isLoading = true; apps = []
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data,
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                else { return }
                apps = arr.compactMap { dict in
                    guard let name = dict["name"] as? String,
                          let pfn = dict["package_family_name"] as? String else { return nil }
                    let launch = dict["launch_cmd"] as? String ?? "shell:AppsFolder\\\(pfn)!App"
                    return WindowsStoreApp(id: pfn, name: name, packageFamilyName: pfn, launchCmd: launch)
                }.sorted { $0.name < $1.name }
            }
        }.resume()
    }

    private func importApp(_ app: WindowsStoreApp) {
        // Zu Sunshine hinzufügen
        let body: [String: Any] = ["name": app.name, "cmd": app.launchCmd]
        if HelperAPI.shared.isConfigured,
           let req = HelperAPI.shared.request("/sunshine/apps/add", method: "POST", body: body) {
            HelperAPI.shared.dataTask(with: req) { _, _, _ in }.resume()
        }
        // Zum Launcher hinzufügen
        guard let store = store else { return }
        if !store.games.contains(where: { $0.name == app.name || $0.appName == app.launchCmd }) {
            let game = Game(name: app.name, appName: app.launchCmd, type: .moonlight)
            store.games.append(game)
            store.save()
        }
        statusMessage = "✓ \(app.name) importiert"
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { statusMessage = "" }
    }
}

// MARK: - Import Game Row

struct ImportGameRow: View {
    let app: ScannedApp
    let isInLauncher: Bool
    let isSelected: Bool
    let store: GameStore?
    let onImport: () -> Void
    let onToggleSelect: () -> Void

    @State private var showEdit = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: isInLauncher ? "checkmark.circle.fill" : (isSelected ? "checkmark.circle.fill" : "circle"))
                .foregroundColor(isInLauncher ? .green : (isSelected ? .rogueRed : .secondary))
                .font(.system(size: 13))

            Text(app.name)
                .font(.system(size: 12))
                .foregroundColor(isInLauncher ? .secondary : .primary)

            Spacer()

            if !isInLauncher {
                Button(action: { showEdit = true }) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.green)
                }
                .buttonStyle(.plain)
                .help("Zu Launcher hinzufügen")
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .contentShape(Rectangle())
        .background(isSelected ? Color.rogueRed.opacity(0.08) : Color.clear)
        .onTapGesture { if !isInLauncher { onToggleSelect() } }
        .sheet(isPresented: $showEdit) {
            if let store {
                let isLocal = app.source == "local"
                let prefilledGame = Game(
                    name: app.name,
                    appName: isLocal ? app.command : app.name,
                    type: isLocal ? .local : .moonlight
                )
                GameEditView(store: store, game: nil, prefill: prefilledGame) {
                    onImport()
                    showEdit = false
                }
            }
        }
    }
}
