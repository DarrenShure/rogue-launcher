import SwiftUI

struct LocalImportView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var apps: [LocalApp] = []
    @State private var selected: Set<UUID> = []
    @State private var isLoading = true
    @State private var searchText = ""
    @State private var showingFilePicker = false

    var filtered: [LocalApp] {
        if searchText.isEmpty { return apps }
        return apps.filter { $0.name.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Lokale Apps importieren")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
                Button(action: { showingFilePicker = true }) {
                    Label("App manuell wählen", systemImage: "folder")
                        .font(.system(size: 12))
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 12)

            // Suchfeld
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("Suchen…", text: $searchText)
                    .textFieldStyle(.plain)
            }
            .padding(8)
            .background(Color.secondary.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .padding(.horizontal, 24)
            .padding(.bottom, 8)

            Divider()

            if isLoading {
                VStack(spacing: 12) {
                    ProgressView()
                    Text("Scanne Applications…")
                        .foregroundColor(.secondary)
                        .font(.callout)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(filtered) { app in
                    HStack(spacing: 10) {
                        Image(systemName: selected.contains(app.id) ? "checkmark.circle.fill" : "circle")
                            .foregroundColor(selected.contains(app.id) ? .accentColor : .secondary)
                            .frame(width: 20)

                        if let icon = app.icon {
                            Image(nsImage: icon)
                                .resizable()
                                .frame(width: 28, height: 28)
                                .clipShape(RoundedRectangle(cornerRadius: 6))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            Text(app.name)
                                .font(.system(size: 13))
                            Text(app.bundleID)
                                .font(.system(size: 10))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        if selected.contains(app.id) { selected.remove(app.id) }
                        else { selected.insert(app.id) }
                    }
                }
                .listStyle(.bordered)

                HStack {
                    Button("Alle auswählen") { selected = Set(filtered.map { $0.id }) }
                        .font(.system(size: 12))
                        .buttonStyle(.plain)
                        .foregroundColor(.accentColor)
                    Button("Keine") { selected.removeAll() }
                        .font(.system(size: 12))
                        .buttonStyle(.plain)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("\(selected.count) ausgewählt")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 8)
            }

            Divider()

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }
                    .keyboardShortcut(.escape)
                Button("Importieren (\(selected.count))") { importSelected() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
        }
        .frame(width: 500, height: 560)
        .onAppear { loadApps() }
        .fileImporter(
            isPresented: $showingFilePicker,
            allowedContentTypes: [.application],
            allowsMultipleSelection: false
        ) { result in
            if let url = try? result.get().first {
                let name = url.deletingPathExtension().lastPathComponent
                let bundleID = Bundle(url: url)?.bundleIdentifier ?? url.path
                let existing = Set(store.games.map { $0.name })
                guard !existing.contains(name) else { return }
                let game = Game(name: name, description: "", genre: "", releaseYear: "",
                                appName: bundleID, type: .local)
                store.add(game)
                dismiss()
            }
        }
    }

    private func loadApps() {
        DispatchQueue.global(qos: .userInitiated).async {
            let found = LocalAppImporter.scanApplications()
            let existing = Set(store.games.map { $0.name })
            let new = found.filter { !existing.contains($0.name) }
            DispatchQueue.main.async {
                apps = new
                isLoading = false
            }
        }
    }

    private func importSelected() {
        let toImport = filtered.filter { selected.contains($0.id) }
        for app in toImport {
            let game = Game(name: app.name, description: "", genre: "", releaseYear: "",
                            appName: app.bundleID, type: .local)
            store.add(game)
        }
        dismiss()
    }
}
