import SwiftUI

// MARK: - Shop Navigation

enum ShopPage {
    case home, allGames, importGames
}

// MARK: - ShopContainerView

struct ShopContainerView: View {
    @ObservedObject var store: GameStore
    @StateObject private var shopStore = ShopStore.shared
    @State private var page: ShopPage = .home

    var body: some View {
        Group {
            switch page {
            case .home:
                ShopHomeView(store: store, shopStore: shopStore, onNavigate: { page = $0 })
            case .allGames:
                AllGamesListView(shopStore: shopStore, onBack: { page = .home })
            case .importGames:
                ShopImportView(onBack: { page = .home })
            }
        }
        .onAppear { shopStore.load() }
    }
}

// MARK: - Shop Home

struct ShopHomeView: View {
    let store: GameStore
    @ObservedObject var shopStore: ShopStore
    let onNavigate: (ShopPage) -> Void

    @State private var genreSamples: [(genre: String, games: [ShopGame])] = []

    // Spiele mit Cover/Hintergrund bevorzugen
    private var featuredPool: [Game] {
        let all = store.games
        let withBg  = all.filter { $0.backgroundImagePath != nil || $0.coverImagePath != nil }
        return (withBg.isEmpty ? all : withBg).shuffled()
    }

    private var heroGame: Game?   { featuredPool.count > 3 ? featuredPool.first : nil }
    private var smallGames: [Game] {
        let pool = heroGame != nil ? Array(featuredPool.dropFirst()) : featuredPool
        return Array(pool.prefix(3))
    }

    var body: some View {
        VStack(spacing: 0) {
            topBar
            Divider()
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if shopStore.isLoading {
                        HStack { Spacer(); ProgressView("Lade Shop…"); Spacer() }.padding(60)
                    } else {
                        VStack(alignment: .leading, spacing: 20) {
                            if !featuredPool.isEmpty {
                                if let hero = heroGame { heroBanner(hero) }
                                if !smallGames.isEmpty { smallTileRow(smallGames) }
                            }
                            genreSection
                        }
                        .padding(20)
                    }
                }
            }
        }
        .onChange(of: shopStore.games.count)      { _, _ in refreshGenres() }
        .onChange(of: shopStore.genreUpdateCount) { _, _ in refreshGenres() }
        .onAppear { refreshGenres() }
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack(spacing: 12) {
            Spacer()
            Button(action: { onNavigate(.importGames) }) {
                Label("Spiele importieren", systemImage: "arrow.down.to.line")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered).controlSize(.small)
            Button(action: { onNavigate(.allGames) }) {
                Label("Alle Spiele", systemImage: "list.bullet")
                    .font(.system(size: 12, weight: .medium))
            }
            .buttonStyle(.bordered).controlSize(.small)
        }
        .padding(.horizontal, 20).padding(.vertical, 10)
    }

    // MARK: - Hero Banner

    @ViewBuilder
    func heroBanner(_ game: Game) -> some View {
        ZStack(alignment: .bottomLeading) {
            // Hintergrund
            Group {
                if let img = game.backgroundImage ?? game.coverImage {
                    Image(nsImage: img).resizable().scaledToFill()
                } else {
                    LinearGradient(colors: colorsForGenre(game.genre),
                                   startPoint: .topLeading, endPoint: .bottomTrailing)
                }
            }
            .frame(maxWidth: .infinity).frame(height: 260).clipped()

            LinearGradient(colors: [.clear, .black.opacity(0.9)],
                           startPoint: .top, endPoint: .bottom).frame(height: 260)

            HStack(alignment: .bottom, spacing: 16) {
                if let cover = game.coverImage {
                    Image(nsImage: cover).resizable().scaledToFill()
                        .frame(width: 80, height: 106)
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                        .shadow(radius: 8)
                }
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 6) {
                        Text("EMPFOHLEN")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.8)
                            .foregroundColor(.black)
                            .padding(.horizontal, 7).padding(.vertical, 3)
                            .background(Color.yellow)
                            .clipShape(RoundedRectangle(cornerRadius: 4))
                        if !game.genre.isEmpty {
                            Text(game.genre.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(1.2)
                                .foregroundColor(.white.opacity(0.6))
                        }
                    }
                    Text(game.name)
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white).lineLimit(2)
                    if !game.description.isEmpty {
                        Text(game.description)
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.65))
                            .lineLimit(2)
                    }
                }
                Spacer()
                // In-Bibliothek Badge
                HStack(spacing: 5) {
                    Image(systemName: "checkmark.circle.fill").font(.system(size: 12))
                    Text("In deiner Bibliothek").font(.system(size: 11, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 12).padding(.vertical, 7)
                .background(Color.white.opacity(0.18))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.bottom, 4)
            }
            .padding(20)
        }
        .frame(height: 260)
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Small Tiles

    @ViewBuilder
    func smallTileRow(_ games: [Game]) -> some View {
        HStack(spacing: 12) {
            ForEach(games) { game in
                ZStack(alignment: .bottomLeading) {
                    Group {
                        if let img = game.backgroundImage ?? game.coverImage {
                            Image(nsImage: img).resizable().scaledToFill()
                        } else {
                            LinearGradient(colors: colorsForGenre(game.genre),
                                           startPoint: .topLeading, endPoint: .bottomTrailing)
                        }
                    }
                    .frame(maxWidth: .infinity).frame(height: 130).clipped()

                    LinearGradient(colors: [.clear, .black.opacity(0.88)],
                                   startPoint: .top, endPoint: .bottom)

                    VStack(alignment: .leading, spacing: 4) {
                        if !game.genre.isEmpty {
                            Text(game.genre.uppercased())
                                .font(.system(size: 8, weight: .bold))
                                .tracking(1.2)
                                .foregroundColor(.white.opacity(0.55))
                        }
                        Text(game.name)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.white).lineLimit(2)
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 9))
                                .foregroundColor(.green)
                            Text("Installiert")
                                .font(.system(size: 9, weight: .medium))
                                .foregroundColor(.green)
                        }
                    }
                    .padding(10)
                }
                .frame(height: 130)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    // MARK: - Genre Section

    @ViewBuilder
    var genreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Genre Übersicht")
                .font(.system(size: 20, weight: .bold))

            if genreSamples.isEmpty {
                Text("Genres werden geladen…")
                    .font(.system(size: 13)).foregroundColor(.secondary).padding(.vertical, 8)
            } else {
                LazyVGrid(
                    columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())],
                    spacing: 16
                ) {
                    ForEach(genreSamples, id: \.genre) { item in
                        GenrePennantCard(genre: item.genre, games: item.games)
                    }
                }
            }

            Button(action: { onNavigate(.allGames) }) {
                HStack {
                    Spacer()
                    Text("Alle Spiele als Liste").font(.system(size: 13, weight: .semibold))
                    Image(systemName: "chevron.right")
                    Spacer()
                }
                .padding(.vertical, 12)
                .background(Color.rogueRed.opacity(0.12))
                .foregroundColor(.rogueRed)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Refresh

    private func refreshGenres() {
        let pool = shopStore.games
        var byGenre: [String: [ShopGame]] = [:]
        for g in pool {
            let genre = normalizeGenre(g.genre)
            if !genre.isEmpty { byGenre[genre, default: []].append(g) }
        }
        let samples = byGenre
            .filter { !$0.value.isEmpty }
            .sorted { $0.key < $1.key }
            .prefix(6)
            .map { (genre: $0.key, games: Array($0.value.shuffled().prefix(3))) }
        if !samples.isEmpty { genreSamples = samples }
    }
}

// MARK: - Genre Pennant Card

struct GenrePennantCard: View {
    let genre: String
    let games: [ShopGame]

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                LinearGradient(colors: colorsForGenre(genre),
                               startPoint: .topLeading, endPoint: .bottomTrailing)
                HStack(spacing: 8) {
                    Image(systemName: iconForGenre(genre)).font(.system(size: 16, weight: .bold))
                    Text(genre).font(.system(size: 14, weight: .bold))
                }
                .foregroundColor(.white)
            }
            .frame(height: 52)
            .clipShape(PennantShape())

            VStack(spacing: 6) {
                ForEach(games) { game in
                    HStack(spacing: 8) {
                        AsyncImage(url: game.coverImageURL) { img in
                            img.resizable().scaledToFill()
                        } placeholder: {
                            RoundedRectangle(cornerRadius: 3).fill(Color.secondary.opacity(0.2))
                        }
                        .frame(width: 28, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 3))

                        Text(game.name)
                            .font(.system(size: 11)).lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
            .padding(10)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.15)))
    }
}

struct PennantShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        path.addLine(to: CGPoint(x: rect.midX, y: rect.maxY - 12))
        path.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
        path.closeSubpath()
        return path
    }
}

// MARK: - Install Button

struct InstallButton: View {
    let game: ShopGame
    let large: Bool
    @State private var showSourcePicker = false

    var body: some View {
        Group {
            Button(action: handleInstall) {
                Label("Installieren", systemImage: "arrow.down.circle.fill")
                    .font(.system(size: large ? 13 : 11, weight: .semibold))
                    .padding(.horizontal, large ? 16 : 10)
                    .padding(.vertical, large ? 8 : 5)
                    .background(Color.green)
                    .foregroundColor(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }
            .buttonStyle(.plain)
        }
        .sheet(isPresented: $showSourcePicker) {
            InstallSourcePickerView(game: game, isPresented: $showSourcePicker)
        }
    }

    private func handleInstall() {
        if game.sources.count <= 1 {
            if let src = game.sources.first { openLauncher(src) }
        } else {
            showSourcePicker = true
        }
    }

    func openLauncher(_ source: ShopGame.InstallSource) {
        switch source {
        case .nas:
            if let g = game.nasGame { BackupStore.shared.install(g) }

        case .steam:
            let appName = AppSettings.shared.gameLaunchers
                .first { $0.id == "steam" }?.sunshineAppName
                ?? (AppSettings.shared.sunshineSteamAppName.isEmpty ? "Steam Big Picture" : AppSettings.shared.sunshineSteamAppName)
            streamWindowed(appName: appName)

        case .epic:
            let appName = AppSettings.shared.gameLaunchers
                .first { $0.id == "epic" }?.sunshineAppName ?? "Epic Games Launcher"
            streamWindowed(appName: appName)

        case .gog:
            let appName = AppSettings.shared.gameLaunchers
                .first { $0.id == "gog" }?.sunshineAppName ?? "GalaxyClient"
            streamWindowed(appName: appName)
        }
    }

    private func streamWindowed(appName: String) {
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

// MARK: - Install Source Picker

struct InstallSourcePickerView: View {
    let game: ShopGame
    @Binding var isPresented: Bool

    var body: some View {
        VStack(spacing: 20) {
            Text("Von wo installieren?").font(.system(size: 16, weight: .bold))
            Text(game.name).font(.system(size: 13)).foregroundColor(.secondary)

            VStack(spacing: 10) {
                ForEach(game.sources.indices, id: \.self) { i in
                    let src = game.sources[i]
                    Button(action: {
                        isPresented = false
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                            InstallButton(game: game, large: false).openLauncher(src)
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: src.icon).font(.system(size: 16)).frame(width: 28)
                            Text(src.label).font(.system(size: 14, weight: .medium))
                            Spacer()
                            Image(systemName: "chevron.right").foregroundColor(.secondary)
                        }
                        .padding(.horizontal, 16).padding(.vertical, 12)
                        .background(Color(NSColor.controlBackgroundColor))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    }
                    .buttonStyle(.plain)
                }
            }
            Button("Abbrechen") { isPresented = false }.buttonStyle(.bordered)
        }
        .padding(24).frame(width: 320)
    }
}

// MARK: - Import Wrapper

struct ShopImportView: View {
    let onBack: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Button(action: onBack) {
                    Label("Zurück zum Shop", systemImage: "chevron.left").font(.system(size: 12))
                }
                .buttonStyle(.bordered).controlSize(.small)
                Spacer()
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            Divider()
            SunshineImportWindowView()
        }
    }
}

