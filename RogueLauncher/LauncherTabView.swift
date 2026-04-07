import SwiftUI

struct HelperLauncher: Identifiable {
    let id: String
    let name: String
    let cmd: String
    let installed: Bool
}

struct MacLauncher: Identifiable {
    let id: String
    let name: String
    let bundleID: String
    let appPaths: [String]

    var resolvedPath: String? {
        // Bundle ID suche
        if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
            return url.path
        }
        // Direkte Pfade
        return appPaths.first { FileManager.default.fileExists(atPath: $0) }
    }

    var isInstalled: Bool { resolvedPath != nil }
}

struct LauncherTabView: View {
    @State private var launchers: [HelperLauncher] = []
    @State private var isLoading = false

    private let macLaunchers: [MacLauncher] = [
        MacLauncher(id: "mac-games",   name: "Spiele",           bundleID: "com.apple.games",                appPaths: ["/System/Applications/Games.app", "/Applications/Games.app"]),
        MacLauncher(id: "mac-steam",   name: "Steam Mac",        bundleID: "com.valvesoftware.steam",         appPaths: ["/Applications/Steam.app"]),
        MacLauncher(id: "mac-gog",     name: "GOG Galaxy Mac",   bundleID: "com.gogcom.GalaxyClient",         appPaths: ["/Applications/GOG Galaxy.app"]),
        MacLauncher(id: "mac-epic",    name: "Epic Games Mac",   bundleID: "com.epicgames.launcher",          appPaths: ["/Applications/Epic Games Launcher.app"]),
        MacLauncher(id: "mac-retroarch",name: "RetroArch",       bundleID: "com.libretro.RetroArch",         appPaths: ["/Applications/RetroArch.app"]),
        MacLauncher(id: "mac-itch",    name: "itch.io Mac",      bundleID: "io.itch.itch",                   appPaths: ["/Applications/itch.app"]),
    ]

    var installedMacLaunchers: [MacLauncher] {
        macLaunchers.filter { $0.isInstalled }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 32) {
                Text("Launcher")
                    .font(.system(size: 28, weight: .bold))
                    .padding(.horizontal, 32)
                    .padding(.top, 28)

                // Host Launcher
                if isLoading {
                    HStack { Spacer(); ProgressView(); Spacer() }
                        .padding(.top, 20)
                } else if !launchers.filter({ $0.installed }).isEmpty {
                    sectionHeader("Auf dem Gaming PC")
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(launchers.filter { $0.installed }) { launcher in
                            LauncherCard(name: launcher.name, onOpen: { openHost(launcher) })
                        }
                    }
                    .padding(.horizontal, 32)
                }

                // Mac Launcher
                if !installedMacLaunchers.isEmpty {
                    sectionHeader("Auf diesem Mac")
                    LazyVGrid(
                        columns: [GridItem(.adaptive(minimum: 160, maximum: 200), spacing: 16)],
                        spacing: 16
                    ) {
                        ForEach(installedMacLaunchers) { launcher in
                            LauncherCard(name: launcher.name, onOpen: { openMac(launcher) })
                        }
                    }
                    .padding(.horizontal, 32)
                }

                Spacer(minLength: 32)
            }
        }
        .onAppear { load() }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .semibold))
            .foregroundColor(.secondary)
            .padding(.horizontal, 32)
            .padding(.bottom, -16)
    }

    private func load() {
        guard let req = HelperAPI.shared.request("/launchers") else { return }
        isLoading = true
        HelperAPI.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isLoading = false
                guard let data = data,
                      let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                else { return }
                launchers = arr.compactMap { dict in
                    guard let id = dict["id"] as? String,
                          let name = dict["name"] as? String else { return nil }
                    let cmd = dict["cmd"] as? String ?? ""
                    let installed = dict["installed"] as? Bool ?? !cmd.isEmpty
                    return HelperLauncher(id: id, name: name, cmd: cmd, installed: installed)
                }
            }
        }.resume()
    }

    private func openHost(_ launcher: HelperLauncher) {
        let appName = AppSettings.shared.gameLaunchers
            .first { $0.id == launcher.id }?.sunshineAppName ?? launcher.name
        let plist = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
        let ip = (NSDictionary(contentsOfFile: plist) as? [String: Any])?["hosts.1.localaddress"] as? String
            ?? AppSettings.shared.pcIPAddress
        let bins = [
            "/Applications/Moonlight.app/Contents/MacOS/Moonlight",
            NSHomeDirectory() + "/Applications/Moonlight.app/Contents/MacOS/Moonlight"
        ]
        guard let path = bins.first(where: { FileManager.default.fileExists(atPath: $0) }) else { return }
        let proc = Process()
        proc.executableURL = URL(fileURLWithPath: path)
        proc.arguments = ["stream", ip, appName, "--display-mode", "windowed"]
        try? proc.run()
    }

    private func openMac(_ launcher: MacLauncher) {
        guard let path = launcher.resolvedPath else { return }
        NSWorkspace.shared.openApplication(at: URL(fileURLWithPath: path),
                                           configuration: NSWorkspace.OpenConfiguration())
    }
}

private struct LauncherCard: View {
    let name: String
    let onOpen: () -> Void
    @State private var hovered = false

    var body: some View {
        Button(action: onOpen) {
            VStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.rogueRed.opacity(0.15))
                        .frame(width: 64, height: 64)
                    Image(systemName: "gamecontroller.fill")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundColor(.rogueRed)
                }
                Text(name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .frame(height: 32, alignment: .top)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 130)
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(NSColor.controlBackgroundColor))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .strokeBorder(
                                hovered ? Color.rogueRed.opacity(0.6) : Color.secondary.opacity(0.12),
                                lineWidth: hovered ? 1.5 : 1
                            )
                    )
            )
            .scaleEffect(hovered ? 1.03 : 1.0)
            .animation(.easeOut(duration: 0.15), value: hovered)
        }
        .buttonStyle(.plain)
        .onHover { hovered = $0 }
        .help("Öffnet \(name)")
    }
}
