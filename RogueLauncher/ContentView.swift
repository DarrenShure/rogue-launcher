import SwiftUI

struct ContentView: View {
    // Statisch gespeichert → überlebt SwiftUI re-renders
    private static var moonlightTerminateObs: NSObjectProtocol?
    private static var moonlightDeactivateObs: NSObjectProtocol?

    static func registerMoonlightObservers() {
        // Alte Observer entfernen
        if let o = moonlightTerminateObs { NSWorkspace.shared.notificationCenter.removeObserver(o) }
        if let o = moonlightDeactivateObs { NSWorkspace.shared.notificationCenter.removeObserver(o) }

        let restore = {
            DispatchQueue.main.async {
                NSApp.windows.filter { $0.isMiniaturized }.forEach { $0.deminiaturize(nil) }
                NSApp.activate(ignoringOtherApps: true)
            }
        }

        moonlightTerminateObs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { note in
            guard (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                    .bundleIdentifier == "com.moonlight-stream.Moonlight" else { return }
            restore()
        }

        moonlightDeactivateObs = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didDeactivateApplicationNotification,
            object: nil, queue: .main
        ) { note in
            guard (note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication)?
                    .bundleIdentifier == "com.moonlight-stream.Moonlight" else { return }
            // Nur wiederherstellen wenn Moonlight nicht mehr läuft (wirklich beendet)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                let stillRunning = NSWorkspace.shared.runningApplications.contains {
                    $0.bundleIdentifier == "com.moonlight-stream.Moonlight"
                }
                if !stillRunning { restore() }
            }
        }
    }
    @StateObject private var store = GameStore()
    @StateObject private var monitor = PCStatusMonitor.shared
    @ObservedObject private var session = SessionTracker.shared
    @State private var selected: Game?
    @State private var showingAddGame = false
    @State private var editingGame: Game?
    @State private var showingMoonlightImport = false
    @State private var showingLocalImport = false
    @State private var showingSettings = false
    @State private var scriptRunning: UUID? = nil
    @State private var scriptResult: (UUID, Bool)? = nil
    @ObservedObject private var scriptStore = CustomScriptStore.shared
    @State private var isLaunching = false
    @State private var wakeTimer: Timer? = nil
    @State private var showHome = true
    @State private var selectedGenre: String? = nil
    @State private var searchText = ""
    @State private var isFetchingAll = false
    @Environment(\.openWindow) private var openWindow

    var isOnline: Bool { monitor.status == .online }

    var desktopGame: Game? {
        store.games.first { $0.name.lowercased() == "desktop" && $0.type == .moonlight }
    }
    var vortexGame: Game? {
        store.games.first { $0.name.lowercased() == "vortex" && $0.type == .moonlight }
    }
    var hasSleepButton: Bool {
        let s = AppSettings.shared
        return HelperAPI.shared.isConfigured || !s.sleepWebhookURL.isEmpty
    }
    var regularGames: [Game] {
        let hiddenContains = ["epic games launcher", "gog galaxy", "galaxyclient", "ea app",
                              "ea desktop", "origin", "ubisoft connect", "uplay", "battle.net",
                              "amazon games", "itch.io", "rockstar games launcher",
                              "minecraft launcher", "steam big picture", "desktop", "vortex", "audials"]
        let hiddenExact = ["steam", "epic games", "gog", "battle.net", "xbox"]
        return store.games
            .filter { game in
                let nl = game.name.lowercased()
                let isHidden = hiddenContains.contains(where: { nl.contains($0) })
                               || hiddenExact.contains(where: { nl == $0 })
                return !(isHidden && game.type == .moonlight)
            }
            .filter { game in
                guard !searchText.isEmpty else { return true }
                if game.name.localizedCaseInsensitiveContains(searchText) { return true }
                // Direkte Übereinstimmung
                if game.genre.localizedCaseInsensitiveContains(searchText) { return true }
                // Normalisierte Übereinstimmung (z.B. "Abenteuer" trifft "Adventure")
                let gameGenres = game.genre.split(separator: ",").map { normalizeGenre(String($0)) }
                return gameGenres.contains { $0.localizedCaseInsensitiveCompare(searchText) == .orderedSame }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var body: some View {
        NavigationSplitView {
            sidebar
                .navigationSplitViewColumnWidth(min: 280, ideal: 320, max: 380)
        } detail: {
            if showHome {
                HomeView(store: store, onSelect: { game in
                    selected = game
                    showHome = false
                })
                .toolbar(.hidden, for: .automatic)
                .toolbarBackground(.hidden, for: .automatic)
            } else {
                detail
                    .toolbar(.hidden, for: .automatic)
                    .toolbarBackground(.hidden, for: .automatic)
            }
        }
        .navigationSplitViewStyle(.balanced)
        .frame(minWidth: 960, minHeight: 620)
        .onReceive(NotificationCenter.default.publisher(for: .selectGame)) { note in
            if let game = note.object as? Game {
                selected = game
                showHome = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .filterByTag)) { note in
            if note.object is String {
                showHome = true
                selected = nil
                searchText = ""
            }
        }
        .sheet(isPresented: $showingAddGame) { GameEditView(store: store, game: nil) }
        .sheet(item: $editingGame) { game in
            GameEditView(store: store, game: game) {
                if let updated = store.games.first(where: { $0.id == game.id }) { selected = updated }
            }
        }
        .sheet(isPresented: $showingMoonlightImport) { MoonlightImportView(store: store) }
        .sheet(isPresented: $showingLocalImport) { LocalImportView(store: store) }
        .sheet(isPresented: $showingSettings) { SettingsView() }
    }

    @ViewBuilder
    // iOS-Style App Icon Button
    private func appIconButton(
        _ systemName: String?,
        active: Bool = false,
        showDot: Bool = false,
        help: String = "",
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            ZStack(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(active
                          ? Color(NSColor.controlBackgroundColor)
                          : Color.secondary.opacity(0.15))
                    .frame(width: 28, height: 28)

                if let name = systemName {
                    Image(systemName: name)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(active ? .primary : .secondary)
                        .frame(width: 28, height: 28)
                } else {
                    ProgressView()
                        .scaleEffect(0.5)
                        .frame(width: 28, height: 28)
                }

                if showDot {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 7, height: 7)
                        .offset(x: 2, y: 2)
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Sidebar

    var sidebar: some View {
        VStack(spacing: 0) {
            HStack(alignment: .center, spacing: 6) {

                // Haus + Bibliothek kombiniert
                Button(action: {
                    showHome = true; selected = nil; selectedGenre = nil
                    NotificationCenter.default.post(name: .goHome, object: nil)
                }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(showHome
                                  ? Color(NSColor.controlBackgroundColor)
                                  : Color.secondary.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "house")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(showHome ? .primary : .secondary)
                    }
                }
                .buttonStyle(.plain)

                if session.hasActiveSession, let appName = session.activeAppName {
                    Button(action: { resumeSession(appName: appName) }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .frame(width: 30, height: 30)
                            Image(systemName: "arrowshape.turn.up.left.fill")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                if let desktop = desktopGame {
                    appIconButton(isLaunching ? nil : "desktopcomputer",
                        active: isOnline,
                        showDot: isOnline,
                        help: isOnline ? "Desktop streamen" : "PC starten und Desktop öffnen") {
                        launchDesktop(desktop)
                    }
                    .disabled(isLaunching)
                }

                if let vortex = vortexGame {
                    appIconButton("shippingbox",
                        active: isOnline,
                        showDot: isOnline,
                        help: isOnline ? "Vortex starten" : "PC starten und Vortex öffnen") {
                        launchSpecial(vortex)
                    }
                }

                // Custom Script Buttons
                ForEach(scriptStore.scripts.filter { $0.showInTopNav }) { script in
                    let isRunning = scriptRunning == script.id
                    let result = scriptResult.flatMap { $0.0 == script.id ? $0 : nil }
                    Button(action: {
                        guard !isRunning else { return }
                        scriptRunning = script.id
                        scriptResult = nil
                        scriptStore.run(script) { success, _ in
                            scriptRunning = nil
                            scriptResult = (script.id, success)
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                                if scriptResult?.0 == script.id { scriptResult = nil }
                            }
                        }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(result != nil
                                      ? (result!.1 ? Color.green.opacity(0.2) : Color.red.opacity(0.2))
                                      : Color.secondary.opacity(0.15))
                                .frame(width: 30, height: 30)
                            if isRunning {
                                ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
                            } else if let r = result {
                                Image(systemName: r.1 ? "checkmark" : "xmark")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundColor(r.1 ? .green : .red)
                            } else {
                                Image(systemName: script.symbol)
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                }

                Button(action: { showingSettings = true }) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.secondary.opacity(0.15))
                            .frame(width: 30, height: 30)
                        Image(systemName: "gearshape")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }
                .buttonStyle(.plain)

                if isFetchingAll {
                    ProgressView().scaleEffect(0.5).frame(width: 16, height: 16)
                }

                if hasSleepButton {
                    Button(action: {
                        if isOnline { sleepPC() } else { wakePC() }
                    }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isOnline ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                                .frame(width: 28, height: 28)
                            Image(systemName: "power")
                                .font(.system(size: 13, weight: .medium))
                                .foregroundColor(isOnline ? .red.opacity(0.8) : .green.opacity(0.8))
                        }
                    }
                    .buttonStyle(.plain)
                }


            }
            .padding(.horizontal, 12).padding(.vertical, 8)

            // Suchfeld (kein Divider)
            HStack(spacing: 6) {
                Image(systemName: selectedGenre != nil ? "tag.fill" : "magnifyingglass")
                    .foregroundColor(selectedGenre != nil ? .green : .secondary)
                    .font(.system(size: 12))
                if let genre = selectedGenre {
                    Text(genre)
                        .font(.system(size: 13))
                        .foregroundColor(.primary)
                    Spacer()
                } else {
                    TextField("Suche...", text: $searchText)
                        .textFieldStyle(.plain).font(.system(size: 13))
                }
                if selectedGenre != nil || !searchText.isEmpty {
                    Button(action: {
                        searchText = ""
                        selectedGenre = nil
                        showHome = true
                        selected = nil
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary).font(.system(size: 12))
                    }.buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 10).padding(.vertical, 5)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 8).padding(.vertical, 5)

            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(regularGames) { game in
                        GameRowView(game: game, isSelected: selected?.id == game.id, moonlightOnline: isOnline)
                            .onTapGesture { selected = game; showHome = false }
                            .contextMenu {
                                Button("Bearbeiten") { editingGame = game }
                                Divider()
                                Button("Löschen", role: .destructive) {
                                    if selected?.id == game.id { selected = nil }
                                    store.delete(game)
                                }
                            }
                    }
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Detail

    @ViewBuilder var detail: some View {
        if let game = selected {
            VStack(spacing: 0) {
                HStack {
                    Button(action: { selected = nil; showHome = true }) {
                        Label("Zurück zum Start", systemImage: "chevron.left")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .cursor(.pointingHand)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
                Divider()
                GameDetailView(
                    game: Binding(
                        get: { store.games.first { $0.id == game.id } ?? game },
                        set: { newGame in selected = newGame }
                    ),
                    store: store,
                    onEdit: { editingGame = store.games.first { $0.id == game.id } ?? game },
                    onLaunchingChanged: { isLaunching = $0 }
                )
            }
        } else {
            EmptyStateView()
        }
    }

    // MARK: - Desktop Launch

    private func fetchAllMetadata() {
        let games = store.games
        guard !games.isEmpty else { return }
        isFetchingAll = true
        var remaining = games.count

        for game in games {
            GameMetadataService.fetch(for: game.name) { meta in
                guard let meta = meta else {
                    remaining -= 1
                    if remaining == 0 { DispatchQueue.main.async { isFetchingAll = false } }
                    return
                }
                // Cover herunterladen wenn noch keines vorhanden
                let needsCover = game.coverImagePath == nil
                let needsBg    = game.backgroundImagePath == nil

                func finish() {
                    remaining -= 1
                    if remaining == 0 { DispatchQueue.main.async { isFetchingAll = false } }
                }

                func updateGame() {
                    DispatchQueue.main.async {
                        if var g = self.store.games.first(where: { $0.id == game.id }) {
                            if g.description.isEmpty { g.description = meta.description }
                            if g.genre.isEmpty        { g.genre = meta.genre }
                            if g.releaseYear.isEmpty  { g.releaseYear = meta.releaseYear }
                            self.store.update(g)
                        }
                    }
                }

                // Background
                if needsBg, let bgURL = meta.backgroundURL {
                    GameMetadataService.downloadCover(from: bgURL, for: "bg_\(game.name)") { path in
                        DispatchQueue.main.async {
                            if var g = self.store.games.first(where: { $0.id == game.id }) {
                                g.backgroundImagePath = path
                                self.store.update(g)
                            }
                        }
                    }
                }

                // Cover
                if needsCover, let coverURL = meta.coverURL {
                    GameMetadataService.downloadCover(from: coverURL, for: game.name) { path in
                        DispatchQueue.main.async {
                            if var g = self.store.games.first(where: { $0.id == game.id }) {
                                g.coverImagePath = path
                                self.store.update(g)
                            }
                        }
                        updateGame()
                        finish()
                    }
                } else {
                    updateGame()
                    finish()
                }
            }
        }
    }

    private func resumeSession(appName: String) {
        let ip = AppSettings.shared.streamingHost
        let bins = ["/Applications/Moonlight.app/Contents/MacOS/Moonlight",
                    NSHomeDirectory() + "/Applications/Moonlight.app/Contents/MacOS/Moonlight"]
        guard let path = bins.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        MoonlightPresetStore.shared.applyToMoonlight()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["stream", ip, appName, "--display-mode", "fullscreen"]
        try? proc.run()
        NSApp.windows.forEach { $0.miniaturize(nil) }
        ContentView.registerMoonlightObservers()
    }

    private func launchDesktop(_ game: Game) {
        if isOnline { streamDesktop(game); return }
        let settings = AppSettings.shared
        if settings.wakeMethod == .webhook && !settings.webhookURL.isEmpty {
            AppSettings.fireWebhook(settings.webhookURL)
        } else { WakeOnLan.send(mac: settings.pcMACAddress) }
        isLaunching = true
        var elapsed = 0.0
        wakeTimer?.invalidate()
        wakeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            elapsed += 2
            GameDetailView.checkPCOnline(ip: settings.pcIPAddress, port: settings.moonlightPort) { online in
                if online {
                    timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { isLaunching = false; streamDesktop(game) }
                } else if elapsed >= 90 { timer.invalidate(); isLaunching = false }
            }
        }
    }

    private func sleepPC() {
        let s = AppSettings.shared
        switch s.shutdownMethod {
        case .rogueHelperShutdown:
            if let req = HelperAPI.shared.request("/shutdown", method: "POST") {
                HelperAPI.shared.dataTask(with: req) { _, _, _ in }.resume()
            }
        case .rogueHelperSleep:
            if let req = HelperAPI.shared.request("/sleep", method: "POST") {
                HelperAPI.shared.dataTask(with: req) { _, _, _ in }.resume()
            }
        case .webhook:
            if !s.shutdownWebhookURL.isEmpty {
                AppSettings.fireWebhook(s.shutdownWebhookURL)
            }
        case .disabled:
            break
        }
        SessionTracker.shared.sessionEnded()
    }

    private func wakePC() {
        let s = AppSettings.shared
        if s.wakeMethod == .webhook && !s.webhookURL.isEmpty {
            AppSettings.fireWebhook(s.webhookURL)
        } else {
            WakeOnLan.send(mac: s.pcMACAddress)
        }
    }


    private func launchSpecial(_ game: Game) {
        if isOnline {
            streamDesktop(game)
        } else {
            let settings = AppSettings.shared
            if settings.wakeMethod == .webhook && !settings.webhookURL.isEmpty {
                AppSettings.fireWebhook(settings.webhookURL)
            } else { WakeOnLan.send(mac: settings.pcMACAddress) }
            isLaunching = true
            var elapsed = 0.0
            wakeTimer?.invalidate()
            wakeTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                elapsed += 2
                GameDetailView.checkPCOnline(ip: settings.pcIPAddress, port: settings.moonlightPort) { online in
                    if online {
                        timer.invalidate()
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isLaunching = false; self.streamDesktop(game)
                        }
                    } else if elapsed >= 90 { timer.invalidate(); isLaunching = false }
                }
            }
        }
    }

    private func killMoonlight() {
        let running = NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.moonlight-stream.Moonlight"
        )
        guard !running.isEmpty else { return }

        DispatchQueue.main.async {
            NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.moonlight-stream.Moonlight"
            ).first?.activate(options: [])
        }

        // Auf Background-Thread warten (blockiert NICHT den Main Thread)
        var waited = 0.0
        while waited < 30.0 {
            Thread.sleep(forTimeInterval: 0.5)
            waited += 0.5
            let stillRunning = NSRunningApplication.runningApplications(
                withBundleIdentifier: "com.moonlight-stream.Moonlight"
            )
            if stillRunning.isEmpty { break }
        }
        Thread.sleep(forTimeInterval: 0.5)
    }

    private func streamDesktop(_ game: Game) {
        let ip = AppSettings.shared.streamingHost
        let bins = ["/Applications/Moonlight.app/Contents/MacOS/Moonlight",
                    NSHomeDirectory() + "/Applications/Moonlight.app/Contents/MacOS/Moonlight"]
        guard let path = bins.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }

        // killMoonlight auf Background-Thread → kein UI-Freeze
        DispatchQueue.global(qos: .userInitiated).async {
            self.killMoonlight()
            DispatchQueue.main.async {
                MoonlightPresetStore.shared.applyToMoonlight()
                let proc2 = Process()
                proc2.executableURL = URL(fileURLWithPath: path)
                proc2.arguments = ["stream", ip, game.appName, "--display-mode", "fullscreen"]
                try? proc2.run()
                SessionTracker.shared.sessionStarted(appName: game.appName)
                NSApp.windows.forEach { $0.miniaturize(nil) }
                ContentView.registerMoonlightObservers()
            }
        }
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "gamecontroller").font(.system(size: 56)).foregroundColor(.secondary.opacity(0.4))
            Text("Kein Spiel ausgewählt").font(.title3).foregroundColor(.secondary)
            Text("Wähle ein Spiel aus der Bibliothek\noder füge ein neues hinzu.")
                .font(.body).foregroundColor(.secondary.opacity(0.7)).multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
