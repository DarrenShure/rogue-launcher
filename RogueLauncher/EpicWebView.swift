import SwiftUI
import WebKit
import AppKit

// MARK: - Nav Action Helper

class WebNavHelper: NSObject {
    weak var webView: WKWebView?
    let homeURL: String

    init(webView: WKWebView, homeURL: String) {
        self.webView = webView
        self.homeURL = homeURL
    }

    @objc func goBack()    { webView?.goBack() }
    @objc func goForward() { webView?.goForward() }
    @objc func reload()    { webView?.reload() }
    @objc func goHome()    { if let u = URL(string: homeURL) { webView?.load(URLRequest(url: u)) } }
}

// MARK: - Einzelner WebView (Epic)

class EpicWebViewWindowController: NSObject, WKNavigationDelegate, NSWindowDelegate {
    static let shared = EpicWebViewWindowController()
    private var window: NSWindow?
    private var webView: WKWebView?
    private var navHelper: WebNavHelper?

    static func open(urlString: String) {
        shared.show(urlString: urlString)
    }

    private func show(urlString: String) {
        if let w = window, w.isVisible {
            w.makeKeyAndOrderFront(nil)
            if let url = URL(string: urlString) { webView?.load(URLRequest(url: url)) }
            return
        }
        let config = WKWebViewConfiguration()
        config.websiteDataStore = .default()
        let wv = WKWebView(frame: .zero, configuration: config)
        wv.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) { wv.underPageBackgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1) }
        wv.navigationDelegate = self
        wv.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        self.webView = wv
        let helper = WebNavHelper(webView: wv, homeURL: urlString)
        self.navHelper = helper

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 750),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered, defer: false)
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        win.title = "Epic Games Store"
        win.isReleasedWhenClosed = false
        win.center()
        win.setFrameAutosaveName("EpicWebWindow")
        win.delegate = self
        self.window = win

        let container = NSView()
        win.contentView = container

        let header = buildHeader(helper: helper, title: "Epic Store")
        header.translatesAutoresizingMaskIntoConstraints = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(header)
        container.addSubview(wv)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: container.topAnchor),
            header.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 36),
            wv.topAnchor.constraint(equalTo: header.bottomAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        if let url = URL(string: urlString) { wv.load(URLRequest(url: url)) }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        window?.title = webView.title ?? "Epic Games Store"
    }

    func windowWillClose(_ notification: Notification) {
        webView?.stopLoading()
        window = nil
        webView = nil
    }
}

// MARK: - Split View: Prime Gaming + GOG

class PrimeGOGWindowController: NSObject, NSWindowDelegate {
    static let shared = PrimeGOGWindowController()
    private var window: NSWindow?
    private var leftHelper: WebNavHelper?
    private var rightHelper: WebNavHelper?

    static func open() {
        shared.show()
    }

    private func show() {
        if let w = window, w.isVisible { w.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true); return }

        let ua = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"

        let leftConfig = WKWebViewConfiguration(); leftConfig.websiteDataStore = .default()
        let left = WKWebView(frame: .zero, configuration: leftConfig)
        left.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) { left.underPageBackgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1) }
        left.customUserAgent = ua
        let lHelper = WebNavHelper(webView: left, homeURL: "https://luna.amazon.com/claims/home")
        self.leftHelper = lHelper

        let rightConfig = WKWebViewConfiguration(); rightConfig.websiteDataStore = .default()
        let right = WKWebView(frame: .zero, configuration: rightConfig)
        right.setValue(false, forKey: "drawsBackground")
        if #available(macOS 12.0, *) { right.underPageBackgroundColor = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1) }
        right.customUserAgent = ua
        let rHelper = WebNavHelper(webView: right, homeURL: "https://www.gog.com/de/")
        self.rightHelper = rHelper

        let win = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1440, height: 820),
                           styleMask: [.titled, .closable, .miniaturizable, .resizable],
                           backing: .buffered, defer: false)
        win.titlebarAppearsTransparent = true
        win.isMovableByWindowBackground = true
        win.backgroundColor = NSColor(red: 0.08, green: 0.08, blue: 0.10, alpha: 1.0)
        win.title = "🎮 Prime Gaming  ⟷  🎁 GOG"
        win.isReleasedWhenClosed = false
        win.center()
        win.setFrameAutosaveName("PrimeGOGWindow")
        win.delegate = self
        self.window = win

        let container = NSView()
        win.contentView = container

        let leftPanel  = buildPanel(webView: left,  helper: lHelper, label: "🎮 Prime Gaming",
                                    color: NSColor(red: 0.5, green: 0.3, blue: 1.0, alpha: 1))
        let rightPanel = buildPanel(webView: right, helper: rHelper, label: "🎁 GOG",
                                    color: NSColor(red: 0.4, green: 0.75, blue: 0.3, alpha: 1))

        let divider = NSView(); divider.wantsLayer = true
        divider.layer?.backgroundColor = NSColor.separatorColor.cgColor
        divider.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(leftPanel); container.addSubview(divider); container.addSubview(rightPanel)
        NSLayoutConstraint.activate([
            leftPanel.topAnchor.constraint(equalTo: container.topAnchor),
            leftPanel.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            leftPanel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            leftPanel.widthAnchor.constraint(equalTo: container.widthAnchor, multiplier: 0.5, constant: -0.5),

            divider.topAnchor.constraint(equalTo: container.topAnchor),
            divider.leadingAnchor.constraint(equalTo: leftPanel.trailingAnchor),
            divider.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            divider.widthAnchor.constraint(equalToConstant: 1),

            rightPanel.topAnchor.constraint(equalTo: container.topAnchor),
            rightPanel.leadingAnchor.constraint(equalTo: divider.trailingAnchor),
            rightPanel.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            rightPanel.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])

        if let u = URL(string: "https://luna.amazon.com/claims/home") { left.load(URLRequest(url: u)) }
        if let u = URL(string: "https://www.gog.com/de/") { right.load(URLRequest(url: u)) }

        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func buildPanel(webView: WKWebView, helper: WebNavHelper, label: String, color: NSColor) -> NSView {
        let panel = NSView(); panel.translatesAutoresizingMaskIntoConstraints = false
        let header = buildHeader(helper: helper, title: label, color: color)
        header.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        panel.addSubview(header); panel.addSubview(webView)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: panel.topAnchor),
            header.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 36),
            webView.topAnchor.constraint(equalTo: header.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: panel.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: panel.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: panel.bottomAnchor),
        ])
        return panel
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
        leftHelper = nil
        rightHelper = nil
    }
}

// MARK: - Shared header builder

func buildHeader(helper: WebNavHelper, title: String, color: NSColor = .labelColor) -> NSView {
    let bar = NSView(); bar.wantsLayer = true
    bar.layer?.backgroundColor = NSColor.windowBackgroundColor.cgColor

    func makeBtn(_ t: String, sel: Selector) -> NSButton {
        let b = NSButton(title: t, target: helper, action: sel)
        b.bezelStyle = NSButton.BezelStyle.rounded
        b.translatesAutoresizingMaskIntoConstraints = false
        return b
    }

    let back = makeBtn("◀", sel: #selector(WebNavHelper.goBack))
    let fwd  = makeBtn("▶", sel: #selector(WebNavHelper.goForward))
    let rel  = makeBtn("↻", sel: #selector(WebNavHelper.reload))
    let home = makeBtn("⌂", sel: #selector(WebNavHelper.goHome))

    let lbl = NSTextField(labelWithString: title)
    lbl.font = .systemFont(ofSize: 12, weight: .semibold)
    lbl.textColor = color
    lbl.translatesAutoresizingMaskIntoConstraints = false

    [back, fwd, rel, home, lbl].forEach { bar.addSubview($0) }

    let btns = [back, fwd, rel, home]
    NSLayoutConstraint.activate([
        back.leadingAnchor.constraint(equalTo: bar.leadingAnchor, constant: 8),
        back.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        back.widthAnchor.constraint(equalToConstant: 28),
    ] + zip(btns, btns.dropFirst()).flatMap { prev, next -> [NSLayoutConstraint] in [
        next.leadingAnchor.constraint(equalTo: prev.trailingAnchor, constant: 4),
        next.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
        next.widthAnchor.constraint(equalToConstant: 28),
    ]} + [
        lbl.leadingAnchor.constraint(equalTo: home.trailingAnchor, constant: 10),
        lbl.centerYAnchor.constraint(equalTo: bar.centerYAnchor),
    ])
    return bar
}
