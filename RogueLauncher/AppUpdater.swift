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
        case idle, checking, upToDate, available, downloading, installing, error(String)
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
            DispatchQueue.main.async {
                guard let self else { return }
                if let err { self.state = .error(err.localizedDescription); return }
                guard let tmpURL else { self.state = .error("Download fehlgeschlagen"); return }
                self.install(zipURL: tmpURL)
            }
        }

        // Progress beobachten
        let observation = task.progress.observe(\.fractionCompleted) { [weak self] p, _ in
            DispatchQueue.main.async { self?.progress = p.fractionCompleted }
        }
        _ = observation
        task.resume()
    }

    private func install(zipURL: URL) {
        state = .installing
        let tmp = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("RogueUpdate_\(UUID().uuidString)")

        DispatchQueue.global(qos: .userInitiated).async {
            do {
                try FileManager.default.createDirectory(at: tmp, withIntermediateDirectories: true)
                // Entpacken
                let result = self.shell("unzip -q \"\(zipURL.path)\" -d \"\(tmp.path)\"")
                guard result == 0 else {
                    DispatchQueue.main.async { self.state = .error("Entpacken fehlgeschlagen (Code \(result))") }
                    return
                }

                // .app finden
                guard let appName = try FileManager.default.contentsOfDirectory(atPath: tmp.path)
                        .first(where: { $0.hasSuffix(".app") })
                else {
                    DispatchQueue.main.async { self.state = .error(".app nicht im ZIP gefunden") }
                    return
                }

                let newApp = tmp.appendingPathComponent(appName)

                // Alte App ersetzen
                let dest = URL(fileURLWithPath: self.appPath)
                if FileManager.default.fileExists(atPath: dest.path) {
                    try FileManager.default.removeItem(at: dest)
                }
                try FileManager.default.moveItem(at: newApp, to: dest)

                // Signieren
                self.shell("codesign --deep --force --sign - \"\(dest.path)\"")

                // Neustart
                DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                    let url = URL(fileURLWithPath: self.appPath)
                    NSWorkspace.shared.openApplication(at: url, configuration: .init()) { _, _ in }
                    NSApp.terminate(nil)
                }
            } catch {
                DispatchQueue.main.async { self.state = .error(error.localizedDescription) }
            }
        }
    }

    @discardableResult
    nonisolated private func shell(_ cmd: String) -> Int32 {
        let p = Process()
        p.launchPath = "/bin/zsh"
        p.arguments = ["-c", cmd]
        p.launch(); p.waitUntilExit()
        return p.terminationStatus
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
