import SwiftUI

struct GenreEditView: View {
    let genre: String
    @ObservedObject var gameStore: GameStore
    @ObservedObject private var mappingStore = GenreMappingStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var newVariant = ""
    @State private var selectedSuggestions: Set<String> = []

    var builtinVariants: [String] {
        genreMapping.first(where: { $0.canonical == genre })?.variants ?? []
    }

    var customVariants: [String] {
        mappingStore.customVariants[genre] ?? []
    }

    var suggestions: [String] {
        mappingStore.unassignedTags(from: gameStore)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: colorsForGenre(genre),
                                            startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 32, height: 32)
                    Image(systemName: iconForGenre(genre))
                        .font(.system(size: 14))
                        .foregroundColor(.white)
                }
                Text("Genre bearbeiten: \(genre)")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button("Schließen") { dismiss() }
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)
            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 20) {

                    // Eingebaute Varianten (nicht editierbar)
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Eingebaute Begriffe")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)
                        FlowTagsView(tags: builtinVariants, removable: false) { _ in }
                    }

                    Divider()

                    // Eigene Varianten
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Eigene Begriffe")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.secondary)

                        if customVariants.isEmpty {
                            Text("Noch keine eigenen Begriffe definiert.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        } else {
                            FlowTagsView(tags: customVariants, removable: true) { variant in
                                mappingStore.removeVariant(variant, from: genre)
                            }
                        }

                        // Neuen Begriff hinzufügen
                        HStack(spacing: 8) {
                            TextField("Begriff hinzufügen (z.B. tactical)", text: $newVariant)
                                .textFieldStyle(.roundedBorder)
                                .onSubmit { addVariant() }
                            Button("Hinzufügen") { addVariant() }
                                .buttonStyle(.bordered)
                                .disabled(newVariant.trimmingCharacters(in: .whitespaces).isEmpty)
                        }
                    }

                    // Vorschläge
                    if !suggestions.isEmpty {
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Nicht zugeordnete Begriffe in deiner Bibliothek")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.secondary)
                            Text("Diese Begriffe kommen in deinen Spielen vor, sind aber keinem Genre zugeordnet. Klicke auf einen Begriff um ihn zu \"\(genre)\" hinzuzufügen.")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)

                            FlowTagsView(tags: suggestions, removable: false, tappable: true) { variant in
                                mappingStore.addVariant(variant, to: genre)
                            }
                        }
                    }
                }
                .padding(24)
            }

            Divider()
            HStack {
                Spacer()
                Button("Fertig") { dismiss() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 560, height: 500)
    }

    private func addVariant() {
        let v = newVariant.trimmingCharacters(in: .whitespaces)
        guard !v.isEmpty else { return }
        mappingStore.addVariant(v, to: genre)
        newVariant = ""
    }
}

struct FlowTagsView: View {
    let tags: [String]
    var removable: Bool = false
    var tappable: Bool = false
    let action: (String) -> Void

    var body: some View {
        FlowLayoutTags(spacing: 6) {
            ForEach(tags, id: \.self) { tag in
                HStack(spacing: 4) {
                    Text(tag)
                        .font(.system(size: 11))
                        .foregroundColor(tappable ? .accentColor : .primary)
                    if removable {
                        Button(action: { action(tag) }) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(
                    tappable
                        ? Color.accentColor.opacity(0.1)
                        : (removable ? Color.rogueRed.opacity(0.1) : Color.secondary.opacity(0.1))
                )
                .clipShape(Capsule())
                .onTapGesture { if tappable { action(tag) } }
            }
        }
    }
}

struct FlowLayoutTags: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let width = proposal.width ?? 500
        var x: CGFloat = 0, y: CGFloat = 0, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > width && x > 0 { y += rowH + spacing; x = 0; rowH = 0 }
            x += size.width + spacing; rowH = max(rowH, size.height)
        }
        return CGSize(width: width, height: y + rowH)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x = bounds.minX, y = bounds.minY, rowH: CGFloat = 0
        for view in subviews {
            let size = view.sizeThatFits(.unspecified)
            if x + size.width > bounds.maxX && x > bounds.minX { y += rowH + spacing; x = bounds.minX; rowH = 0 }
            view.place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
            x += size.width + spacing; rowH = max(rowH, size.height)
        }
    }
}
