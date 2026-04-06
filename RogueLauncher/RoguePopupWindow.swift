import AppKit
import WebKit

// Popup-Fensterstil nach Homebox-Muster:
// titlebarAppearsTransparent + passender backgroundColor = nahtloser Look

class RoguePopupWindow: NSWindow {

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    private let bgColor = NSColor(red: 0.09, green: 0.09, blue: 0.11, alpha: 1.0)

    init(width: CGFloat, height: CGFloat, title: String = "") {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: width, height: height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        self.title = title
        titlebarAppearsTransparent = true
        backgroundColor = bgColor
        isReleasedWhenClosed = false
    }

    // Einzelne WebView einbetten
    func embedWebView(_ wv: WKWebView) {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.backgroundColor = bgColor.cgColor
        wv.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(wv)
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: container.topAnchor),
            wv.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: container.bottomAnchor),
        ])
        contentView = container
    }
}
