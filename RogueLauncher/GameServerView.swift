import SwiftUI

struct GameServerView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if settings.craftyEnabled && !settings.craftyServers.isEmpty {
                serverSection(title: "Crafty", iconName: "server.rack", color: .green) {
                    ForEach(settings.craftyServers) { server in
                        CraftyServerCard(server: server)
                    }
                }
            }

            if settings.nitradoEnabled && !settings.nitradoServers.isEmpty {
                serverSection(title: "Nitrado", iconName: "server.rack", color: .green) {
                    ForEach(settings.nitradoServers) { server in
                        NitradoServerCard(server: server)
                    }
                }
            }
        }
    }

    private func serverSection<Content: View>(title: String, iconName: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                Image(systemName: iconName).foregroundColor(color).font(.system(size: 13))
                Text(title).font(.system(size: 14, weight: .semibold))
            }
            content()
        }
    }
}

// MARK: - Crafty Card

struct CraftyServerCard: View {
    let server: CraftyServer
    @State private var status: ServerStatus = .unknown
    @State private var command = ""
    @State private var isLoading = false
    @State private var showTerminal = false
    @State private var showCommands = false
    @State private var feedback: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                statusDot(status)
                Text(server.name.isEmpty ? server.serverID : server.name)
                    .font(.system(size: 13, weight: .medium))
                Text(status.label)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Spacer()
                if isLoading { ProgressView().frame(width: 16, height: 16) }
                actionButtons
            }

            // Feedback
            if let fb = feedback {
                Text(fb)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundColor(.green)
                    .transition(.opacity)
            }

            // QOL Schnellbefehle — immer sichtbar
            Divider()
            VStack(alignment: .leading, spacing: 10) {
                commandGroup("Spieler", icon: "person.fill",
                    buttons: [
                        ("Whitelist +",      "plus.circle",        { playerInput("whitelist add") }),
                        ("Whitelist −",      "minus.circle",       { playerInput("whitelist remove") }),
                        ("Op geben",         "crown.fill",         { playerInput("op") }),
                        ("Op entziehen",     "crown",              { playerInput("deop") }),
                        ("Kick",             "arrow.right.square", { playerInput("kick") }),
                        ("Ban",              "xmark.octagon",      { playerInput("ban") }),
                    ])
                commandGroup("Spielmodus", icon: "gamecontroller.fill",
                    buttons: [
                        ("Creative",   "wand.and.stars", { playerInput("gamemode creative") }),
                        ("Survival",   "figure.walk",    { playerInput("gamemode survival") }),
                        ("Adventure",  "map.fill",       { playerInput("gamemode adventure") }),
                        ("Spectator",  "eye.fill",       { playerInput("gamemode spectator") }),
                    ])
                commandGroup("Welt", icon: "globe",
                    buttons: [
                        ("Tag",      "sun.max.fill",    { send("time set day") }),
                        ("Nacht",    "moon.fill",       { send("time set night") }),
                        ("Klar",     "cloud.sun.fill",  { send("weather clear") }),
                        ("Regen",    "cloud.rain.fill", { send("weather rain") }),
                        ("Gewitter", "cloud.bolt.fill", { send("weather thunder") }),
                    ])
                commandGroup("Gamerules", icon: "gearshape.fill",
                    buttons: [
                        ("Keep Inventory ✓", "bag.fill",   { send("gamerule keepInventory true") }),
                        ("Keep Inventory ✗", "bag",        { send("gamerule keepInventory false") }),
                        ("Mob Spawning ✓",   "hare.fill",  { send("gamerule doMobSpawning true") }),
                        ("Mob Spawning ✗",   "hare",       { send("gamerule doMobSpawning false") }),
                        ("Fire Spread ✓",    "flame.fill", { send("gamerule doFireTick true") }),
                        ("Fire Spread ✗",    "flame",      { send("gamerule doFireTick false") }),
                    ])
                commandGroup("Teleport", icon: "location.fill",
                    buttons: [
                        ("Spieler → Spieler", "arrow.left.and.right", { tpPlayerToPlayer() }),
                        ("Spieler → XYZ",     "mappin.circle",        { tpToCoords() }),
                        ("Alle → Spawn",       "house.fill",           { send("execute as @a run tp @s 0 64 0") }),
                    ])
            }
            .padding(.top, 4)

            // Terminal
            if showTerminal {
                HStack {
                    TextField("Minecraft Befehl...", text: $command)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12, design: .monospaced))
                    Button("Senden") { sendCommand() }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(command.isEmpty)
                }
            }
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { refreshStatus() }
    }

    private var actionButtons: some View {
        HStack(spacing: 6) {
            Button(action: { serverAction("start_server") }) {
                Image(systemName: "play.fill").font(.system(size: 11))
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(status == .online || isLoading)

            Button(action: { serverAction("stop_server") }) {
                Image(systemName: "stop.fill").font(.system(size: 11))
            }
            .buttonStyle(.bordered).controlSize(.small)
            .disabled(status == .offline || isLoading)

            Button(action: { serverAction("restart_server") }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
            }
            .buttonStyle(.bordered).controlSize(.small).disabled(isLoading)

            Button(action: { showTerminal.toggle() }) {
                Image(systemName: "terminal").font(.system(size: 11))
            }
            .buttonStyle(.bordered).controlSize(.small)

            Button(action: refreshStatus) {
                Image(systemName: "arrow.clockwise.circle").font(.system(size: 11))
            }
            .buttonStyle(.plain).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func commandGroup(_ title: String, icon: String, buttons: [(String, String, () -> Void)]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.rogueRed)
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(buttons.indices, id: \.self) { i in
                        CommandButton(buttons[i].0, icon: buttons[i].1, action: buttons[i].2)
                    }
                }
                .padding(.horizontal, 10).padding(.bottom, 10)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Command helpers

    private func send(_ cmd: String) {
        GameServerService.craftySendCommand(serverID: server.serverID, command: cmd) { _ in
            showFeedback("✓ \(cmd)")
        }
    }

    private func showFeedback(_ msg: String) {
        DispatchQueue.main.async {
            withAnimation { feedback = msg }
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation { feedback = nil }
            }
        }
    }

    private func playerInput(_ baseCmd: String) {
        let alert = NSAlert()
        alert.messageText = "Spielername"
        alert.informativeText = "Befehl: /\(baseCmd) <name>"
        alert.addButton(withTitle: "Ausführen")
        alert.addButton(withTitle: "Abbrechen")
        let tf = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        tf.placeholderString = "Spielername"
        alert.accessoryView = tf
        alert.window.initialFirstResponder = tf
        if alert.runModal() == .alertFirstButtonReturn && !tf.stringValue.isEmpty {
            send("\(baseCmd) \(tf.stringValue)")
        }
    }

    private func tpPlayerToPlayer() {
        let alert = NSAlert()
        alert.messageText = "Teleportieren"
        alert.informativeText = "Von → Zu"
        alert.addButton(withTitle: "Teleportieren")
        alert.addButton(withTitle: "Abbrechen")
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: 56))
        stack.orientation = .vertical; stack.spacing = 6
        let from = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        from.placeholderString = "Von (Spieler)"
        let to = NSTextField(frame: NSRect(x: 0, y: 0, width: 260, height: 24))
        to.placeholderString = "Zu (Spieler)"
        stack.addArrangedSubview(from); stack.addArrangedSubview(to)
        alert.accessoryView = stack
        if alert.runModal() == .alertFirstButtonReturn && !from.stringValue.isEmpty && !to.stringValue.isEmpty {
            send("tp \(from.stringValue) \(to.stringValue)")
        }
    }

    private func tpToCoords() {
        let alert = NSAlert()
        alert.messageText = "Zu Koordinaten teleportieren"
        alert.addButton(withTitle: "Teleportieren")
        alert.addButton(withTitle: "Abbrechen")
        let stack = NSStackView(frame: NSRect(x: 0, y: 0, width: 260, height: 90))
        stack.orientation = .vertical; stack.spacing = 6
        let player = NSTextField(frame: .init(x: 0, y: 0, width: 260, height: 24))
        player.placeholderString = "Spieler (oder @a für alle)"
        let x = NSTextField(frame: .init(x: 0, y: 0, width: 260, height: 24))
        x.placeholderString = "X Y Z  (z.B. 0 64 0)"
        stack.addArrangedSubview(player); stack.addArrangedSubview(x)
        alert.accessoryView = stack
        if alert.runModal() == .alertFirstButtonReturn && !player.stringValue.isEmpty && !x.stringValue.isEmpty {
            send("tp \(player.stringValue) \(x.stringValue)")
        }
    }

    private func refreshStatus() {
        GameServerService.craftyServerStatus(serverID: server.serverID) { s in status = s }
    }

    private func serverAction(_ action: String) {
        isLoading = true
        status = action == "stop_server" ? .stopping : .starting
        GameServerService.craftyServerAction(serverID: server.serverID, action: action) { _ in
            isLoading = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) { refreshStatus() }
        }
    }

    private func sendCommand() {
        let cmd = command; command = ""
        GameServerService.craftySendCommand(serverID: server.serverID, command: cmd) { _ in
            showFeedback("✓ \(cmd)")
        }
    }
}

// MARK: - Command Button

private struct CommandButton: View {
    let title: String
    let icon: String
    let action: () -> Void
    init(_ title: String, icon: String, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
                Text(title)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(width: 72, height: 52)
            .background(Color.secondary.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Flow Layout (simple wrap using HStack wrapping)

private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let content: Content
    init(spacing: CGFloat = 6, @ViewBuilder content: () -> Content) {
        self.spacing = spacing; self.content = content()
    }
    var body: some View {
        HStack(alignment: .top, spacing: spacing) {
            content
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }
}


// MARK: - Nitrado Card

struct NitradoServerCard: View {
    let server: NitradoServer
    @State private var status: ServerStatus = .unknown
    @State private var isLoading = false
    @State private var details: GameServerService.NitradoServerDetails? = nil
    @State private var showSettings = false
    @State private var feedback: String? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                statusDot(status)
                Text(server.name.isEmpty ? server.serverID : server.name)
                    .font(.system(size: 13, weight: .medium))
                if let d = details, !d.game.isEmpty {
                    Text(d.game.capitalized)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                } else {
                    Text(status.label)
                        .font(.system(size: 11)).foregroundColor(.secondary)
                }
                Spacer()
                if isLoading { ProgressView().frame(width: 16, height: 16) }
                nitradoActionButtons
            }

            if let fb = feedback {
                Text(fb).font(.system(size: 11, design: .monospaced)).foregroundColor(.green).transition(.opacity)
            }

            Divider()

            VStack(alignment: .leading, spacing: 10) {
                // Server-Status
                if let d = details {
                    nitroGroup("Server-Status", icon: "chart.bar.fill") {
                        statTile("Spieler", value: "\(d.players.count)/\(d.slots)", icon: "person.2.fill")
                        if d.memoryMB > 0 { statTile("RAM", value: "\(d.memoryMB) MB", icon: "memorychip") }
                        if !d.map.isEmpty { statTile("Map", value: d.map, icon: "map.fill") }
                        if !d.version.isEmpty { statTile("Version", value: d.version, icon: "info.circle.fill") }
                    }
                }

                // Spieler
                nitroGroup("Spieler online", icon: "person.fill") {
                    if let d = details, !d.players.isEmpty {
                        ForEach(d.players, id: \.self) { player in
                            CommandButton(player, icon: "person.circle", action: {})
                        }
                    } else {
                        Text("Keine Spieler online")
                            .font(.system(size: 11)).foregroundColor(.secondary).italic()
                            .padding(.horizontal, 12).padding(.bottom, 10)
                    }
                }

                // Server-Aktionen
                nitroGroup("Server", icon: "server.rack") {
                    CommandButton("Starten",       icon: "play.fill",          action: { nitradoAction("start") })
                    CommandButton("Stoppen",       icon: "stop.fill",          action: { nitradoAction("stop") })
                    CommandButton("Neustarten",    icon: "arrow.clockwise",    action: { nitradoAction("restart") })
                    CommandButton("Einstellungen", icon: "gearshape.fill",     action: { showSettings = true })
                }
            }
            .padding(.top, 4)
        }
        .padding(12)
        .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .onAppear { refreshAll() }
        .sheet(isPresented: $showSettings) {
            if let d = details { NitradoSettingsView(serverID: server.serverID, game: d.game) }
        }
    }

    private var nitradoActionButtons: some View {
        HStack(spacing: 6) {
            Button(action: { nitradoAction("restart") }) {
                Image(systemName: "arrow.clockwise").font(.system(size: 11))
            }.buttonStyle(.bordered).controlSize(.small).disabled(isLoading)
            Button(action: { nitradoAction("stop") }) {
                Image(systemName: "stop.fill").font(.system(size: 11))
            }.buttonStyle(.bordered).controlSize(.small).disabled(status == .offline || isLoading)
            Button(action: refreshAll) {
                Image(systemName: "arrow.clockwise.circle").font(.system(size: 11))
            }.buttonStyle(.plain).foregroundColor(.secondary)
        }
    }

    @ViewBuilder
    private func nitroGroup<Content: View>(_ title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundColor(.rogueRed)
                Text(title).font(.system(size: 12, weight: .semibold))
            }
            .padding(.horizontal, 12).padding(.top, 10).padding(.bottom, 2)
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) { content() }
                    .padding(.horizontal, 10).padding(.bottom, 10)
            }
        }
        .background(Color(NSColor.controlBackgroundColor).opacity(0.6))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func statTile(_ label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.system(size: 14, weight: .medium)).foregroundColor(.primary)
            Text(value).font(.system(size: 11, weight: .semibold))
            Text(label).font(.system(size: 10)).foregroundColor(.secondary)
        }
        .frame(width: 80, height: 64)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func refreshAll() {
        GameServerService.nitradoServerDetails(serverID: server.serverID) { d in
            details = d
            if let d = d { status = d.status }
        }
    }

    private func nitradoAction(_ action: String) {
        isLoading = true
        status = action == "stop" ? .stopping : .starting
        GameServerService.nitradoServerAction(serverID: server.serverID, action: action) { _ in
            isLoading = false
            DispatchQueue.main.asyncAfter(deadline: .now() + 5) { refreshAll() }
        }
    }
}

// MARK: - Nitrado Settings View

struct NitradoSettingsView: View {
    let serverID: String
    let game: String
    @Environment(\.dismiss) private var dismiss
    @State private var settings: [String: Any] = [:]
    @State private var isLoading = true
    @State private var isSaving = false
    @State private var saveMessage = ""

    // Editierbare Felder
    @State private var serverName = ""
    @State private var serverPassword = ""
    @State private var maxPlayers = ""

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Server-Einstellungen")
                        .font(.system(size: 15, weight: .semibold))
                    Text(game.capitalized)
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                Spacer()
                Button("Schließen") { dismiss() }.buttonStyle(.bordered)
            }
            .padding(16)
            Divider()

            if isLoading {
                Spacer()
                ProgressView("Lade Einstellungen…")
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        settingRow("Server-Name", binding: $serverName)
                        settingRow("Passwort", binding: $serverPassword, secure: true)
                        settingRow("Max. Spieler", binding: $maxPlayers, keyboardType: true)

                        if !saveMessage.isEmpty {
                            Text(saveMessage)
                                .font(.system(size: 12))
                                .foregroundColor(saveMessage.hasPrefix("✓") ? .green : .red)
                        }

                        Button(action: saveSettings) {
                            HStack {
                                if isSaving { ProgressView().frame(width: 20, height: 20) }
                                Text("Speichern")
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(isSaving)
                    }
                    .padding(20)
                }
            }
        }
        .frame(width: 420, height: 360)
        .onAppear { loadSettings() }
    }

    private func settingRow(_ label: String, binding: Binding<String>, secure: Bool = false, keyboardType: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            if secure {
                SecureField("", text: binding)
                    .textFieldStyle(.roundedBorder)
            } else {
                TextField("", text: binding)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    private func loadSettings() {
        GameServerService.nitradoGetSettings(serverID: serverID) { s in
            isLoading = false
            guard let s = s else { return }
            settings = s
            // Felder aus den Settings befüllen — Nitrado gibt verschachtelte Kategorien zurück
            for (_, catVal) in s {
                guard let cat = catVal as? [String: Any] else { continue }
                for (key, val) in cat {
                    let v = (val as? [String: Any])?["value"] as? String ?? (val as? String ?? "")
                    switch key.lowercased() {
                    case "server_name", "hostname", "name": if serverName.isEmpty { serverName = v }
                    case "server_password", "password": if serverPassword.isEmpty { serverPassword = v }
                    case "max_players", "maxplayers", "slots": if maxPlayers.isEmpty { maxPlayers = v }
                    default: break
                    }
                }
            }
        }
    }

    private func saveSettings() {
        isSaving = true
        saveMessage = ""
        let group = DispatchGroup()

        func save(_ key: String, _ value: String) {
            guard !value.isEmpty else { return }
            group.enter()
            GameServerService.nitradoSetSetting(serverID: serverID, category: "general",
                                                key: key, value: value) { _ in group.leave() }
        }

        save("server_name", serverName)
        save("server_password", serverPassword)
        save("max_players", maxPlayers)

        group.notify(queue: .main) {
            isSaving = false
            saveMessage = "✓ Gespeichert"
            DispatchQueue.main.asyncAfter(deadline: .now() + 2) { saveMessage = "" }
        }
    }
}

// MARK: - FlowLayout (für Spieler-Tags)


// MARK: - Helper

private func statusDot(_ status: ServerStatus) -> some View {
    Circle()
        .fill(status == .online ? Color.green : status == .offline ? Color.red : status == .unknown ? Color.gray : Color.orange)
        .frame(width: 8, height: 8)
}
