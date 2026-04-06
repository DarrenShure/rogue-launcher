import SwiftUI
import Network

struct GameDetailView: View {
    @Binding var game: Game
    let store: GameStore
    let onEdit: () -> Void
    let onLaunchingChanged: (Bool) -> Void

    @ObservedObject private var monitor = PCStatusMonitor.shared
    @ObservedObject private var session = SessionTracker.shared
    @State private var isLaunching = false
    @State private var isSwitchingSession = false
    @State private var moonlightSwitching = false
    @State private var launchProgress: Double = 0
    @State private var launchTimer: Timer? = nil
    @State private var showingPosterPicker = false
    @State private var screenshots: [String] = []
    @State private var igdbRating: Double? = nil
    @State private var displayDescription: String = ""
    @State private var zoomedScreenshot: String? = nil
    @State private var measuredPanelH: CGFloat = 300

    var similarGames: [Game] {
        let hidden = ["desktop", "vortex", "audials", "ruhemodus", "sunshine", "nexus", "mod organizer", "epic games launcher", "epic games"]
        let myGenres = Set(game.genre.components(separatedBy: CharacterSet(charactersIn: ", ")).filter { !$0.isEmpty })
        let franchisePrefix = game.name.components(separatedBy: " ").prefix(2).joined(separator: " ").lowercased()

        struct Scored { let game: Game; let score: Int }

        let scored: [Scored] = store.games.compactMap { other in
            guard other.id != game.id else { return nil }
            // Utility-Apps ausblenden
            let lower = other.name.lowercased()
            guard !hidden.contains(where: { lower.contains($0) }) else { return nil }
            var score = 0
            if other.name.lowercased().hasPrefix(franchisePrefix) { score += 100 }
            if !other.genre.isEmpty {
                let otherGenres = Set(other.genre.components(separatedBy: CharacterSet(charactersIn: ", ")).filter { !$0.isEmpty })
                score += myGenres.intersection(otherGenres).count * 10
            }
            guard score > 0 else { return nil }
            return Scored(game: other, score: score)
        }

        return scored.sorted { $0.score > $1.score }.map(\.game)
    }

    var isOnline: Bool { monitor.status == .online }
    var backgroundImg: NSImage? { game.backgroundImage ?? game.coverImage }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {

                // SCHICHT 1: Blurriger Hintergrund – volle Fläche
                if let img = backgroundImg {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .blur(radius: 40)
                        .clipped()
                        .allowsHitTesting(false)
                } else {
                    LinearGradient(
                        colors: [Color(red:0.10,green:0.10,blue:0.14), Color(red:0.08,green:0.08,blue:0.12)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .frame(width: geo.size.width, height: geo.size.height)
                    .allowsHitTesting(false)
                }

                // SCHICHT 2: Poster – Graustufen, mit Abstand zum Panel
                let gap: CGFloat = 12
                let posterTop: CGFloat = measuredPanelH + gap + 16
                let posterW = geo.size.width - 16
                let posterH = geo.size.height - posterTop - 8

                if let img = backgroundImg, posterH > 0 {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: posterW, height: posterH)
                        .saturation(0)
                        .opacity(0.45)
                        .clipShape(UnevenRoundedRectangle(
                            topLeadingRadius: 12, bottomLeadingRadius: 12,
                            bottomTrailingRadius: 0, topTrailingRadius: 0))
                        .offset(x: 16, y: posterTop)
                        .allowsHitTesting(false)
                }

                // SCHICHT 3: YouTube (links 3×3) + Screenshots (rechts 3×3) über dem Poster
                if posterH > 0 {
                    HStack(alignment: .top, spacing: 12) {

                        // Ähnliche Spiele
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("Ähnliche Spiele")
                            if similarGames.isEmpty {
                                Text("Keine ähnlichen Spiele in der Bibliothek")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .center)
                            } else {
                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: 8
                                ) {
                                    ForEach(similarGames.prefix(9)) { g in
                                        Button(action: { game = g }) {
                                            LibrarySimilarGameCard(game: g)
                                        }
                                        .buttonStyle(.plain)
                                        .cursor(.pointingHand)
                                    }
                                }
                            }
                        }
                        .padding(14)
                        .frame(maxWidth: .infinity)
                        .background(RoundedRectangle(cornerRadius: 12)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.45)))

                        // Screenshots 3×3
                        if !screenshots.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                sectionLabel("Screenshots")
                                LazyVGrid(
                                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                                    spacing: 6
                                ) {
                                    ForEach(screenshots.prefix(9), id: \.self) { url in
                                        Button(action: { zoomedScreenshot = url }) {
                                            AsyncImage(url: URL(string: url)) { img in
                                                img.resizable().aspectRatio(16/9, contentMode: .fill)
                                            } placeholder: {
                                                Rectangle().fill(Color.secondary.opacity(0.2))
                                                    .aspectRatio(16/9, contentMode: .fit)
                                            }
                                            .clipShape(RoundedRectangle(cornerRadius: 6))
                                        }
                                        .buttonStyle(.plain)
                                        .cursor(.pointingHand)
                                    }
                                }
                            }
                            .padding(14)
                            .frame(maxWidth: .infinity)
                            .background(RoundedRectangle(cornerRadius: 12)
                                .fill(Color(NSColor.windowBackgroundColor).opacity(0.45)))
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 16)
                    .frame(width: posterW)
                    .offset(x: 16, y: posterTop)
                }

                // SCHICHT 4: Info-Panel oben (misst eigene Höhe)
                HStack(alignment: .top, spacing: 28) {
                    coverColumn
                    infoColumn
                }
                .padding(20)
                .frame(width: geo.size.width - 16)
                .background(
                    UnevenRoundedRectangle(
                        topLeadingRadius: 16, bottomLeadingRadius: 16,
                        bottomTrailingRadius: 0, topTrailingRadius: 0)
                        .fill(Color(NSColor.windowBackgroundColor).opacity(0.72))
                        .shadow(color: .black.opacity(0.25), radius: 12, x: 0, y: 4)
                        .background(GeometryReader { bg in
                            Color.clear.preference(key: PanelHeightKey.self, value: bg.size.height)
                        })
                )
                .offset(x: 16, y: 16)
            }
            .onPreferenceChange(PanelHeightKey.self) { measuredPanelH = $0 }
        }
        .sheet(isPresented: $showingPosterPicker) {
            PosterPickerView(gameName: game.name) { path in
                if var g = store.games.first(where: { $0.id == game.id }) {
                    g.backgroundImagePath = path
                    store.update(g)
                }
            }
        }
        .sheet(item: Binding(
            get: { zoomedScreenshot.map { ScreenshotID(url: $0) } },
            set: { zoomedScreenshot = $0?.url }
        )) { item in
            ScreenshotZoomView(url: item.url)
        }
        .onAppear { loadDetailData() }
        .onChange(of: game.id) { _, _ in
            screenshots = []; igdbRating = nil; displayDescription = ""
            loadDetailData()
        }
    }

    // MARK: - Section Label

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .foregroundColor(.secondary)
            .textCase(.uppercase)
    }

    // MARK: - Cover Column

    private var coverColumn: some View {
        VStack(spacing: 12) {
            Group {
                if let img = game.coverImage {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                } else if game.type == .local, let icon = game.localAppIcon {
                    Color.secondary.opacity(0.1)
                        .overlay(Image(nsImage: icon).resizable().frame(width: 80, height: 80))
                } else {
                    Rectangle()
                        .fill(LinearGradient(
                            colors: [Color.secondary.opacity(0.2), Color.secondary.opacity(0.1)],
                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay(Image(systemName: "gamecontroller")
                            .font(.system(size: 36)).foregroundColor(.secondary.opacity(0.5)))
                }
            }
            .frame(width: 160, height: 215)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.4), radius: 12, x: 0, y: 6)
            .overlay(alignment: .bottom) {
                if isLaunching {
                    VStack(spacing: 4) {
                        ProgressView(value: launchProgress)
                            .progressViewStyle(.linear).tint(.accentColor)
                        Text(isSwitchingSession ? "Session wird gewechselt…"
                             : (launchProgress < 1.0 ? "PC wird gestartet…" : "Starte Spiel…"))
                            .font(.system(size: 10)).foregroundColor(.white)
                    }
                    .padding(.horizontal, 12).padding(.vertical, 8)
                    .background(Color.black.opacity(0.65))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .padding(8)
                }
            }

            if moonlightSwitching {
                VStack(spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.triangle.2.circlepath").foregroundColor(.orange)
                        Text("Moonlight läuft noch").font(.system(size: 12, weight: .semibold))
                    }
                    Text("Bestätige den Dialog in Moonlight\num zum neuen Spiel zu wechseln.")
                        .font(.system(size: 11)).foregroundColor(.secondary).multilineTextAlignment(.center)
                }
                .padding(10)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

            if isLaunching {
                actionButton(title: "Abbrechen", icon: "xmark", action: cancelLaunch)
            } else if game.type == .console {
                consoleActionButton
            } else if game.type == .rom {
                actionButton(title: "Mit RetroArch spielen", icon: "play.fill", action: launchRom)
            } else if game.type == .local {
                actionButton(title: "Spielen", icon: "play.fill", action: launchLocal)
            } else if isOnline {
                if session.activeAppName == game.appName {
                    // Dieses Spiel läuft gerade → fortsetzen
                    actionButton(title: "Spiel fortsetzen", icon: "arrow.right.circle.fill", action: launchMoonlight)
                } else if session.hasActiveSession {
                    // Anderes Spiel läuft → wechseln
                    actionButton(title: "Session wechseln", icon: "arrow.triangle.2.circlepath", action: restartAndLaunch)
                } else {
                    actionButton(title: "Spielen", icon: "play.fill", action: launchMoonlight)
                }
            } else {
                actionButton(title: "PC starten und spielen", icon: "power", action: wakeAndPlay)
                    .disabled(monitor.status == .checking)
            }
        }
    }

    // MARK: - Info Column

    private var infoColumn: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(game.name).font(.system(size: 24, weight: .bold))

            HStack(spacing: 8) {
                if !game.genre.isEmpty       { MetaPill(icon: "tag",                  text: game.genre) }
                if !game.releaseYear.isEmpty { MetaPill(icon: "calendar",             text: game.releaseYear) }
                if !game.ageRating.isEmpty   { MetaPill(icon: "person.fill.checkmark",text: game.ageRating) }
                Spacer()
                typeLabel
                Button(action: onEdit) {
                    HStack(spacing: 4) {
                        Image(systemName: "pencil").font(.system(size: 10))
                        Text("Bearbeiten").font(.system(size: 11, weight: .medium))
                    }
                    .padding(.horizontal, 9).padding(.vertical, 5)
                    .background(Color.secondary.opacity(0.15))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }

            if let rating = igdbRating {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill").foregroundColor(.yellow).font(.system(size: 13))
                    Text(String(format: "%.0f / 100", rating))
                        .font(.system(size: 13, weight: .semibold))
                    Text("(IGDB)").font(.system(size: 11)).foregroundColor(.secondary)
                }
            }

            // Beschreibung
            let desc = displayDescription.isEmpty ? game.description : displayDescription
            if !desc.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 4) {
                    sectionLabel("Beschreibung")
                    Text(desc)
                        .font(.system(size: 13))
                        .lineSpacing(3)
                        .foregroundColor(.primary.opacity(0.85))
                        .lineLimit(4)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Helpers

    @ViewBuilder private var consoleActionButton: some View {
        let settings = AppSettings.shared
        // consoleType → passenden HDMI-Eingang in der Map finden
        let typeLC = game.consoleType.lowercased()
        let inputEntry = settings.hdmiInputMap.first { _, label in
            let labelLC = label.lowercased()
            // Direkte Enthaltung in beide Richtungen
            if labelLC.contains(typeLC) || typeLC.contains(labelLC) { return true }
            // Keyword-Matching für bekannte Konsolen
            let switchKeys = ["switch", "nintendo"]
            let psKeys     = ["ps4", "ps5", "playstation"]
            let xboxKeys   = ["xbox", "microsoft"]
            if switchKeys.contains(typeLC) { return switchKeys.contains(where: { labelLC.contains($0) }) }
            if psKeys.contains(typeLC)     { return psKeys.contains(where: { labelLC.contains($0) }) }
            if xboxKeys.contains(typeLC)   { return xboxKeys.contains(where: { labelLC.contains($0) }) }
            return false
        }
        let inputNumber = inputEntry.flatMap { Int($0.key) } ?? 17
        let consoleName = inputEntry?.value ?? game.consoleType

        Button(action: {
            var updated = game
            updated.lastPlayedAt = Date()
            NotificationCenter.default.post(name: .init("UpdateGame"), object: updated)
            // Erst Status-Item zeigen, dann nach kurzer Pause umschalten
            MenuBarManager.shared.activateConsoleMode(
                consoleName: consoleName,
                inputNumber: inputNumber,
                macInput: settings.macInputNumber
            )
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                DDCSwitcher.setInput(inputNumber)
            }
        }) {
            HStack(spacing: 6) {
                Image(systemName: "display.2")
                Text("Bildschirm umschalten").lineLimit(1)
            }
            .frame(height: 32)
        }
        .buttonStyle(.bordered)
        .fixedSize()
    }

    private func actionButton(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) { Image(systemName: icon); Text(title).lineLimit(1) }
                .frame(height: 32)
        }
        .buttonStyle(.bordered)
        .fixedSize()
    }

    @ViewBuilder private var typeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: game.type == .moonlight ? "moon.fill" : game.type == .console ? "gamecontroller.fill" : game.type == .rom ? "cpu" : "macwindow").font(.system(size: 9))
            Text(game.type == .moonlight ? "Moonlight" : game.type == .console ? "Konsole" : game.type == .rom ? "ROM" : "Lokal").font(.system(size: 10, weight: .semibold))
        }
        .foregroundColor(.white).padding(.horizontal, 8).padding(.vertical, 4)
        .background(game.type == .console ? Color.green : game.type == .local ? Color.green : game.type == .rom ? Color.green : (isOnline ? Color.green : Color.secondary))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Data Loading
    private func loadDetailData() {
        let name = game.name

        // 1. Cache — nur wenn vollständig (Screenshots vorhanden)
        if let cached = GameDetailCache.shared.load(for: name),
           !cached.screenshotURLs.isEmpty {
            displayDescription = cached.description
            screenshots        = cached.screenshotURLs
            igdbRating         = cached.rating
            if game.ageRating.isEmpty && !cached.ageRating.isEmpty {
                var g = game; g.ageRating = cached.ageRating; store.update(g)
            }
            return
        }

        // 2. Kein Cache – per IGDB-ID wenn vorhanden, sonst per Name
        let handleMeta: (GameMetadata?) -> Void = { meta in
            guard let meta = meta else { return }
            DispatchQueue.main.async {
                self.screenshots = meta.screenshotURLs
                self.igdbRating  = meta.rating
                if !meta.description.isEmpty { self.displayDescription = meta.description }
            }
            let detail = CachedGameDetail(
                description:     meta.description,
                genre:           meta.genre,
                releaseYear:     meta.releaseYear,
                ageRating:       meta.ageRating,
                rating:          meta.rating,
                screenshotURLs:  meta.screenshotURLs,
                youtubeVideoIDs: [],
                youtubeTitles:   [],
                fetchedAt:       Date()
            )
            GameDetailCache.shared.save(detail, for: name)
        }

        if let igdbID = game.igdbID {
            GameMetadataService.fetchFromIGDBbyID(id: igdbID, completion: handleMeta)
        } else {
            GameMetadataService.fetch(for: name, completion: handleMeta)
        }
    }

    // MARK: - Launch

    private func launchRom() {
        guard let path = game.romPath else { return }
        RetroArchLauncher.launch(romPath: path, system: game.romSystem)
    }

    private func launchLocal() {
        store.trackPlay(game)
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: game.appName) {
            NSWorkspace.shared.openApplication(at: url, configuration: .init(), completionHandler: nil); return
        }
        if FileManager.default.fileExists(atPath: game.appName) {
            NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: game.appName), configuration: .init(), completionHandler: nil)
        }
    }

    private func launchMoonlight() {
        guard !game.appName.isEmpty else { return }
        store.trackPlay(game)
        let ip = AppSettings.shared.streamingHost
        let bins = ["/Applications/Moonlight.app/Contents/MacOS/Moonlight",
                    NSHomeDirectory() + "/Applications/Moonlight.app/Contents/MacOS/Moonlight"]
        guard let path = bins.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }

        // Moonlight beenden falls aktiv
        NSRunningApplication.runningApplications(
            withBundleIdentifier: "com.moonlight-stream.Moonlight"
        ).forEach { $0.terminate() }

        MoonlightPresetStore.shared.applyToMoonlight()
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["stream", ip, game.appName, "--display-mode", "fullscreen"]
        try? proc.run()
        SessionTracker.shared.sessionStarted(appName: game.appName)

        NSApp.windows.forEach { $0.miniaturize(nil) }

        // Einmaliger Observer: Fenster nur wiederherstellen wenn Moonlight wirklich endet
        let observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didTerminateApplicationNotification,
            object: nil, queue: .main
        ) { note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
                  app.bundleIdentifier == "com.moonlight-stream.Moonlight" else { return }
            NSApp.windows.forEach { $0.deminiaturize(nil) }
            NSApp.activate(ignoringOtherApps: true)
        }
        _ = observer
    }

    private func restartAndLaunch() {
        guard !game.appName.isEmpty else { return }
        let ip = AppSettings.shared.streamingHost
        let bins = ["/Applications/Moonlight.app/Contents/MacOS/Moonlight",
                    NSHomeDirectory() + "/Applications/Moonlight.app/Contents/MacOS/Moonlight"]
        guard let path = bins.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }

        isLaunching = true; isSwitchingSession = true; launchProgress = 0.1; onLaunchingChanged(true)

        DispatchQueue.global(qos: .userInitiated).async {
            DispatchQueue.main.async { launchProgress = 0.2 }
            let kill = Process()
            kill.executableURL = URL(fileURLWithPath: "/usr/bin/killall")
            kill.arguments = ["-9", "Moonlight"]
            try? kill.run(); kill.waitUntilExit()

            DispatchQueue.main.async { launchProgress = 0.4 }
            if HelperAPI.shared.isConfigured,
               let req = HelperAPI.shared.request("/sunshine/restart", method: "POST") {
                let sem = DispatchSemaphore(value: 0)
                HelperAPI.shared.dataTask(with: req) { _, _, _ in sem.signal() }.resume()
                _ = sem.wait(timeout: .now() + 5)
            }

            DispatchQueue.main.async { launchProgress = 0.6 }
            Thread.sleep(forTimeInterval: 5.0)

            DispatchQueue.main.async {
                launchProgress = 1.0
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: path)
                proc.arguments = ["stream", ip, game.appName, "--display-mode", "fullscreen"]
                try? proc.run()
                SessionTracker.shared.sessionStarted(appName: game.appName)
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isLaunching = false; isSwitchingSession = false
                    launchProgress = 0; onLaunchingChanged(false)
                }
            }
        }
    }

    private func wakeAndPlay() {
        let settings = AppSettings.shared
        if settings.wakeMethod == .webhook && !settings.webhookURL.isEmpty {
            AppSettings.fireWebhook(settings.webhookURL)
        } else {
            PCStatusMonitor.shared.sendWakeOnLan()
        }
        isLaunching = true; launchProgress = 0; onLaunchingChanged(true)
        var elapsed = 0.0
        launchTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
            elapsed += 2; launchProgress = min(elapsed / 60.0, 0.97)
            Self.checkPCOnline(ip: settings.pcIPAddress, port: settings.moonlightPort) { online in
                if online {
                    launchProgress = 1.0; timer.invalidate()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        isLaunching = false; onLaunchingChanged(false); launchMoonlight()
                    }
                } else if elapsed >= 90 { timer.invalidate(); isLaunching = false; onLaunchingChanged(false) }
            }
        }
    }

    static func checkPCOnline(ip: String, port: Int, completion: @escaping (Bool) -> Void) {
        guard !ip.isEmpty else { completion(false); return }
        let conn = NWConnection(host: NWEndpoint.Host(ip),
                                port: NWEndpoint.Port(rawValue: UInt16(port)) ?? 47989, using: .tcp)
        var resolved = false
        conn.stateUpdateHandler = { (state: NWConnection.State) in
            guard !resolved else { return }
            switch state {
            case .ready:
                resolved = true; conn.cancel(); DispatchQueue.main.async { completion(true) }
            case .failed, .waiting:
                resolved = true; conn.cancel(); DispatchQueue.main.async { completion(false) }
            default: break
            }
        }
        conn.start(queue: .global())
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            guard !resolved else { return }
            resolved = true; conn.cancel(); DispatchQueue.main.async { completion(false) }
        }
    }

    private func cancelLaunch() {
        launchTimer?.invalidate(); launchTimer = nil
        isLaunching = false; launchProgress = 0; onLaunchingChanged(false)
    }
}

struct MetaPill: View {
    let icon: String; let text: String
    var body: some View {
        HStack(spacing: 5) {
            Image(systemName: icon).font(.system(size: 11))
            Text(text).font(.system(size: 12, weight: .medium))
        }
        .padding(.horizontal, 10).padding(.vertical, 5)
        .background(Color.secondary.opacity(0.12)).clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Screenshot Zoom

struct ScreenshotID: Identifiable {
    let url: String
    var id: String { url }
}

struct ScreenshotZoomView: View {
    let url: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()

            AsyncImage(url: URL(string: url)) { img in
                img.resizable().aspectRatio(contentMode: .fit)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } placeholder: {
                ProgressView().frame(maxWidth: .infinity, maxHeight: .infinity)
            }

            // Mac-style Schließen-Button oben links
            Button(action: { dismiss() }) {
                Circle()
                    .fill(Color(red: 1, green: 0.37, blue: 0.34))
                    .frame(width: 14, height: 14)
                    .overlay(
                        Image(systemName: "xmark")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundColor(.black.opacity(0.5))
                    )
            }
            .buttonStyle(.plain)
            .padding(14)
        }
        .frame(minWidth: 960, minHeight: 540)
    }
}

// MARK: - Cursor helper

extension View {
    func cursor(_ cursor: NSCursor) -> some View {
        self.onHover { inside in
            if inside { cursor.push() } else { NSCursor.pop() }
        }
    }
}

// MARK: - PreferenceKey für Panel-Höhenmessung

private struct PanelHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 300
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
}

// MARK: - Library Similar Game Card

struct LibrarySimilarGameCard: View {
    let game: Game

    var body: some View {
        VStack(spacing: 6) {
            Group {
                if let img = game.coverImage {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                } else if game.type == .local, let icon = game.localAppIcon {
                    Color.secondary.opacity(0.1)
                        .overlay(Image(nsImage: icon).resizable().frame(width: 50, height: 50))
                } else {
                    Rectangle().fill(Color.secondary.opacity(0.15))
                        .overlay(Image(systemName: "gamecontroller")
                            .foregroundColor(.secondary.opacity(0.4)))
                }
            }
            .frame(width: 80, height: 107)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            Text(game.name)
                .font(.system(size: 10))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
    }
}
