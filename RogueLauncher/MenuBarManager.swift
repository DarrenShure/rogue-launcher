import AppKit
import SwiftUI

// MARK: - Menu Bar Manager

class MenuBarManager: NSObject {
    static let shared = MenuBarManager()
    private var statusItem: NSStatusItem?
    private(set) var consoleActive = false
    private var consoleName = ""
    private var consoleMacInput = 15
    private var consoleInputNumber = 17

    override init() {
        super.init()
        // Verzögert starten damit App vollständig initialisiert ist
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            self.updateVisibility()
        }
    }

    private func updateVisibility() {
        assert(Thread.isMainThread)
        let enabled = AppSettings.shared.consolesEnabled
        if enabled && statusItem == nil {
            statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            updateIcon()
        } else if !enabled, let item = statusItem {
            NSStatusBar.system.removeStatusItem(item)
            statusItem = nil
        }
    }

    /// Aufruf wenn consolesEnabled sich ändert (aus SettingsView)
    func refresh() {
        DispatchQueue.main.async { self.updateVisibility() }
    }

    private func updateIcon() {
        guard AppSettings.shared.consolesEnabled, let button = statusItem?.button else { return }
        let config = NSImage.SymbolConfiguration(pointSize: 14, weight: .medium)
        let iconName = consoleActive ? "gamecontroller.fill" : "gamecontroller"
        let icon = NSImage(systemSymbolName: iconName, accessibilityDescription: "Rogue Launcher")?
            .withSymbolConfiguration(config)
        icon?.isTemplate = true
        button.image = icon
        button.target = self
        button.action = #selector(showMenu)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    func activateConsoleMode(consoleName name: String, inputNumber: Int, macInput: Int) {
        consoleActive = true
        self.consoleName = name
        consoleInputNumber = inputNumber
        consoleMacInput = macInput
        DispatchQueue.main.async { self.updateIcon() }
    }

    func deactivateConsoleMode() {
        consoleActive = false
        DispatchQueue.main.async { self.updateIcon() }
    }

    @objc private func showMenu() {
        guard let button = statusItem?.button else { return }
        let menu = buildMenu()
        statusItem?.menu = menu
        button.performClick(nil)
        statusItem?.menu = nil
    }

    private func buildMenu() -> NSMenu {
        let menu = NSMenu()

        // Konsolen-Session aktiv
        if consoleActive {
            let activeItem = NSMenuItem(title: "🎮 \(consoleName) aktiv", action: nil, keyEquivalent: "")
            activeItem.isEnabled = false
            menu.addItem(activeItem)

            let reconnect = NSMenuItem(
                title: "Bildschirm wieder verbinden",
                action: #selector(reconnectDisplay),
                keyEquivalent: "")
            reconnect.target = self
            menu.addItem(reconnect)
            menu.addItem(.separator())
        }

        // Zuletzt gespielt Header
        let headerItem = NSMenuItem(title: "Zuletzt gespielt", action: nil, keyEquivalent: "")
        headerItem.isEnabled = false
        menu.addItem(headerItem)

        // Cover-Grid
        let store = GameStore()
        let recent = Array(store.games
            .filter { $0.lastPlayedAt != nil }
            .sorted { ($0.lastPlayedAt ?? .distantPast) > ($1.lastPlayedAt ?? .distantPast) }
            .prefix(8))

        if recent.isEmpty {
            let empty = NSMenuItem(title: "Noch keine gespielten Spiele", action: nil, keyEquivalent: "")
            empty.isEnabled = false
            menu.addItem(empty)
        } else {
            let gridItem = NSMenuItem()
            gridItem.view = RecentGamesMenuView(games: recent)
            menu.addItem(gridItem)
        }

        menu.addItem(.separator())

        let bringAll = NSMenuItem(
            title: "Alle Fenster auf Mac-Bildschirm holen",
            action: #selector(bringAllWindowsToInternalDisplay),
            keyEquivalent: "")
        bringAll.target = self
        bringAll.image = NSImage(systemSymbolName: "macbook", accessibilityDescription: nil)
        menu.addItem(bringAll)

        menu.addItem(.separator())

        let open = NSMenuItem(title: "Rogue Launcher öffnen",
                              action: #selector(openApp), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let quit = NSMenuItem(title: "Beenden",
                              action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        menu.addItem(quit)

        return menu
    }

    @objc private func bringAllWindowsToInternalDisplay() {
        guard let internalScreen = NSScreen.screens.first(where: {
            let n = $0.localizedName.lowercased()
            return n.contains("built-in") || n.contains("liquid") ||
                   n.contains("color lcd") || n.contains("macbook")
        }) ?? NSScreen.screens.min(by: { $0.frame.width < $1.frame.width })
        else { return }

        let f = internalScreen.visibleFrame
        // Ziel: Fenster mittig auf dem internen Display
        let x = Int(f.minX + 100)
        let y = Int(f.minY + 100)

        // AppleScript: alle Prozesse mit Fenstern verschieben
        let script = """
        tell application "System Events"
            set allProcs to every process whose visible is true
            repeat with proc in allProcs
                try
                    set position of every window of proc to {\(x), \(y)}
                end try
            end repeat
        end tell
        """
        var error: NSDictionary?
        if let as_ = NSAppleScript(source: script) {
            as_.executeAndReturnError(&error)
        }

        // Eigene Fenster auch verschieben
        for win in NSApp.windows where win.isVisible && !win.isMiniaturized {
            win.setFrameOrigin(NSPoint(x: f.minX + 100, y: f.minY + 100))
        }
        NSApp.activate(ignoringOtherApps: true)
    }

    @objc private func reconnectDisplay() {
        DDCSwitcher.setInput(consoleMacInput)
        deactivateConsoleMode()
    }

    @objc private func openApp() {
        NSApp.activate(ignoringOtherApps: true)
        NSApp.windows.first { $0.isVisible }?.makeKeyAndOrderFront(nil)
    }
}

// MARK: - Recent Games Grid View (für NSMenu)

class RecentGamesMenuView: NSView {
    private let games: [Game]
    private let cellSize: CGFloat = 48
    private let padding: CGFloat = 8
    private let columns = 8

    init(games: [Game]) {
        self.games = games
        let rows = Int(ceil(Double(games.count) / Double(8)))
        let w = CGFloat(8) * 48 + CGFloat(9) * 8
        let h = CGFloat(rows) * 48 + CGFloat(rows + 1) * 8
        super.init(frame: NSRect(x: 0, y: 0, width: w, height: h + 8))
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        for (i, game) in games.enumerated() {
            let col = i % columns
            let row = i / columns
            let x = padding + CGFloat(col) * (cellSize + padding)
            let y = frame.height - padding - CGFloat(row + 1) * cellSize - CGFloat(row) * padding - 8

            let cell = GameCoverCell(game: game, size: cellSize)
            cell.frame = NSRect(x: x, y: y, width: cellSize, height: cellSize)
            addSubview(cell)
        }
    }
}

class GameCoverCell: NSView {
    private let game: Game

    init(game: Game, size: CGFloat) {
        self.game = game
        super.init(frame: NSRect(x: 0, y: 0, width: size, height: size))
        setup()
    }

    required init?(coder: NSCoder) { fatalError() }

    private func setup() {
        wantsLayer = true
        layer?.cornerRadius = 6
        layer?.masksToBounds = true

        let imgView = NSImageView(frame: bounds)
        imgView.imageScaling = .scaleProportionallyUpOrDown
        if let path = game.coverImagePath, let img = NSImage(contentsOfFile: path) {
            imgView.image = img
        } else {
            imgView.image = NSImage(systemSymbolName: "gamecontroller", accessibilityDescription: nil)
        }
        addSubview(imgView)

        // Tooltip mit Spielname
        toolTip = game.name
    }

    override func mouseUp(with event: NSEvent) {
        // Menü schließen und Spiel fokussieren
        NSApp.activate(ignoringOtherApps: true)
        // Notification um Spiel in der App zu öffnen
        NotificationCenter.default.post(name: .init("OpenGame"), object: game)
        // Menü schließen
        if let menu = enclosingMenuItem?.menu { menu.cancelTracking() }
    }
}
