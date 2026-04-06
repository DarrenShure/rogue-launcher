import SwiftUI

struct IGDBSearchView: View {
    let originalName: String
    let onSelect: (String, String?, Int) -> Void  // (displayName, coverPath, igdbID)
    @Environment(\.dismiss) private var dismiss

    @State private var query = ""
    @State private var results: [GameMetadataService.IGDBSearchResult] = []
    @State private var isSearching = false
    @State private var isApplying: Int? = nil
    @State private var slugInput = ""
    @State private var isLoadingSlug = false
    @State private var slugError = ""

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Spiel bei IGDB suchen")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Abbrechen") { dismiss() }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            Divider()

            // Suchfeld
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass").foregroundColor(.secondary)
                TextField("Suchen… oder \"Exakter Name\"", text: $query)
                    .textFieldStyle(.plain)
                    .onSubmit { search() }
                if isSearching {
                    ProgressView().frame(width: 20, height: 20)
                } else if !query.isEmpty {
                    Button(action: search) {
                        Text("Suchen")
                            .font(.system(size: 12, weight: .medium))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            .padding(.horizontal, 16).padding(.vertical, 10)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(16)

            // IGDB URL / Slug Direkteingabe
            VStack(alignment: .leading, spacing: 6) {
                Text("Direkt per IGDB-URL zuordnen")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.secondary)
                Text("Suchfeld oben muss leer sein")
                    .font(.system(size: 10))
                    .foregroundColor(.secondary.opacity(0.8))
                HStack(spacing: 8) {
                    Image(systemName: "link").foregroundColor(.secondary).font(.system(size: 12))
                    TextField("https://www.igdb.com/games/islanders", text: $slugInput)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12))
                        .onSubmit { fetchBySlug() }
                    if isLoadingSlug {
                        ProgressView().frame(width: 16, height: 16)
                    } else if !slugInput.isEmpty {
                        Button("Laden") { fetchBySlug() }
                            .buttonStyle(.bordered).controlSize(.small)
                    }
                }
                .padding(8)
                .background(Color.secondary.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                if !slugError.isEmpty {
                    Text(slugError).font(.system(size: 11)).foregroundColor(.red)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 8)

            Divider()

            // Ergebnisse
            if results.isEmpty && !isSearching {
                Spacer()
                VStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 36)).foregroundColor(.secondary.opacity(0.4))
                    Text("Suchbegriff eingeben und Enter drücken")
                        .foregroundColor(.secondary)
                }
                Spacer()
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(results) { result in
                            resultRow(result)
                            Divider().padding(.leading, 72)
                        }
                    }
                }
            }
        }
        .frame(width: 500, height: 520)
        .onAppear { query = originalName; search() }
    }

    private func resultRow(_ result: GameMetadataService.IGDBSearchResult) -> some View {
        HStack(spacing: 12) {
            // Mini-Cover
            Group {
                if let urlStr = result.coverURL, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                        default: Color.secondary.opacity(0.15)
                        }
                    }
                } else {
                    Color.secondary.opacity(0.15)
                        .overlay(Image(systemName: "gamecontroller").foregroundColor(.secondary))
                }
            }
            .frame(width: 40, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 3) {
                Text(result.name)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(2)
                if !result.year.isEmpty {
                    Text(result.year)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
            Spacer()

            if isApplying == result.id {
                ProgressView().frame(width: 20, height: 20)
            } else {
                Button("Zuordnen") { apply(result) }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(isApplying != nil)
            }
        }
        .padding(.horizontal, 16).padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func fetchBySlug() {
        var slug = slugInput.trimmingCharacters(in: .whitespaces)
        // URL → Slug extrahieren
        if slug.contains("igdb.com/games/") {
            slug = slug.components(separatedBy: "igdb.com/games/").last?
                .components(separatedBy: "/").first ?? slug
        }
        guard !slug.isEmpty else { return }
        isLoadingSlug = true
        slugError = ""
        GameMetadataService.fetchFromIGDBbySlug(slug: slug) { result in
            DispatchQueue.main.async {
                isLoadingSlug = false
                if let result = result {
                    apply(result)
                } else {
                    slugError = "Spiel nicht gefunden für Slug: \"\(slug)\""
                }
            }
        }
    }

    private func search() {
        let q = query.trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { return }
        isSearching = true
        results = []

        let isExact = q.hasPrefix("\"") && q.hasSuffix("\"") && q.count > 2
        let searchTerm = isExact ? String(q.dropFirst().dropLast()) : q

        GameMetadataService.searchIGDB(query: searchTerm) { found in
            DispatchQueue.main.async {
                if isExact {
                    let lower = searchTerm.lowercased().trimmingCharacters(in: .whitespaces)
                    // Erst exakt, dann case-insensitive contains als Fallback
                    let exact = found.filter { $0.name.lowercased().trimmingCharacters(in: .whitespaces) == lower }
                    results = exact.isEmpty ? found.filter { $0.name.lowercased().contains(lower) } : exact
                } else {
                    results = found
                }
                isSearching = false
            }
        }
    }

    private func apply(_ result: GameMetadataService.IGDBSearchResult) {
        isApplying = result.id
        guard let coverURL = result.coverURL else {
            onSelect(result.name, nil, result.id)
            dismiss()
            return
        }
        GameMetadataService.downloadCover(from: coverURL.replacingOccurrences(of: "t_cover_small", with: "t_cover_big"), for: result.name) { path in
            DispatchQueue.main.async {
                onSelect(result.name, path, result.id)
                dismiss()
            }
        }
    }
}
