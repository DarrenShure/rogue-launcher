import SwiftUI

struct PosterPickerView: View {
    let gameName: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var artworks: [IGDBArtwork] = []
    @State private var isLoading = true
    @State private var downloading: String? = nil
    @State private var showingFilePicker = false

    struct IGDBArtwork: Identifiable {
        let id: String
        let url: String
        let fullURL: String
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Poster auswählen")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Schließen") { dismiss() }
            }
            .padding(.horizontal, 20).padding(.vertical, 16)
            Divider()

            Picker("", selection: $selectedTab) {
                Text("Eigenes Bild").tag(0)
                Text("IGDB Artworks").tag(1)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 20).padding(.vertical, 12)

            if selectedTab == 0 {
                // Eigenes Bild
                VStack(spacing: 20) {
                    Spacer()
                    Image(systemName: "photo.badge.plus")
                        .font(.system(size: 52))
                        .foregroundColor(.secondary)
                    Text("Wähle ein Bild von deinem Mac")
                        .foregroundColor(.secondary)
                    Button("Datei auswählen…") { showingFilePicker = true }
                        .buttonStyle(.borderedProminent)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .fileImporter(isPresented: $showingFilePicker,
                              allowedContentTypes: [.png, .jpeg, .heic, .tiff, .bmp],
                              allowsMultipleSelection: false) { result in
                    if let url = try? result.get().first {
                        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                        let dir = support.appendingPathComponent("RogueLauncher/Covers")
                        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                        let dest = dir.appendingPathComponent("bg_\(gameName)_custom_\(url.lastPathComponent)")
                        try? FileManager.default.copyItem(at: url, to: dest)
                        onSelect(dest.path)
                        dismiss()
                    }
                }
            } else {
                // IGDB Artworks
                if isLoading {
                    Spacer()
                    ProgressView("Lade Bilder…")
                    Spacer()
                } else if artworks.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "photo.slash").font(.system(size: 40)).foregroundColor(.secondary)
                        Text("Keine Artworks gefunden").foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    ScrollView {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 180), spacing: 12)], spacing: 12) {
                            ForEach(artworks) { artwork in
                                artworkCell(artwork)
                            }
                        }
                        .padding(16)
                    }
                }
            }
        }
        .frame(width: 680, height: 500)
        .onAppear { loadArtworks() }
    }

    private func artworkCell(_ artwork: IGDBArtwork) -> some View {
        Button(action: { downloadAndSelect(artwork) }) {
            ZStack(alignment: .center) {
                AsyncImage(url: URL(string: artwork.url)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().aspectRatio(contentMode: .fill)
                    case .failure:
                        Color.secondary.opacity(0.2)
                            .overlay(Image(systemName: "photo").foregroundColor(.secondary))
                    default:
                        Color.secondary.opacity(0.1)
                            .overlay(ProgressView().frame(width: 20, height: 20))
                    }
                }
                .frame(height: 120).clipped()

                if downloading == artwork.id {
                    Color.black.opacity(0.5)
                    ProgressView().tint(.white)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.secondary.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(downloading != nil)
    }

    private func loadArtworks() {
        isLoading = true
        GameMetadataService.fetchIGDBartworks(for: gameName) { results in
            artworks = results.map { item in
                let id = item["image_id"] as? String ?? UUID().uuidString
                let thumb = "https://images.igdb.com/igdb/image/upload/t_screenshot_big/\(id).jpg"
                let full  = "https://images.igdb.com/igdb/image/upload/t_1080p/\(id).jpg"
                return IGDBArtwork(id: id, url: thumb, fullURL: full)
            }
            isLoading = false
        }
    }

    private func downloadAndSelect(_ artwork: IGDBArtwork) {
        downloading = artwork.id
        GameMetadataService.downloadCover(from: artwork.fullURL, for: "bg_\(gameName)_\(artwork.id)") { path in
            downloading = nil
            if let path = path {
                onSelect(path)
                dismiss()
            }
        }
    }
}
