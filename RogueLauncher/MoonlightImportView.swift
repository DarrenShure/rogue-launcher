import SwiftUI

struct MoonlightImportView: View {
    let store: GameStore
    @Environment(\.dismiss) private var dismiss

    @State private var apps: [MoonlightApp] = []
    @State private var selected: Set<UUID> = []
    @State private var isLoading = true
    @State private var errorMessage: String? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Aus Moonlight/Sunshine importieren")
                    .font(.system(size: 15, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 24).padding(.top, 20).padding(.bottom, 16)

            Divider()

            Group {
                if isLoading {
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Verbinde mit Sunshine…")
                            .foregroundColor(.secondary).font(.callout)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if let err = errorMessage {
                    VStack(spacing: 16) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 36)).foregroundColor(.orange)
                        Text(err)
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary).font(.callout)
                            .padding(.horizontal)
                        Button("Erneut versuchen") { load() }
                            .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else if apps.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "moon.zzz")
                            .font(.system(size: 40)).foregroundColor(.secondary)
                        Text("Keine neuen Spiele gefunden")
                            .font(.headline).foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                } else {
                    List(apps) { app in
                        HStack {
                            Image(systemName: selected.contains(app.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundColor(selected.contains(app.id) ? .accentColor : .secondary)
                            Text(app.name).font(.system(size: 13))
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if selected.contains(app.id) { selected.remove(app.id) }
                            else { selected.insert(app.id) }
                        }
                    }
                    .listStyle(.bordered)

                    HStack {
                        Button("Alle") { selected = Set(apps.map { $0.id }) }
                            .font(.system(size: 12)).buttonStyle(.plain).foregroundColor(.accentColor)
                        Spacer()
                        Text("\(selected.count) ausgewählt").font(.system(size: 12)).foregroundColor(.secondary)
                    }
                    .padding(.horizontal, 24).padding(.top, 8)
                }
            }

            Divider()

            HStack {
                Spacer()
                Button("Abbrechen") { dismiss() }.keyboardShortcut(.escape)
                Button("Importieren (\(selected.count))") { importSelected() }
                    .keyboardShortcut(.return)
                    .buttonStyle(.borderedProminent)
                    .disabled(selected.isEmpty)
            }
            .padding(.horizontal, 24).padding(.vertical, 16)
        }
        .frame(width: 440, height: 480)
        .onAppear { load() }
    }

    private func load() {
        isLoading = true
        errorMessage = nil
        let ip   = AppSettings.shared.pcIPAddress
        let port = AppSettings.shared.moonlightPort
        let existing = Set(store.games.map { $0.name })

        MoonlightImporter.fetchApps(ip: ip, port: port) { fetched, error in
            isLoading = false
            if let error = error {
                errorMessage = error
                return
            }
            let new = fetched.filter { !existing.contains($0.name) }
            apps = new
            selected = Set(new.map { $0.id })
        }
    }

    private func importSelected() {
        for app in apps where selected.contains(app.id) {
            store.add(Game(name: app.name, description: "", genre: "", releaseYear: "", appName: app.name, type: .moonlight))
        }
        dismiss()
    }
}
