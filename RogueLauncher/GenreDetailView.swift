import SwiftUI

struct GenreDetailView: View {
    let genre: String
    @ObservedObject var store: GameStore
    let onSelect: (Game) -> Void
    var onBack: (() -> Void)? = nil

    var games: [Game] {
        let hidden = ["desktop", "vortex", "audials", "ruhemodus"]
        return store.games
            .filter { !hidden.contains($0.name.lowercased()) }
            .filter { game in
                let genres = game.genre.split(separator: ",").map { normalizeGenre(String($0)) }
                return genres.contains { $0.localizedCaseInsensitiveCompare(genre) == .orderedSame }
            }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var colors: [Color] { colorsForGenre(genre) }

    let columns = [GridItem(.adaptive(minimum: 130), spacing: 16)]

    var body: some View {
        ZStack(alignment: .topLeading) {
            // Hintergrund mit Genre-Farbe
            LinearGradient(
                colors: [colors[0].opacity(0.3), Color(NSColor.controlBackgroundColor)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Zurück Button
                    if let onBack = onBack {
                        Button(action: onBack) {
                            HStack(spacing: 6) {
                                Image(systemName: "chevron.left")
                                    .font(.system(size: 12, weight: .semibold))
                                Text("Zurück")
                                    .font(.system(size: 12, weight: .medium))
                            }
                            .foregroundColor(.white.opacity(0.8))
                            .padding(.horizontal, 12).padding(.vertical, 6)
                            .background(Color.white.opacity(0.15))
                            .clipShape(Capsule())
                            .overlay(Capsule().stroke(Color.white.opacity(0.3), lineWidth: 1))
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 24)
                        .padding(.top, 16)
                    }

                    // Header
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing))
                                .frame(width: 56, height: 56)
                            Image(systemName: iconForGenre(genre))
                                .font(.system(size: 24))
                                .foregroundColor(.white)
                        }
                        VStack(alignment: .leading, spacing: 4) {
                            Text(genre)
                                .font(.system(size: 28, weight: .bold))
                            Text("\(games.count) Spiel\(games.count == 1 ? "" : "e")")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 24)

                    Divider().padding(.horizontal, 24)

                    // Beschreibung
                    if let desc = genreDescriptions[genre] {
                        Text(desc)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineSpacing(4)
                            .padding(.horizontal, 24)
                    }

                    // Spiele-Grid
                    LazyVGrid(columns: columns, spacing: 16) {
                        ForEach(games) { game in
                            GenreGameCard(game: game, accentColor: colors[0]) {
                                onSelect(game)
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
    }
}

struct GenreGameCard: View {
    let game: Game
    let accentColor: Color
    let action: () -> Void
    @ObservedObject private var monitor = PCStatusMonitor.shared

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                ZStack(alignment: .topTrailing) {
                    Group {
                        if let img = game.coverImage {
                            Image(nsImage: img)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                        } else if game.type == .local, let icon = game.localAppIcon {
                            Color.secondary.opacity(0.1)
                                .overlay(Image(nsImage: icon).resizable().frame(width: 60, height: 60))
                        } else {
                            RoundedRectangle(cornerRadius: 10)
                                .fill(accentColor.opacity(0.2))
                                .overlay(Image(systemName: "gamecontroller")
                                    .font(.system(size: 28))
                                    .foregroundColor(accentColor.opacity(0.6)))
                        }
                    }
                    .frame(width: 130, height: 174)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .shadow(color: .black.opacity(0.3), radius: 6, x: 0, y: 3)

                    // Online Badge
                    if game.type == .moonlight {
                        Circle()
                            .fill(monitor.status == .online ? Color.green : Color.secondary)
                            .frame(width: 8, height: 8)
                            .padding(6)
                    }
                }

                Text(game.name)
                    .font(.system(size: 12, weight: .medium))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(width: 130, height: 32, alignment: .top)
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }
}
