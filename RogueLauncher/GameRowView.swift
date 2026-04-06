import SwiftUI

struct GameRowView: View {
    let game: Game
    let isSelected: Bool
    let moonlightOnline: Bool

    // Badge-Farbe: Lokal = immer grün, Moonlight = grün wenn online, grau wenn offline
    var badgeColor: Color {
        switch game.type {
        case .local:      return .green
        case .console:    return .green
        case .rom:        return .green
        case .moonlight:  return moonlightOnline ? .green : .secondary
        }
    }

    var badgeIcon: String {
        switch game.type {
        case .moonlight: return "moon.fill"
        case .local:     return "macwindow"
        case .console:   return "gamecontroller.fill"
        case .rom:       return "cpu"
        }
    }

    var body: some View {
        HStack(spacing: 10) {
            ZStack(alignment: .bottomTrailing) {
                if let img = game.coverImage {
                    Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                        .frame(width: 36, height: 48).clipShape(RoundedRectangle(cornerRadius: 7))
                } else if game.type == .local, let icon = game.localAppIcon {
                    Image(nsImage: icon).resizable().frame(width: 36, height: 36)
                        .clipShape(RoundedRectangle(cornerRadius: 7))
                } else {
                    RoundedRectangle(cornerRadius: 7).fill(Color.secondary.opacity(0.15))
                        .frame(width: 36, height: 48)
                        .overlay(Image(systemName: "gamecontroller").font(.system(size: 14)).foregroundColor(.secondary))
                }

                Image(systemName: badgeIcon)
                    .font(.system(size: 8)).foregroundColor(.white)
                    .padding(3).background(badgeColor).clipShape(Circle())
                    .offset(x: 4, y: 4)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(game.name).font(.system(size: 13, weight: .medium)).lineLimit(1)
                if !game.genre.isEmpty {
                    Text(game.genre).font(.system(size: 11)).foregroundColor(.secondary).lineLimit(1)
                }
            }
            Spacer()

        }
        .padding(.horizontal, 12).padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 8).fill(isSelected ? Color.rogueBlue.opacity(0.2) : Color.clear))
        .padding(.horizontal, 6)
        .contentShape(Rectangle())
    }
}
