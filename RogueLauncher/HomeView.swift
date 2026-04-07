import SwiftUI

// Genre → SF Symbol Mapping
// Genre-Normalisierung: alle Varianten → kanonischer Name
let genreDescriptions: [String: String] = [
    "Abenteuer":          "Abenteuerspiele leben von ihrer erzählerischen Tiefe und der Neugier des Spielers, unbekannte Welten zu erkunden. Im Mittelpunkt stehen oft Rätsel, die durch Logik oder Kreativität gelöst werden müssen, während die Handlung durch Dialoge und Entdeckungen voranschreitet.",
    "Arcade":             "Arcade-Spiele sind der Inbegriff von schnellem, zugänglichem Spielvergnügen. Mit einfachen, aber fesselnden Mechaniken fordern sie den Spieler auf, Highscores zu knacken oder Level mit immer höherem Schwierigkeitsgrad zu meistern.",
    "Puzzle":             "Puzzlespiele stellen den Spieler vor knifflige Herausforderungen, die durch Logik, Mustererkennung oder experimentelles Ausprobieren gemeistert werden müssen. Die Befriedigung, eine scheinbar unlösbare Aufgabe zu knacken, steht im Vordergrund.",
    "Rennen":             "Rennspiele bieten rasante Action auf Strecken, in offenen Welten oder sogar abseits der Schwerkraft, wo Präzision und Reaktionsvermögen über Sieg oder Niederlage entscheiden. Der Adrenalinkick, eine Kurve perfekt zu treffen oder im letzten Moment zu überholen, macht den Reiz aus.",
    "Rollenspiel":        "Rollenspiele versetzen den Spieler in die Rolle eines Charakters, dessen Fähigkeiten, Entscheidungen und Entwicklung die Spielwelt nachhaltig prägen. Epische Geschichten, komplexe Kampfsysteme und moralische Dilemmata sorgen für stundenlange Spielsessions.",
    "Shooter":            "Shooter setzen auf actiongeladene Kämpfe, bei denen Präzision, Taktik und oft auch Teamplay den Unterschied machen. Ob aus der Egoperspektive oder als Third-Person-Erlebnis – das Genre reicht von militaristischen Simulationen bis zu sci-fi-lastigen Arena-Shootern.",
    "Simulation":         "Simulationsspiele bilden reale oder fiktive Systeme detailgetreu ab, sei es das Führen einer Farm, das Steuern eines Flugzeugs oder das Managen einer ganzen Stadt. Für Fans von Planung und Mikromanagement ist das Genre ein endloses Experimentierfeld.",
    "Strategie":          "Strategiespiele verlangen taktisches Geschick und langfristige Planung, um Armeen zu führen, Imperien aufzubauen oder Ressourcen effizient zu verwalten. Ob rundenbasiert oder in Echtzeit – jeder Zug kann über Sieg oder Niederlage entscheiden.",
    "Crafting":           "Crafting-Spiele stellen das Sammeln von Ressourcen und das Erschaffen von Gegenständen in den Mittelpunkt. Ob Werkzeuge, Waffen oder ganze Gebäude – der kreative Aufbau gehört zum Kern des Spielerlebnisses.",
    "Survival":           "Survival-Spiele setzen den Spieler in feindliche Umgebungen aus, in denen es gilt, mit begrenzten Mitteln zu überleben. Hunger, Durst und Wetterbedingungen erfordern ständige Aufmerksamkeit, während Crafting und Basisbau für Fortschritt sorgen.",
    "Online Multiplayer": "Online-Multiplayer-Spiele leben von der Interaktion mit anderen Spielern, sei es kooperativ oder kompetitiv. Teamplay, Kommunikation und manchmal auch Verrat machen den besonderen Reiz aus.",
    "Indie":              "Indie-Spiele stehen für kreative Freiheit und innovative Ideen abseits der großen Publisher. Oft von kleinen Teams entwickelt, überzeugen sie mit einzigartigen Kunststilen, ungewöhnlichen Gameplay-Mechaniken und persönlichen Geschichten.",
    "Horror":             "Horror-Spiele nutzen Atmosphäre, Sounddesign und unerwartete Schockmomente, um beim Spieler Angst und Spannung zu erzeugen. Der Nervenkitzel, nicht zu wissen, was hinter der nächsten Tür lauert, ist unschlagbar.",
    "Action":             "Action-Spiele sind pure Adrenalinquellen, in denen schnelle Reflexe, spektakuläre Kämpfe und atemberaubende Bewegungen im Mittelpunkt stehen. Hier zählt nicht nur Geschick, sondern auch der Spaß am Chaos.",
    "Beat 'em up":        "Beat 'em ups sind der Inbegriff von Nahkampf-Action, bei der der Spieler sich durch Horden von Gegnern schlägt. Koop-Modi und Combo-Systeme sorgen für Wiederspielwert, während ikonische Charaktere Kultstatus genießen.",
    "Plattformer":        "Plattformer fordern Präzision und Timing, um durch springende, laufende und kletternde Passagen zu navigieren. Von klassischen 2D-Jump 'n' Runs bis zu anspruchsvollen 3D-Abenteuern – das Genre ist zeitlos.",
    "Sport":              "Sportspiele bringen reale Disziplinen wie Fußball, Basketball oder Rennsport auf den Bildschirm – mal realistisch, mal übertrieben. Besonders im E-Sport haben sich Sport-Simulationen als ernsthafte Wettbewerbe etabliert.",
    "Stealth":            "Stealth-Spiele belohnen Geduld und taktisches Vorgehen statt offener Konfrontation. Der Nervenkitzel, knapp der Entdeckung zu entgehen, ist einzigartig.",
    "Open World":         "Open-World-Spiele bieten maximale Freiheit in riesigen, lebendigen Welten, die es zu erkunden gilt. Neben der Hauptgeschichte locken unzählige Nebenmissionen, Geheimnisse und dynamische Ereignisse.",
    "Metroidvania":       "Metroidvanias verbinden erkundbare Welten mit fortschreitenden Fähigkeiten, die neue Bereiche zugänglich machen. Die Balance zwischen Herausforderung und Belohnung macht es so fesselnd.",
    "Roguelike":          "Roguelikes überzeugen durch prozedural generierte Level und Permadeath, die jeden Durchlauf einzigartig machen. Der Reiz liegt darin, mit jedem Versuch ein bisschen besser zu werden.",
    "Battle Royale":      "Battle-Royale-Spiele setzen Dutzende Spieler auf einer schrumpfenden Karte gegeneinander, bis nur einer übrig bleibt. Die Mischung aus Spannung und Unvorhersehbarkeit macht es so fesselnd.",
    "Sandbox":            "Sandbox-Spiele geben dem Spieler Werkzeuge an die Hand, um eigene Welten zu gestalten – ohne feste Ziele oder Regeln. Hier ist der Fantasie keine Grenze gesetzt.",
]

let genreMapping: [(canonical: String, variants: [String])] = [
    ("Abenteuer",        ["adventure", "abenteuer", "action-adventure"]),
    ("Arcade",           ["arcade"]),
    ("Puzzle",           ["puzzle", "logic", "mystery"]),
    ("Rennen",           ["racing", "rennen", "rennspiel", "driving", "kart"]),
    ("Rollenspiel",      ["rpg", "role-playing", "rollenspiel", "role playing", "jrpg", "action rpg", "tactical rpg", "crpg"]),
    ("Shooter",          ["shooter", "tactical", "tactical shooter", "first-person", "fps", "third-person shooter", "rail shooter", "shoot 'em up", "shmup"]),
    ("Simulation",       ["simulator", "simulation", "management", "farming", "life simulation", "city builder"]),
    ("Strategie",        ["strategy", "strategie", "real time strategy", "rts", "turn-based strategy", "tbs", "tower defense", "grand strategy", "4x"]),
    ("Survival",         ["survival", "survival horror"]),
    ("Crafting",         ["crafting", "bauen", "handwerk", "base building"]),
    ("Online Multiplayer",["mmo", "mmorpg", "online multiplayer", "battle online", "co-op", "cooperative"]),
    ("Indie",            ["indie"]),
    ("Horror",           ["horror", "psychological horror"]),
    ("Action",           ["action", "hack and slash", "hack & slash", "brawler", "musou"]),
    ("Beat 'em up",      ["beat 'em up", "beat em up", "fighting", "beat-em-up"]),
    ("Plattformer",      ["platform", "platformer", "plattform", "plattformer", "jump and run"]),
    ("Sport",            ["sports", "sport", "football", "soccer", "basketball", "tennis", "golf"]),
    ("Stealth",          ["stealth", "infiltration"]),
    ("Open World",       ["open world", "open-world", "sandbox open"]),
    ("Metroidvania",     ["metroidvania", "metroid", "castlevania"]),
    ("Roguelike",        ["roguelike", "roguelite", "rogue-like", "rogue-lite", "dungeon crawler"]),
    ("Battle Royale",    ["battle royale", "last man standing"]),
    ("Sandbox",          ["sandbox", "building", "construction"]),
]

func normalizeGenre(_ raw: String) -> String {
    let lower = raw.lowercased().trimmingCharacters(in: .whitespaces)
    // Custom Varianten zuerst
    let customStore = GenreMappingStore.shared
    for entry in genreMapping {
        let custom = customStore.customVariants[entry.canonical] ?? []
        if custom.contains(where: { lower.contains($0) }) { return entry.canonical }
    }
    // Eingebautes Mapping
    for entry in genreMapping {
        if entry.variants.contains(where: { lower.contains($0) }) { return entry.canonical }
    }
    return raw.trimmingCharacters(in: .whitespaces)
}

let genreColors: [String: [Color]] = [
    "Abenteuer":          [Color(red: 0.2, green: 0.6, blue: 0.3), Color(red: 0.1, green: 0.3, blue: 0.15)],
    "Shooter":            [Color(red: 0.7, green: 0.2, blue: 0.2), Color(red: 0.4, green: 0.1, blue: 0.1)],
    "Rollenspiel":        [Color(red: 0.5, green: 0.2, blue: 0.7), Color(red: 0.3, green: 0.1, blue: 0.4)],
    "Strategie":          [Color(red: 0.2, green: 0.4, blue: 0.7), Color(red: 0.1, green: 0.2, blue: 0.4)],
    "Simulation":         [Color(red: 0.1, green: 0.5, blue: 0.6), Color(red: 0.05, green: 0.3, blue: 0.4)],
    "Rennen":             [Color(red: 0.8, green: 0.5, blue: 0.1), Color(red: 0.5, green: 0.3, blue: 0.05)],
    "Action":             [Color(red: 0.8, green: 0.3, blue: 0.1), Color(red: 0.5, green: 0.15, blue: 0.05)],
    "Puzzle":             [Color(red: 0.1, green: 0.5, blue: 0.5), Color(red: 0.05, green: 0.3, blue: 0.3)],
    "Horror":             [Color(red: 0.2, green: 0.02, blue: 0.02), Color(red: 0.4, green: 0.05, blue: 0.05)],
    "Sport":              [Color(red: 0.1, green: 0.6, blue: 0.4), Color(red: 0.05, green: 0.35, blue: 0.2)],
    "Indie":              [Color(red: 0.6, green: 0.4, blue: 0.1), Color(red: 0.35, green: 0.2, blue: 0.05)],
    "Arcade":             [Color(red: 0.7, green: 0.1, blue: 0.5), Color(red: 0.4, green: 0.05, blue: 0.3)],
    "Plattformer":        [Color(red: 0.3, green: 0.5, blue: 0.1), Color(red: 0.15, green: 0.3, blue: 0.05)],
    "Crafting":           [Color(red: 0.20, green: 0.50, blue: 0.35), Color(red: 0.10, green: 0.30, blue: 0.20)],
    "Survival":           [Color(red: 0.4, green: 0.25, blue: 0.05), Color(red: 0.6, green: 0.4, blue: 0.1)],
    "Online Multiplayer": [Color(red: 0.1, green: 0.3, blue: 0.7), Color(red: 0.05, green: 0.15, blue: 0.45)],
    "Beat 'em up":        [Color(red: 0.6, green: 0.1, blue: 0.1), Color(red: 0.35, green: 0.05, blue: 0.05)],
    "Stealth":            [Color(red: 0.1, green: 0.1, blue: 0.2), Color(red: 0.2, green: 0.2, blue: 0.35)],
    "Open World":         [Color(red: 0.15, green: 0.45, blue: 0.2), Color(red: 0.05, green: 0.25, blue: 0.1)],
    "Metroidvania":       [Color(red: 0.4, green: 0.1, blue: 0.5), Color(red: 0.2, green: 0.05, blue: 0.3)],
    "Roguelike":          [Color(red: 0.5, green: 0.35, blue: 0.05), Color(red: 0.3, green: 0.2, blue: 0.02)],
    "Battle Royale":      [Color(red: 0.6, green: 0.2, blue: 0.05), Color(red: 0.35, green: 0.1, blue: 0.02)],
    "Sandbox":            [Color(red: 0.3, green: 0.3, blue: 0.1), Color(red: 0.15, green: 0.15, blue: 0.05)],
]

func colorsForGenre(_ genre: String) -> [Color] {
    genreColors[genre] ?? [Color.rogueBlue.opacity(0.7), Color.rogueNavy.opacity(0.9)]
}

let genreIcons: [String: String] = [
    "default": "gamecontroller.fill"
]

func iconForGenre(_ genre: String) -> String {
    return "gamecontroller.fill"
}

// Cache-Struct für featured Games — speichert nur was für die Anzeige nötig ist
struct HomeView: View {
    @ObservedObject var store: GameStore
    let onSelect: (Game) -> Void
    var onOpenShop: (() -> Void)? = nil
    @ObservedObject private var monitor = PCStatusMonitor.shared
    @ObservedObject private var settings = AppSettings.shared
    @ObservedObject private var shopStore = ShopStore.shared
    // heroLibGame entfernt — nur noch featureLibGames
    @State private var featureLibGames: [Game] = []
    @State private var refreshTimer: Timer? = nil
    @State private var activeTab: HomeTab = .start
    @State private var selectedGenre: String? = nil
    @State private var randomGame: Game? = nil

    enum HomeTab { case start, genres, library, launcher, import_, servers, consoles, emulators }

    var recentGames: [Game] {
        let hidden = ["desktop", "vortex", "audials", "ruhemodus", "sunshine", "epic games", "epic games launcher", "gog galaxy", "galaxyclient", "ea app", "ea desktop", "origin", "ubisoft connect", "uplay", "battle.net", "amazon games", "itch.io", "rockstar games launcher", "minecraft launcher", "steam big picture"]
        return store.games
            .filter { g in
                let lower = g.name.lowercased()
                return !hidden.contains { lower.contains($0) }
            }
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
            .prefix(100).map { $0 }
    }

    let fixedGenres: [String] = [
        "Abenteuer", "Action", "Arcade", "Battle Royale", "Beat 'em up",
        "Crafting", "Horror", "Indie", "Metroidvania", "Music",
        "Online Multiplayer", "Open World", "Plattformer", "Puzzle", "Rennen",
        "Roguelike", "Rollenspiel", "Sandbox", "Shooter", "Simulation",
        "Sport", "Stealth", "Strategie", "Survival"
    ]

    var allTags: [(String, Int)] {
        var counts: [String: Int] = [:]
        for g in fixedGenres { counts[g] = 0 }
        for game in store.games {
            for raw in game.genre.split(separator: ",").map({ $0.trimmingCharacters(in: .whitespaces) }) {
                if !raw.isEmpty { counts[normalizeGenre(raw), default: 0] += 1 }
            }
        }
        return fixedGenres.map { ($0, counts[$0] ?? 0) }
    }

    var body: some View {
        VStack(spacing: 0) {
            topNav
            Divider()
            Group {
                if activeTab == .start        { startPage }
                else if activeTab == .library  { libraryPage }
                else if activeTab == .genres {
                    if let genre = selectedGenre {
                        GenreDetailView(genre: genre, store: store, onSelect: { game in
                            NotificationCenter.default.post(name: .selectGame, object: game)
                            selectedGenre = nil
                        }, onBack: {
                            selectedGenre = nil
                        })
                    } else {
                        genresPage
                    }
                }
                else if activeTab == .launcher { LauncherTabView() }
                else if activeTab == .import_  { importPage }
                else if activeTab == .servers  { serversPage }
                else if activeTab == .consoles { consolesPage }
                else if activeTab == .emulators { EmulatorsView(store: store) }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                if let img = NSImage(named: "HomeBackground") {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .saturation(0)
                        .opacity(0.18)
                        .clipped()
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: .goHome)) { _ in
                activeTab = .start
            }
            .onReceive(NotificationCenter.default.publisher(for: .filterByTag)) { note in
                if let tag = note.object as? String {
                    selectedGenre = tag
                    activeTab = .genres
                }
            }
        }
        .onAppear {
            pickFeaturedGames()
            if shopStore.games.isEmpty { shopStore.load() }
            refreshTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { _ in pickFeaturedGames() }
            autoImportDesktopIfNeeded()
        }
        .onDisappear { refreshTimer?.invalidate() }
        .onChange(of: store.games.count) { _, _ in
            if featureLibGames.isEmpty { pickFeaturedGames() }
        }
    }

    // MARK: - Top Navigation Bar

    var topNav: some View {
        HStack(spacing: 0) {
            tabButton("Start", tab: .start)
            if settings.pcOS != "linux" { tabButton("Bibliothek", tab: .library) }
            tabButton("Genres", tab: .genres)
            tabButton("Launcher", tab: .launcher)
            tabButton("Spiele importieren", tab: .import_)
            if settings.consolesEnabled { tabButton("Konsolen", tab: .consoles) }
            if settings.emulatorsEnabled { tabButton("Emulatoren", tab: .emulators) }
            tabButton("Spiele Server", tab: .servers)
        }
        .frame(maxWidth: .infinity)
        .overlay(alignment: .trailing) {
            let imagePath = UserDefaults.standard.string(forKey: "userProfileImagePath")
            let displayName = UserDefaults.standard.string(forKey: "userDisplayName") ?? NSFullUserName()
            HStack(spacing: 8) {
                // Chat Icons links vom Namen (kein Spacer → Frame nur so breit wie Inhalt)
                ForEach(ChatService.allCases) { service in
                    if settings.chatEnabledServices[service.rawValue] == true {
                        ChatIconButton(service: service)
                    }
                }
                // Name
                Text(displayName)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.secondary)
                    .allowsHitTesting(false)
                // Avatar
                Group {
                    if let path = imagePath, let img = NSImage(contentsOfFile: path) {
                        Image(nsImage: img).resizable().scaledToFill()
                    } else if let img = loadMacOSUserImage() {
                        Image(nsImage: img).resizable().scaledToFill()
                    } else {
                        Text(String(displayName.prefix(1)))
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .background(Color.rogueRed)
                    }
                }
                .frame(width: 28, height: 28)
                .clipShape(Circle())
                .allowsHitTesting(false)
            }
            .padding(.trailing, 16)
            // Kein allowsHitTesting(false) auf HStack — aber kein Spacer →
            // Frame ist nur ~200pt breit (rechts), überlappt NICHT mit Tabs
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor).opacity(0.95))
    }

    private func tabButton(_ label: String, tab: HomeTab) -> some View {
        Text(label)
            .font(.system(size: 13, weight: activeTab == tab ? .semibold : .regular))
            .foregroundColor(activeTab == tab ? .primary : .secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .background(
                activeTab == tab ?
                RoundedRectangle(cornerRadius: 6).fill(Color.secondary.opacity(0.15)) :
                RoundedRectangle(cornerRadius: 6).fill(Color.clear)
            )
            .contentShape(Rectangle())
            .onTapGesture { activeTab = tab }
    }

    // MARK: - Start Page

    var startPage: some View {
        GeometryReader { geo in
            ZStack(alignment: .topLeading) {
                if let img = NSImage(named: "HomeBackground") {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                        .allowsHitTesting(false)
                } else {
                    Color(NSColor.controlBackgroundColor)
                }
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        VStack(alignment: .leading, spacing: 24) {
                            if !featureLibGames.isEmpty {
                                HStack(spacing: 12) {
                                    ForEach(Array(featureLibGames.enumerated()), id: \.element.id) { idx, game in
                                        featureTile(game, isFirst: idx == 0)
                                    }
                                }
                                .padding(.top, 16)
                            }
                            if !recentGames.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    Text("Zuletzt gespielt").font(.system(size: 16, weight: .semibold))
                                    GeometryReader { rowGeo in
                                        let cardW: CGFloat = 110
                                        let spacing: CGFloat = 12
                                        let count = max(1, Int((rowGeo.size.width + spacing) / (cardW + spacing)))
                                        let hidden = ["desktop", "vortex", "audials", "ruhemodus", "sunshine", "epic games", "epic games launcher", "gog galaxy", "galaxyclient", "ea app", "ea desktop", "origin", "ubisoft connect", "uplay", "battle.net", "amazon games", "itch.io", "rockstar games launcher", "minecraft launcher", "steam big picture"]
                                        let padded: [Game] = {
                                            var list = recentGames
                                            if list.count < count {
                                                let ids = Set(list.map(\.id))
                                                let extras = store.games
                                                    .filter { !ids.contains($0.id) }
                                                    .filter { g in !hidden.contains { g.name.lowercased().contains($0) } }
                                                    .prefix(count - list.count)
                                                list += extras
                                            }
                                            return Array(list.prefix(count))
                                        }()
                                        let columns = Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
                                        LazyVGrid(columns: columns, spacing: 0) {
                                            ForEach(padded) { recentGameCard($0) }
                                        }
                                    }
                                    .frame(height: 185)
                                }
                                .padding(20)
                                .background(RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(NSColor.windowBackgroundColor).opacity(0.75)))
                            }

                            WuerfelView(store: store, randomGame: $randomGame)

                            if settings.epicFreeGamesEnabled { EpicFreeGamesView() }
                        }
                        .padding(16)
                    }
                }
            }
        }
    }

    // MARK: - Genres Page
    var genresPage: some View {
        let spacing: CGFloat = 12
        let cols = 6
        let padded: [(String, Int)?] = {
            var result: [(String, Int)?] = allTags.map { Optional($0) }
            while result.count % cols != 0 { result.append(nil) }
            return result
        }()
        return GeometryReader { geo in
            let totalW = geo.size.width - 40 // 20pt padding each side
            let tileW = (totalW - spacing * CGFloat(cols - 1)) / CGFloat(cols)
            let tileH = tileW * 0.55
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Text("Genre-Übersicht")
                        .font(.system(size: 22, weight: .bold))
                        .padding(.top, 20)
                    LazyVGrid(
                        columns: Array(repeating: GridItem(.fixed(tileW), spacing: spacing), count: cols),
                        spacing: spacing
                    ) {
                        ForEach(Array(padded.enumerated()), id: \.offset) { _, item in
                            if let (tag, count) = item {
                                Button(action: {
                                    selectedGenre = tag
                                }) {
                                    ZStack {
                                        // Basis-Farbgradient
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(LinearGradient(
                                                colors: colorsForGenre(tag),
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            ))
                                        // Genre-Bild falls vorhanden
                                        if let img = NSImage(named: "Genre_\(tag.replacingOccurrences(of: " ", with: "_").replacingOccurrences(of: "'", with: ""))") {
                                            Image(nsImage: img)
                                                .resizable()
                                                .scaledToFill()
                                                .frame(width: tileW, height: tileH)
                                                .clipped()
                                                .opacity(0.4)
                                            // Farbiger Overlay für Lesbarkeit
                                            LinearGradient(
                                                colors: colorsForGenre(tag).map { $0.opacity(0.6) },
                                                startPoint: .topLeading,
                                                endPoint: .bottomTrailing
                                            )
                                        }
                                        // Text
                                        VStack(spacing: 8) {
                                            Image(systemName: iconForGenre(tag))
                                                .font(.system(size: 28))
                                                .foregroundColor(.white.opacity(0.9))
                                            Text(tag)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(.white)
                                                .multilineTextAlignment(.center)
                                                .lineLimit(2)
                                            Text(count == 0 ? "–" : "\(count) Spiel\(count == 1 ? "" : "e")")
                                                .font(.system(size: 10))
                                                .foregroundColor(.white.opacity(count == 0 ? 0.4 : 0.7))
                                        }
                                        .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 1)
                                        .padding(14)
                                    }
                                    .frame(width: tileW, height: tileH)
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain)
                            } else {
                                Color.clear
                                    .frame(width: tileW, height: tileH)
                            }
                        }
                    }
                    .padding(.bottom, 20)
                }
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Library Page

    var libraryPage: some View {
        AllGamesListView(shopStore: shopStore)
    }

    // MARK: - Import Page

    var importPage: some View {
        SunshineImportWindowView(store: store)
    }

    // MARK: - Consoles Page

    var consolesPage: some View {
        ConsolesLibraryView(store: store)
    }

    // MARK: - Servers Page

    var serversPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if settings.craftyEnabled || settings.nitradoEnabled {
                    GameServerView()
                        .padding(20)
                        .background(RoundedRectangle(cornerRadius: 16)
                            .fill(Color(NSColor.windowBackgroundColor).opacity(0.75)))
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "server.rack")
                            .font(.system(size: 40)).foregroundColor(.secondary)
                        Text("Keine Game Server konfiguriert")
                            .font(.system(size: 16)).foregroundColor(.secondary)
                        Text("Game Server können in den Einstellungen aktiviert werden.")
                            .font(.system(size: 13)).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(60)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Featured Games Picker

    private func autoImportDesktopIfNeeded() {
        guard store.games.first(where: { $0.name.lowercased() == "desktop" && $0.type == .moonlight }) == nil,
              HelperAPI.shared.isConfigured,
              let req = HelperAPI.shared.request("/sunshine/apps") else { return }
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            guard let data = data else { return }
            let arr: [[String: Any]]
            if let a = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { arr = a }
            else if let j = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                    let a = j["apps"] as? [[String: Any]] { arr = a }
            else { return }
            let hasDesktop = arr.contains {
                let n = ($0["title"] as? String ?? $0["name"] as? String ?? "").lowercased()
                return n == "desktop"
            }
            guard hasDesktop else { return }
            DispatchQueue.main.async {
                guard store.games.first(where: { $0.name.lowercased() == "desktop" }) == nil else { return }
                store.games.append(Game(name: "Desktop", appName: "Desktop", type: .moonlight))
                store.save()
            }
        }.resume()
    }

    private func pickFeaturedGames() {
        let hidden = ["desktop", "vortex", "audials", "ruhemodus", "sunshine", "epic games", "epic games launcher", "gog galaxy", "galaxyclient", "ea app", "ea desktop", "origin", "ubisoft connect", "uplay", "battle.net", "amazon games", "itch.io", "rockstar games launcher", "minecraft launcher", "steam big picture"]
        let pool = store.games
            .filter { g in !hidden.contains { g.name.lowercased().contains($0) } }
            .filter { $0.backgroundImagePath != nil || $0.coverImagePath != nil }
            .shuffled()
        let fallback = store.games.filter { g in !hidden.contains { g.name.lowercased().contains($0) } }.shuffled()
        let source = pool.isEmpty ? fallback : pool
        guard !source.isEmpty else { return }
        featureLibGames = Array(source.prefix(3))
    }

    // MARK: - Feature Tile

    private func featureTile(_ game: Game, isFirst: Bool = false) -> some View {
        Button(action: { onSelect(game) }) {
            GeometryReader { tileGeo in
                ZStack(alignment: .bottomLeading) {
                    // Wallpaper zentriert — exakte Breite aus GeometryReader
                    Group {
                        if let img = game.backgroundImage ?? game.coverImage {
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            LinearGradient(colors: [Color.rogueNavy, Color.rogueBlue.opacity(0.5)],
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .frame(width: tileGeo.size.width, height: 280)
                    .clipped()

                    // Dunkler Gradient von unten
                    LinearGradient(colors: [.clear, .clear, .black.opacity(0.7), .black.opacity(0.9)],
                                   startPoint: .top, endPoint: .bottom)

                    // Content unten
                    VStack(alignment: .leading, spacing: 0) {
                        Spacer()
                        HStack(alignment: .bottom, spacing: 12) {
                            if let cover = game.coverImage {
                                Image(nsImage: cover).resizable().aspectRatio(contentMode: .fill)
                                    .frame(width: 70, height: 95)
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                                    .shadow(radius: 6)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text("EMPFOHLEN")
                                        .font(.system(size: 9, weight: .bold)).tracking(1.8)
                                        .foregroundColor(.black)
                                        .padding(.horizontal, 7).padding(.vertical, 3)
                                        .background(Color.yellow)
                                        .clipShape(RoundedRectangle(cornerRadius: 4))
                                    if !game.genre.isEmpty {
                                        Text(game.genre.uppercased())
                                            .font(.system(size: 9, weight: .semibold)).tracking(1.2)
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                    }
                                }
                                Text(game.name)
                                    .font(.system(size: 16, weight: .bold)).foregroundColor(.white)
                                    .lineLimit(1)
                                if !game.description.isEmpty {
                                    Text(game.description)
                                        .font(.system(size: 11)).foregroundColor(.white.opacity(0.65))
                                        .lineLimit(2)
                                }
                                Label("Zur Spielseite", systemImage: "arrow.right.circle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 10).padding(.vertical, 6)
                                    .background(Color.white.opacity(0.18))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(16)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .frame(maxWidth: .infinity).frame(height: 280)
        }
        .buttonStyle(.plain)
        .cursor(.pointingHand)
    }

    // MARK: - Recent Game Card

    private func recentGameCard(_ game: Game) -> some View {
        Button(action: { onSelect(game) }) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let img = game.coverImage {
                            Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(Color.secondary.opacity(0.15))
                                .overlay(Image(systemName: "gamecontroller")
                                    .font(.system(size: 24)).foregroundColor(.secondary))
                        }
                    }
                    .frame(width: 110, height: 150)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                    if game.type == .moonlight {
                        Circle()
                            .fill(monitor.status == .online ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                            .padding(6)
                    }
                }
                Text(game.name)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(2).multilineTextAlignment(.center)
                    .frame(width: 110).foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}

// Horizontale ScrollView die auch Maus-Scrollrad unterstützt
struct GenreGridView: View {
    let tags: [(String, Int)]
    let onTap: (String) -> Void
    @ObservedObject var store: GameStore
    @State private var editingGenre: String? = nil
    @State private var showingEdit = false
    @State private var scrollProxy: ScrollViewProxy? = nil

    var body: some View {
        VStack(spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(tags.enumerated()), id: \.offset) { _, item in
                        let (tag, count) = item
                        Button(action: { onTap(tag) }) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(LinearGradient(
                                        colors: colorsForGenre(tag),
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                VStack(spacing: 6) {
                                    Image(systemName: iconForGenre(tag))
                                        .font(.system(size: 22))
                                        .foregroundColor(.white.opacity(0.9))
                                    Text(tag)
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundColor(.white)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                    Text(count == 0 ? "–" : "\(count) Spiel\(count == 1 ? "" : "e")")
                                        .font(.system(size: 9))
                                        .foregroundColor(.white.opacity(count == 0 ? 0.4 : 0.7))
                                }
                                .padding(10)
                            }
                            .frame(width: 110, height: 82)
                        }
                        .buttonStyle(.plain)
                        .contextMenu {
                            Button(action: {
                                editingGenre = tag
                                showingEdit = true
                            }) {
                                Label("Genre bearbeiten", systemImage: "pencil")
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .padding(.top, 2)
            }
            // Dezenter custom Scrollbalken (2pt hoch)
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 1)
                    .fill(Color.secondary.opacity(0.3))
                    .frame(height: 2)
            }
            .frame(height: 2)
        }
        .frame(height: 96)
        .sheet(isPresented: $showingEdit) {
            if let genre = editingGenre {
                GenreEditView(genre: genre, gameStore: store)
            }
        }
    }
}


// MARK: - Würfel mir ein Spiel
struct WuerfelView: View {
    @ObservedObject var store: GameStore
    @Binding var randomGame: Game?
    @State private var isSpinning = false

    private var installedGames: [Game] {
        let hiddenContains = ["epic games launcher", "gog galaxy", "galaxyclient", "ea app",
                              "ea desktop", "origin", "ubisoft connect", "uplay", "battle.net",
                              "amazon games", "itch.io", "rockstar games launcher",
                              "minecraft launcher", "steam big picture", "desktop", "vortex", "audials"]
        let hiddenExact = ["steam", "epic games", "gog", "battle.net", "xbox"]
        return store.games.filter { game in
            guard game.type == .moonlight || game.type == .local else { return false }
            let nl = game.name.lowercased()
            let isHidden = hiddenContains.contains(where: { nl.contains($0) })
                        || hiddenExact.contains(where: { nl == $0 })
            return !isHidden
        }
    }

    var body: some View {
        HStack(spacing: 20) {
            // Würfel-Button
            Button(action: rollGame) {
                VStack(spacing: 10) {
                    Image(systemName: "die.face.5.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.white)
                        .rotationEffect(.degrees(isSpinning ? 20 : 0))
                        .animation(.spring(response: 0.3, dampingFraction: 0.4), value: isSpinning)
                    Text("Würfeln")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(.white.opacity(0.85))
                }
                .frame(width: 110, height: 140)
                .background(
                    RoundedRectangle(cornerRadius: 16)
                        .fill(Color(NSColor.controlBackgroundColor))
                        .overlay(RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.08), lineWidth: 1))
                )
            }
            .buttonStyle(.plain)

            // Spiel-Anzeige
            if let game = randomGame {
                HStack(spacing: 16) {
                    // Cover
                    Group {
                        if let img = game.coverImage {
                            Image(nsImage: img).resizable().scaledToFill()
                        } else {
                            ZStack {
                                Color.gray.opacity(0.3)
                                Image(systemName: "gamecontroller.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .frame(width: 90, height: 125)
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    // Info
                    VStack(alignment: .leading, spacing: 6) {
                        Text(game.name)
                            .font(.system(size: 16, weight: .bold))
                            .lineLimit(2)
                        if !game.genre.isEmpty {
                            Text(game.genre)
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                        if !game.description.isEmpty {
                            Text(game.description)
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                                .lineLimit(4)
                        }
                        Spacer()
                        Button(action: {
                            NotificationCenter.default.post(name: .selectGame, object: game)
                        }) {
                            Label("Zur Spielseite", systemImage: "arrow.right.circle")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.rogueRed)
                    }
                    Spacer()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.95)))
            } else {
                Text("Drücke den Würfel für ein zufälliges Spiel!")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(20)
        .frame(height: 180)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(NSColor.windowBackgroundColor).opacity(0.75)))
        .animation(.easeInOut(duration: 0.25), value: randomGame?.id)
        .onAppear { if randomGame == nil { rollGame() } }
    }

    private func rollGame() {
        guard !installedGames.isEmpty else { return }
        isSpinning.toggle()
        withAnimation(.easeInOut(duration: 0.2)) {
            randomGame = installedGames.randomElement()
        }
    }
}

extension Notification.Name {
    static let filterByTag = Notification.Name("filterByTag")
    static let goHome      = Notification.Name("goHome")
    static let goToGenres  = Notification.Name("goToGenres")
    static let selectGame  = Notification.Name("selectGame")
}

// MARK: - Shop Section auf Startseite

struct ShopSectionView: View {
    var onOpenShop: (() -> Void)?
    @ObservedObject private var settings = AppSettings.shared

    let shops: [(icon: String, label: String, color: Color, tab: Int)] = [
        ("internaldrive",        "NAS",      Color(red: 0.3, green: 0.5, blue: 0.7), 0),
        ("arrow.down.circle.fill","Steam",   Color(red: 0.1, green: 0.35, blue: 0.6), 1),
        ("gamecontroller.fill",  "Launcher", Color(red: 0.55, green: 0.1, blue: 0.7), 2),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Shop")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button(action: { onOpenShop?() }) {
                    Text("Alle anzeigen")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }

            HStack(spacing: 12) {
                ForEach(shops, id: \.label) { shop in
                    Button(action: { onOpenShop?() }) {
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(LinearGradient(
                                        colors: [shop.color, shop.color.opacity(0.7)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(height: 70)
                                Image(systemName: shop.icon)
                                    .font(.system(size: 28))
                                    .foregroundColor(.white)
                            }
                            Text(shop.label)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.primary)
                        }
                    }
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(NSColor.windowBackgroundColor).opacity(0.75))
        )
    }
}

private func loadMacOSUserImage() -> NSImage? {
    let username = NSUserName()
    let plistPath = "/private/var/db/dslocal/nodes/Default/users/\(username).plist"
    if let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any],
       let jpegArray = dict["jpegphoto"] as? [Data],
       let data = jpegArray.first,
       let img = NSImage(data: data) { return img }
    for path in [
        "\(NSHomeDirectory())/Library/Application Support/AddressBook/Images/ABPerson.jpg",
        "\(NSHomeDirectory())/Library/Application Support/AddressBook/Images/ABPerson.png"
    ] {
        if let img = NSImage(contentsOfFile: path) { return img }
    }
    return nil
}
