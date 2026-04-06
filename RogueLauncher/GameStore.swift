import Foundation
import Combine

class GameStore: ObservableObject {
    @Published var games: [Game] = []

    private let saveURL: URL = {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = support.appendingPathComponent("RogueLauncher")
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("games.json")
    }()

    init() {
        load()
        NotificationCenter.default.addObserver(forName: .init("UpdateGame"), object: nil, queue: .main) { [weak self] note in
            if let game = note.object as? Game { self?.update(game) }
        }
    }

    func save() {
        try? JSONEncoder().encode(games).write(to: saveURL)
    }

    func load() {
        guard let data = try? Data(contentsOf: saveURL),
              let decoded = try? JSONDecoder().decode([Game].self, from: data)
        else { return }
        games = decoded
    }

    func add(_ game: Game) {
        games.append(game)
        save()
    }

    func update(_ game: Game) {
        if let i = games.firstIndex(where: { $0.id == game.id }) {
            games[i] = game
            save()
        }
    }

    func trackPlay(_ game: Game) {
        if var g = games.first(where: { $0.id == game.id }) {
            g.lastPlayedAt = Date()
            update(g)
        }
    }

    func delete(_ game: Game) {
        games.removeAll { $0.id == game.id }
        save()
    }
}
