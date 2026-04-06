import SwiftUI
import WebKit
import AppKit

// MARK: - Chat Service

enum ChatService: String, CaseIterable, Identifiable {
    case element  = "element"
    case steam    = "steam"
    case discord  = "discord"
    case signal   = "signal"
    case whatsapp = "whatsapp"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .element:  return "Element"
        case .steam:    return "Steam Chat"
        case .discord:  return "Discord"
        case .signal:   return "Signal"
        case .whatsapp: return "WhatsApp"
        }
    }

    var color: Color {
        switch self {
        case .element:  return Color(red: 0.0,  green: 1.0,  blue: 0.5)
        case .steam:    return Color(red: 0.75, green: 0.75, blue: 0.75)
        case .discord:  return Color(red: 0.55, green: 0.40, blue: 0.90)
        case .signal:   return Color(red: 0.20, green: 0.55, blue: 0.95)
        case .whatsapp: return Color(red: 0.07, green: 0.53, blue: 0.25)
        }
    }

    var webURL: String {
        switch self {
        case .element:  return "https://app.element.io"
        case .steam:    return "https://steamcommunity.com/chat"
        case .discord:  return "https://discord.com/app"
        case .signal:   return "https://app.signal.org"
        case .whatsapp: return "https://web.whatsapp.com"
        }
    }

    var appPath: String {
        switch self {
        case .element:  return "/Applications/Element.app"
        case .steam:    return "/Applications/Steam.app"
        case .discord:  return "/Applications/Discord.app"
        case .signal:   return "/Applications/Signal.app"
        case .whatsapp: return "/Applications/WhatsApp.app"
        }
    }

    var appInstalled: Bool { FileManager.default.fileExists(atPath: appPath) }
    var icon: String { "bubble.left.fill" }
}

// MARK: - Chat Window Manager

class ChatWindowManager {
    static let shared = ChatWindowManager()
    private var windows: [ChatService: NSWindow] = [:]

    func toggle(_ service: ChatService) {
        let mode = AppSettings.shared.chatServiceMode[service.rawValue] ?? "webview"
        if mode == "app" {
            NSWorkspace.shared.openApplication(
                at: URL(fileURLWithPath: service.appPath),
                configuration: NSWorkspace.OpenConfiguration()
            )
            return
        }
        if let win = windows[service], win.isVisible {
            win.close()
            windows.removeValue(forKey: service)
        } else {
            openWebView(service)
        }
    }

    func isOpen(_ service: ChatService) -> Bool {
        let mode = AppSettings.shared.chatServiceMode[service.rawValue] ?? "webview"
        if mode == "app" { return false }
        return windows[service]?.isVisible == true
    }

    private func openWebView(_ service: ChatService) {
        let win = RoguePopupWindow(width: 960, height: 780, title: service.label)
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        win.embedWebView(wv)
        if let url = URL(string: service.webURL) { wv.load(URLRequest(url: url)) }
        win.center()
        win.makeKeyAndOrderFront(nil)
        win.delegate = WindowCloseDelegate(onClose: { [weak self] in self?.windows.removeValue(forKey: service) })
        windows[service] = win
    }
}

class WindowCloseDelegate: NSObject, NSWindowDelegate {
    let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}

// MARK: - Chat Icon Button

struct ChatIconButton: View {
    let service: ChatService
    @State private var isOpen = false

    var body: some View {
        Button(action: {
            ChatWindowManager.shared.toggle(service)
            isOpen = ChatWindowManager.shared.isOpen(service)
        }) {
            ZStack {
                Circle()
                    .fill(isOpen ? service.color : service.color.opacity(0.18))
                    .frame(width: 26, height: 26)
                Image(systemName: service.icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(isOpen ? .black.opacity(0.7) : service.color)
            }
        }
        .buttonStyle(.plain)
        .help(service.label)
    }
}

// MARK: - Chat Settings Tab

struct ChatSettingsView: View {
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                GroupBox {
                    HStack(spacing: 8) {
                        Image(systemName: "info.circle").foregroundColor(.accentColor)
                        Text("Aktivierte Dienste erscheinen als farbige Icons neben deinem Namen in der Navigationsleiste.")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)
                }

                ForEach(ChatService.allCases) { service in
                    ChatServiceRow(service: service, settings: settings)
                }
            }
            .padding(24)
        }
    }
}

struct ChatServiceRow: View {
    let service: ChatService
    @ObservedObject var settings: AppSettings

    private var isEnabled: Bool { settings.chatEnabledServices[service.rawValue] ?? false }
    private var mode: String { settings.chatServiceMode[service.rawValue] ?? "webview" }

    var body: some View {
        GroupBox {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(isEnabled ? service.color : service.color.opacity(0.15))
                            .frame(width: 34, height: 34)
                        Image(systemName: service.icon)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(isEnabled ? .black.opacity(0.6) : service.color.opacity(0.5))
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(service.label)
                            .font(.system(size: 13, weight: .semibold))
                        Text(isEnabled ? "Aktiv" : "Deaktiviert")
                            .font(.system(size: 11))
                            .foregroundColor(isEnabled ? .green : .secondary)
                    }
                    Spacer()
                    Toggle("", isOn: Binding(
                        get: { isEnabled },
                        set: { val in
                            settings.chatEnabledServices[service.rawValue] = val
                            settings.save()
                        }
                    )).labelsHidden()
                }

                if isEnabled {
                    Divider()
                    // Modus-Picker
                    HStack(spacing: 0) {
                        modePill("webview", label: "WebView", icon: "globe")
                        modePill("app",     label: "Desktop App", icon: "desktopcomputer")
                    }
                    .background(Color.secondary.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    if mode == "app" {
                        HStack(spacing: 6) {
                            Image(systemName: service.appInstalled ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundColor(service.appInstalled ? .green : .red)
                                .font(.system(size: 11))
                            Text(service.appInstalled
                                 ? "\(service.label) ist installiert"
                                 : "Nicht gefunden: \(service.appPath)")
                                .font(.system(size: 11))
                                .foregroundColor(service.appInstalled ? .secondary : .red)
                        }
                    }
                }
            }
            .padding(4)
        }
    }

    @ViewBuilder
    private func modePill(_ m: String, label: String, icon: String) -> some View {
        Button(action: {
            settings.chatServiceMode[service.rawValue] = m
            settings.save()
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon).font(.system(size: 11))
                Text(label).font(.system(size: 12, weight: .medium))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(mode == m ? service.color.opacity(0.2) : Color.clear)
            .foregroundColor(mode == m ? service.color : .secondary)
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
