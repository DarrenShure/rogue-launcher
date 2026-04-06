import Foundation
import AppKit

@MainActor
final class AppUpdater: ObservableObject {

    static let shared = AppUpdater()

    private let repoAPI = "https://api.github.com/repos/DarrenShure/rogue-launcher/releases/latest"
    private let appPath = "/Applications/Rogue Launcher.app"

    @Published var state: UpdateState = .idle
    @Published var latestRelease: GitHubRelease?
    @Published var progress: Double = 0

    enum UpdateState {
        case idle, checking, upToDate, available, downloading, installing(String), error(String)
    }

    var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }

    func checkForUpdates() {
        state = .checking
        latestRelease = nil

        guard let url = URL(string: repoAPI) else { state = .error("Ungültige URL"); return }

        var req = URLRequest(url: url)
        req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")

        URLSession.shared.dataTask(with: req) { [weak self] data, _, err in
            DispatchQueue.main.async {
                guard let self else { return }
                if let err { self.state = .error(err.localizedDescription); return }
                guard let data,
                      let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
                else { self.state = .error("Antwort konnte nicht gelesen werden"); return }

                self.latestRelease = release
                let latest = release.tagName.hasPrefix("v") ? String(release.tagName.dropFirst()) : release.tagName
                self.state = latest.isNewerThan(self.currentVersion) ? .available : .upToDate
            }
        }.resume()
    }

    func downloadAndInstall() {
        guard let release = latestRelease,
              let asset = release.assets.first(where: { $0.name.hasSuffix(".zip") }),
              let url = URL(string: asset.browserDownloadURL)
        else { state = .error("Kein ZIP-Asset gefunden"); return }

        state = .downloading
        progress = 0

        let task = URLSession.shared.downloadTask(with: url) { [weak self] tmpURL, _, err in
            // WICHTIG: Temp-Datei sofort sichern, bevor der Handler zurückkehrt,
            // da URLSession die Datei danach löscht.
            guard let self else { return }

            if let err {
                DispatchQueue.main.async { self.state = .error(err.localizedDescription) }
                return
            }
            guard let tmpURL else {
                DispatchQueue.main.async { self.state = .error("Download fehlgeschlagen") }
                return
            }

            let savedZip = URL(fileURLWithPath: NSTemporaryDirectory())
                .appendingPathComponent("RogueUpdate_\(UUID().uuidString).zip")
            do {
                try FileManager.default.copyItem(at: tmpURL, to: savedZip)
            } catch {
                DispatchQueue.main.async { self.state = .error("ZIP konnte nicht gesichert werden: \(error.localizedDescription)") }
                return
            }

            DispatchQueue.main.async {
                self.install(zipURL: savedZip)
            }
        }

        let observation = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            DispatchQueue.main.async { self?.progress = p.fractionCompleted }
        }
        _ = observation
        task.resume()
    }

    private func install(zipURL: URL) {
        state = .installing("Starte Installation ...")
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RogueUpdate_\(UUID().uuidString)")
        let destPath = appPath
        let zipSize = (try? FileManager.default.attributesOfItem(atPath: zipURL.path)[.size] as? Int) ?? 0

        Task.detached(priority: .userInitiated) {
            do {
                try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)

                // Entpacken
                await MainActor.run { self.state = .installing("Entpacke ZIP (\(zipSize / 1024) KB) ...") }
                let unzipResult = shellRun("/usr/bin/unzip", args: ["-o", "-q", zipURL.path, "-d", tmp.path])
                try? FileManager.default.removeItem(at: zipURL)

                guard unzipResult == 0 else {
                    await MainActor.run { self.state = .error("Entpacken fehlgeschlagen (Code \(unzipResult), ZIP: \(zipSize) Bytes)") }
                    return
                }

                // .app finden
                await MainActor.run { self.state = .installing("Suche .app im Archiv ...") }
                guard let appName = try FileManager.default.contentsOfDirectory(atPath: tmp.path)
                        .first(where: { $0.hasSuffix(".app") })
                else {
                    let contents = (try? FileManager.default.contentsOfDirectory(atPath: tmp.path)) ?? []
                    await MainActor.run { self.state = .error(".app nicht gefunden. Inhalt: \(contents.joined(separator: ", "))") }
                    return
                }

                let newApp = tmp.appendingPathComponent(appName)
                let dest = URL(fileURLWithPath: destPath)

                // Alte App ersetzen
                await MainActor.run { self.state = .installing("Ersetze alte App ...") }
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: newApp, to: dest)

                // Signieren
                await MainActor.run { self.state = .installing("Signiere App ...") }
                let signResult = shellRun("/usr/bin/codesign", args: ["--deep", "--force", "--sign", "-", dest.path])

                await MainActor.run { self.state = .installing("Starte neu ...") }

                // Neustart: Shell-Prozess spawnen, der nach Beenden die neue App öffnet
                let relaunchProcess = Process()
                relaunchProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
                relaunchProcess.arguments = ["-c", "sleep 2 && open \"\(destPath)\""]
                try? relaunchProcess.run()

                await MainActor.run {
                    NSApp.terminate(nil)
                }
            } catch {
                await MainActor.run { self.state = .error("Fehler: \(error.localizedDescription)") }
            }
        }
    }

}

@discardableResult
private func shellRun(_ executable: String, args: [String]) -> Int32 {
    let p = Process()
    p.executableURL = URL(fileURLWithPath: executable)
    p.arguments = args
    do {
        try p.run()
        p.waitUntilExit()
        return p.terminationStatus
    } catch {
        return -1
    }
}

// MARK: - Models

struct GitHubRelease: Decodable {
    let tagName: String
    let name: String
    let body: String?
    let publishedAt: String
    let assets: [GitHubAsset]

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case name, body
        case publishedAt = "published_at"
        case assets
    }
}

struct GitHubAsset: Decodable {
    let name: String
    let browserDownloadURL: String
    let size: Int

    enum CodingKeys: String, CodingKey {
        case name
        case browserDownloadURL = "browser_download_url"
        case size
    }
}

// MARK: - Version Comparison

private extension String {
    func isNewerThan(_ other: String) -> Bool {
        let a = components(separatedBy: ".").compactMap(Int.init)
        let b = other.components(separatedBy: ".").compactMap(Int.init)
        let len = max(a.count, b.count)
        for i in 0..<len {
            let av = i < a.count ? a[i] : 0
            let bv = i < b.count ? b[i] : 0
            if av != bv { return av > bv }
        }
        return false
    }
}
