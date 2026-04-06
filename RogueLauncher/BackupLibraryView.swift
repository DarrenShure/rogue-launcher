import SwiftUI

struct BackupLibraryView: View {
    @ObservedObject private var backupStore = BackupStore.shared
    @State private var retryTimer: Timer? = nil
    @ObservedObject private var settings = AppSettings.shared

    let columns = [GridItem(.adaptive(minimum: 160), spacing: 16)]

    var body: some View {
        GeometryReader { _ in
            ZStack {
                Color(NSColor.controlBackgroundColor)

                if backupStore.isScanning {
                    ProgressView("Scanne Backup-Verzeichnis…")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if backupStore.games.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "bag").font(.system(size: 52)).foregroundColor(.secondary.opacity(0.4))
                        Text("Keine Spiele gefunden").font(.title3).foregroundColor(.secondary)
                        Text("Stelle sicher dass dein Backup-Verzeichnis\nin den Einstellungen korrekt hinterlegt ist\nund die Struktur Verzeichnis/Spielname/Spiel.pkg|dmg hat.")
                            .font(.body).foregroundColor(.secondary.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 0) {
                            // Header
                            HStack(alignment: .bottom, spacing: 0) {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Dein Game Store")
                                        .font(.system(size: 28, weight: .bold))
                                    Text("Bereit zur Installation von deinem NAS")
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }
                                Spacer()
                                HStack(spacing: 24) {
                                    statBadge(value: "\(backupStore.games.count)", label: "Spiele")
                                    statBadge(value: "\(backupStore.games.filter { $0.installerType == .pkg }.count)", label: "PKG")
                                    statBadge(value: "\(backupStore.games.filter { $0.installerType == .dmg }.count)", label: "DMG")
                                    statBadge(value: "\(backupStore.games.filter { $0.coverImagePath != nil }.count)", label: "Mit Cover")
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 24)
                            .padding(.bottom, 20)

                            Divider().padding(.horizontal, 20).padding(.bottom, 8)

                            LazyVGrid(columns: columns, spacing: 16) {
                                ForEach(backupStore.games) { game in
                                    BackupGameCard(game: game)
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 20)
                        }
                    }
                }
            }
        }
        .onAppear {
            backupStore.scan(path: settings.backupPath, nasURL: settings.nasURL)
            // Periodischer Retry alle 30s falls NAS nicht erreichbar
            retryTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { _ in
                if backupStore.games.isEmpty && !settings.backupPath.isEmpty {
                    backupStore.scan(path: settings.backupPath, nasURL: settings.nasURL)
                }
            }
        }
        .onDisappear { retryTimer?.invalidate(); retryTimer = nil }
        .onReceive(NotificationCenter.default.publisher(for: NSWorkspace.didMountNotification)) { _ in
            guard !settings.backupPath.isEmpty else { return }
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                backupStore.scan(path: settings.backupPath, nasURL: settings.nasURL)
            }
        }
    }

    private func statBadge(value: String, label: String) -> some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(minWidth: 52)
    }
}

struct BackupGameCard: View {
    let game: BackupGame
    @ObservedObject private var backupStore = BackupStore.shared
    @State private var showingSearch = false

    var isInstalling: Bool { backupStore.isInstalling == game.id }
    var anyInstalling: Bool { backupStore.isInstalling != nil }

    var body: some View {
        VStack(spacing: 10) {
            ZStack(alignment: .topLeading) {
                // Cover
                Group {
                    if let img = game.coverImage {
                        Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.secondary.opacity(0.15))
                            .overlay(Image(systemName: "opticaldisc").font(.system(size: 36)).foregroundColor(.secondary.opacity(0.4)))
                    }
                }
                .frame(width: 160, height: 214)
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)

                // Installing Overlay
                if isInstalling {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.black.opacity(0.6))
                        .frame(width: 160, height: 214)
                    VStack(spacing: 8) {
                        ProgressView().tint(.white)
                        Text(backupStore.installProgress)
                            .font(.system(size: 11)).foregroundColor(.white)
                            .multilineTextAlignment(.center).padding(.horizontal, 8)
                    }
                    .frame(width: 160, height: 214)
                }

                // Stift oben links → IGDB Suche
                Button(action: { showingSearch = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundColor(.white).padding(6)
                        .background(Color.black.opacity(0.5)).clipShape(Circle())
                }
                .buttonStyle(.plain).padding(6)

                // Format Badge oben rechts
                VStack {
                    HStack {
                        Spacer()
                        Text(game.installerType == .dmg ? "DMG" : "PKG")
                            .font(.system(size: 9, weight: .bold)).foregroundColor(.white)
                            .padding(.horizontal, 6).padding(.vertical, 3)
                            .background(Color.rogueBlue.opacity(0.85)).clipShape(Capsule())
                            .padding(6)
                    }
                    Spacer()
                }
                .frame(width: 160, height: 214)
            }

            Text(game.displayName)
                .font(.system(size: 12, weight: .medium))
                .lineLimit(2).multilineTextAlignment(.center)
                .frame(width: 160, height: 36, alignment: .top)

            // Ladebalken beim Kopieren (nur für dieses Spiel)
            if backupStore.isInstalling == game.id && backupStore.isCopying {
                VStack(spacing: 4) {
                    ProgressView(value: backupStore.copyProgress)
                        .progressViewStyle(.linear)
                        .tint(.accentColor)
                        .frame(width: 140)
                    Text("Kopiere… \(Int(backupStore.copyProgress * 100))%")
                        .font(.system(size: 10))
                        .foregroundColor(.secondary)
                }
            } else {
                Button(action: { backupStore.install(game) }) {
                    HStack(spacing: 5) {
                        Image(systemName: "arrow.down.circle")
                        Text("Installieren")
                    }
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 140, height: 28)
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.rogueBlue)
                .disabled(anyInstalling)
            }
        }
        .padding(.bottom, 4)
        .sheet(isPresented: $showingSearch) {
            IGDBSearchView(originalName: game.displayName) { newName, coverPath, _ in
                backupStore.rename(game: game, to: newName, coverPath: coverPath)
            }
        }
    }
}
