import Foundation
import AppKit

struct BackupGame: Identifiable {
    let id = UUID()
    let name: String
    var customName: String?
    let installerURL: URL
    var coverImagePath: String?

    var displayName: String { customName ?? name }

    var coverImage: NSImage? {
        guard let path = coverImagePath else { return nil }
        return NSImage(contentsOfFile: path)
    }

    var installerType: InstallerType {
        switch installerURL.pathExtension.lowercased() {
        case "pkg": return .pkg
        case "dmg": return .dmg
        default:    return .unknown
        }
    }

    enum InstallerType { case pkg, dmg, unknown }
}

class BackupStore: ObservableObject {
    static let shared = BackupStore()

    @Published var games: [BackupGame] = []
    @Published var isScanning = false
    @Published var isInstalling: UUID? = nil
    @Published var installProgress: String = ""
    @Published var copyProgress: Double = 0  // 0.0 - 1.0
    @Published var isCopying = false

    private let customNamesKey = "backupCustomNames"
    private let customCoversKey = "backupCustomCovers"

    private func loadCustomizations() -> ([String: String], [String: String]) {
        let names = UserDefaults.standard.dictionary(forKey: customNamesKey) as? [String: String] ?? [:]
        let covers = UserDefaults.standard.dictionary(forKey: customCoversKey) as? [String: String] ?? [:]
        return (names, covers)
    }

    private func saveCustomizations() {
        var names: [String: String] = [:]
        var covers: [String: String] = [:]
        for game in games {
            if let n = game.customName { names[game.name] = n }
            if let c = game.coverImagePath { covers[game.name] = c }
        }
        UserDefaults.standard.set(names, forKey: customNamesKey)
        UserDefaults.standard.set(covers, forKey: customCoversKey)
    }

    private init() {}

    /// Mountet den NAS-Pfad via SMB/AFP-URL und scannt dann.
    func scan(path: String, nasURL: String = "") {
        guard !path.isEmpty else { games = []; return }
        isScanning = true
        DispatchQueue.global(qos: .userInitiated).async {
            self.mountAndScan(path: path, nasURL: nasURL)
        }
    }

    private func mountAndScan(path: String, nasURL: String) {
        let fm = FileManager.default

        // Prüfe ob Pfad erreichbar
        if !fm.fileExists(atPath: path) {
            // Mounten via SMB/AFP-URL — Credentials kommen aus macOS-Keychain
            // (einmalig manuell via Finder → "Mit Server verbinden" + "Passwort merken")
            if let url = nasURL.isEmpty ? nil : URL(string: nasURL) {
                // mount_smbfs im Hintergrund, nutzt Keychain-Credentials
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                proc.arguments = [url.absoluteString]
                proc.qualityOfService = .background
                DispatchQueue.main.async { try? proc.run() }
            }
            // Warte bis zu 15 Sekunden auf Mount
            var attempts = 0
            while !fm.fileExists(atPath: path) && attempts < 30 {
                Thread.sleep(forTimeInterval: 0.5)
                attempts += 1
            }
            // Immer noch nicht erreichbar → still abbrechen, Retry via Timer
            guard fm.fileExists(atPath: path) else {
                DispatchQueue.main.async { self.isScanning = false }
                return
            }
        }

        let root = URL(fileURLWithPath: path)
        var found: [BackupGame] = []

        guard let dirs = try? fm.contentsOfDirectory(at: root, includingPropertiesForKeys: [.isDirectoryKey], options: .skipsHiddenFiles) else {
            DispatchQueue.main.async { self.isScanning = false }
            return
        }

            for dir in dirs {
                guard (try? dir.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true else { continue }
                let gameName = dir.lastPathComponent
                guard let files = try? fm.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil, options: .skipsHiddenFiles) else { continue }
                guard let installer = files.first(where: { ["pkg","dmg"].contains($0.pathExtension.lowercased()) }) else { continue }
                let support = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let coverPath = support.appendingPathComponent("RogueLauncher/Covers/\(gameName).jpg").path
                let cover = fm.fileExists(atPath: coverPath) ? coverPath : nil
                found.append(BackupGame(name: gameName, installerURL: installer, coverImagePath: cover))
            }

            let sorted = found.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            DispatchQueue.main.async {
                let (names, covers) = self.loadCustomizations()
                self.games = sorted.map { game in
                    var g = game
                    if let n = names[game.name] { g.customName = n }
                    if let c = covers[game.name], FileManager.default.fileExists(atPath: c) { g.coverImagePath = c }
                    return g
                }
                self.isScanning = false
                self.fetchMissingCovers()
            }
    }

    private func fetchMissingCovers() {
        for (i, game) in games.enumerated() where game.coverImagePath == nil {
            GameMetadataService.fetch(for: game.displayName) { [weak self] meta in
                guard let self = self, let meta = meta, let coverURL = meta.coverURL else { return }
                GameMetadataService.downloadCover(from: coverURL, for: game.name) { path in
                    guard let path = path else { return }
                    DispatchQueue.main.async {
                        if i < self.games.count { self.games[i].coverImagePath = path }
                    }
                }
            }
        }
    }

    func rename(game: BackupGame, to newName: String, coverPath: String?) {
        guard let i = games.firstIndex(where: { $0.id == game.id }) else { return }
        games[i].customName = newName
        if let path = coverPath {
            games[i].coverImagePath = path
        }
        saveCustomizations()
    }

    func install(_ game: BackupGame) {
        isInstalling = game.id
        installProgress = "Vorbereitung…"
        DispatchQueue.global(qos: .userInitiated).async {
            // Cache-Kopie wenn konfiguriert
            let cacheDir = AppSettings.shared.nasCacheDir
            var installerURL = game.installerURL
            if !cacheDir.isEmpty {
                let cached = URL(fileURLWithPath: cacheDir).appendingPathComponent(game.installerURL.lastPathComponent)
                if !FileManager.default.fileExists(atPath: cached.path) {
                    DispatchQueue.main.async { self.isCopying = true; self.copyProgress = 0 }
                    self.copyWithProgress(from: game.installerURL, to: cached)
                    DispatchQueue.main.async { self.isCopying = false; self.copyProgress = 0 }
                }
                if FileManager.default.fileExists(atPath: cached.path) {
                    installerURL = cached
                }
            }
            switch game.installerType {
            case .dmg:     self.installDMG(game, url: installerURL)
            case .pkg:     self.openInstaller(installerURL)
            case .unknown: DispatchQueue.main.async { self.isInstalling = nil }
            }
        }
    }

    private func copyWithProgress(from src: URL, to dest: URL) {
        guard let srcSize = try? src.resourceValues(forKeys: [.fileSizeKey]).fileSize, srcSize > 0 else {
            try? FileManager.default.copyItem(at: src, to: dest)
            return
        }
        // Chunk-weises Kopieren für Fortschritt
        guard let input = InputStream(url: src),
              let output = OutputStream(url: dest, append: false) else { return }
        input.open(); output.open()
        let chunkSize = 1024 * 1024 // 1MB
        var buffer = [UInt8](repeating: 0, count: chunkSize)
        var totalRead: Int64 = 0
        while input.hasBytesAvailable {
            let read = input.read(&buffer, maxLength: chunkSize)
            if read <= 0 { break }
            output.write(buffer, maxLength: read)
            totalRead += Int64(read)
            let progress = Double(totalRead) / Double(srcSize)
            DispatchQueue.main.async { self.copyProgress = min(progress, 1.0) }
        }
        input.close(); output.close()
    }

    private func installDMG(_ game: BackupGame, url: URL) {
        DispatchQueue.main.async { self.installProgress = "Mounte Disk Image…" }
        let mount = Process()
        mount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
        mount.arguments = ["attach", url.path, "-nobrowse", "-plist"]
        let pipe = Pipe()
        mount.standardOutput = pipe
        try? mount.run()
        mount.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard !data.isEmpty,
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let entities = plist["system-entities"] as? [[String: Any]],
              let mountPoint = entities.compactMap({ $0["mount-point"] as? String }).first
        else {
            DispatchQueue.main.async { self.isInstalling = nil; self.installProgress = "" }
            return
        }

        DispatchQueue.main.async { self.installProgress = "Suche App…" }
        let fm = FileManager.default
        let mountURL = URL(fileURLWithPath: mountPoint)

        if let contents = try? fm.contentsOfDirectory(at: mountURL, includingPropertiesForKeys: nil),
           let appURL = contents.first(where: { $0.pathExtension == "app" }) {
            DispatchQueue.main.async { self.installProgress = "Kopiere nach /Applications…" }
            let dest = URL(fileURLWithPath: "/Applications/\(appURL.lastPathComponent)")
            try? fm.removeItem(at: dest)
            do {
                try fm.copyItem(at: appURL, to: dest)
                DispatchQueue.main.async {
                    self.installProgress = "Fertig!"
                    NSWorkspace.shared.open(dest)
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                        self.isInstalling = nil
                        self.installProgress = ""
                    }
                }
            } catch {
                self.openInstaller(game.installerURL)
            }
        } else if let contents = try? fm.contentsOfDirectory(at: mountURL, includingPropertiesForKeys: nil),
                  let pkgURL = contents.first(where: { $0.pathExtension == "pkg" }) {
            self.openInstaller(pkgURL)
        } else {
            self.openInstaller(game.installerURL)
        }

        DispatchQueue.global().asyncAfter(deadline: .now() + 5) {
            let unmount = Process()
            unmount.executableURL = URL(fileURLWithPath: "/usr/bin/hdiutil")
            unmount.arguments = ["detach", mountPoint, "-quiet"]
            try? unmount.run()
        }
    }

    private func openInstaller(_ url: URL) {
        DispatchQueue.main.async {
            self.installProgress = "Öffne Installer…"
            NSWorkspace.shared.open(url)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.isInstalling = nil
                self.installProgress = ""
            }
        }
    }
}
