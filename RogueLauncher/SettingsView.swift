import SwiftUI

struct SettingsView: View {
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var monitor  = PCStatusMonitor.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var saved = false

    // PC
    @State private var ip = ""
    @State private var moonlightHostOverride = ""
    @State private var mac = ""
    @State private var port = 47989
    @State private var wakeMethod = AppSettings.WakeMethod.magicPacket
    @State private var webhookURL = ""
    @State private var shutdownMethod = AppSettings.ShutdownMethod.rogueHelperShutdown
    @State private var shutdownWebhookURL = ""
    @State private var sleepWebhook = ""
    @State private var gameLaunchers: [GameLauncherConfig] = AppSettings.shared.gameLaunchers
    @State private var showAddLauncher = false
    @State private var editingLauncher: GameLauncherConfig? = nil
    @State private var gogFixStatus: GogFixStatus = .unknown

    enum GogFixStatus { case unknown, needsFix, fixed, noEntry }

    @State private var sleepMethod = "webhook"

    // Server
    @State private var craftyEnabled = false
    @State private var craftyURL = ""
    @State private var craftyKey = ""
    @State private var craftyServers: [CraftyServer] = []
    @State private var craftyTestResult = ""
    @State private var craftyTestOK = false
    @State private var nitradoEnabled = false
    @State private var nitradoToken = ""
    @State private var nitradoServers: [NitradoServer] = []
    @State private var nitradoTestResult = ""
    @State private var nitradoTestOK = false

    // Sunshine
    @State private var sunshineHost = ""
    @State private var sunshinePort = "47990"
    @State private var sunshineUser = ""
    @State private var sunshinePassword = ""
    @State private var sunshineTestResult = ""
    @State private var sunshineTestOK = false
    @State private var sunshineApps: [[String: Any]] = []
    @State private var sunshineAppsLoading = false
    // Sunshine Config
    @State private var sunshineCfgResW = ""
    @State private var sunshineCfgResH = ""
    @State private var sunshineCfgFPS = ""
    @State private var sunshineCfgBitrate = ""
    @State private var sunshineCfgEncoder = ""
    @State private var sunshineCfgPort = ""
    @State private var sunshineCfgUpnp = ""
    @State private var sunshineCfgLoading = false
    @State private var sunshineCfgSaveMsg = ""

    // Helper
    @State private var helperHost = ""
    @State private var helperPort = "9876"
    @State private var helperUser = ""
    @State private var helperPassword = ""
    @State private var helperTestResult = UserDefaults.standard.string(forKey: "helperLastStatus") ?? ""
    @State private var helperTestOK = UserDefaults.standard.bool(forKey: "helperLastOK")
    // Steam Login
    @State private var steamLoginUser = ""
    @State private var steamLoginPass = ""
    @State private var steamLoginJobID: String? = nil
    @State private var steamLoginStatus = ""
    @State private var steamLoginOK = false
    @State private var steamLogin2FACode = ""
    @State private var steamLoginPolling = false

    // Bibliothek
    @State private var backupPath = ""
    @State private var nasURL = ""
    @State private var nasCacheDir = ""
    @State private var epicClaimURL = ""
    @State private var epicClaimMode = "webview"
    @State private var epicClaimWebhookURL = ""
    @State private var epicFreeGamesEnabled = true
    @State private var igdbID = ""
    @State private var igdbSecret = ""
    @State private var rawgKey = ""
    @State private var sgdbKey = ""
    @State private var youtubeKey = ""

    let tabs = [
        ("person.circle",                    "Benutzer"),
        ("books.vertical",                   "Bibliothek"),
        ("bubble.left.and.bubble.right",     "Chat"),
        ("cpu",                              "Emulatoren"),
        ("desktopcomputer",                  "Gaming PC"),
        ("square.and.arrow.up.on.square",    "Import/Export"),
        ("gamecontroller.fill",              "Konsolen"),
        ("apple.logo",                       "Mac Launcher"),
        ("moon.stars.fill",                  "Moonlight"),
        ("puzzlepiece.fill",                 "Rogue Helper"),
        ("terminal",                         "Scripte"),
        ("sun.max.fill",                     "Sunshine"),
        ("info.circle",                      "Über_HIDDEN"),
        ("server.rack",                      "Spiele Server"),
        ("arrow.down.circle",                 "Updates"),
    ]

    var body: some View {
        HStack(spacing: 0) {
            // Sidebar Navigation
            VStack(spacing: 4) {
                // Logo
                if let logo = NSImage(named: "RogueLogo") {
                    Image(nsImage: logo)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(height: 32)
                        .padding(.bottom, 16)
                        .padding(.top, 8)
                }

                ForEach(Array(tabs.enumerated().filter { !$0.1.1.hasSuffix("_HIDDEN") }), id: \.0) { i, tab in
                    Button(action: { selectedTab = i }) {
                        HStack(spacing: 10) {
                            Image(systemName: tab.0)
                                .font(.system(size: 14))
                                .frame(width: 20)
                            Text(tab.1)
                                .font(.system(size: 13, weight: selectedTab == i ? .semibold : .regular))
                            Spacer()
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedTab == i ? Color.rogueRed.opacity(0.15) : Color.clear)
                        )
                        .foregroundColor(selectedTab == i ? Color.rogueRed : .primary)
                    }
                    .buttonStyle(.plain)
                }

                Spacer()

                // Über — immer unten
                Divider().padding(.bottom, 4)
                Button(action: { selectedTab = 12 }) {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .frame(width: 20)
                        Text("Über")
                            .font(.system(size: 13, weight: selectedTab == 12 ? .semibold : .regular))
                        Spacer()
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(selectedTab == 12 ? Color.rogueRed.opacity(0.15) : Color.clear)
                    )
                    .foregroundColor(selectedTab == 12 ? Color.rogueRed : .secondary)
                }
                .buttonStyle(.plain)

                // Speichern Status
                if saved {
                    Label("Gespeichert", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.system(size: 11))
                }
            }
            .padding(12)
            .frame(width: 220)
            .background(Color(NSColor.controlBackgroundColor))

            Divider()

            // Content
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        switch selectedTab {
                        case 0:  tabBenutzer
                        case 1:  tabBibliothek
                        case 2:  ChatSettingsView()
                        case 3:  tabEmulatoren
                        case 4:  tabPC
                        case 5:  tabImportExport
                        case 6:  tabKonsolen
                        case 7:  tabLauncher
                        case 8:  tabMoonlight
                        case 9:  tabHelper
                        case 10: tabScripte
                        case 11: tabSunshine
                        case 12: tabUeber
                        case 13: tabServer
                        case 14: tabUpdates
                        default: tabBenutzer
                        }
                    }
                    .padding(24)
                }

                Divider()

                HStack {
                    Spacer()
                    Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
                    Button("Speichern") { saveAll() }
                        .keyboardShortcut(.return)
                        .buttonStyle(.borderedProminent)
                        .tint(Color.rogueRed)
                }
                .padding(.horizontal, 20).padding(.vertical, 14)
            }
        }
        .frame(width: 1100, height: 720)
        .onAppear {
            populate()
            checkSteamLoginStatus()
        }
        .sheet(isPresented: $showAddLauncher) {
            LauncherEditSheet(launcher: GameLauncherConfig(
                id: UUID().uuidString, name: "", sunshineAppName: "",
                iconName: "gamecontroller.fill", colorHex: "#1A5276"
            )) { newLauncher in
                gameLaunchers.append(newLauncher)
            }
        }
        .sheet(item: $editingLauncher) { launcher in
            LauncherEditSheet(launcher: launcher) { updated in
                if let idx = gameLaunchers.firstIndex(where: { $0.id == updated.id }) {
                    gameLaunchers[idx] = updated
                }
            }
        }
    }

    // MARK: - Tab: Gaming PC

    var tabPC: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Gaming PC", icon: "desktopcomputer")

            group("VERBINDUNG") {
                row("IP-Adresse") { TextField("z.B. 192.168.178.94", text: $ip) }
                row("MAC-Adresse") { TextField("z.B. 74:56:3C:4B:EF:AE", text: $mac) }

                row("Port") {
                    HStack {
                        TextField("47989", value: $port, format: .number).frame(width: 80)
                        Spacer()
                    }
                }
            }

            group("MOONLIGHT HOST") {
                row("Stream-Host") {
                    TextField("Leer = IP-Adresse oben verwenden", text: $moonlightHostOverride)
                        .onChange(of: moonlightHostOverride) { _, v in
                            settings.moonlightHostOverride = v; settings.save()
                        }
                }
                Text("Wenn Moonlight mehrere PCs kennt, hier die IP des Gaming-PCs eintragen um immer den richtigen zu streamen.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 4)
            }

            group("HOST-OS") {
                Picker("", selection: Binding(
                    get: { settings.pcOS },
                    set: { v in DispatchQueue.main.async { settings.pcOS = v; settings.save() } }
                )) {
                    Text("Windows").tag("windows")
                    Text("Linux").tag("linux")
                }
                .pickerStyle(.segmented).padding(.horizontal, 16)
            }

            group("PC STARTEN") {
                Picker("", selection: $wakeMethod) {
                    ForEach(AppSettings.WakeMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, 16)

                if wakeMethod == .webhook {
                    row("Webhook URL") { TextField("https://...", text: $webhookURL) }
                }
            }

            group("PC HERUNTERFAHREN") {
                Picker("", selection: $shutdownMethod) {
                    ForEach(AppSettings.ShutdownMethod.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented).padding(.horizontal, 16)

                if shutdownMethod == .webhook {
                    row("Webhook URL") { TextField("https://...", text: $shutdownWebhookURL) }
                }
                if shutdownMethod == .rogueHelperShutdown {
                    Text("Sendet POST /shutdown an den Rogue Helper (Windows fährt in 5s herunter).")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
                if shutdownMethod == .rogueHelperSleep {
                    Text("Sendet POST /sleep an den Rogue Helper (Windows geht in den Ruhezustand).")
                        .font(.system(size: 11)).foregroundColor(.secondary)
                        .padding(.horizontal, 16)
                }
            }

            group("PC STATUS") {
                HStack(spacing: 12) {
                    Circle().fill(statusColor).frame(width: 10, height: 10)
                    Text(statusText).font(.system(size: 13)).foregroundColor(.secondary)
                    Spacer()
                    Button("Aktualisieren") { monitor.checkNow() }.buttonStyle(.bordered).controlSize(.small)
                }.padding(.horizontal, 16)
                Button(action: wakePC) { Label("PC jetzt starten", systemImage: "power") }
                    .padding(.horizontal, 16).disabled(ip.isEmpty && mac.isEmpty)
            }

            group("PC SCHLAFEN LEGEN") {
                Picker("Methode", selection: $sleepMethod) {
                    Text("Webhook").tag("webhook")
                    Text("Rogue Helper").tag("helper")
                }
                .pickerStyle(.segmented)
                .padding(.horizontal, 16)

                if sleepMethod == "webhook" {
                    row("Sleep Webhook") { TextField("https://... (optional)", text: $sleepWebhook) }
                    Text("Wenn eingetragen, erscheint der 🌙-Button in der Sidebar.")
                        .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
                } else {
                    Text("Nutzt den Rogue Helper um Moonlight sauber zu beenden und den PC in den Ruhemodus zu versetzen.")
                        .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
                    if AppSettings.shared.helperHost.isEmpty {
                        Text("⚠️ Kein Rogue Helper konfiguriert — bitte zuerst im Rogue Helper Tab einrichten.")
                            .font(.system(size: 11)).foregroundColor(.orange).padding(.horizontal, 16)
                    }
                }
            }

            group("LAUNCHER AUF DEM GAMING PC") {
                VStack(spacing: 0) {
                    ForEach($gameLaunchers) { $launcher in
                        HStack(spacing: 12) {
                            // Farb-Icon
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(launcher.color)
                                    .frame(width: 32, height: 32)
                                Image(systemName: launcher.iconName)
                                    .font(.system(size: 14))
                                    .foregroundColor(.white)
                            }

                            VStack(alignment: .leading, spacing: 2) {
                                Text(launcher.name)
                                    .font(.system(size: 13, weight: .medium))
                                Text(launcher.sunshineAppName)
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: $launcher.enabled)
                                .labelsHidden()

                            Button(action: { editingLauncher = launcher }) {
                                Image(systemName: "pencil")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 8)
                        Divider().padding(.leading, 60)
                    }
                }

                HStack {
                    Button(action: { showAddLauncher = true }) {
                        Label("Launcher hinzufügen", systemImage: "plus")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.top, 8)

                // GOG Galaxy Working Directory Fix – immer sichtbar
                GogWorkingDirFixRow()

                // Hinweis
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Der **App-Name** muss exakt mit dem Namen der App in Sunshine übereinstimmen. Den richtigen Namen findest du unter Spiele Server → Sunshine Apps.")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 16).padding(.bottom, 8)
            }
        }
        .onAppear { checkGogFix() }
    }

    // MARK: - Tab: Game Server

    var tabServer: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Game Server", icon: "server.rack")

            group("CRAFTY") {
                Toggle("Crafty aktivieren", isOn: $craftyEnabled).padding(.horizontal, 16)
                if craftyEnabled {
                    row("URL") { TextField("https://192.168.178.111:8443", text: $craftyURL) }
                    row("API Key") { SecureField("Crafty API Key", text: $craftyKey) }
                    HStack {
                        Button(action: testCraftyConnection) {
                            Label("Verbindung testen", systemImage: "antenna.radiowaves.left.and.right").font(.system(size: 12))
                        }.buttonStyle(.bordered).controlSize(.small)
                    }.padding(.horizontal, 16)
                    if !craftyTestResult.isEmpty {
                        Text(craftyTestResult).font(.system(size: 11))
                            .foregroundColor(craftyTestOK ? .green : .red).padding(.horizontal, 16)
                    }
                    Divider().padding(.horizontal, 16)
                    serverList(title: "Crafty Server", servers: $craftyServers) {
                        craftyServers.append(CraftyServer())
                    } onRemove: { i in craftyServers.remove(at: i) }
                }
            }

            group("NITRADO") {
                Toggle("Nitrado aktivieren", isOn: $nitradoEnabled).padding(.horizontal, 16)
                if nitradoEnabled {
                    row("API Token") { SecureField("Nitrado API Token", text: $nitradoToken) }
                    HStack {
                        Button(action: testNitradoConnection) {
                            Label("Verbindung testen", systemImage: "antenna.radiowaves.left.and.right").font(.system(size: 12))
                        }.buttonStyle(.bordered).controlSize(.small)
                    }.padding(.horizontal, 16)
                    if !nitradoTestResult.isEmpty {
                        Text(nitradoTestResult).font(.system(size: 11))
                            .foregroundColor(nitradoTestOK ? .green : .red).padding(.horizontal, 16)
                    }
                    Divider().padding(.horizontal, 16)
                    serverList(title: "Nitrado Server", servers: $nitradoServers) {
                        nitradoServers.append(NitradoServer())
                    } onRemove: { i in nitradoServers.remove(at: i) }
                }
            }
        }
    }

    // MARK: - Tab: Bibliothek

    var tabBibliothek: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Bibliothek", icon: "books.vertical")

            group("SPIELE-BACKUP (NAS)") {
                row("Verzeichnis") {
                    HStack {
                        TextField("/Volumes/NAS/Spiele/GOG Mac", text: $backupPath)
                        Button(action: selectBackupFolder) {
                            Image(systemName: "folder")
                        }.buttonStyle(.bordered).controlSize(.small)
                    }
                }
                row("Netzwerk-URL") {
                    TextField("smb://nas/Spiele  (optional, für Auto-Mount)", text: $nasURL)
                }
                Text("Erwartet: Hauptverzeichnis/Spielname/Spiel.pkg oder .dmg")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
                Text("Einmalig: Finder → 'Mit Server verbinden' (⌘K) → Passwort merken. Danach mountet die App automatisch.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
            }


            group("INSTALLATIONS-CACHE") {
                row("Cache-Ordner") {
                    HStack {
                        TextField("~/Downloads/RogueCache (optional)", text: $nasCacheDir)
                        Button(action: selectCacheFolder) {
                            Image(systemName: "folder")
                        }.buttonStyle(.bordered).controlSize(.small)
                    }
                }
                Text("PKG/DMG-Dateien werden vor der Installation hier zwischengespeichert.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
                if !nasCacheDir.isEmpty {
                    Button(action: clearCache) {
                        Label("Cache leeren", systemImage: "trash").font(.system(size: 12))
                    }.buttonStyle(.bordered).foregroundColor(.red).padding(.horizontal, 16)
                }
            }

            group("EPIC GAMES") {
                Toggle("Sektion auf Startseite anzeigen", isOn: $epicFreeGamesEnabled).padding(.horizontal, 16)
                if epicFreeGamesEnabled {
                    row("Jetzt claimen öffnet") {
                        Picker("", selection: $epicClaimMode) {
                            Text("Web Wrapper").tag("webview")
                            Text("Epic in Moonlight").tag("moonlight")
                            Text("Webhook").tag("webhook")
                            Text("Browser").tag("browser")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 320)
                    }
                    if epicClaimMode == "webhook" {
                        row("Webhook URL") { TextField("https://...", text: $epicClaimWebhookURL) }
                    } else if epicClaimMode == "browser" {
                        row("Claim URL") { TextField("https://... (leer = Epic Store)", text: $epicClaimURL) }
                    }
                }
            }

            group("IGDB (PRIMÄRE QUELLE)") {
                row("Client ID") { SecureField("Twitch/IGDB Client ID", text: $igdbID) }
                row("Client Secret") { SecureField("Twitch/IGDB Client Secret", text: $igdbSecret) }
                Text("Kostenlos: dev.twitch.tv/console → Neue App → Kategorie: Spiele")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
            }

            group("WEITERE QUELLEN") {
                row("RAWG API Key") { SecureField("rawg.io/apidocs", text: $rawgKey) }
                row("SteamGridDB Key") { SecureField("steamgriddb.com", text: $sgdbKey) }
                row("YouTube API Key") { SecureField("console.cloud.google.com", text: $youtubeKey) }
                Text("Reihenfolge: IGDB → RAWG → SteamGridDB → Steam.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
            }
        }
    }

    // MARK: - Tab: Moonlight

    var tabMoonlight: some View {
        MoonlightSettingsTab()
    }

    // MARK: - Tab: Benutzer

    var tabBenutzer: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Benutzer", icon: "person.circle")

            group("PROFIL") {
                HStack(spacing: 20) {
                    // Profilbild
                    ZStack(alignment: .bottomTrailing) {
                        Group {
                            if let path = UserDefaults.standard.string(forKey: "userProfileImagePath"),
                               let img = NSImage(contentsOfFile: path) {
                                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                ZStack {
                                    LinearGradient(colors: [Color.rogueBlue, Color.rogueNavy],
                                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                                    Text(String((UserDefaults.standard.string(forKey: "userDisplayName") ?? NSFullUserName()).prefix(1)))
                                        .font(.system(size: 32, weight: .bold)).foregroundColor(.white)
                                }
                            }
                        }
                        .frame(width: 90, height: 90).clipShape(Circle())

                        Button(action: { selectProfileImage() }) {
                            Image(systemName: "pencil.circle.fill")
                                .font(.system(size: 22)).foregroundColor(.white)
                                .background(Color.rogueBlue).clipShape(Circle())
                        }
                        .buttonStyle(.plain).offset(x: 4, y: 4)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Anzeigename").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                            TextField(NSFullUserName(), text: Binding(
                                get: { UserDefaults.standard.string(forKey: "userDisplayName") ?? NSFullUserName() },
                                set: { UserDefaults.standard.set($0, forKey: "userDisplayName") }
                            ))
                            .textFieldStyle(.roundedBorder)
                        }
                        Text("Wird verwendet wenn kein macOS-Profilname erkannt wird.")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    }
                }
                .padding(.horizontal, 16).padding(.vertical, 4)
            }

            group("PROFILBILD") {
                HStack(spacing: 12) {
                    Button("Bild auswählen…") { selectProfileImage() }.buttonStyle(.bordered)
                    if UserDefaults.standard.string(forKey: "userProfileImagePath") != nil {
                        Button("Bild entfernen") {
                            UserDefaults.standard.removeObject(forKey: "userProfileImagePath")
                        }.buttonStyle(.bordered).foregroundColor(.red)
                    }
                }.padding(.horizontal, 16)
                Text("Unterstützte Formate: PNG, JPEG, HEIC. Das Bild wird auf die Profil-Karte zugeschnitten.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
            }
        }
    }

    private func selectProfileImage() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        panel.prompt = "Auswählen"
        if panel.runModal() == .OK, let url = panel.url {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("RogueLauncher")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent("UserProfile.\(url.pathExtension)")
            try? FileManager.default.removeItem(at: dest)
            try? FileManager.default.copyItem(at: url, to: dest)
            UserDefaults.standard.set(dest.path, forKey: "userProfileImagePath")
        }
    }

    // MARK: - Tab: Emulatoren

    var tabEmulatoren: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                GroupBox {
                    Toggle(isOn: $settings.emulatorsEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Emulatoren-Tab aktivieren")
                                .font(.system(size: 13, weight: .medium))
                            Text("Zeigt einen eigenen Tab zum Importieren und Starten von ROM-Dateien.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settings.emulatorsEnabled) { _ in settings.save() }
                }

                GroupBox(label: Text("Voraussetzungen").font(.system(size: 12, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "info.circle").foregroundColor(.accentColor)
                            Text("RetroArch wird benoetigt um ROMs zu starten. Installiere es via Homebrew.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 6) {
                            Image(systemName: "terminal").foregroundColor(.secondary).font(.system(size: 11))
                            Text("brew install retroarch")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        let installed = RetroArchLauncher.isInstalled
                        HStack(spacing: 6) {
                            Image(systemName: installed ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(installed ? .green : .red)
                            Text(installed ? "RetroArch ist installiert" : "RetroArch ist nicht installiert")
                                .font(.system(size: 12))
                            Spacer()
                            if !installed {
                                Button("Im Terminal installieren") {
                                    let script = "tell application \"Terminal\" to do script \"brew install retroarch\""
                                    NSAppleScript(source: script)?.executeAndReturnError(nil)
                                }
                                .buttonStyle(.bordered).controlSize(.small)
                            }
                        }
                        Text("Cores werden automatisch unter ~/.config/retroarch/cores/ gesucht.")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 4)
                }
            }
            .padding(24)
        }
    }

    // MARK: - Tab: Launcher

    var tabLauncher: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Mac Launcher", icon: "apple.logo")

            Text("Installiere Game Launcher auf deinem Mac via Homebrew.")
                .font(.system(size: 13)).foregroundColor(.secondary)

            let launchers: [(String, String, String, String)] = [
                ("Battle.net", "Launcher für Warcraft, Overwatch, Diablo & mehr.", "battle-net", "https://battle.net"),
                ("Epic Games Launcher", "Kostenlose Spiele jeden Monat und exklusive Titel.", "epic", "https://epicgames.com"),
                ("GOG Galaxy", "DRM-freie Spiele und universelle Bibliothek.", "gog-galaxy", "https://gog.com"),
                ("League of Legends", "Das meistgespielte MOBA der Welt.", "league-of-legends", "https://leagueoflegends.com"),
                ("Moonlight", "Game Streaming Client für NVIDIA GameStream & Sunshine.", "moonlight", "https://moonlight-stream.org"),
                ("Prism Launcher", "Der beste Minecraft-Launcher mit Mod-Support.", "prismlauncher", "https://prismlauncher.org"),
                ("RetroArch", "All-in-One Emulator für klassische Spielkonsolen.", "retroarch", "https://retroarch.com"),
                ("Steam", "Der beliebteste PC-Game-Launcher mit tausenden Spielen.", "steam", "https://store.steampowered.com"),
            ]

            group("VERFÜGBARE LAUNCHER") {
                VStack(spacing: 0) {
                    ForEach(launchers, id: \.0) { name, desc, brew, url in
                        SettingsLauncherRow(name: name, description: desc, brewCask: brew, url: url)
                        if name != launchers.last?.0 { Divider().padding(.horizontal, 16) }
                    }
                }
            }
        }
    }

    // MARK: - Tab: Rogue Helper

    var tabHelper: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Rogue Helper", icon: "puzzlepiece.fill")

            group("VERBINDUNG") {
                row("Host / IP") { TextField(AppSettings.shared.pcIPAddress.isEmpty ? "192.168.178.94" : AppSettings.shared.pcIPAddress, text: $helperHost) }
                row("Port") {
                    HStack {
                        TextField("9876", text: $helperPort).frame(width: 80)
                        Spacer()
                    }
                }
                Text("Der Rogue Helper läuft auf dem Windows-PC (Moonlight-Server) auf Port 9876.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
            }

            group("AUTHENTIFIZIERUNG") {
                row("Benutzername") { TextField("Benutzername", text: $helperUser) }
                row("Passwort") { SecureField("Passwort", text: $helperPassword) }
            }

            group("VERBINDUNGSTEST") {
                HStack(spacing: 8) {
                    Button(action: testHelperConnection) {
                        Label("Verbindung testen", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered).controlSize(.small)

                    if !helperTestResult.isEmpty {
                        Button(action: {
                            helperTestResult = ""
                            helperTestOK = false
                            UserDefaults.standard.removeObject(forKey: "helperLastStatus")
                            UserDefaults.standard.removeObject(forKey: "helperLastOK")
                        }) {
                            Image(systemName: "xmark.circle")
                                .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                        .help("Verbindungsstatus zurücksetzen")
                    }
                    Spacer()
                }
                .padding(.horizontal, 16)

                if !helperTestResult.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: helperTestOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(helperTestOK ? .green : .red)
                        Text(helperTestResult)
                            .font(.system(size: 11))
                            .foregroundColor(helperTestOK ? .green : .red)
                    }
                    .padding(.horizontal, 16)
                }
            }
        }
    }

    private func checkSteamLoginStatus() {
        guard let req = HelperAPI.shared.request("/steam/login/status") else { return }
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                steamLoginOK = json["logged_in"] as? Bool ?? false
                if let user = json["username"] as? String, !user.isEmpty {
                    steamLoginUser = user
                }
            }
        }.resume()
    }

    private func startSteamLogin() {
        guard let req = HelperAPI.shared.request(
            "/steam/login/start", method: "POST",
            body: ["username": steamLoginUser, "password": steamLoginPass]
        ) else { return }
        steamLoginPolling = true
        steamLoginStatus = "Verbinde mit steamcmd…"
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                steamLoginPass = "" // Passwort sofort löschen
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    steamLoginPolling = false; return
                }
                steamLoginJobID = json["job_id"] as? String
                pollSteamLoginStatus()
            }
        }.resume()
    }

    private func pollSteamLoginStatus() {
        guard let jobID = steamLoginJobID,
              let req = HelperAPI.shared.request("/steam/login/progress/\(jobID)") else { return }
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
                let status = json["status"] as? String ?? ""
                switch status {
                case "needs_2fa":
                    steamLoginStatus = "needs_2fa"
                    steamLoginPolling = false
                case "success":
                    steamLoginOK = true
                    steamLoginStatus = ""
                    steamLoginPolling = false
                    steamLoginJobID = nil
                case "error":
                    steamLoginStatus = "✗ Fehler: \(json["output"] as? String ?? "")"
                    steamLoginPolling = false
                default:
                    steamLoginStatus = json["output"] as? String ?? "Lädt…"
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) { pollSteamLoginStatus() }
                }
            }
        }.resume()
    }

    private func submitSteamLogin2FA() {
        guard let jobID = steamLoginJobID,
              let req = HelperAPI.shared.request(
                "/steam/login/2fa", method: "POST",
                body: ["job_id": jobID, "code": steamLogin2FACode]
              ) else { return }
        steamLogin2FACode = ""
        steamLoginStatus = "Code wird übermittelt…"
        steamLoginPolling = true
        HelperAPI.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async { pollSteamLoginStatus() }
        }.resume()
    }

    private func testHelperConnection() {
        helperTestResult = "Verbinde…"
        helperTestOK = false
        let host = helperHost.isEmpty ? AppSettings.shared.pcIPAddress : helperHost
        let port = helperPort.isEmpty ? "9876" : helperPort
        guard let url = URL(string: "https://\(host):\(port)/status") else {
            helperTestResult = "✗ Ungültige URL"
            return
        }
        var request = URLRequest(url: url, timeoutInterval: 5)
        if !helperUser.isEmpty {
            let creds = "\(helperUser):\(helperPassword)"
            if let data = creds.data(using: .utf8) {
                request.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }
        let session = URLSession(configuration: .default, delegate: SelfSignedDelegate(), delegateQueue: nil)
        session.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                if let error = error {
                    helperTestResult = "✗ \(error.localizedDescription)"
                    helperTestOK = false
                    UserDefaults.standard.set(helperTestResult, forKey: "helperLastStatus")
                    UserDefaults.standard.set(false, forKey: "helperLastOK")
                } else if let http = response as? HTTPURLResponse, http.statusCode == 200 {
                    if let data = data,
                       let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                       let pc = json["pc_name"] as? String {
                        helperTestResult = "Verbunden mit \(pc)"
                    } else {
                        helperTestResult = "Helper erreichbar"
                    }
                    helperTestOK = true
                    UserDefaults.standard.set(helperTestResult, forKey: "helperLastStatus")
                    UserDefaults.standard.set(true, forKey: "helperLastOK")
                } else {
                    helperTestResult = "✗ HTTP \((response as? HTTPURLResponse)?.statusCode ?? 0)"
                    helperTestOK = false
                    UserDefaults.standard.set(helperTestResult, forKey: "helperLastStatus")
                    UserDefaults.standard.set(false, forKey: "helperLastOK")
                }
            }
        }.resume()
    }

    // MARK: - Tab: Sunshine

    var tabSunshine: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Sunshine", icon: "sun.max.fill")

            group("SUNSHINE ZUGANGSDATEN") {
                Text("Diese Daten werden an den Rogue Helper weitergegeben damit er Sunshine lokal ansprechen kann.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)
                row("Benutzername") { TextField("Sunshine-Benutzername", text: $sunshineUser) }
                row("Passwort") { SecureField("Passwort", text: $sunshinePassword) }
                HStack {
                    Button(action: saveSunshineCredentials) {
                        Label("An Helper übertragen", systemImage: "arrow.up.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!HelperAPI.shared.isConfigured)
                    Spacer()
                }
                .padding(.horizontal, 16)
            }

            group("VERBINDUNG") {
                Text("Sunshine wird über den Rogue Helper angesprochen — kein direkter Zugriff vom Mac nötig.")
                    .font(.system(size: 11)).foregroundColor(.secondary).padding(.horizontal, 16)

                HStack(spacing: 8) {
                    Button(action: testSunshineConnection) {
                        Label("Verbindung testen", systemImage: "antenna.radiowaves.left.and.right")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!HelperAPI.shared.isConfigured)
                    Spacer()
                }
                .padding(.horizontal, 16)

                if !sunshineTestResult.isEmpty {
                    HStack(spacing: 6) {
                        Image(systemName: sunshineTestOK ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(sunshineTestOK ? .green : .red)
                        Text(sunshineTestResult)
                            .font(.system(size: 11))
                            .foregroundColor(sunshineTestOK ? .green : .red)
                    }
                    .padding(.horizontal, 16)
                }

                if !HelperAPI.shared.isConfigured {
                    Text("⚠️ Bitte zuerst den Rogue Helper konfigurieren.")
                        .font(.system(size: 11)).foregroundColor(.orange).padding(.horizontal, 16)
                }
            }

            group("KONFIGURATION") {
                if sunshineCfgLoading {
                    HStack { Spacer(); ProgressView().frame(width: 20, height: 20); Spacer() }
                        .padding(.vertical, 8)
                } else {
                    row("Auflösung") {
                        HStack(spacing: 6) {
                            TextField("1920", text: $sunshineCfgResW)
                                .frame(width: 70)
                            Text("×").foregroundColor(.secondary)
                            TextField("1080", text: $sunshineCfgResH)
                                .frame(width: 70)
                        }
                    }
                    row("FPS") {
                        TextField("60", text: $sunshineCfgFPS).frame(width: 70)
                    }
                    row("Bitrate (kbps)") {
                        TextField("10000", text: $sunshineCfgBitrate).frame(width: 100)
                    }
                    row("Encoder") {
                        Picker("", selection: $sunshineCfgEncoder) {
                            Text("Auto").tag("auto")
                            Text("NVENC (NVIDIA)").tag("nvenc")
                            Text("AMF (AMD)").tag("amf")
                            Text("QuickSync (Intel)").tag("quicksync")
                            Text("Software (x264)").tag("software")
                        }
                        .labelsHidden().frame(width: 180)
                    }
                    row("Port") {
                        TextField("47989", text: $sunshineCfgPort).frame(width: 80)
                    }
                    row("UPnP") {
                        Picker("", selection: $sunshineCfgUpnp) {
                            Text("Aktiviert").tag("on")
                            Text("Deaktiviert").tag("off")
                        }
                        .labelsHidden().pickerStyle(.segmented).frame(width: 160)
                    }
                }
                HStack(spacing: 8) {
                    Button(action: loadSunshineCfg) {
                        Label("Laden", systemImage: "arrow.down.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.bordered).controlSize(.small)
                    .disabled(!HelperAPI.shared.isConfigured)

                    Button(action: saveSunshineCfg) {
                        Label("Speichern", systemImage: "checkmark.circle")
                            .font(.system(size: 12))
                    }
                    .buttonStyle(.borderedProminent).tint(.rogueRed).controlSize(.small)
                    .disabled(!HelperAPI.shared.isConfigured || sunshineCfgLoading)

                    if !sunshineCfgSaveMsg.isEmpty {
                        Text(sunshineCfgSaveMsg)
                            .font(.system(size: 11))
                            .foregroundColor(sunshineCfgSaveMsg.hasPrefix("✓") ? .green : .red)
                    }
                    Spacer()
                }
                .padding(.horizontal, 16).padding(.bottom, 4)
            }
        }
        .onAppear { if HelperAPI.shared.isConfigured { loadSunshineApps(); loadSunshineCfg() } }
    }

    private func saveSunshineCredentials() {
        guard let req = HelperAPI.shared.request(
            "/config", method: "POST",
            body: ["sunshine_user": sunshineUser, "sunshine_password": sunshinePassword]
        ) else { return }
        HelperAPI.shared.dataTask(with: req) { _, _, _ in
            DispatchQueue.main.async { sunshineTestResult = "✓ Zugangsdaten übertragen" }
        }.resume()
    }

    private func testSunshineConnection() {
        guard let req = HelperAPI.shared.request("/sunshine/status") else { return }
        HelperAPI.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                if let error = error {
                    sunshineTestResult = "✗ \(error.localizedDescription)"
                    sunshineTestOK = false
                } else if let data = data,
                          let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                          let running = json["running"] as? Bool, running {
                    sunshineTestResult = "Verbunden — Sunshine läuft"
                    sunshineTestOK = true
                    loadSunshineApps()
                } else {
                    sunshineTestResult = "✗ Sunshine nicht erreichbar"
                    sunshineTestOK = false
                }
            }
        }.resume()
    }

    private func loadSunshineCfg() {
        guard let req = HelperAPI.shared.request("/sunshine/config") else { return }
        sunshineCfgLoading = true
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                sunshineCfgLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let cfg = json["config"] as? [String: Any] else { return }
                if let res = cfg["resolution"] as? String {
                    let parts = res.split(separator: "x")
                    sunshineCfgResW = parts.first.map(String.init) ?? ""
                    sunshineCfgResH = parts.last.map(String.init) ?? ""
                }
                sunshineCfgFPS     = cfg["fps"] as? String ?? (cfg["fps"] as? Int).map(String.init) ?? ""
                sunshineCfgBitrate = cfg["bitrate"] as? String ?? (cfg["bitrate"] as? Int).map(String.init) ?? ""
                sunshineCfgEncoder = cfg["encoder"] as? String ?? "auto"
                sunshineCfgPort    = cfg["port"] as? String ?? (cfg["port"] as? Int).map(String.init) ?? ""
                sunshineCfgUpnp    = cfg["upnp"] as? String ?? "off"
            }
        }.resume()
    }

    private func saveSunshineCfg() {
        var body: [String: String] = [:]
        if !sunshineCfgResW.isEmpty && !sunshineCfgResH.isEmpty {
            body["resolution"] = "\(sunshineCfgResW)x\(sunshineCfgResH)"
        }
        if !sunshineCfgFPS.isEmpty     { body["fps"] = sunshineCfgFPS }
        if !sunshineCfgBitrate.isEmpty { body["bitrate"] = sunshineCfgBitrate }
        if !sunshineCfgEncoder.isEmpty { body["encoder"] = sunshineCfgEncoder }
        if !sunshineCfgPort.isEmpty    { body["port"] = sunshineCfgPort }
        if !sunshineCfgUpnp.isEmpty    { body["upnp"] = sunshineCfgUpnp }

        guard let req = HelperAPI.shared.request("/sunshine/config", method: "POST", body: body) else { return }
        sunshineCfgLoading = true
        HelperAPI.shared.dataTask(with: req) { _, _, error in
            DispatchQueue.main.async {
                sunshineCfgLoading = false
                if error == nil {
                    sunshineCfgSaveMsg = "✓ Gespeichert"
                } else {
                    sunshineCfgSaveMsg = "✗ Fehler beim Speichern"
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) { sunshineCfgSaveMsg = "" }
            }
        }.resume()
    }

    private func checkGogFix() {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/sunshine/apps") else { return }
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let apps = json["apps"] as? [[String: Any]] else { return }
            let gog = apps.first {
                ($0["name"] as? String ?? "").lowercased().contains("galaxyclient")
                || ($0["cmd"]  as? String ?? "").lowercased().contains("galaxyclient")
            }
            DispatchQueue.main.async {
                guard let gog else { gogFixStatus = .noEntry; return }
                let wd = gog["working-dir"] as? String ?? gog["working_dir"] as? String ?? ""
                gogFixStatus = wd.isEmpty ? .needsFix : .fixed
            }
        }.resume()
    }

    private func applyGogFix() {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/sunshine/apps") else { return }
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let apps = json["apps"] as? [[String: Any]],
                  // Nach Name "GOG GALAXY" oder "GalaxyClient" suchen (nicht nach cmd!)
                  let gog = apps.first(where: {
                      let name = ($0["name"] as? String ?? "").lowercased()
                      return name.contains("gog galaxy") || name.contains("galaxyclient")
                  }),
                  let appID = gog["id"] as? Int else { return }

            let name      = gog["name"] as? String ?? "GOG GALAXY"
            let imagePath = gog["image-path"] as? String ?? gog["image_path"] as? String ?? ""
            // Immer GalaxyClient.exe verwenden — nie vom alten cmd übernehmen (könnte unins000.exe sein!)
            let fixedCmd  = "cmd /c \"cd /d \\\"C:\\Program Files (x86)\\GOG Galaxy\\\" && GalaxyClient.exe\""

            guard let deleteReq = HelperAPI.shared.request("/sunshine/apps/\(appID)", method: "DELETE") else { return }
            HelperAPI.shared.dataTask(with: deleteReq) { _, _, _ in
                // Kurz warten damit Sunshine den Eintrag verarbeitet
                Thread.sleep(forTimeInterval: 0.5)
                var body: [String: Any] = ["name": name, "cmd": fixedCmd]
                if !imagePath.isEmpty { body["image_path"] = imagePath }
                guard let addReq = HelperAPI.shared.request("/sunshine/apps/add", method: "POST", body: body) else { return }
                HelperAPI.shared.dataTask(with: addReq) { _, _, _ in
                    DispatchQueue.main.async { gogFixStatus = .fixed }
                }.resume()
            }.resume()
        }.resume()
    }

    private func loadSunshineApps() {
        guard let req = HelperAPI.shared.request("/sunshine/apps") else { return }
        sunshineAppsLoading = true
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                sunshineAppsLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let apps = json["apps"] as? [[String: Any]] else { return }
                sunshineApps = apps
            }
        }.resume()
    }

    // MARK: - Tab: Import/Export

    var tabImportExport: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Import / Export", icon: "square.and.arrow.up.on.square")

            group("EINSTELLUNGEN EXPORTIEREN") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exportiert alle Einstellungen als JSON-Datei (ohne API-Keys).")
                        .font(.system(size: 12)).foregroundColor(.secondary).padding(.horizontal, 16)
                    Button(action: exportSettings) {
                        Label("Einstellungen exportieren…", systemImage: "square.and.arrow.up")
                    }.buttonStyle(.bordered).padding(.horizontal, 16)
                }
            }

            group("EINSTELLUNGEN IMPORTIEREN") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Importiert eine zuvor exportierte Einstellungsdatei.")
                        .font(.system(size: 12)).foregroundColor(.secondary).padding(.horizontal, 16)
                    Button(action: importSettings) {
                        Label("Einstellungen importieren…", systemImage: "square.and.arrow.down")
                    }.buttonStyle(.bordered).padding(.horizontal, 16)
                }
            }

            group("SPIELEBIBLIOTHEK") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Exportiert die gesamte Spielebibliothek als JSON (Name, Genre, Cover-Pfade).")
                        .font(.system(size: 12)).foregroundColor(.secondary).padding(.horizontal, 16)
                    HStack(spacing: 12) {
                        Button(action: exportLibrary) {
                            Label("Bibliothek exportieren…", systemImage: "square.and.arrow.up")
                        }.buttonStyle(.bordered)
                        Button(action: importLibrary) {
                            Label("Bibliothek importieren…", systemImage: "square.and.arrow.down")
                        }.buttonStyle(.bordered)
                    }.padding(.horizontal, 16)
                    Text("⚠️ Import überschreibt die bestehende Bibliothek.")
                        .font(.system(size: 11)).foregroundColor(.orange).padding(.horizontal, 16)
                }
            }
        }
    }

    private func exportSettings() {
        let s = AppSettings.shared
        let dict: [String: Any] = [
            "pcIPAddress": s.pcIPAddress,
            "pcMACAddress": s.pcMACAddress,
            "moonlightPort": s.moonlightPort,
            "wakeMethod": s.wakeMethod.rawValue,
            "craftyEnabled": s.craftyEnabled,
            "craftyURL": s.craftyURL,
            "nitradoEnabled": s.nitradoEnabled,
            "backupPath": s.backupPath,
            "epicFreeGamesEnabled": s.epicFreeGamesEnabled,
            "epicClaimURL": s.epicClaimURL,
        ]
        let panel = NSSavePanel()
        panel.nameFieldStringValue = "RogueLauncher-Settings.json"
        panel.allowedContentTypes = [.json]
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? JSONSerialization.data(withJSONObject: dict, options: .prettyPrinted) {
            try? data.write(to: url)
        }
    }

    private func importSettings() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url,
           let data = try? Data(contentsOf: url),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let s = AppSettings.shared
            if let v = dict["pcIPAddress"] as? String { s.pcIPAddress = v }
            if let v = dict["pcMACAddress"] as? String { s.pcMACAddress = v }
            if let v = dict["moonlightPort"] as? Int { s.moonlightPort = v }
            if let v = dict["craftyEnabled"] as? Bool { s.craftyEnabled = v }
            if let v = dict["craftyURL"] as? String { s.craftyURL = v }
            if let v = dict["nitradoEnabled"] as? Bool { s.nitradoEnabled = v }
            if let v = dict["backupPath"] as? String { s.backupPath = v }
            if let v = dict["epicFreeGamesEnabled"] as? Bool { s.epicFreeGamesEnabled = v }
            if let v = dict["epicClaimURL"] as? String { s.epicClaimURL = v }
            s.save()
            populate()
        }
    }

    private func exportLibrary() {
        // GameStore via Notification anstoßen
        NotificationCenter.default.post(name: Notification.Name("exportLibrary"), object: nil)
    }

    private func importLibrary() {
        NotificationCenter.default.post(name: Notification.Name("importLibrary"), object: nil)
    }

    // MARK: - Tab: Scripte

    @StateObject private var scriptStore = CustomScriptStore.shared
    @State private var editingScript: CustomScript? = nil
    @State private var showAddScript = false
    @State private var newScriptName = ""
    @State private var newScriptPath = ""
    @State private var newScriptSymbol = "terminal"
    @State private var newScriptTopNav = true
    @State private var helperScripts: [HelperScript] = []
    @State private var isFetchingHelperScripts = false
    @State private var selectedHelperScript: HelperScript? = nil
    @State private var scriptRunResult: String? = nil

    let commonSymbols = [
        "terminal", "bolt.fill", "play.fill", "arrow.clockwise",
        "laptopcomputer",
        "trash", "folder", "doc", "wrench.and.screwdriver",
        "gear", "cpu", "network", "wifi", "display",
        "powerplug", "gamecontroller", "music.note", "camera"
    ]

    var tabScripte: some View {
        VStack(alignment: .leading, spacing: 20) {
            tabHeader("Scripte", icon: "terminal")

            group("SCRIPTE") {
                if scriptStore.scripts.isEmpty {
                    Text("Keine Scripte vorhanden.")
                        .foregroundColor(.secondary)
                        .font(.system(size: 12))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                } else {
                    ForEach(scriptStore.scripts) { script in
                        HStack(spacing: 10) {
                            Image(systemName: script.symbol)
                                .frame(width: 20)
                                .foregroundColor(.rogueRed)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(script.name).font(.system(size: 13, weight: .medium))
                                Text(script.path).font(.system(size: 10)).foregroundColor(.secondary).lineLimit(1)
                            }
                            Spacer()
                            if script.showInTopNav {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.secondary)
                            }
                            Button("Bearbeiten") { editingScript = script }
                                .buttonStyle(.bordered).controlSize(.small)
                            Button(role: .destructive) {
                                if let i = scriptStore.scripts.firstIndex(where: { $0.id == script.id }) {
                                    scriptStore.delete(at: IndexSet([i]))
                                }
                            } label: { Image(systemName: "trash") }
                                .buttonStyle(.bordered).controlSize(.small)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                        Divider().padding(.leading, 16)
                    }
                }
                Button(action: {
                    newScriptName = ""; newScriptPath = ""
                    newScriptSymbol = "terminal"; newScriptTopNav = true
                    showAddScript = true
                }) {
                    Label("Script hinzufügen", systemImage: "plus")
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
        }
        .sheet(isPresented: $showAddScript) {
            scriptEditSheet(
                title: "Script hinzufügen",
                name: $newScriptName,
                path: $newScriptPath,
                symbol: $newScriptSymbol,
                topNav: $newScriptTopNav,
                onSave: {
                    let s = CustomScript(name: newScriptName, path: newScriptPath,
                                        symbol: newScriptSymbol, showInTopNav: newScriptTopNav)
                    scriptStore.add(s)
                    showAddScript = false
                },
                onCancel: { showAddScript = false }
            )
            .onAppear {
                isFetchingHelperScripts = true
                HelperAPI.shared.fetchScripts { list in
                    helperScripts = list
                    isFetchingHelperScripts = false
                }
            }
        }
        .sheet(item: $editingScript) { script in
            ScriptEditSheetWrapper(script: script, store: scriptStore)
        }
    }

    private func scriptEditSheet(title: String, name: Binding<String>, path: Binding<String>,
                                  symbol: Binding<String>, topNav: Binding<Bool>,
                                  onSave: @escaping () -> Void, onCancel: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(title).font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    TextField("z.B. Restart Server", text: name).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Script vom Helper").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            isFetchingHelperScripts = true
                            HelperAPI.shared.fetchScripts { list in
                                helperScripts = list
                                isFetchingHelperScripts = false
                            }
                        }) {
                            if isFetchingHelperScripts {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Label("Laden", systemImage: "arrow.clockwise")
                                    .font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                    if helperScripts.isEmpty {
                        Text("Klicke \'Laden\' um verfügbare Scripte vom Helper abzurufen")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    } else {
                        Picker("Script wählen", selection: $selectedHelperScript) {
                            Text("– bitte wählen –").tag(Optional<HelperScript>.none)
                            ForEach(helperScripts) { hs in
                                Text(hs.name).tag(Optional(hs))
                            }
                        }
                        .onChange(of: selectedHelperScript) { _, hs in
                            if let hs = hs {
                                path.wrappedValue = hs.path
                                if name.wrappedValue.isEmpty { name.wrappedValue = hs.name }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dateipfad").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    TextField("C:\\scripts\\foo.bat", text: path).textFieldStyle(.roundedBorder)
                    Text("Wird automatisch ausgefüllt wenn Script oben gewählt")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 9), spacing: 8) {
                        ForEach(commonSymbols, id: \.self) { sym in
                            Button(action: { symbol.wrappedValue = sym }) {
                                Image(systemName: sym)
                                    .font(.system(size: 15))
                                    .frame(width: 36, height: 36)
                                    .background(symbol.wrappedValue == sym
                                                ? Color.rogueRed.opacity(0.2)
                                                : Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .foregroundColor(symbol.wrappedValue == sym ? .rogueRed : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Toggle("In TopNav anzeigen", isOn: topNav)
            }

            HStack {
                Spacer()
                Button("Abbrechen", action: onCancel).keyboardShortcut(.escape)
                Button("Speichern", action: onSave)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.wrappedValue.isEmpty || path.wrappedValue.isEmpty)
            }
        }
        .padding(28)
        .frame(minWidth: 480, idealWidth: 500)
    }

    // MARK: - Tab: Konsolen

    @State private var showConsoleWizard = false

    var tabKonsolen: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Enable Toggle
                GroupBox {
                    Toggle(isOn: $settings.consolesEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Konsolen-Funktion aktivieren")
                                .font(.system(size: 13, weight: .medium))
                            Text("Zeigt einen eigenen Tab zum Importieren von Konsolenspielen.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                    .onChange(of: settings.consolesEnabled) { _ in
                        settings.save()
                        MenuBarManager.shared.refresh()
                    }
                }

                // Voraussetzungen
                GroupBox(label: Text("Voraussetzungen").font(.system(size: 12, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Für die Display-Umschaltung werden folgende Tools benötigt:")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                        HStack(spacing: 6) {
                            Image(systemName: "terminal")
                                .foregroundColor(.secondary)
                            Text("brew install m1ddc displayplacer")
                                .font(.system(size: 12, design: .monospaced))
                        }
                        .padding(8)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                        Button("Im Terminal öffnen") {
                            let script = "tell application \"Terminal\" to do script \"brew install m1ddc displayplacer\""
                            NSAppleScript(source: script)?.executeAndReturnError(nil)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.top, 4)
                }

                // Display-Einrichtung
                GroupBox(label: Text("Display-Einrichtung").font(.system(size: 12, weight: .semibold))) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle")
                                .foregroundColor(.orange).font(.system(size: 11))
                            Text("Wichtig: Deaktiviere im Monitor-OSD \"Auto Input Switch\" / \"Auto Source Detection\", damit der Monitor beim Umschalten nicht automatisch zurückspringt.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(8)
                        .background(Color.orange.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        if settings.hdmiInputMap.isEmpty {
                            Text("Noch nicht eingerichtet. Starte den Wizard um deine Anschlüsse zuzuordnen.")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 4) {
                                ForEach(Array(settings.hdmiInputMap.keys.sorted()), id: \.self) { k in
                                    HStack {
                                        Text("HDMI \(k == "17" ? "1" : "2") (Eingang \(k)):")
                                            .foregroundColor(.secondary)
                                        Text(settings.hdmiInputMap[k] ?? "")
                                            .fontWeight(.medium)
                                    }
                                    .font(.system(size: 12))
                                }
                                HStack {
                                    Text("Mac-Eingang:").foregroundColor(.secondary)
                                    Text("\(settings.macInputNumber)")
                                        .fontWeight(.medium)
                                }
                                .font(.system(size: 12))
                            }
                        }

                        Button(action: { showConsoleWizard = true }) {
                            Label(settings.hdmiInputMap.isEmpty ? "Einrichtung starten" : "Erneut einrichten",
                                  systemImage: "display.2")
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(Color.rogueRed)
                        .controlSize(.small)
                        .sheet(isPresented: $showConsoleWizard) {
                            DisplaySetupWizard()
                        }
                    }
                    .padding(.top, 4)
                }
            }
            .padding(20)
        }
    }

    // MARK: - Tab: Über

    var tabUeber: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                tabHeader("Über Rogue Launcher", icon: "info.circle")

                // App Info
                VStack(alignment: .leading, spacing: 8) {
                    Text("Rogue Launcher")
                        .font(.system(size: 18, weight: .bold))
                    Text("Gebaut von Christian Sielaff mit der Hilfe von Claude (Anthropic).")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("Ein persönlicher Game-Launcher für Moonlight/Sunshine-Streaming und lokale macOS-Spiele. Kostenlos, Open Source, ohne Werbung.")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Rechtliches / Disclaimer
                VStack(alignment: .leading, spacing: 10) {
                    Label("Rechtlicher Hinweis", systemImage: "shield")
                        .font(.system(size: 13, weight: .semibold))
                    VStack(alignment: .leading, spacing: 6) {
                        disclaimerRow("Spielcover & Metadaten werden dynamisch von IGDB, Steam und weiteren Diensten geladen. Das Copyright liegt bei den jeweiligen Publishern und Rechteinhabern.")
                        disclaimerRow("Rogue Launcher ist kein offizielles Produkt von Steam, Epic Games, GOG, Ubisoft, EA, Moonlight oder anderen genannten Diensten.")
                        disclaimerRow("Die App wird kostenlos und ohne Gewinnerzielungsabsicht angeboten.")
                        disclaimerRow("Moonlight ist Open Source (GPL). Rogue Launcher nutzt ausschließlich die öffentliche Binary ohne Modifikation.")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Datenquellen
                VStack(alignment: .leading, spacing: 10) {
                    Label("Datenquellen & Dienste", systemImage: "externaldrive.connected.to.line.below")
                        .font(.system(size: 13, weight: .semibold))
                    VStack(alignment: .leading, spacing: 6) {
                        creditRow(name: "IGDB", description: "Spieledatenbank (Cover, Metadaten, Screenshots)", url: "igdb.com")
                        creditRow(name: "RAWG", description: "Altersfreigabe & Genre", url: "rawg.io")
                        creditRow(name: "SteamGridDB", description: "Cover & Artwork", url: "steamgriddb.com")
                        creditRow(name: "Steam", description: "Spieleinfos & Cover", url: "store.steampowered.com")
                        creditRow(name: "Epic Games Store", description: "Kostenlose Spiele", url: "store.epicgames.com")
                        creditRow(name: "Moonlight", description: "Open-Source Game Streaming Client (GPL)", url: "moonlight-stream.org")
                        creditRow(name: "Claude (Anthropic)", description: "KI-Assistent bei der Entwicklung", url: "anthropic.com")
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .padding(16)
        }
    }

    private func disclaimerRow(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - Helpers

    private func tabHeader(_ title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon).font(.system(size: 18)).foregroundColor(Color.rogueRed)
            Text(title).font(.system(size: 18, weight: .bold))
        }
    }

    private func group<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                .padding(.horizontal, 4)
            VStack(alignment: .leading, spacing: 10) { content() }
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.secondary.opacity(0.1), lineWidth: 1))
        }
    }

    private func row<Content: View>(_ label: String, @ViewBuilder field: () -> Content) -> some View {
        HStack(spacing: 12) {
            Text(label).font(.system(size: 13)).frame(width: 120, alignment: .leading)
            field().textFieldStyle(.roundedBorder)
        }.padding(.horizontal, 16)
    }

    private func serverList<S: ServerProtocol>(title: String, servers: Binding<[S]>, onAdd: @escaping () -> Void, onRemove: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.system(size: 12, weight: .semibold)).foregroundColor(.secondary).padding(.horizontal, 16)
            ForEach(servers.wrappedValue.indices, id: \.self) { i in
                HStack(spacing: 8) {
                    TextField("Name", text: servers[i].name).textFieldStyle(.roundedBorder)
                    TextField("ID", text: servers[i].serverID).textFieldStyle(.roundedBorder).frame(width: 110)
                    Button(action: { onRemove(i) }) {
                        Image(systemName: "minus.circle").foregroundColor(.red)
                    }.buttonStyle(.plain)
                }.padding(.horizontal, 16)
            }
            Button(action: onAdd) {
                Label("Server hinzufügen", systemImage: "plus.circle").font(.system(size: 12))
            }.buttonStyle(.plain).foregroundColor(.accentColor).padding(.horizontal, 16)
        }
    }

    private func creditRow(name: String, description: String, url: String) -> some View {
        HStack(spacing: 6) {
            Text("•").foregroundColor(.secondary).font(.system(size: 11))
            Text(name).font(.system(size: 11, weight: .semibold))
            Text("–").foregroundColor(.secondary).font(.system(size: 11))
            Text(description).font(.system(size: 11)).foregroundColor(.secondary)
            Spacer()
            Button(url) { if let u = URL(string: "https://\(url)") { NSWorkspace.shared.open(u) } }
                .buttonStyle(.plain).font(.system(size: 10)).foregroundColor(.blue)
        }
    }

    private var statusColor: Color {
        switch monitor.status { case .online: .green; case .offline: .red; case .checking: .orange }
    }
    private var statusText: String {
        switch monitor.status { case .online: "PC ist online"; case .offline: "PC ist offline"; case .checking: "Wird geprüft…" }
    }

    private func wakePC() {
        if wakeMethod == .webhook && !webhookURL.isEmpty { AppSettings.fireWebhook(webhookURL) }
        else { WakeOnLan.send(mac: mac) }
    }

    private func selectCacheFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = "Auswählen"
        if panel.runModal() == .OK, let url = panel.url { nasCacheDir = url.path }
    }

    private func clearCache() {
        guard !nasCacheDir.isEmpty else { return }
        let contents = (try? FileManager.default.contentsOfDirectory(atPath: nasCacheDir)) ?? []
        for file in contents where file.hasSuffix(".pkg") || file.hasSuffix(".dmg") {
            try? FileManager.default.removeItem(atPath: (nasCacheDir as NSString).appendingPathComponent(file))
        }
    }

    private func selectBackupFolder() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false; panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false; panel.prompt = "Auswählen"
        if panel.runModal() == .OK, let url = panel.url { backupPath = url.path }
    }

    private func testCraftyConnection() {
        AppSettings.shared.craftyURL = craftyURL; AppSettings.shared.craftyAPIKey = craftyKey
        craftyTestResult = "Verbinde..."; craftyTestOK = false
        GameServerService.craftyRequest(path: "/servers/list") { result in
            switch result {
            case .success: craftyTestResult = "✓ Verbindung erfolgreich"; craftyTestOK = true
            case .failure(let e): craftyTestResult = "✗ \(e.localizedDescription)"; craftyTestOK = false
            }
        }
    }

    private func testNitradoConnection() {
        AppSettings.shared.nitradoAPIToken = nitradoToken
        nitradoTestResult = "Verbinde..."; nitradoTestOK = false
        GameServerService.nitradoRequest(path: "/user") { result in
            switch result {
            case .success:
                nitradoTestResult = "✓ Verbindung erfolgreich"; nitradoTestOK = true
            case .failure(let e):
                nitradoTestResult = "✗ \(e.localizedDescription)"; nitradoTestOK = false
            }
        }
    }

    private func populate() {
        ip = settings.pcIPAddress; mac = settings.pcMACAddress; port = settings.moonlightPort
        moonlightHostOverride = settings.moonlightHostOverride
        wakeMethod = settings.wakeMethod; webhookURL = settings.webhookURL
        shutdownMethod = settings.shutdownMethod; shutdownWebhookURL = settings.shutdownWebhookURL
        sleepWebhook = settings.sleepWebhookURL
        sleepMethod = settings.sleepMethod
        helperHost = settings.helperHost
        helperPort = settings.helperPort
        gameLaunchers = settings.gameLaunchers
        helperUser = settings.helperUser
        helperPassword = settings.helperPassword
        sunshineHost = settings.sunshineHost
        sunshinePort = settings.sunshinePort
        sunshineUser = settings.sunshineUser
        sunshinePassword = settings.sunshinePassword
        craftyEnabled = settings.craftyEnabled; craftyURL = settings.craftyURL
        craftyKey = settings.craftyAPIKey; craftyServers = settings.craftyServers
        nitradoEnabled = settings.nitradoEnabled; nitradoToken = settings.nitradoAPIToken
        nitradoServers = settings.nitradoServers
        backupPath = settings.backupPath
        nasURL = settings.nasURL
        nasCacheDir = settings.nasCacheDir
        epicClaimURL = settings.epicClaimURL; epicClaimMode = settings.epicClaimMode; epicClaimWebhookURL = settings.epicClaimWebhookURL; epicFreeGamesEnabled = settings.epicFreeGamesEnabled
        igdbID = settings.igdbClientID; igdbSecret = settings.igdbClientSecret; youtubeKey = settings.youtubeAPIKey
        rawgKey = settings.rawgAPIKey; sgdbKey = settings.steamGridDBKey
    }

    private func saveAll() {
        settings.pcIPAddress = ip; settings.pcMACAddress = mac; settings.moonlightPort = port
        settings.moonlightHostOverride = moonlightHostOverride
        settings.wakeMethod = wakeMethod; settings.webhookURL = webhookURL
        settings.shutdownMethod = shutdownMethod; settings.shutdownWebhookURL = shutdownWebhookURL
        settings.sleepWebhookURL = sleepWebhook
        settings.sleepMethod = sleepMethod
        settings.helperHost = helperHost
        settings.gameLaunchers = gameLaunchers
        settings.helperPort = helperPort
        settings.helperUser = helperUser
        settings.helperPassword = helperPassword
        settings.sunshineHost = sunshineHost
        settings.sunshinePort = sunshinePort
        settings.sunshineUser = sunshineUser
        settings.sunshinePassword = sunshinePassword
        settings.craftyEnabled = craftyEnabled; settings.craftyURL = craftyURL
        settings.craftyAPIKey = craftyKey; settings.craftyServers = craftyServers
        settings.nitradoEnabled = nitradoEnabled; settings.nitradoAPIToken = nitradoToken
        settings.nitradoServers = nitradoServers
        settings.backupPath = backupPath
        settings.nasURL = nasURL
        settings.nasCacheDir = nasCacheDir
        settings.epicClaimURL = epicClaimURL; settings.epicClaimMode = epicClaimMode; settings.epicClaimWebhookURL = epicClaimWebhookURL; settings.epicFreeGamesEnabled = epicFreeGamesEnabled
        settings.igdbClientID = igdbID; settings.igdbClientSecret = igdbSecret; settings.youtubeAPIKey = youtubeKey
        settings.rawgAPIKey = rawgKey; settings.steamGridDBKey = sgdbKey
        GameMetadataService.invalidateToken()
        settings.save()
        saved = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saved = false }
        monitor.checkNow()
    }
}

// Protocol für generische Server-Liste
protocol ServerProtocol {
    var name: String { get set }
    var serverID: String { get set }
}
extension CraftyServer: ServerProtocol {}
extension NitradoServer: ServerProtocol {}

struct SettingsLauncherRow: View {
    let name: String
    let description: String
    let brewCask: String
    let url: String

    @State private var installing = false
    @State private var installed = false
    @State private var output = ""

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text(name).font(.system(size: 13, weight: .semibold))
                Text(description).font(.system(size: 11)).foregroundColor(.secondary)
                if !output.isEmpty {
                    Text(output).font(.system(size: 10)).foregroundColor(installed ? .green : .orange)
                }
            }
            Spacer()
            Button(action: install) {
                if installing {
                    ProgressView().controlSize(.small)
                } else {
                    Label(installed ? "Installiert ✓" : "Installieren", systemImage: "arrow.down.circle")
                        .font(.system(size: 11))
                }
            }
            .buttonStyle(.bordered)
            .disabled(installing || installed)
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
    }

    private func install() {
        installing = true
        output = "Installiere via Homebrew…"
        DispatchQueue.global(qos: .userInitiated).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/bin/bash")
            task.arguments = ["-c", "/opt/homebrew/bin/brew install --cask \(brewCask) 2>&1 || /usr/local/bin/brew install --cask \(brewCask) 2>&1"]
            let pipe = Pipe()
            task.standardOutput = pipe
            task.standardError = pipe
            try? task.run()
            task.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let result = String(data: data, encoding: .utf8) ?? ""
            DispatchQueue.main.async {
                installing = false
                if task.terminationStatus == 0 {
                    installed = true
                    output = "✓ Erfolgreich installiert"
                } else if result.contains("already installed") {
                    installed = true
                    output = "✓ Bereits installiert"
                } else {
                    output = "✗ Fehler – Homebrew installiert?"
                }
            }
        }
    }
}

// MARK: - Launcher Edit Sheet

struct LauncherEditSheet: View {
    @State var launcher: GameLauncherConfig
    let onSave: (GameLauncherConfig) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var registryApps: [[String: Any]] = []
    @State private var isLoadingRegistry = false
    @State private var showRegistryPicker = false

    let availableIcons = [
        "gamecontroller.fill", "star.fill", "moon.fill", "bolt.fill",
        "shield.fill", "cart.fill", "heart.fill", "cube.fill",
        "tv.fill", "desktopcomputer", "memorychip", "arcade.stick"
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(launcher.name.isEmpty ? "Launcher hinzufügen" : "Launcher bearbeiten")
                .font(.system(size: 15, weight: .semibold))

            // Preview
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(launcher.color)
                        .frame(width: 48, height: 48)
                    Image(systemName: launcher.iconName)
                        .font(.system(size: 22))
                        .foregroundColor(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(launcher.name.isEmpty ? "Name" : launcher.name)
                        .font(.system(size: 14, weight: .semibold))
                    Text(launcher.sunshineAppName.isEmpty ? "Sunshine App-Name" : launcher.sunshineAppName)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
            }
            .padding(12)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 10))

            Divider()

            Group {
                HStack {
                    Text("Name").frame(width: 140, alignment: .leading)
                        .font(.system(size: 13))
                    TextField("z.B. Steam", text: $launcher.name)
                        .textFieldStyle(.roundedBorder)
                }
                HStack {
                    Text("Sunshine App-Name").frame(width: 140, alignment: .leading)
                        .font(.system(size: 13))
                    TextField("z.B. Steam Big Picture", text: $launcher.sunshineAppName)
                        .textFieldStyle(.roundedBorder)
                }
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Registry-Eintrag").frame(width: 140, alignment: .leading)
                            .font(.system(size: 13))
                        Text("Optional, für Host-Erkennung")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            TextField("z.B. HKLM\\SOFTWARE\\Valve\\Steam", text: $launcher.registryKey)
                                .textFieldStyle(.roundedBorder)
                                .font(.system(size: 12))
                            Button(action: loadRegistryApps) {
                                if isLoadingRegistry {
                                    ProgressView().frame(width: 16, height: 16)
                                } else {
                                    Image(systemName: "arrow.down.circle")
                                        .font(.system(size: 14))
                                }
                            }
                            .buttonStyle(.plain)
                            .help("Registry-Einträge vom Host laden")
                            .disabled(isLoadingRegistry)
                        }
                        if !registryApps.isEmpty {
                            ScrollView {
                                VStack(spacing: 0) {
                                    ForEach(registryApps.indices, id: \.self) { i in
                                        let app = registryApps[i]
                                        let name = app["name"] as? String ?? ""
                                        let cmd  = app["command"] as? String ?? ""
                                        Button(action: {
                                            launcher.registryKey = cmd
                                            if launcher.name.isEmpty { launcher.name = name }
                                            registryApps = []
                                        }) {
                                            HStack {
                                                VStack(alignment: .leading, spacing: 2) {
                                                    Text(name)
                                                        .font(.system(size: 12, weight: .medium))
                                                        .foregroundColor(.primary)
                                                    Text(cmd)
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                        .lineLimit(1)
                                                }
                                                Spacer()
                                            }
                                            .padding(.horizontal, 8)
                                            .padding(.vertical, 6)
                                            .contentShape(Rectangle())
                                        }
                                        .buttonStyle(.plain)
                                        if i < registryApps.count - 1 { Divider() }
                                    }
                                }
                            }
                            .frame(maxHeight: 150)
                            .background(Color(NSColor.controlBackgroundColor))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(Color.secondary.opacity(0.2)))
                        }
                    }
                }
                HStack {
                    Text("Farbe").frame(width: 140, alignment: .leading)
                        .font(.system(size: 13))
                    ColorPicker("", selection: Binding(
                        get: { launcher.color },
                        set: { launcher.colorHex = $0.toHex }
                    ))
                    .labelsHidden()
                }
            }

            Text("Icon").font(.system(size: 13))
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 44))], spacing: 8) {
                ForEach(availableIcons, id: \.self) { icon in
                    Button(action: { launcher.iconName = icon }) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(launcher.iconName == icon ? launcher.color : Color.secondary.opacity(0.1))
                                .frame(width: 40, height: 40)
                            Image(systemName: icon)
                                .font(.system(size: 18))
                                .foregroundColor(launcher.iconName == icon ? .white : .primary)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
                Button("Speichern") {
                    onSave(launcher)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .tint(.rogueRed)
                .disabled(launcher.name.isEmpty || launcher.sunshineAppName.isEmpty)
                .keyboardShortcut(.return)
            }
        }
        .padding(24)
        .frame(width: 420)
    }

    private func loadRegistryApps() {
        guard let req = HelperAPI.shared.request("/sunshine/apps/scan?source=registry") else { return }
        isLoadingRegistry = true
        registryApps = []
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isLoadingRegistry = false
                guard let data = data else { return }
                let arr: [[String: Any]]
                if let a = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { arr = a }
                else if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                        let a = j["apps"] as? [[String: Any]] ?? j["games"] as? [[String: Any]] { arr = a }
                else { return }

                let systemJunk = ["visual c++", "redistributable", "runtime", "driver",
                                  "directx", ".net ", "windows sdk", "uninst", "package cache",
                                  "gigabyte", "nvidia", "amd chipset", "amd software", "amd ryzen",
                                  "realtek", "corsair", "maintenance service", "git ", "python ",
                                  "vigem", "smart backup", "gbt_", "microsoft edge",
                                  "mozilla maintenance", "windows desktop runtime"]

                registryApps = arr.compactMap { dict in
                    let name = dict["name"] as? String ?? ""
                    guard !name.isEmpty else { return nil }
                    let cmd = dict["cmd"] as? String ?? dict["exe"] as? String ?? ""
                    let nameLower = name.lowercased()
                    guard !systemJunk.contains(where: { nameLower.contains($0) }) else { return nil }
                    return ["name": name, "command": cmd]
                }.sorted { ($0["name"] as? String ?? "") < ($1["name"] as? String ?? "") }
            }
        }.resume()
    }
}

// MARK: - GOG Working Directory Fix Row

struct GogWorkingDirFixRow: View {
    @State private var showInstructions = false
    @State private var fixing = false
    @State private var fixed = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: fixed ? "checkmark.circle.fill" : "wrench.and.screwdriver.fill")
                .foregroundColor(fixed ? .green : .rogueRed)
            VStack(alignment: .leading, spacing: 2) {
                Text("GOG Galaxy: Working Directory Fix")
                    .font(.system(size: 12, weight: .semibold))
                Text("Behebt den Repair/Uninstall-Dialog beim Öffnen via Moonlight.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("Anleitung") { showInstructions = true }
                .buttonStyle(.plain)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
            if fixing {
                ProgressView().frame(width: 20, height: 20)
            } else {
                Button(fixed ? "Erneut anwenden" : "Fix anwenden") { runFix() }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(12)
        .background(Color.rogueRed.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal, 16).padding(.bottom, 8)
        .sheet(isPresented: $showInstructions) {
            GogFixInstructionsView()
        }
    }

    private func runFix() {
        guard HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/sunshine/apps") else { return }
        fixing = true
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            guard let data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let apps = json["apps"] as? [[String: Any]],
                  let gog = apps.first(where: {
                      let name = ($0["name"] as? String ?? "").lowercased()
                      return name.contains("gog galaxy") || name.contains("galaxyclient")
                  }),
                  let appID = gog["id"] as? Int else {
                DispatchQueue.main.async { fixing = false }
                return
            }
            // Bestehenden Eintrag komplett neu aufbauen mit korrektem Command
            var updated = gog
            updated["cmd"] = "\"C:\\Program Files (x86)\\GOG Galaxy\\GalaxyClient.exe\""
            updated.removeValue(forKey: "id")

            // Löschen und neu anlegen
            guard let deleteReq = HelperAPI.shared.request("/sunshine/apps/\(appID)", method: "DELETE") else { return }
            HelperAPI.shared.dataTask(with: deleteReq) { _, _, _ in
                Thread.sleep(forTimeInterval: 0.8)
                guard let addReq = HelperAPI.shared.request("/sunshine/apps/add", method: "POST", body: updated) else { return }
                HelperAPI.shared.dataTask(with: addReq) { _, _, _ in
                    DispatchQueue.main.async { fixing = false; fixed = true }
                }.resume()
            }.resume()
        }.resume()
    }
}

struct GogFixInstructionsView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    var sunshineURL: String {
        let base = settings.pcIPAddress.isEmpty ? "192.168.178.94" : settings.pcIPAddress
        return "https://\(base):47990"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("GOG Galaxy Working Directory Fix")
                    .font(.system(size: 16, weight: .bold))
                Spacer()
                Button("Schließen") { dismiss() }.buttonStyle(.bordered)
            }

            Text("Öffne die Sunshine-Weboberfläche und setze das Working Directory für GalaxyClient:")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 12) {
                step(1, "Sunshine-Weboberfläche öffnen") {
                    Button(sunshineURL) {
                        NSWorkspace.shared.open(URL(string: sunshineURL)!)
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.accentColor)
                }
                step(2, "Zu Applications → GOG GALAXY navigieren") {
                    Text("Klicke auf den Stift-Button neben GOG GALAXY")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
                step(3, "Command ersetzen") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Den Command-Wert ersetzen durch:").font(.system(size: 12)).foregroundColor(.secondary)
                        copyField("\"C:\\Program Files (x86)\\GOG Galaxy\\GalaxyClient.exe\"")
                    }
                }
                step(4, "Save klicken und fertig") {
                    Text("Working Directory leer lassen — nur Command ändern genügt.")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Warum?").font(.system(size: 12, weight: .semibold))
                Text("Ohne Working Directory startet Sunshine GalaxyClient.exe im falschen Verzeichnis. GOG denkt dann, es wird der Installer ausgeführt, und zeigt einen Repair/Uninstall-Dialog.")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(24)
        .frame(width: 480)
    }

    private func step<Content: View>(_ n: Int, _ title: String, @ViewBuilder content: () -> Content) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(n)")
                .font(.system(size: 11, weight: .bold))
                .foregroundColor(.white)
                .frame(width: 20, height: 20)
                .background(Color.rogueRed)
                .clipShape(Circle())
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 13, weight: .medium))
                content()
            }
        }
    }

    private func copyField(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(.system(size: 12, design: .monospaced))
                .padding(.horizontal, 10).padding(.vertical, 5)
                .background(Color(NSColor.controlBackgroundColor))
                .clipShape(RoundedRectangle(cornerRadius: 6))
            Button(action: { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(text, forType: .string) }) {
                Image(systemName: "doc.on.doc").font(.system(size: 11))
            }
            .buttonStyle(.plain)
            .help("Kopieren")
        }
    }
}

// MARK: - Script Edit Sheet (für bestehende Scripte)

struct ScriptEditSheetWrapper: View {
    let script: CustomScript
    let store: CustomScriptStore
    @Environment(\.dismiss) private var dismiss

    @State private var name: String
    @State private var path: String
    @State private var symbol: String
    @State private var topNav: Bool
    @State private var helperScripts: [HelperScript] = []
    @State private var isFetching = false
    @State private var selectedHelperScript: HelperScript? = nil

    let commonSymbols = [
        "terminal", "bolt.fill", "play.fill", "arrow.clockwise",
        "laptopcomputer",
        "trash", "folder", "doc", "wrench.and.screwdriver",
        "gear", "cpu", "network", "wifi", "display",
        "powerplug", "gamecontroller", "music.note", "camera"
    ]

    init(script: CustomScript, store: CustomScriptStore) {
        self.script = script
        self.store = store
        _name = State(initialValue: script.name)
        _path = State(initialValue: script.path)
        _symbol = State(initialValue: script.symbol)
        _topNav = State(initialValue: script.showInTopNav)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Script bearbeiten").font(.headline)

            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Name").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    TextField("z.B. Restart Server", text: $name).textFieldStyle(.roundedBorder)
                }
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Script vom Helper").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                        Spacer()
                        Button(action: {
                            isFetching = true
                            HelperAPI.shared.fetchScripts { list in
                                helperScripts = list
                                isFetching = false
                            }
                        }) {
                            if isFetching {
                                ProgressView().scaleEffect(0.6)
                            } else {
                                Label("Laden", systemImage: "arrow.clockwise").font(.system(size: 11))
                            }
                        }
                        .buttonStyle(.bordered).controlSize(.small)
                    }
                    if helperScripts.isEmpty {
                        Text("Klicke 'Laden' um verfügbare Scripte vom Helper abzurufen")
                            .font(.system(size: 11)).foregroundColor(.secondary)
                    } else {
                        Picker("Script wählen", selection: $selectedHelperScript) {
                            Text("– bitte wählen –").tag(Optional<HelperScript>.none)
                            ForEach(helperScripts) { hs in
                                Text(hs.name).tag(Optional(hs))
                            }
                        }
                        .onChange(of: selectedHelperScript) { _, hs in
                            if let hs = hs {
                                path = hs.path
                                if name.isEmpty { name = hs.name }
                            }
                        }
                    }
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text("Dateipfad").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    TextField("C:\\scripts\\foo.bat", text: $path).textFieldStyle(.roundedBorder)
                    Text("Wird automatisch ausgefüllt wenn Script oben gewählt")
                        .font(.system(size: 10)).foregroundColor(.secondary)
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Icon").font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(40)), count: 9), spacing: 8) {
                        ForEach(commonSymbols, id: \.self) { sym in
                            Button(action: { symbol = sym }) {
                                Image(systemName: sym)
                                    .font(.system(size: 15))
                                    .frame(width: 36, height: 36)
                                    .background(symbol == sym
                                                ? Color.rogueRed.opacity(0.2)
                                                : Color.secondary.opacity(0.1))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .foregroundColor(symbol == sym ? .rogueRed : .primary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                Toggle("In TopNav anzeigen", isOn: $topNav)
            }

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
                Button("Speichern") {
                    if let i = store.scripts.firstIndex(where: { $0.id == script.id }) {
                        store.scripts[i].name = name
                        store.scripts[i].path = path
                        store.scripts[i].symbol = symbol
                        store.scripts[i].showInTopNav = topNav
                        store.save()
                    }
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.isEmpty || path.isEmpty)
            }
        }
        .padding(28)
        .frame(minWidth: 480, idealWidth: 500)
        .onAppear {
            isFetching = true
            HelperAPI.shared.fetchScripts { list in
                helperScripts = list
                isFetching = false
            }
        }
    }
}

// MARK: - Tab: Updates

extension SettingsView {
    @MainActor
    var tabUpdates: some View {
        let updater = AppUpdater.shared
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                tabHeader("Updates", icon: "arrow.down.circle")

                // Aktuelle Version
                GroupBox {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Installierte Version", systemImage: "checkmark.seal.fill")
                                .font(.headline)
                            Spacer()
                            Text(updater.currentVersion)
                                .font(.system(.body, design: .monospaced))
                                .foregroundColor(.secondary)
                        }
                        if let release = updater.latestRelease {
                            let latest = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
                            HStack {
                                Label("Verfügbare Version", systemImage: "arrow.down.circle")
                                    .font(.headline)
                                Spacer()
                                Text(latest)
                                    .font(.system(.body, design: .monospaced))
                                    .foregroundColor(isNewer(latest, than: updater.currentVersion) ? .green : .secondary)
                            }
                        }
                    }
                    .padding(8)
                }

                // Status & Aktion
                GroupBox {
                    VStack(spacing: 12) {
                        switch updater.state {
                        case .idle:
                            Button(action: { updater.checkForUpdates() }) {
                                Label("Auf Updates prüfen", systemImage: "arrow.clockwise")
                            }
                            .buttonStyle(.borderedProminent)

                        case .checking:
                            ProgressView("Prüfe auf Updates ...")

                        case .upToDate:
                            Label("Rogue Launcher ist aktuell.", systemImage: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Button(action: { updater.checkForUpdates() }) {
                                Label("Erneut prüfen", systemImage: "arrow.clockwise")
                            }

                        case .available:
                            Label("Update verfügbar!", systemImage: "exclamationmark.circle.fill")
                                .foregroundColor(.orange)
                                .font(.headline)
                            Button(action: { updater.downloadAndInstall() }) {
                                Label("Jetzt aktualisieren", systemImage: "arrow.down.circle.fill")
                            }
                            .buttonStyle(.borderedProminent)

                        case .downloading:
                            VStack(spacing: 8) {
                                Label("Lade Update herunter ...", systemImage: "arrow.down.circle")
                                ProgressView(value: updater.progress)
                                    .progressViewStyle(.linear)
                                Text("\(Int(updater.progress * 100)) %")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                        case .installing:
                            Label("Installiere Update ...", systemImage: "gear")
                            ProgressView()

                        case .error(let msg):
                            Label(msg, systemImage: "xmark.circle.fill")
                                .foregroundColor(.red)
                            Button(action: { updater.checkForUpdates() }) {
                                Label("Erneut versuchen", systemImage: "arrow.clockwise")
                            }
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity)
                }

                // Changelog
                if let release = updater.latestRelease, let body = release.body, !body.isEmpty {
                    GroupBox(label: Label("Changelog — \(release.name)", systemImage: "doc.text")) {
                        ScrollView {
                            Text(body)
                                .font(.system(size: 12, design: .monospaced))
                                .foregroundColor(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(8)
                        }
                        .frame(maxHeight: 200)
                    }
                }

                Spacer()
            }
            .padding()
        }
        .onAppear { updater.checkForUpdates() }
    }

    private func isNewer(_ a: String, than b: String) -> Bool {
        let av = a.components(separatedBy: ".").compactMap(Int.init)
        let bv = b.components(separatedBy: ".").compactMap(Int.init)
        let len = max(av.count, bv.count)
        for i in 0..<len {
            let x = i < av.count ? av[i] : 0
            let y = i < bv.count ? bv[i] : 0
            if x != y { return x > y }
        }
        return false
    }
}
