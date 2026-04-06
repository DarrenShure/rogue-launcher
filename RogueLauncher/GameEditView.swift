import SwiftUI

struct GameEditView: View {
    let store: GameStore
    let game: Game?
    var prefill: Game? = nil   // Vorausgefülltes Spiel für Import
    var onSave: (() -> Void)? = nil

    @Environment(\.dismiss) private var dismiss

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var genre: String = ""
    @State private var releaseYear: String = ""
    @State private var ageRating: String = ""
    @State private var appName: String = ""
    @State private var steamAppID: String = ""
    @State private var steamSearching = false
    @State private var steamSearchResults: [(name: String, appID: String)] = []
    @State private var showingSteamResults = false
    @State private var coverImagePath: String? = nil
    @State private var coverPreview: NSImage? = nil
    @State private var backgroundImagePath: String? = nil
    @State private var gameType: GameType = .moonlight
    @State private var showingFilePicker = false
    @State private var showingIGDBSearch = false
    @State private var showingBGSearch = false
    @State private var isFetchingMeta = false
    @State private var metaSource: String? = nil
    @State private var metaError: String? = nil
    @State private var editTab = 0  // 0 = Spiel, 1 = Poster
    @State private var igdbID: Int? = nil

    var isEditing: Bool { game != nil }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text(isEditing ? "Spiel bearbeiten" : "Spiel hinzufügen")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                if isEditing {
                    Picker("", selection: $editTab) {
                        Text("Spiel").tag(0)
                        Text("Poster").tag(1)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 160)
                }
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)

            Divider()

            if editTab == 1 {
                // Poster-Tab
                PosterEditTab(
                    coverImagePath: $coverImagePath,
                    coverPreview: $coverPreview,
                    backgroundImagePath: $backgroundImagePath,
                    gameName: name,
                    showingIGDBSearch: $showingIGDBSearch,
                    showingBGSearch: $showingBGSearch
                )
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        Button(action: { showingFilePicker = true }) {
                            Group {
                                if let img = coverPreview {
                                    Image(nsImage: img)
                                        .resizable().aspectRatio(contentMode: .fill)
                                } else {
                                    Rectangle()
                                        .fill(Color.secondary.opacity(0.1))
                                        .overlay(VStack(spacing: 8) {
                                            Image(systemName: "photo.badge.plus")
                                                .font(.system(size: 28)).foregroundColor(.secondary)
                                            Text("Cover auswählen")
                                                .font(.system(size: 12)).foregroundColor(.secondary)
                                        })
                                }
                            }
                            .frame(width: 160, height: 214)
                            .clipShape(RoundedRectangle(cornerRadius: 14))
                            .overlay(RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.secondary.opacity(0.2), lineWidth: 1))
                        }
                        .buttonStyle(.plain)

                        Button(action: { showingIGDBSearch = true }) {
                            HStack(spacing: 4) {
                                Image(systemName: "magnifyingglass")
                                Text("Neu zuordnen")
                            }
                            .font(.system(size: 12))
                        }
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)

                        if coverImagePath != nil {
                            Button("Cover entfernen") { coverImagePath = nil; coverPreview = nil }
                                .font(.system(size: 12)).foregroundColor(.red).buttonStyle(.plain)
                        }
                    }

                    // Felder
                    VStack(alignment: .leading, spacing: 14) {
                        LabeledField(label: "Name") {
                            TextField("z.B. Cyberpunk 2077", text: $name)
                                .textFieldStyle(.roundedBorder)
                        }

                        // Auto-Fetch Button
                        HStack {
                            Button(action: fetchMetadata) {
                                HStack(spacing: 6) {
                                    if isFetchingMeta {
                                        ProgressView().frame(width: 20, height: 20)
                                    } else {
                                        Image(systemName: "sparkles")
                                    }
                                    Text(isFetchingMeta ? "Suche…" : "Infos automatisch laden")
                                        .font(.system(size: 12))
                                }
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || isFetchingMeta)

                            if let src = metaSource {
                                Text("via \(src)").font(.system(size: 11)).foregroundColor(.secondary)
                            }
                            if let err = metaError {
                                Text(err).font(.system(size: 11)).foregroundColor(.red)
                            }
                        }

                        LabeledField(label: "Genre") {
                            TextField("z.B. RPG, Action", text: $genre)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField(label: "Erscheinungsjahr") {
                            TextField("z.B. 2020", text: $releaseYear)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField(label: "Altersfreigabe") {
                            TextField("z.B. USK 18, PEGI 16", text: $ageRating)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField(label: "App / Prozessname") {
                            TextField("z.B. Cyberpunk 2077", text: $appName)
                                .textFieldStyle(.roundedBorder)
                        }
                        LabeledField(label: "Steam AppID") {
                            VStack(alignment: .leading, spacing: 6) {
                                HStack(spacing: 6) {
                                    TextField("z.B. 1091500 (optional)", text: $steamAppID)
                                        .textFieldStyle(.roundedBorder)
                                        .frame(width: 130)
                                    Button(action: searchSteamAppID) {
                                        if steamSearching {
                                            ProgressView().frame(width: 16, height: 16)
                                        } else {
                                            Label("Suchen", systemImage: "magnifyingglass")
                                                .font(.system(size: 11))
                                        }
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                    .disabled(name.isEmpty || steamSearching)
                                    if !steamAppID.isEmpty {
                                        Text("✓ ID gesetzt")
                                            .font(.system(size: 10))
                                            .foregroundColor(.green)
                                    } else {
                                        Text("für News auf dem Poster")
                                            .font(.system(size: 10))
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                }
                                // Suchergebnisse
                                if showingSteamResults && !steamSearchResults.isEmpty {
                                    VStack(alignment: .leading, spacing: 2) {
                                        ForEach(steamSearchResults.prefix(5), id: \.appID) { result in
                                            Button(action: {
                                                steamAppID = result.appID
                                                showingSteamResults = false
                                            }) {
                                                HStack {
                                                    Text(result.name)
                                                        .font(.system(size: 11))
                                                        .foregroundColor(.primary)
                                                        .lineLimit(1)
                                                    Spacer()
                                                    Text("ID: \(result.appID)")
                                                        .font(.system(size: 10))
                                                        .foregroundColor(.secondary)
                                                }
                                                .padding(.horizontal, 8)
                                                .padding(.vertical, 4)
                                                .background(Color.secondary.opacity(0.08))
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                } else if showingSteamResults && steamSearchResults.isEmpty {
                                    Text("Kein Spiel auf Steam gefunden.")
                                        .font(.system(size: 10)).foregroundColor(.secondary)
                                }
                            }
                        }
                        LabeledField(label: "Beschreibung") {
                            TextEditor(text: $description)
                                .font(.system(size: 13))
                                .frame(height: 100)
                                .overlay(RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color.secondary.opacity(0.25), lineWidth: 1))
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(24)
            } // end Spiel-Tab

            Divider()

            HStack {
                if isEditing {
                    Button("Löschen", role: .destructive) {
                        if let g = game { store.delete(g) }
                        dismiss()
                    }
                }
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
                Button(isEditing ? "Speichern" : "Hinzufügen") { saveGame() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 640, height: 560)
        .onAppear { populate() }
        .sheet(isPresented: $showingBGSearch) {
            IGDBBackgroundPickerView(gameName: name.isEmpty ? (game?.name ?? "") : name, igdbID: igdbID) { path in
                backgroundImagePath = path
            }
        }
        .sheet(isPresented: $showingIGDBSearch) {
            IGDBSearchView(originalName: name.isEmpty ? (game?.name ?? "") : name) { newName, coverPath, newIGDBID in
                // Cache löschen
                GameDetailCache.shared.clear(for: game?.name ?? name)
                GameDetailCache.shared.clear(for: name)
                GameDetailCache.shared.clear(for: newName)
                // Name + IGDB-ID übernehmen
                name = newName
                igdbID = newIGDBID
                // Cover übernehmen
                if let path = coverPath {
                    coverImagePath = path
                    coverPreview = NSImage(contentsOfFile: path)
                }
                // Metadaten per IGDB-ID laden — exakt das richtige Spiel
                isFetchingMeta = true
                metaSource = nil
                metaError = nil
                GameMetadataService.fetchFromIGDBbyID(id: newIGDBID) { meta in
                    DispatchQueue.main.async {
                        isFetchingMeta = false
                        guard let meta = meta else { metaError = "Nicht gefunden"; return }
                        description = meta.description
                        genre = meta.genre
                        releaseYear = meta.releaseYear
                        if !meta.ageRating.isEmpty { ageRating = meta.ageRating }
                        metaSource = meta.source
                        if let bgURL = meta.backgroundURL {
                            GameMetadataService.downloadCover(from: bgURL, for: "bg_\(newName)") { path in
                                if let path = path { backgroundImagePath = path }
                            }
                        }
                    }
                }
            }
        }
        .fileImporter(isPresented: $showingFilePicker,
                      allowedContentTypes: [.png, .jpeg, .heic, .tiff],
                      allowsMultipleSelection: false) { result in
            if let url = try? result.get().first {
                let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let dir = support.appendingPathComponent("RogueLauncher/Covers")
                try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let dest = dir.appendingPathComponent(url.lastPathComponent)
                try? FileManager.default.copyItem(at: url, to: dest)
                coverImagePath = dest.path
                coverPreview = NSImage(contentsOf: dest)
            }
        }
    }

    private func searchSteamAppID() {
        guard !name.isEmpty else { return }
        steamSearching = true
        showingSteamResults = false
        steamSearchResults = []

        let query = name.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? name
        let urlStr = "https://store.steampowered.com/api/storesearch/?term=\(query)&l=german&cc=DE"
        guard let url = URL(string: urlStr) else { steamSearching = false; return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            DispatchQueue.main.async {
                steamSearching = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let items = json["items"] as? [[String: Any]] else {
                    showingSteamResults = true
                    return
                }
                steamSearchResults = items.compactMap { item in
                    guard let appID = item["id"] as? Int,
                          let name = item["name"] as? String else { return nil }
                    return (name: name, appID: String(appID))
                }
                showingSteamResults = true
            }
        }.resume()
    }

    private func fetchMetadata() {
        isFetchingMeta = true
        metaSource = nil
        metaError = nil
        // Cache löschen damit frische Daten von IGDB kommen
        GameDetailCache.shared.clear(for: name)
        GameDetailCache.shared.clear(for: game?.name ?? name)
        GameMetadataService.fetch(for: name) { meta in
            isFetchingMeta = false
            guard let meta = meta else {
                metaError = "Nicht gefunden"
                return
            }
            if !meta.description.isEmpty { description = meta.description }
            if !meta.genre.isEmpty { genre = meta.genre }
            if !meta.releaseYear.isEmpty { releaseYear = meta.releaseYear }
            if !meta.ageRating.isEmpty { ageRating = meta.ageRating }
            metaSource = meta.source

            // Cover automatisch laden wenn keins gesetzt
            if coverImagePath == nil, let coverURL = meta.coverURL {
                GameMetadataService.downloadCover(from: coverURL, for: name) { path in
                    if let path = path {
                        coverImagePath = path
                        coverPreview = NSImage(contentsOfFile: path)
                    }
                }
            }
            // Hintergrundbild laden
            if let bgURL = meta.backgroundURL {
                GameMetadataService.downloadCover(from: bgURL, for: "bg_\(name)") { path in
                    if let path = path { backgroundImagePath = path }
                }
            }
        }
    }

    private func populate() {
        // prefill hat Vorrang wenn kein bestehendes game
        let g = game ?? prefill
        guard let g else { return }
        name = g.name; description = g.description; genre = g.genre
        releaseYear = g.releaseYear; appName = g.appName; steamAppID = g.steamAppID
        ageRating = g.ageRating
        coverImagePath = g.coverImagePath; backgroundImagePath = g.backgroundImagePath; gameType = g.type
        igdbID = g.igdbID
        if let path = g.coverImagePath { coverPreview = NSImage(contentsOfFile: path) }
    }

    private func saveGame() {
        if var existing = game {
            let oldName = existing.name
            existing.name = name; existing.description = description; existing.genre = genre
            existing.releaseYear = releaseYear; existing.ageRating = ageRating; existing.appName = appName
            existing.steamAppID = steamAppID
            existing.coverImagePath = coverImagePath; existing.backgroundImagePath = backgroundImagePath; existing.type = gameType
            existing.igdbID = igdbID
            // Cache löschen damit IGDB-Daten neu abgerufen werden
            GameDetailCache.shared.clear(for: oldName)
            if name != oldName { GameDetailCache.shared.clear(for: name) }
            store.update(existing)
        } else {
            var newGame = Game(name: name, description: description, genre: genre,
                               releaseYear: releaseYear, appName: appName.isEmpty ? name : appName,
                               coverImagePath: coverImagePath, backgroundImagePath: backgroundImagePath, type: gameType, ageRating: ageRating)
            newGame.steamAppID = steamAppID
            store.add(newGame)
        }
        onSave?()
        dismiss()
    }
}

struct LabeledField<Content: View>: View {
    let label: String
    @ViewBuilder let content: Content
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(label).font(.system(size: 12, weight: .medium)).foregroundColor(.secondary)
            content
        }
    }
}

// MARK: - Poster Edit Tab

struct PosterEditTab: View {
    @Binding var coverImagePath: String?
    @Binding var coverPreview: NSImage?
    @Binding var backgroundImagePath: String?
    let gameName: String
    @Binding var showingIGDBSearch: Bool
    @Binding var showingBGSearch: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Cover
                VStack(alignment: .leading, spacing: 10) {
                    Text("COVER").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    HStack(spacing: 16) {
                        // Preview
                        Group {
                            if let img = coverPreview {
                                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.1))
                                    .overlay(Image(systemName: "photo").font(.system(size: 28)).foregroundColor(.secondary))
                            }
                        }
                        .frame(width: 100, height: 134)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 10) {
                            Button("Bild auswählen…") { selectCover() }.buttonStyle(.bordered)
                            Button("Online suchen…") { showingIGDBSearch = true }.buttonStyle(.bordered)
                            if coverImagePath != nil {
                                Button("Entfernen") { coverImagePath = nil; coverPreview = nil }
                                    .buttonStyle(.plain).foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))

                // Hintergrundbild
                VStack(alignment: .leading, spacing: 10) {
                    Text("HINTERGRUNDBILD (POSTER)").font(.system(size: 11, weight: .semibold)).foregroundColor(.secondary)
                    HStack(spacing: 16) {
                        Group {
                            if let path = backgroundImagePath, let img = NSImage(contentsOfFile: path) {
                                Image(nsImage: img).resizable().aspectRatio(contentMode: .fill)
                            } else {
                                RoundedRectangle(cornerRadius: 10)
                                    .fill(Color.secondary.opacity(0.1))
                                    .overlay(Image(systemName: "photo.on.rectangle").font(.system(size: 28)).foregroundColor(.secondary))
                            }
                        }
                        .frame(width: 178, height: 100)
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.2), lineWidth: 1))

                        VStack(alignment: .leading, spacing: 10) {
                            Button("Bild auswählen…") { selectBackground() }.buttonStyle(.bordered)
                            Button("Online suchen…") { showingBGSearch = true }.buttonStyle(.bordered)
                            Text("Wird groß hinter den Spielinfos angezeigt.")
                                .font(.system(size: 11)).foregroundColor(.secondary)
                            if backgroundImagePath != nil {
                                Button("Entfernen") { backgroundImagePath = nil }
                                    .buttonStyle(.plain).foregroundColor(.red)
                            }
                        }
                    }
                }
                .padding(16)
                .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .padding(24)
        }
    }

    private func selectCover() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("RogueLauncher/Covers")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
            coverImagePath = dest.path
            coverPreview = NSImage(contentsOf: dest)
        }
    }

    private func selectBackground() {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = [.png, .jpeg, .heic, .tiff]
        panel.allowsMultipleSelection = false
        if panel.runModal() == .OK, let url = panel.url {
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("RogueLauncher/Backgrounds")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let dest = dir.appendingPathComponent(url.lastPathComponent)
            try? FileManager.default.copyItem(at: url, to: dest)
            backgroundImagePath = dest.path
        }
    }
}

// MARK: - IGDB Background Picker

struct IGDBBackgroundPickerView: View {
    let gameName: String
    var igdbID: Int? = nil
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var urls: [String] = []
    @State private var isLoading = true

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Hintergrundbild auswählen")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Abbrechen") { dismiss() }.buttonStyle(.bordered)
            }
            .padding(16)
            Divider()

            if isLoading {
                ProgressView("Lade Bilder…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if urls.isEmpty {
                Text("Keine Bilder gefunden")
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                        ForEach(urls, id: \.self) { url in
                            Button(action: { downloadAndSelect(url) }) {
                                AsyncImage(url: URL(string: url)) { img in
                                    img.resizable().aspectRatio(16/9, contentMode: .fill)
                                } placeholder: {
                                    Rectangle().fill(Color.secondary.opacity(0.2))
                                        .aspectRatio(16/9, contentMode: .fit)
                                }
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(16)
                }
            }
        }
        .frame(width: 700, height: 500)
        .onAppear { loadImages() }
    }

    private func loadImages() {
        let group = DispatchGroup()
        var all: [String] = []

        // IGDB Artworks + Screenshots — per ID wenn vorhanden, sonst per Name
        group.enter()
        if let id = igdbID {
            GameMetadataService.fetchIGDBartworksByID(id: id) { artworks in
                let urls = artworks.compactMap { $0["image_id"] as? String }
                    .map { "https://images.igdb.com/igdb/image/upload/t_1080p/\($0).jpg" }
                all += urls
                group.leave()
            }
        } else {
            GameMetadataService.fetchIGDBartworks(for: gameName) { artworks in
                let urls = artworks.compactMap { $0["image_id"] as? String }
                    .map { "https://images.igdb.com/igdb/image/upload/t_1080p/\($0).jpg" }
                all += urls
                group.leave()
            }
        }

        // SteamGridDB Heroes
        group.enter()
        GameMetadataService.fetchSteamGridDBHeroes(for: gameName) { urls in
            all += urls
            group.leave()
        }

        group.notify(queue: .main) {
            self.urls = all
            self.isLoading = false
        }
    }

    private func downloadAndSelect(_ url: String) {
        GameMetadataService.downloadCover(from: url, for: "bg_\(gameName)") { path in
            if let path = path {
                onSelect(path)
                dismiss()
            }
        }
    }
}
