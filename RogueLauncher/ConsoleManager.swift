import SwiftUI
import AppKit

// MARK: - DDC Display Switcher

class DDCSwitcher {
    static let m1ddcPath: String = {
        // Homebrew auf Apple Silicon: /opt/homebrew/bin, Intel: /usr/local/bin
        let paths = ["/opt/homebrew/bin/m1ddc", "/usr/local/bin/m1ddc"]
        return paths.first { FileManager.default.fileExists(atPath: $0) } ?? "m1ddc"
    }()

    static func setInput(_ inputNumber: Int, display: Int = 1) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-c", "\(m1ddcPath) display \(display) set input \(inputNumber)"]
        try? proc.run()
    }

    static func getInput(display: Int = 1, completion: @escaping (Int?) -> Void) {
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: "/bin/bash")
        proc.arguments = ["-c", "\(m1ddcPath) display \(display) get input"]
        let pipe = Pipe()
        proc.standardOutput = pipe
        proc.terminationHandler = { _ in
            let out = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
            completion(Int(out.trimmingCharacters(in: .whitespacesAndNewlines)))
        }
        try? proc.run()
    }

    static func isInstalled() -> Bool {
        let paths = ["/opt/homebrew/bin/m1ddc", "/usr/local/bin/m1ddc"]
        return paths.contains { FileManager.default.fileExists(atPath: $0) }
    }
}

// MARK: - Display Setup Wizard

struct DisplaySetupWizard: View {
    @ObservedObject private var settings = AppSettings.shared
    @Environment(\.dismiss) private var dismiss

    let hdmiInputs = [17, 18]
    @State private var currentStep = 0
    @State private var inputLabels: [Int: String] = [:]
    @State private var isSwitching = false
    @State private var labelInput = ""
    @State private var macInput = 15
    @State private var done = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("Display-Einrichtung")
                        .font(.system(size: 15, weight: .semibold))
                    Text("Schritt \(min(currentStep + 1, hdmiInputs.count + 1)) von \(hdmiInputs.count + 1)")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Abbrechen") { dismiss() }
            }
            .padding(20)
            Divider()

            if done {
                doneView
            } else if currentStep < hdmiInputs.count {
                stepView(inputNumber: hdmiInputs[currentStep])
            } else {
                macStepView
            }
        }
        .frame(width: 480, height: 480)
    }

    private func stepView(inputNumber: Int) -> some View {
        ScrollView {
          VStack(spacing: 16) {
            Image(systemName: "display.2")
                .font(.system(size: 32))
                .foregroundColor(.rogueRed)
                .padding(.top, 12)

            Text("HDMI \(inputNumber == 17 ? "1" : "2") (Eingang \(inputNumber))")
                .font(.system(size: 16, weight: .semibold))

            // Hinweis
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: "info.circle")
                    .foregroundColor(.orange).font(.system(size: 11))
                Text("Tipp: Deaktiviere \"Auto Input Switch\" im Monitor-OSD damit der Monitor nicht zurückspringt.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(8)
            .background(Color.orange.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if isSwitching {
                VStack(spacing: 8) {
                    ProgressView()
                    Text("Schalte auf HDMI \(inputNumber == 17 ? "1" : "2") um…")
                        .font(.system(size: 12)).foregroundColor(.secondary)
                }
            } else {
                VStack(spacing: 12) {
                    Text("Was siehst du gerade auf dem externen Monitor?")
                        .font(.system(size: 13))
                        .multilineTextAlignment(.center)
                    TextField("z.B. PlayStation 5, Nintendo Switch, Leer…", text: $labelInput)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 280)
                }
            }

            Spacer()

            HStack {
                if !isSwitching {
                    Button("Umschalten & prüfen") {
                        isSwitching = true
                        labelInput = ""
                        DDCSwitcher.setInput(inputNumber)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                            isSwitching = false
                        }
                    }
                    .buttonStyle(.bordered)
                }
                Spacer()
                if !isSwitching {
                    Button("Weiter") {
                        if !labelInput.trimmingCharacters(in: .whitespaces).isEmpty {
                            inputLabels[inputNumber] = labelInput.trimmingCharacters(in: .whitespaces)
                        }
                        labelInput = ""
                        currentStep += 1
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
          }
          .padding(.horizontal, 20)
        }
    }

    private var macStepView: some View {
        VStack(spacing: 20) {
            Image(systemName: "laptopcomputer")
                .font(.system(size: 36))
                .foregroundColor(.rogueRed)
                .padding(.top, 20)

            Text("Mac-Eingang bestätigen")
                .font(.system(size: 16, weight: .semibold))

            Text("Zum Abschluss schalten wir zurück auf deinen Mac.\nWelche DDC-Nummer hat dein USB-C/DP Eingang?")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Picker("Mac-Eingang", selection: $macInput) {
                Text("15 (DisplayPort / USB-C)").tag(15)
                Text("16 (DisplayPort 2)").tag(16)
                Text("27 (USB-C direkt)").tag(27)
            }
            .pickerStyle(.radioGroup)

            Spacer()

            HStack {
                Spacer()
                Button("Fertigstellen") {
                    // Zurück auf Mac schalten
                    DDCSwitcher.setInput(macInput)
                    // Speichern
                    var map: [String: String] = [:]
                    for (k, v) in inputLabels { map[String(k)] = v }
                    settings.hdmiInputMap = map
                    settings.macInputNumber = macInput
                    settings.consolesEnabled = true
                    settings.save()
                    done = true
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
    }

    private var doneView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(.green)
                .padding(.top, 24)

            Text("Einrichtung abgeschlossen!")
                .font(.system(size: 16, weight: .semibold))

            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(inputLabels.keys.sorted()), id: \.self) { k in
                    HStack {
                        Text("HDMI \(k == 17 ? "1" : "2"):")
                            .foregroundColor(.secondary)
                        Text(inputLabels[k] ?? "")
                            .fontWeight(.medium)
                    }
                    .font(.system(size: 13))
                }
                HStack {
                    Text("Mac:").foregroundColor(.secondary)
                    Text("Eingang \(macInput)").fontWeight(.medium)
                }
                .font(.system(size: 13))
            }

            Spacer()
            Button("Schließen") { dismiss() }
                .buttonStyle(.borderedProminent)
                .padding(.bottom, 16)
        }
        .padding(.horizontal, 20)
    }
}

// MARK: - Console Game Import View

struct ConsoleImportView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var settings = AppSettings.shared

    @State private var searchQuery = ""
    @State private var searchResults: [GameMetadataService.IGDBSearchResult] = []
    @State private var isSearching = false
    @State private var selectedConsole = "ps5"
    @State private var importing: Int? = nil

    let consoles: [(id: String, label: String, icon: String)] = [
        ("ps5",    "PlayStation 5", "🎮"),
        ("switch", "Nintendo Switch", "🕹️"),
        ("xbox",   "Xbox", "🎯"),
        ("ps4",    "PlayStation 4", "🎮"),
    ]

    var availableConsoles: [(id: String, label: String, icon: String)] {
        consoles.filter { c in
            settings.hdmiInputMap.values.contains { $0.lowercased().contains(c.id) || $0.lowercased().contains(c.label.lowercased()) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Konsolenspiel hinzufügen")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Schließen") { dismiss() }
            }
            .padding(20)
            Divider()

            VStack(spacing: 12) {
                // Konsolen-Picker
                HStack(spacing: 8) {
                    Text("Konsole:").font(.system(size: 12)).foregroundColor(.secondary)
                    ForEach(consoles, id: \.id) { c in
                        Button(action: { selectedConsole = c.id }) {
                            HStack(spacing: 4) {
                                Text(c.icon).font(.system(size: 14))
                                Text(c.label).font(.system(size: 12))
                            }
                            .padding(.horizontal, 10).padding(.vertical, 5)
                            .background(selectedConsole == c.id ? Color.rogueRed.opacity(0.15) : Color.secondary.opacity(0.1))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .foregroundColor(selectedConsole == c.id ? .rogueRed : .primary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 16)

                // Suche
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                    TextField("Spielname bei IGDB suchen…", text: $searchQuery)
                        .textFieldStyle(.plain)
                        .onSubmit { search() }
                    if isSearching {
                        ProgressView().frame(width: 16, height: 16)
                    } else if !searchQuery.isEmpty {
                        Button("Suchen") { search() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(10)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 16)
            }
            .padding(.top, 12)

            Divider().padding(.top, 8)

            // Ergebnisse
            if searchResults.isEmpty && !isSearching {
                VStack(spacing: 8) {
                    Image(systemName: "gamecontroller")
                        .font(.system(size: 32)).foregroundColor(.secondary.opacity(0.4))
                    Text("Spielname eingeben und suchen")
                        .font(.system(size: 13)).foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(searchResults, id: \.id) { result in
                            HStack(spacing: 12) {
                                if let url = result.coverURL, let nsURL = URL(string: url) {
                                    AsyncImage(url: nsURL) { phase in
                                        if case .success(let img) = phase {
                                            img.resizable().aspectRatio(contentMode: .fill)
                                        } else {
                                            Color.secondary.opacity(0.2)
                                        }
                                    }
                                    .frame(width: 40, height: 53)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                } else {
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(Color.secondary.opacity(0.15))
                                        .frame(width: 40, height: 53)
                                }

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.name).font(.system(size: 13, weight: .medium))
                                    Text(result.year).font(.system(size: 11)).foregroundColor(.secondary)
                                }
                                Spacer()

                                let alreadyAdded = store.games.contains { $0.igdbID == result.id && $0.consoleType == selectedConsole }

                                if alreadyAdded {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                } else if importing == result.id {
                                    ProgressView().frame(width: 20, height: 20)
                                } else {
                                    Button("Hinzufügen") { addGame(result) }
                                        .buttonStyle(.borderedProminent)
                                        .tint(Color.rogueRed)
                                        .controlSize(.small)
                                }
                            }
                            .padding(.horizontal, 16).padding(.vertical, 8)
                            Divider().padding(.leading, 68)
                        }
                    }
                }
            }
        }
        .frame(width: 560, height: 520)
    }

    private func search() {
        guard !searchQuery.isEmpty else { return }
        isSearching = true
        searchResults = []
        GameMetadataService.searchIGDB(query: searchQuery) { found in
            DispatchQueue.main.async {
                searchResults = found
                isSearching = false
            }
        }
    }

    private func addGame(_ result: GameMetadataService.IGDBSearchResult) {
        importing = result.id

        // Volle Metadaten von IGDB laden (Beschreibung, Genre, Hintergrundbild)
        GameMetadataService.fetchFromIGDBbyID(id: result.id) { metadata in
            // Cover herunterladen
            let coverURL = metadata?.coverURL ?? result.coverURL
            let bgURL = metadata?.backgroundURL

            func saveImage(from urlString: String?, filename: String, completion: @escaping (String?) -> Void) {
                guard let urlString, let url = URL(string: urlString) else { completion(nil); return }
                URLSession.shared.dataTask(with: url) { data, _, _ in
                    guard let data else { completion(nil); return }
                    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        .appendingPathComponent("RogueLauncher/Covers")
                    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                    let file = dir.appendingPathComponent(filename)
                    try? data.write(to: file)
                    completion(file.path)
                }.resume()
            }

            saveImage(from: coverURL, filename: "\(result.id)_cover.jpg") { coverPath in
                saveImage(from: bgURL, filename: "\(result.id)_bg.jpg") { bgPath in
                    DispatchQueue.main.async {
                        var game = Game(name: result.name,
                                       description: metadata?.description ?? "",
                                       genre: metadata?.genre ?? "",
                                       releaseYear: result.year,
                                       appName: "", type: .console)
                        game.coverImagePath = coverPath
                        game.backgroundImagePath = bgPath
                        game.igdbID = result.id
                        game.consoleType = self.selectedConsole
                        self.store.add(game)
                        self.importing = nil
                    }
                }
            }
        }
    }
}


// MARK: - Consoles Library View

struct ConsolesLibraryView: View {
    @ObservedObject var store: GameStore
    @State private var showImportSheet = false

    private let consoleDefs: [(id: String, label: String)] = [
        ("ps5", "PlayStation 5"),
        ("ps4", "PlayStation 4"),
        ("switch", "Nintendo Switch"),
        ("xbox", "Xbox"),
    ]

    private var consoleGames: [Game] {
        store.games.filter { $0.type == .console }
    }

    private func games(for consoleID: String) -> [Game] {
        consoleGames.filter { $0.consoleType.lowercased() == consoleID }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Konsolen")
                        .font(.system(size: 20, weight: .bold))
                    Text("\(consoleGames.count) Spiel\(consoleGames.count == 1 ? "" : "e")")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { showImportSheet = true }) {
                    Label("Spiel hinzufügen", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            Divider()

            if consoleGames.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "tv")
                        .font(.system(size: 48))
                        .foregroundColor(.secondary.opacity(0.4))
                    Text("Keine Konsolenspiele importiert")
                        .font(.system(size: 16, weight: .medium))
                    Text("Klicke auf Spiel hinzufügen um ein Konsolenspiel zu importieren.")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(40)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        ForEach(consoleDefs, id: \.id) { console in
                            let g = games(for: console.id)
                            if !g.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "gamecontroller.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 13))
                                        Text(console.label)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("(\(g.count))")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    LazyVGrid(
                                        columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)],
                                        spacing: 16
                                    ) {
                                        ForEach(g) { game in
                                            ConsoleGameCard(game: game, store: store)
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(24)
                }
            }
        }
        .sheet(isPresented: $showImportSheet) {
            ConsoleImportView(store: store)
        }
    }
}

// MARK: - Console Game Card

struct ConsoleGameCard: View {
    let game: Game
    let store: GameStore
    @State private var hovering = false

    private var consoleName: String {
        let defs: [(String, String)] = [("ps5","PlayStation 5"),("ps4","PlayStation 4"),("switch","Nintendo Switch"),("xbox","Xbox")]
        return defs.first { $0.0 == game.consoleType }?.1 ?? game.consoleType
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                Group {
                    if let path = game.coverImagePath, let img = NSImage(contentsOfFile: path) {
                        Image(nsImage: img)
                            .resizable()
                            .scaledToFill()
                    } else {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color.secondary.opacity(0.15))
                            Image(systemName: "gamecontroller.fill")
                                .font(.system(size: 28))
                                .foregroundColor(.secondary.opacity(0.4))
                        }
                    }
                }
                .frame(width: 140, height: 196)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    hovering ? RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)) : nil
                )

                if hovering {
                    Button(action: switchDisplay) {
                        Image(systemName: "display.2")
                            .font(.system(size: 32))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                }
            }

            Text(game.name)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 140)
        }
        .onHover { hovering = $0 }
        .contextMenu {
            Button("Bildschirm umschalten") { switchDisplay() }
            Divider()
            Button("Löschen", role: .destructive) { store.delete(game) }
        }
    }

    private func switchDisplay() {
        let settings = AppSettings.shared
        let typeLC = game.consoleType.lowercased()
        let switchKeys = ["switch", "nintendo"]
        let psKeys = ["ps4", "ps5", "playstation"]
        let xboxKeys = ["xbox", "microsoft"]

        let inputEntry = settings.hdmiInputMap.first { _, label in
            let labelLC = label.lowercased()
            if labelLC.contains(typeLC) || typeLC.contains(labelLC) { return true }
            if switchKeys.contains(typeLC) { return switchKeys.contains(where: { labelLC.contains($0) }) }
            if psKeys.contains(typeLC) { return psKeys.contains(where: { labelLC.contains($0) }) }
            if xboxKeys.contains(typeLC) { return xboxKeys.contains(where: { labelLC.contains($0) }) }
            return false
        }
        guard let entry = inputEntry, let inputNumber = Int(entry.key) else { return }

        var updated = game
        updated.lastPlayedAt = Date()
        NotificationCenter.default.post(name: .init("UpdateGame"), object: updated)

        MenuBarManager.shared.activateConsoleMode(
            consoleName: entry.value,
            inputNumber: inputNumber,
            macInput: settings.macInputNumber
        )
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            DDCSwitcher.setInput(inputNumber)
        }
    }
}
