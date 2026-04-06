import SwiftUI

struct EpicFreeGame: Identifiable {
    let id: String
    let title: String
    let description: String
    let coverURL: String?
    let originalPrice: String
    let claimURL: String
}

class EpicFreeGamesService: ObservableObject {
    static let shared = EpicFreeGamesService()
    @Published var games: [EpicFreeGame] = []
    @Published var isLoading = false
    @Published var lastError: String? = nil

    private init() {}

    func fetch() {
        isLoading = true
        lastError = nil
        guard let url = URL(string: "https://store-site-backend-static.ak.epicgames.com/freeGamesPromotions?locale=de&country=DE&allowCountries=DE") else {
            isLoading = false; return
        }
        URLSession.shared.dataTask(with: url) { data, _, error in
            DispatchQueue.main.async {
                self.isLoading = false
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let catalog = (json["data"] as? [String: Any])?["Catalog"] as? [String: Any],
                      let searchStore = (catalog["searchStore"] as? [String: Any])?["elements"] as? [[String: Any]]
                else {
                    self.lastError = "Keine Daten von Epic erhalten"
                    return
                }

                self.games = searchStore.compactMap { element -> EpicFreeGame? in
                    guard let title = element["title"] as? String else { return nil }

                    // Nur aktuell kostenlose Spiele
                    let promotions = (element["promotions"] as? [String: Any])?["promotionalOffers"] as? [[String: Any]] ?? []
                    let hasActiveOffer = promotions.first.flatMap {
                        ($0["promotionalOffers"] as? [[String: Any]])?.first
                    }.flatMap { offer -> Bool? in
                        guard let discount = (offer["discountSetting"] as? [String: Any])?["discountPercentage"] as? Int else { return nil }
                        return discount == 0
                    } ?? false
                    guard hasActiveOffer else { return nil }

                    let desc = element["description"] as? String ?? ""
                    let id = element["id"] as? String ?? UUID().uuidString

                    // Cover
                    var coverURL: String? = nil
                    if let images = element["keyImages"] as? [[String: Any]] {
                        let preferred = ["OfferImageTall", "Thumbnail", "DieselStoreFrontWide", "OfferImageWide"]
                        for type_ in preferred {
                            if let img = images.first(where: { ($0["type"] as? String) == type_ }),
                               let urlStr = img["url"] as? String {
                                coverURL = urlStr; break
                            }
                        }
                        if coverURL == nil { coverURL = images.first?["url"] as? String }
                    }

                    // Originalpreis
                    let price = ((element["price"] as? [String: Any])?["totalPrice"] as? [String: Any])?["fmtPrice"] as? [String: Any]
                    let originalPrice = price?["originalPrice"] as? String ?? "Kostenlos"

                    // Claim URL
                    let slug = (element["catalogNs"] as? [String: Any]).flatMap {
                        ($0["mappings"] as? [[String: Any]])?.first?["pageSlug"] as? String
                    } ?? (element["productSlug"] as? String ?? "")
                    let claimURL = "https://store.epicgames.com/de/p/\(slug)"

                    return EpicFreeGame(id: id, title: title, description: desc,
                                       coverURL: coverURL, originalPrice: originalPrice, claimURL: claimURL)
                }

                if self.games.isEmpty {
                    self.lastError = "Aktuell keine kostenlosen Spiele gefunden"
                }
            }
        }.resume()
    }
}

struct EpicFreeGamesView: View {
    @ObservedObject private var service = EpicFreeGamesService.shared
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "gift.fill")
                    .foregroundColor(Color.rogueGold)
                Text("Kostenlose Spiele bei Amazon und Epic Games")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
                if service.isLoading {
                    ProgressView().frame(width: 20, height: 20)
                } else {
                    Button(action: { service.fetch() }) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 11))
                    }
                    .buttonStyle(.plain)
                    .foregroundColor(.secondary)
                }
            }

            if let error = service.lastError {
                Text(error).font(.system(size: 12)).foregroundColor(.secondary)
            } else if service.games.isEmpty && !service.isLoading {
                Text("Lade…").font(.system(size: 12)).foregroundColor(.secondary)
            } else {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(service.games) { game in
                        EpicGameRow(game: game)
                            .frame(maxWidth: .infinity)
                    }
                    PrimeGamingCard()
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(20)
        .background(RoundedRectangle(cornerRadius: 16)
            .fill(Color(NSColor.windowBackgroundColor).opacity(0.75)))
        .onAppear { if service.games.isEmpty { service.fetch() } }
    }
}

struct EpicGameRow: View {
    let game: EpicFreeGame
    @ObservedObject private var settings = AppSettings.shared

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Cover hochkant
            AsyncImage(url: URL(string: game.coverURL ?? "")) { phase in
                switch phase {
                case .success(let img): img.resizable().aspectRatio(contentMode: .fill)
                default:
                    Color.secondary.opacity(0.15)
                        .overlay(Image(systemName: "gamecontroller").foregroundColor(.secondary))
                }
            }
            .frame(width: 80, height: 107)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .top) {
                    Text(game.title)
                        .font(.system(size: 13, weight: .semibold))
                        .lineLimit(2)
                    Spacer()
                    HStack(spacing: 4) {
                        Text(game.originalPrice)
                            .font(.system(size: 11))
                            .strikethrough()
                            .foregroundColor(.secondary)
                        Text("Kostenlos")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.green)
                    }
                    .fixedSize()
                }
                Text(game.description)
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: { openClaim() }) {
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.right.circle.fill")
                        Text("Jetzt claimen")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color.rogueGold)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 8)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func openClaim() {
        let s = AppSettings.shared
        switch s.epicClaimMode {
        case "webview":
            let urlStr = s.epicClaimURL.isEmpty ? game.claimURL : s.epicClaimURL
            EpicWebViewWindowController.open(urlString: urlStr)
        case "webhook":
            guard !s.epicClaimWebhookURL.isEmpty,
                  let url = URL(string: s.epicClaimWebhookURL) else { return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            URLSession.shared.dataTask(with: req).resume()
        case "browser":
            let target = s.epicClaimURL.isEmpty ? game.claimURL : s.epicClaimURL
            if let url = URL(string: target) { NSWorkspace.shared.open(url) }
        default: // "moonlight"
            let appName = s.gameLaunchers.first { $0.id == "epic" }?.sunshineAppName ?? "Epic Games Launcher"
            let plist = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
            let ip = (NSDictionary(contentsOfFile: plist) as? [String: Any])?["hosts.1.localaddress"] as? String ?? s.pcIPAddress
            let bins = ["/Applications/Moonlight.app/Contents/MacOS/Moonlight",
                        NSHomeDirectory() + "/Applications/Moonlight.app/Contents/MacOS/Moonlight"]
            if let path = bins.first(where: { FileManager.default.fileExists(atPath: $0) }) {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: path)
                proc.arguments = ["stream", ip, appName, "--display-mode", "windowed"]
                try? proc.run()
            } else {
                let target = s.epicClaimURL.isEmpty ? game.claimURL : s.epicClaimURL
                if let url = URL(string: target) { NSWorkspace.shared.open(url) }
            }
        }
    }
}

// MARK: - Prime Gaming & GOG Card

struct PrimeGamingCard: View {
    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            // Cover
            Group {
                if let img = NSImage(named: "PrimeGamingCover") {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } else {
                    LinearGradient(
                        colors: [Color(red: 0.1, green: 0.05, blue: 0.25),
                                 Color(red: 0.05, green: 0.03, blue: 0.15)],
                        startPoint: .top, endPoint: .bottom
                    )
                    .overlay(
                        VStack(spacing: 4) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 28))
                                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
                            Text("prime\ngaming")
                                .font(.system(size: 11, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(.white)
                        }
                    )
                }
            }
            .frame(width: 80, height: 107)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Info
            VStack(alignment: .leading, spacing: 5) {
                Text("Prime Gaming & GOG")
                    .font(.system(size: 13, weight: .semibold))
                    .lineLimit(2)
                Text("Claime deine kostenlosen Spiele bei Amazon Prime Gaming und im GOG Store.")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 4)
                Button(action: {
                    PrimeGOGWindowController.open()
                }) {
                    HStack(spacing: 4) {
                        Image(systemName: "crown.fill")
                        Text("Prime Gaming & GOG öffnen")
                    }
                    .font(.system(size: 11, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundColor(Color(red: 0.6, green: 0.4, blue: 1.0))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.trailing, 8)
        }
        .padding(10)
        .background(Color.secondary.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
