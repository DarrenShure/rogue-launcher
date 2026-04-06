import SwiftUI

struct AllGamesListView: View {
    @ObservedObject var shopStore: ShopStore
    @ObservedObject private var backupStore = BackupStore.shared
    var onBack: (() -> Void)? = nil

    @State private var searchText = ""
    @State private var scrollTarget: String? = nil
    @State private var showInstalled = false
    @State private var showDLC = false

    var grouped: [(letter: String, games: [ShopGame])] {
        let launcherNames = ["epic games launcher", "gog galaxy", "galaxyclient", "ea app",
                             "ea desktop", "origin", "ubisoft connect", "uplay", "battle.net",
                             "amazon games", "itch.io", "rockstar games launcher",
                             "minecraft launcher", "steam big picture"]
        var filtered = searchText.isEmpty
            ? shopStore.notInstalled
            : shopStore.notInstalled.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
        filtered = filtered.filter { g in
            let nl = g.name.lowercased()
            return !launcherNames.contains(where: { nl.contains($0) })
        }

        if !showDLC {
            filtered = filtered.filter { !isDLCName($0.name) }
        }

        var dict: [String: [ShopGame]] = [:]
        for g in filtered {
            let ch = String(g.name.prefix(1)).uppercased()
            let key = ch.first?.isLetter == true ? ch : "#"
            dict[key, default: []].append(g)
        }
        return dict.map { (letter: $0.key, games: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.letter < $1.letter }
    }

    private func isDLCName(_ name: String) -> Bool {
        let n = name.lowercased()
        // GOG-interne DLC-IDs (dlc_11_a, dlc_6_a etc.)
        if n.hasPrefix("dlc_") { return true }
        let keywords = [" - dlc", " dlc", " expansion", " season pass", " soundtrack",
                        " bundle", " pack", " content", " booster", " cosmetic",
                        " skin pack", " weapon pack", " map pack", " mission pack",
                        " upgrade", " bonus", ": dlc", "artbook", "art book",
                        "official soundtrack", "digital art", "digital book"]
        return keywords.contains { n.contains($0) }
    }

    var letters: [String] { grouped.map { $0.letter } }

    var body: some View {
        HStack(spacing: 0) {
            // Main list
            VStack(spacing: 0) {
                // Header
                HStack(spacing: 12) {
                    Text("Alle Spiele")
                        .font(.system(size: 16, weight: .bold))

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "magnifyingglass")
                            .foregroundColor(.secondary)
                            .font(.system(size: 12))
                        TextField("Suche…", text: $searchText)
                            .textFieldStyle(.plain)
                            .font(.system(size: 13))
                    }
                    .padding(.horizontal, 10).padding(.vertical, 7)
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .frame(width: 200)

                    // Installiert/Nicht installiert Toggle
                    HStack(spacing: 6) {
                        Button(action: { showInstalled = false }) {
                            Text("Nicht installiert")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .tint(showInstalled ? .secondary : .rogueRed)

                        Button(action: { showInstalled = true }) {
                            Text("Installiert (\(shopStore.installedGames.count))")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.regular)
                        .tint(showInstalled ? .rogueRed : .secondary)

                        if !showInstalled {
                            Button(action: { showDLC.toggle() }) {
                                Text(showDLC ? "DLCs ausblenden" : "DLCs einblenden")
                                    .font(.system(size: 11))
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.regular)
                            .tint(.secondary)
                        }
                    }

                    Text("\(showInstalled ? shopStore.installedGames.count : grouped.flatMap { $0.games }.count) Spiele")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 16).padding(.vertical, 10)

                Divider()

                if showInstalled {
                    InstalledGamesListView(shopStore: shopStore)
                } else if shopStore.isLoading {
                    VStack { ProgressView("Lädt…") }.frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if grouped.isEmpty {
                    VStack(spacing: 12) {
                        Spacer()
                        Image(systemName: "wifi.slash").font(.system(size: 36)).foregroundColor(.secondary)
                        Text("Keine Verbindung zum Helper").font(.system(size: 15)).foregroundColor(.secondary)
                        Text("Bitte sicherstellen dass der Windows Helper läuft.")
                            .font(.system(size: 12)).foregroundColor(.secondary)
                        Button("Neu laden") { shopStore.load() }.buttonStyle(.bordered)
                        Spacer()
                    }.frame(maxWidth: .infinity)
                } else {

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 0, pinnedViews: [.sectionHeaders]) {
                            ForEach(grouped, id: \.letter) { group in
                                Section {
                                    ForEach(group.games) { game in
                                        GameListRow(game: game)
                                        Divider().padding(.leading, 60)
                                    }
                                } header: {
                                    Text(group.letter)
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 16)
                                        .padding(.vertical, 4)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                                        .id(group.letter)
                                }
                            }
                        }
                    }
                    .onChange(of: scrollTarget) { _, target in
                        if let t = target {
                            withAnimation { proxy.scrollTo(t, anchor: .top) }
                            scrollTarget = nil
                        }
                    }
                }
                } // end else (not installed)

                // NAS Kopier-Fortschritt
                if backupStore.isCopying || backupStore.isInstalling != nil {
                    VStack(spacing: 0) {
                        Divider()
                        HStack(spacing: 12) {
                            Image(systemName: "internaldrive")
                                .foregroundColor(.rogueRed)
                                .font(.system(size: 14))
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    Text(backupStore.isCopying ? "Kopiere vom NAS…" : backupStore.installProgress)
                                        .font(.system(size: 12, weight: .medium))
                                    Spacer()
                                    if backupStore.isCopying {
                                        Text("\(Int(backupStore.copyProgress * 100))%")
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(.rogueRed)
                                    }
                                }
                                if backupStore.isCopying {
                                    ProgressView(value: backupStore.copyProgress)
                                        .progressViewStyle(.linear)
                                        .tint(.rogueRed)
                                } else {
                                    ProgressView()
                                        .progressViewStyle(.linear)
                                        .tint(.rogueRed)
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }

            // Jump list
            Divider()
            VStack(spacing: 2) {
                ForEach(letters, id: \.self) { letter in
                    Button(action: { scrollTarget = letter }) {
                        Text(letter)
                            .font(.system(size: 10, weight: .medium))
                            .foregroundColor(.rogueRed)
                            .frame(width: 20, height: 16)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .frame(width: 28)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
}

// MARK: - Game List Row

struct GameListRow: View {
    let game: ShopGame

    var body: some View {
        HStack(spacing: 12) {
            // Name
            Text(game.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)

            Spacer()

            // Sources
            HStack(spacing: 4) {
                ForEach(game.sources.indices, id: \.self) { i in
                    let src = game.sources[i]
                    Label(src.label, systemImage: src.icon)
                        .font(.system(size: 10))
                        .padding(.horizontal, 7).padding(.vertical, 3)
                        .background(Color.rogueRed.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .foregroundColor(.rogueRed)
                }
            }

            // Install Button
            InstallButton(game: game, large: false)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .contentShape(Rectangle())
    }
}

// MARK: - Installed Games List

struct InstalledGamesListView: View {
    @ObservedObject var shopStore: ShopStore

    var grouped: [(letter: String, games: [ShopGame])] {
        let launcherNames = ["epic games launcher", "gog galaxy", "galaxyclient", "ea app",
                             "ea desktop", "origin", "ubisoft connect", "uplay", "battle.net",
                             "amazon games", "itch.io", "rockstar games launcher",
                             "minecraft launcher", "steam big picture"]
        var dict: [String: [ShopGame]] = [:]
        for g in shopStore.installedGames {
            let nl = g.name.lowercased()
            guard !launcherNames.contains(where: { nl.contains($0) }) else { continue }
            let ch = String(g.name.prefix(1)).uppercased()
            let key = ch.first?.isLetter == true ? ch : "#"
            dict[key, default: []].append(g)
        }
        return dict.map { (letter: $0.key, games: $0.value.sorted { $0.name < $1.name }) }
            .sorted { $0.letter < $1.letter }
    }

    var letters: [String] { grouped.map { $0.letter } }

    var body: some View {
        HStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                        ForEach(grouped, id: \.letter) { section in
                            Section {
                                ForEach(section.games) { game in
                                    InstalledGameRow(game: game)
                                    Divider().padding(.leading, 16)
                                }
                            } header: {
                                Text(section.letter)
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.secondary)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 4)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                                    .id(section.letter)
                            }
                        }
                    }
                }
            }

            // Jump list
            Divider()
            VStack(spacing: 2) {
                ForEach(letters, id: \.self) { letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.rogueRed)
                        .frame(width: 20, height: 16)
                }
                Spacer()
            }
            .padding(.vertical, 8)
            .frame(width: 28)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
        }
    }
}

struct InstalledGameRow: View {
    let game: ShopGame
    @State private var showConfirm = false

    var canUninstall: Bool {
        ["epic", "gog", "steam", "ubisoft", "ea", "amazon", "itchio", "battlenet"].contains(game.installedVia)
    }

    var storeLabel: String {
        switch game.installedVia {
        case "epic":     return "Epic Games"
        case "gog":      return "GOG"
        case "steam":    return "Steam"
        case "ubisoft":  return "Ubisoft"
        case "ea":       return "EA App"
        case "amazon":   return "Amazon"
        case "itchio":   return "itch.io"
        case "battlenet":return "Battle.net"
        case "nas":      return "NAS"
        default:         return ""
        }
    }

    var storeIcon: String {
        switch game.installedVia {
        case "nas":   return "internaldrive"
        default:      return "gamecontroller"
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Text(game.name)
                .font(.system(size: 14, weight: .medium))
                .lineLimit(1)

            Spacer()

            // Source chip
            if !storeLabel.isEmpty {
                Label(storeLabel, systemImage: storeIcon)
                    .font(.system(size: 10))
                    .padding(.horizontal, 7).padding(.vertical, 3)
                    .background(Color.rogueRed.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .foregroundColor(.rogueRed)
            }

            // Deinstallieren Button
            if canUninstall {
                Button(action: { showConfirm = true }) {
                    Label("Deinstallieren", systemImage: "trash.circle.fill")
                        .font(.system(size: 11, weight: .semibold))
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.red.opacity(0.15))
                        .foregroundColor(.red)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 8)
        .contentShape(Rectangle())
        .confirmationDialog("Deinstallieren?", isPresented: $showConfirm, titleVisibility: .visible) {
            Button("Deinstallieren", role: .destructive) { doUninstall() }
            Button("Abbrechen", role: .cancel) {}
        } message: {
            Text("Der jeweilige Launcher wird geöffnet um \(game.name) zu deinstallieren.")
        }
    }

    private func doUninstall() {
        switch game.installedVia {
        case "steam":
            if let appID = game.steamAppID,
               let req = HelperAPI.shared.request("/steam/uninstall", method: "POST", body: ["appid": appID]) {
                HelperAPI.shared.dataTask(with: req) { _, _, _ in
                    DispatchQueue.main.async { openLauncherWindowed("steam") }
                }.resume()
            } else {
                openLauncherWindowed("steam")
            }
        case "epic":
            openLauncherWindowed("epic")
        case "gog":
            openLauncherWindowed("gog")
        case "ubisoft":
            openLauncherWindowed("ubisoft")
        case "ea":
            openLauncherWindowed("ea")
        case "amazon":
            openLauncherWindowed("amazon")
        case "itchio":
            openLauncherWindowed("itchio")
        case "battlenet":
            openLauncherWindowed("battlenet")
        default:
            break
        }
    }

    private func openLauncherWindowed(_ store: String) {
        let appName: String
        switch store {
        case "steam":    appName = AppSettings.shared.gameLaunchers.first { $0.id == "steam" }?.sunshineAppName
                          ?? (AppSettings.shared.sunshineSteamAppName.isEmpty ? "Steam Big Picture" : AppSettings.shared.sunshineSteamAppName)
        case "epic":     appName = AppSettings.shared.gameLaunchers.first { $0.id == "epic" }?.sunshineAppName ?? "Epic Games Launcher"
        case "gog":      appName = AppSettings.shared.gameLaunchers.first { $0.id == "gog" }?.sunshineAppName ?? "GalaxyClient"
        case "ubisoft":  appName = AppSettings.shared.gameLaunchers.first { $0.id == "ubisoft" }?.sunshineAppName ?? "Ubisoft Connect"
        case "ea":       appName = AppSettings.shared.gameLaunchers.first { $0.id == "ea" }?.sunshineAppName ?? "EA App"
        case "amazon":   appName = AppSettings.shared.gameLaunchers.first { $0.id == "amazon" }?.sunshineAppName ?? "Amazon Games"
        case "itchio":   appName = AppSettings.shared.gameLaunchers.first { $0.id == "itchio" }?.sunshineAppName ?? "itch.io"
        case "battlenet":appName = AppSettings.shared.gameLaunchers.first { $0.id == "battlenet" }?.sunshineAppName ?? "Battle.net"
        default: return
        }
        let plist = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
        let ip = (NSDictionary(contentsOfFile: plist) as? [String: Any])?["hosts.1.localaddress"] as? String
            ?? AppSettings.shared.pcIPAddress
        let bins = ["/Applications/Moonlight.app/Contents/MacOS/Moonlight",
                    NSHomeDirectory() + "/Applications/Moonlight.app/Contents/MacOS/Moonlight"]
        guard let path = bins.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["stream", ip, appName, "--display-mode", "windowed"]
        try? proc.run()
    }
}
