import SwiftUI

@main
struct RogueLauncherApp: App {
    init() {
        // Disk-Cache für AsyncImage — 500 MB Disk, 100 MB RAM
        let cachesDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
            .appendingPathComponent("RogueLauncher/ImageCache")
        try? FileManager.default.createDirectory(at: cachesDir, withIntermediateDirectories: true)
        URLCache.shared = URLCache(
            memoryCapacity: 100 * 1024 * 1024,
            diskCapacity:   500 * 1024 * 1024,
            directory:      cachesDir
        )

        // Prefetch GameDetail-Cache für installierte Spiele (im Hintergrund)
        DispatchQueue.global(qos: .background).asyncAfter(deadline: .now() + 3) {
            let store = GameStore()
            let sem = DispatchSemaphore(value: 2)
            for game in store.games {
                guard GameDetailCache.shared.load(for: game.name) == nil else { continue }
                sem.wait()
                GameMetadataService.fetch(for: game.name) { meta in
                    guard let meta = meta else { sem.signal(); return }
                    let detail = CachedGameDetail(
                        description:    meta.description,
                        genre:          meta.genre,
                        releaseYear:    meta.releaseYear,
                        ageRating:      meta.ageRating,
                        rating:         meta.rating,
                        screenshotURLs: meta.screenshotURLs,
                        youtubeVideoIDs: [],
                        youtubeTitles:   [],
                        fetchedAt:      Date()
                    )
                    if !meta.screenshotURLs.isEmpty {
                        GameDetailCache.shared.save(detail, for: game.name)
                    }
                    sem.signal()
                }
            }
        }
        // Menu Bar Icon permanent initialisieren
        _ = MenuBarManager.shared
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        Window("Spiele Import", id: "sunshine-import") {
            SunshineImportWindowView()
        }
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
    }
}
