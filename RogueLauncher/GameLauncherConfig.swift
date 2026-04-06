import SwiftUI

struct GameLauncherConfig: Identifiable, Codable {
    var id: String
    var name: String
    var sunshineAppName: String
    var enabled: Bool = true
    var iconName: String
    var colorHex: String
    var registryKey: String = ""   // Registry-Pfad auf dem Host, z.B. HKLM\SOFTWARE\Valve\Steam

    var color: Color {
        Color(hex: colorHex) ?? .blue
    }

    static let defaults: [GameLauncherConfig] = [
        GameLauncherConfig(id: "steam",    name: "Steam",           sunshineAppName: "Steam Big Picture",   iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\Valve\\Steam"),
        GameLauncherConfig(id: "epic",     name: "Epic Games",      sunshineAppName: "Epic Games Launcher", iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\Epic Games\\EpicGamesLauncher"),
        GameLauncherConfig(id: "gog",      name: "GOG Galaxy",      sunshineAppName: "GalaxyClient",        iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\GOG.com\\GalaxyClient"),
        GameLauncherConfig(id: "ea",       name: "EA App",          sunshineAppName: "EA App",              iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\Electronic Arts\\EA Desktop"),
        GameLauncherConfig(id: "ubisoft",  name: "Ubisoft Connect", sunshineAppName: "Ubisoft Connect",     iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\Ubisoft\\Launcher"),
        GameLauncherConfig(id: "battlenet",name: "Battle.net",      sunshineAppName: "Battle.net",          iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\Blizzard Entertainment\\Battle.net"),
        GameLauncherConfig(id: "amazon",   name: "Amazon Games",    sunshineAppName: "Amazon Games",        iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\Amazon\\Amazon Games"),
        GameLauncherConfig(id: "itchio",   name: "itch.io",         sunshineAppName: "itch.io",             iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: "HKLM\\SOFTWARE\\itch"),
        GameLauncherConfig(id: "heroic",   name: "Heroic Launcher", sunshineAppName: "Heroic",              iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: ""),
        GameLauncherConfig(id: "lutris",   name: "Lutris",          sunshineAppName: "Lutris",              iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: ""),
        GameLauncherConfig(id: "steam-linux", name: "Steam (Linux)",sunshineAppName: "steam",   enabled: false, iconName: "gamecontroller.fill", colorHex: "#C8282D", registryKey: ""),
    ]
}

// MARK: - Color Hex Extension
extension Color {
    init?(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        default:
            return nil
        }
        self.init(red: Double(r)/255, green: Double(g)/255, blue: Double(b)/255)
    }

    var toHex: String {
        let ui = NSColor(self).usingColorSpace(.sRGB) ?? .black
        return String(format: "#%02X%02X%02X",
            Int(ui.redComponent * 255),
            Int(ui.greenComponent * 255),
            Int(ui.blueComponent * 255))
    }
}
