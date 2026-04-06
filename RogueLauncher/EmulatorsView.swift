import SwiftUI
import AppKit

// MARK: - Supported ROM Systems

struct RomSystem: Identifiable {
    let id: String
    let label: String
    let extensions: [String]
    let core: String  // RetroArch core filename

    static let coresPath = NSHomeDirectory() + "/.config/retroarch/cores/"

    static let all: [RomSystem] = [
        RomSystem(id: "nes",      label: "NES",              extensions: ["nes"],             core: "nestopia_libretro.dylib"),
        RomSystem(id: "snes",     label: "SNES",             extensions: ["smc","sfc","fig"], core: "snes9x_libretro.dylib"),
        RomSystem(id: "n64",      label: "Nintendo 64",      extensions: ["n64","z64","v64"], core: "mupen64plus_next_libretro.dylib"),
        RomSystem(id: "gba",      label: "Game Boy Advance", extensions: ["gba"],             core: "mgba_libretro.dylib"),
        RomSystem(id: "gbc",      label: "Game Boy Color",   extensions: ["gbc"],             core: "gambatte_libretro.dylib"),
        RomSystem(id: "gb",       label: "Game Boy",         extensions: ["gb"],              core: "gambatte_libretro.dylib"),
        RomSystem(id: "nds",      label: "Nintendo DS",      extensions: ["nds"],             core: "desmume2015_libretro.dylib"),
        RomSystem(id: "gamecube", label: "GameCube",         extensions: ["iso","gcm","gcz"], core: "dolphin_libretro.dylib"),
        RomSystem(id: "ps1",      label: "PlayStation 1",    extensions: ["bin","cue"],       core: "mednafen_psx_hw_libretro.dylib"),
        RomSystem(id: "ps2",      label: "PlayStation 2",    extensions: ["iso"],             core: "pcsx2_libretro.dylib"),
        RomSystem(id: "genesis",  label: "Sega Genesis",     extensions: ["md","bin","smd"],  core: "genesis_plus_gx_libretro.dylib"),
        RomSystem(id: "sms",      label: "Sega Master Sys.", extensions: ["sms"],             core: "genesis_plus_gx_libretro.dylib"),
    ]

    static func detect(for url: URL) -> RomSystem? {
        let ext = url.pathExtension.lowercased()
        return all.first { $0.extensions.contains(ext) }
    }

    var corePath: String { RomSystem.coresPath + core }
    var coreInstalled: Bool { FileManager.default.fileExists(atPath: corePath) }
}

// MARK: - RetroArch Launcher

struct RetroArchLauncher {
    // RetroArch kann als CLI oder als .app installiert sein
    static var retroarchCLI: String? {
        let cliPaths = ["/opt/homebrew/bin/retroarch", "/usr/local/bin/retroarch"]
        return cliPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    static var retroarchApp: String? {
        let appPaths = ["/Applications/RetroArch.app", NSHomeDirectory() + "/Applications/RetroArch.app"]
        return appPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    static var isInstalled: Bool {
        retroarchCLI != nil || retroarchApp != nil
    }

    static func launch(romPath: String, system: String) {
        guard let romSystem = RomSystem.all.first(where: { $0.id == system }) else { return }

        if let cli = retroarchCLI {
            // CLI-Modus: retroarch -L core rom
            let proc = Process()
            proc.executableURL = URL(fileURLWithPath: "/bin/bash")
            var args = [cli]
            if romSystem.coreInstalled {
                args += ["-L", romSystem.corePath]
            }
            args.append(romPath)
            proc.arguments = ["-c", args.map { "\"\($0)\"" }.joined(separator: " ")]
            try? proc.run()
        } else if let app = retroarchApp {
            // App-Modus: ROM direkt mit RetroArch oeffnen
            let romURL = URL(fileURLWithPath: romPath)
            NSWorkspace.shared.open(
                [romURL],
                withApplicationAt: URL(fileURLWithPath: app),
                configuration: NSWorkspace.OpenConfiguration()
            )
        }
    }
}

// MARK: - EmulatorsView

struct EmulatorsView: View {
    @ObservedObject var store: GameStore
    @ObservedObject private var settings = AppSettings.shared
    @State private var showImportSheet = false

    private var romGames: [Game] {
        store.games.filter { $0.type == .rom }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Emulatoren")
                        .font(.system(size: 20, weight: .bold))
                    Text("\(romGames.count) ROM\(romGames.count == 1 ? "" : "s")")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button(action: { showImportSheet = true }) {
                    Label("ROM importieren", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
                .disabled(!RetroArchLauncher.isInstalled)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)

            // RetroArch Warnung
            if !RetroArchLauncher.isInstalled {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("RetroArch ist nicht installiert.")
                            .font(.system(size: 12, weight: .medium))
                        Text("brew install retroarch")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Im Terminal installieren") {
                        let script = "tell application \"Terminal\" to do script \"brew install retroarch\""
                        NSAppleScript(source: script)?.executeAndReturnError(nil)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
                .padding(12)
                .background(Color.orange.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .padding(.horizontal, 24)
                .padding(.bottom, 8)
            }

            Divider()

            if romGames.isEmpty {
                emptyState
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 32) {
                        // Gruppiert nach bekanntem System
                        ForEach(RomSystem.all) { system in
                            let games = romGames.filter { $0.romSystem == system.id }
                            if !games.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    HStack(spacing: 8) {
                                        Image(systemName: "cpu")
                                            .foregroundColor(.green)
                                            .font(.system(size: 13))
                                        Text(system.label)
                                            .font(.system(size: 14, weight: .semibold))
                                        Text("(\(games.count))")
                                            .font(.system(size: 12))
                                            .foregroundColor(.secondary)
                                    }
                                    LazyVGrid(
                                        columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)],
                                        spacing: 16
                                    ) {
                                        ForEach(games) { game in
                                            RomCard(game: game, store: store)
                                        }
                                    }
                                }
                            }
                        }

                        // Fallback: ROMs ohne bekanntes System
                        let knownIDs = Set(RomSystem.all.map { $0.id })
                        let unmatched = romGames.filter { !knownIDs.contains($0.romSystem) }
                        if !unmatched.isEmpty {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "cpu")
                                        .foregroundColor(.green)
                                        .font(.system(size: 13))
                                    Text("Sonstige")
                                        .font(.system(size: 14, weight: .semibold))
                                    Text("(\(unmatched.count))")
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                }
                                LazyVGrid(
                                    columns: [GridItem(.adaptive(minimum: 140, maximum: 160), spacing: 16)],
                                    spacing: 16
                                ) {
                                    ForEach(unmatched) { game in
                                        RomCard(game: game, store: store)
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
            RomImportSheet(store: store)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "gamecontroller")
                .font(.system(size: 48))
                .foregroundColor(.secondary.opacity(0.4))
            Text("Keine ROMs importiert")
                .font(.system(size: 16, weight: .medium))
            Text("Importiere eine ROM-Datei um sie hier anzuzeigen.")
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            Spacer()
        }
        .padding(40)
    }
}

// MARK: - ROM Card

struct RomCard: View {
    let game: Game
    let store: GameStore
    @State private var hovering = false

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
                    hovering ?
                    RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.3)) : nil
                )

                if hovering {
                    Button(action: launchRom) {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 40))
                            .foregroundColor(.white)
                            .shadow(radius: 4)
                    }
                    .buttonStyle(.plain)
                }

                if !game.romSystem.isEmpty {
                    Text(RomSystem.all.first(where: { $0.id == game.romSystem })?.label ?? game.romSystem.uppercased())
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(.white)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Color.black.opacity(0.7))
                        .clipShape(RoundedRectangle(cornerRadius: 4))
                        .padding(6)
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
            Button("Spielen") { launchRom() }
            Divider()
            Button("Löschen", role: .destructive) { store.delete(game) }
        }
    }

    private func launchRom() {
        guard let path = game.romPath else { return }
        RetroArchLauncher.launch(romPath: path, system: game.romSystem)
    }
}

// MARK: - ROM Import Sheet

struct RomImportSheet: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var selectedSystem = RomSystem.all[0]
    @State private var romURL: URL? = nil
    @State private var searchQuery = ""
    @State private var searchResults: [GameMetadataService.IGDBSearchResult] = []
    @State private var selectedMetadata: GameMetadataService.IGDBSearchResult? = nil
    @State private var searching = false
    @State private var importing = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("ROM importieren")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                Button("Abbrechen") { dismiss() }
            }
            .padding(20)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // System
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SYSTEM")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: 8) {
                                ForEach(RomSystem.all) { system in
                                    Button(action: { selectedSystem = system }) {
                                        HStack(spacing: 4) {
                                            if !system.coreInstalled {
                                                Image(systemName: "exclamationmark.circle.fill")
                                                    .font(.system(size: 10))
                                                    .foregroundColor(.orange)
                                            }
                                            Text(system.label)
                                                .font(.system(size: 12, weight: selectedSystem.id == system.id ? .semibold : .regular))
                                        }
                                        .padding(.horizontal, 10).padding(.vertical, 6)
                                        .background(selectedSystem.id == system.id ? Color.accentColor.opacity(0.2) : Color.secondary.opacity(0.1))
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                        if !selectedSystem.coreInstalled {
                            HStack(spacing: 6) {
                                Image(systemName: "exclamationmark.triangle").foregroundColor(.orange)
                                Text("Core nicht installiert. Im Terminal:")
                                    .font(.system(size: 11))
                                    .foregroundColor(.secondary)
                                Text("retroarch-coreinfo && retroarch -v")
                                    .font(.system(size: 11, design: .monospaced))
                            }
                        }
                    }

                    // ROM Datei
                    VStack(alignment: .leading, spacing: 8) {
                        Text("ROM-DATEI")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack {
                            if let url = romURL {
                                Image(systemName: "doc.fill").foregroundColor(.accentColor)
                                Text(url.lastPathComponent)
                                    .font(.system(size: 13)).lineLimit(1)
                                Spacer()
                                Button("Ändern") { pickRom() }
                                    .buttonStyle(.bordered).controlSize(.small)
                            } else {
                                Button(action: pickRom) {
                                    Label("ROM-Datei wählen", systemImage: "folder")
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        .padding(10)
                        .background(Color.secondary.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // IGDB Suche
                    VStack(alignment: .leading, spacing: 8) {
                        Text("SPIELNAME SUCHEN (optional)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                        HStack {
                            TextField("Spielname bei IGDB suchen...", text: $searchQuery)
                                .textFieldStyle(.roundedBorder)
                            Button(action: searchIGDB) {
                                if searching { ProgressView().scaleEffect(0.7) }
                                else { Text("Suchen") }
                            }
                            .buttonStyle(.bordered)
                            .disabled(searchQuery.isEmpty || searching)
                        }

                        if !searchResults.isEmpty {
                            VStack(spacing: 4) {
                                ForEach(searchResults.prefix(8)) { result in
                                    Button(action: { selectedMetadata = result }) {
                                        HStack {
                                            if let url = result.coverURL, let nsurl = URL(string: url) {
                                                AsyncImage(url: nsurl) { img in
                                                    img.resizable().scaledToFill()
                                                } placeholder: {
                                                    Color.secondary.opacity(0.2)
                                                }
                                                .frame(width: 32, height: 45)
                                                .clipShape(RoundedRectangle(cornerRadius: 4))
                                            }
                                            VStack(alignment: .leading) {
                                                Text(result.name)
                                                    .font(.system(size: 13, weight: .medium))
                                                if !result.year.isEmpty {
                                                    Text(result.year)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.secondary)
                                                }
                                            }
                                            Spacer()
                                            if selectedMetadata?.id == result.id {
                                                Image(systemName: "checkmark.circle.fill")
                                                    .foregroundColor(.accentColor)
                                            }
                                        }
                                        .padding(8)
                                        .background(selectedMetadata?.id == result.id ? Color.accentColor.opacity(0.1) : Color.clear)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                            .padding(8)
                            .background(Color.secondary.opacity(0.05))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(20)
            }

            Divider()

            HStack {
                if importing { ProgressView().scaleEffect(0.8) }
                Spacer()
                Button("Importieren") { importRom() }
                    .buttonStyle(.borderedProminent)
                    .disabled(romURL == nil || importing)
            }
            .padding(16)
        }
        .frame(width: 520, height: 580)
    }

    private func pickRom() {
        let panel = NSOpenPanel()
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.title = "ROM-Datei wahlen"
        if panel.runModal() == .OK, let url = panel.url {
            romURL = url
            if let detected = RomSystem.detect(for: url) {
                selectedSystem = detected
            }
            let name = url.deletingPathExtension().lastPathComponent
                .replacingOccurrences(of: "_", with: " ")
                .replacingOccurrences(of: "-", with: " ")
            if searchQuery.isEmpty { searchQuery = name }
        }
    }

    private func searchIGDB() {
        guard !searchQuery.isEmpty else { return }
        searching = true
        GameMetadataService.searchIGDB(query: searchQuery) { results in
            DispatchQueue.main.async {
                searchResults = results
                searching = false
                if let first = results.first { selectedMetadata = first }
            }
        }
    }

    private func importRom() {
        guard let url = romURL else { return }
        importing = true

        func saveImage(from urlStr: String?, filename: String, completion: @escaping (String?) -> Void) {
            guard let urlStr, let imgURL = URL(string: urlStr) else { completion(nil); return }
            URLSession.shared.dataTask(with: imgURL) { data, _, _ in
                guard let data else { completion(nil); return }
                let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                    .appendingPathComponent("RogueLauncher/Covers")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let file = dir.appendingPathComponent(filename)
                try? data.write(to: file)
                completion(file.path)
            }.resume()
        }

        let finalize: (String?, String?) -> Void = { cover, bg in
            DispatchQueue.main.async {
                let meta = self.selectedMetadata
                var game = Game(
                    name: meta?.name ?? url.deletingPathExtension().lastPathComponent,
                    description: "",
                    genre: "",
                    releaseYear: meta?.year ?? "",
                    appName: "",
                    type: .rom
                )
                game.romPath = url.path
                game.romSystem = self.selectedSystem.id
                game.coverImagePath = cover
                game.backgroundImagePath = bg
                if let id = meta?.id { game.igdbID = id }
                self.store.add(game)
                self.importing = false
                self.dismiss()
            }
        }

        if let meta = selectedMetadata {
            GameMetadataService.fetchFromIGDBbyID(id: meta.id) { fullMeta in
                saveImage(from: fullMeta?.coverURL ?? meta.coverURL, filename: "\(meta.id)_cover.jpg") { cover in
                    saveImage(from: fullMeta?.backgroundURL, filename: "\(meta.id)_bg.jpg") { bg in
                        finalize(cover, bg)
                    }
                }
            }
        } else {
            finalize(nil, nil)
        }
    }
}
