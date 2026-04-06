import Foundation
import AppKit

struct LocalApp: Identifiable {
    let id = UUID()
    let name: String
    let bundleID: String
    let path: String
    let icon: NSImage?
}

class LocalAppImporter {

    /// Liest alle .app-Bundles aus /Applications und ~/Applications
    static func scanApplications() -> [LocalApp] {
        var apps: [LocalApp] = []
        let fm = FileManager.default
        let dirs = [
            "/Applications",
            NSHomeDirectory() + "/Applications"
        ]
        for dir in dirs {
            guard let contents = try? fm.contentsOfDirectory(atPath: dir) else { continue }
            for item in contents where item.hasSuffix(".app") {
                let path = "\(dir)/\(item)"
                let name = item.replacingOccurrences(of: ".app", with: "")
                let bundleID = Bundle(path: path)?.bundleIdentifier ?? path
                let icon = NSWorkspace.shared.icon(forFile: path)
                apps.append(LocalApp(name: name, bundleID: bundleID, path: path, icon: icon))
            }
        }
        return apps.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
