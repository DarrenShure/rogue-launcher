import Foundation
import AppKit

struct GameMetadata {
    var description: String
    var genre: String
    var releaseYear: String
    var ageRating: String = ""
    var rating: Double? = nil        // IGDB 0–100
    var coverURL: String?
    var backgroundURL: String?
    var screenshotURLs: [String] = []
    var source: String
}

class GameMetadataService {

    private static var igdbToken: String? = nil
    private static var igdbTokenExpiry: Date = .distantPast
    private static var igdbClientID: String { AppSettings.shared.igdbClientID }
    private static var igdbClientSecret: String { AppSettings.shared.igdbClientSecret }

    /// Reihenfolge: IGDB → RAWG → SteamGridDB → Steam
    static func fetch(for gameName: String, completion: @escaping (GameMetadata?) -> Void) {
        fetchFromIGDB(gameName: gameName) { result in
            if var r = result {
                // Steam für: Altersfreigabe + Deutsche Beschreibung
                fetchFromSteam(gameName: gameName) { steam in
                    r.ageRating = steam?.ageRating.isEmpty == false ? steam!.ageRating : "Ohne Altersbeschränkung"
                    if let steamDesc = steam?.description, !steamDesc.isEmpty {
                        r.description = steamDesc   // Steam-Beschreibung ist auf Deutsch
                    }
                    completion(r)
                }
                return
            }
            fetchFromRAWG(gameName: gameName) { result in
                if var r = result {
                    if r.ageRating.isEmpty {
                        fetchFromSteam(gameName: gameName) { steam in
                            r.ageRating = steam?.ageRating.isEmpty == false ? steam!.ageRating : "Ohne Altersbeschränkung"
                            if let steamDesc = steam?.description, !steamDesc.isEmpty { r.description = steamDesc }
                            completion(r)
                        }
                    } else { completion(r) }
                    return
                }
                fetchCoverFromSteamGridDB(gameName: gameName) { coverURL in
                    fetchFromSteam(gameName: gameName) { steamResult in
                        if var r = steamResult {
                            if let sgdbCover = coverURL { r.coverURL = sgdbCover; r.source = "SteamGridDB + Steam"; r.backgroundURL = nil }
                            if r.ageRating.isEmpty { r.ageRating = "Ohne Altersbeschränkung" }
                            completion(r)
                        } else if let coverURL = coverURL {
                            completion(GameMetadata(description: "", genre: "", releaseYear: "", ageRating: "Ohne Altersbeschränkung", coverURL: coverURL, backgroundURL: nil, source: "SteamGridDB"))
                        } else {
                            completion(nil)
                        }
                    }
                }
            }
        }
    }


    // MARK: - IGDB

    static func fetchFromIGDB(gameName: String, completion: @escaping (GameMetadata?) -> Void) {
        guard !igdbClientID.isEmpty, !igdbClientSecret.isEmpty else { completion(nil); return }
        getIGDBToken { token in
            guard let token = token else { completion(nil); return }

            guard let url = URL(string: "https://api.igdb.com/v4/games") else { completion(nil); return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.httpBody = """
            search "\(gameName.replacingOccurrences(of: "\"", with: "\\\""))";
            fields name,summary,genres.name,first_release_date,cover.image_id,artworks.image_id,screenshots.image_id,rating;
            limit 1;
            """.data(using: .utf8)

            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data = data,
                      let games = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let game = games.first
                else { completion(nil); return }

                let desc = game["summary"] as? String ?? ""
                let genres = (game["genres"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.prefix(2).joined(separator: ", ") ?? ""
                var year = ""
                if let ts = game["first_release_date"] as? Int {
                    let date = Date(timeIntervalSince1970: TimeInterval(ts))
                    year = Calendar.current.component(.year, from: date).description
                }
                let igdbRating = game["rating"] as? Double

                var coverURL: String? = nil
                if let coverID = (game["cover"] as? [String: Any])?["image_id"] as? String {
                    coverURL = "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/\(coverID).jpg"
                }
                var backgroundURL: String? = nil
                if let artworks = game["artworks"] as? [[String: Any]],
                   let artID = artworks.first?["image_id"] as? String {
                    backgroundURL = "https://images.igdb.com/igdb/image/upload/t_1080p/\(artID).jpg"
                } else if let screenshots = game["screenshots"] as? [[String: Any]],
                          let ssID = screenshots.first?["image_id"] as? String {
                    backgroundURL = "https://images.igdb.com/igdb/image/upload/t_1080p/\(ssID).jpg"
                }

                // Screenshot-Wall: bis zu 9 Screenshots
                let screenshotURLs: [String] = (game["screenshots"] as? [[String: Any]] ?? [])
                    .prefix(9)
                    .compactMap { ($0["image_id"] as? String).map { "https://images.igdb.com/igdb/image/upload/t_screenshot_big/\($0).jpg" } }

                completion(GameMetadata(description: desc, genre: genres, releaseYear: year, ageRating: "", rating: igdbRating, coverURL: coverURL, backgroundURL: backgroundURL, screenshotURLs: screenshotURLs, source: "IGDB"))
            }.resume()
        }
    }

    static func invalidateToken() {
        igdbToken = nil
        igdbTokenExpiry = .distantPast
    }

    private static func getIGDBToken(completion: @escaping (String?) -> Void) {
        // Token noch gültig?
        if let token = igdbToken, Date() < igdbTokenExpiry {
            completion(token); return
        }
        guard let url = URL(string: "https://id.twitch.tv/oauth2/token?client_id=\(igdbClientID)&client_secret=\(igdbClientSecret)&grant_type=client_credentials") else {
            completion(nil); return
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let token = json["access_token"] as? String,
                  let expiresIn = json["expires_in"] as? Int
            else { completion(nil); return }
            igdbToken = token
            igdbTokenExpiry = Date().addingTimeInterval(TimeInterval(expiresIn - 60))
            completion(token)
        }.resume()
    }

    // MARK: - IGDB Search (mehrere Ergebnisse)

    struct IGDBSearchResult: Identifiable {
        let id: Int
        let name: String
        let coverURL: String?
        let year: String
    }

    static func searchIGDB(query: String, completion: @escaping ([IGDBSearchResult]) -> Void) {
        guard !igdbClientID.isEmpty, !igdbClientSecret.isEmpty else { completion([]); return }
        getIGDBToken { token in
            guard let token = token else { completion([]); return }
            guard let url = URL(string: "https://api.igdb.com/v4/games") else { completion([]); return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            let safe = query.replacingOccurrences(of: "\"", with: "\\\"")
            req.httpBody = """
            search "\(safe)";
            fields name,cover.image_id,first_release_date;
            limit 20;
            """.data(using: .utf8)

            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data = data,
                      let games = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                else { completion([]); return }

                let results: [IGDBSearchResult] = games.compactMap { game in
                    guard let id = game["id"] as? Int,
                          let name = game["name"] as? String else { return nil }
                    var coverURL: String? = nil
                    if let coverID = (game["cover"] as? [String: Any])?["image_id"] as? String {
                        coverURL = "https://images.igdb.com/igdb/image/upload/t_cover_small/\(coverID).jpg"
                    }
                    var year = ""
                    if let ts = game["first_release_date"] as? Int {
                        year = Calendar.current.component(.year, from: Date(timeIntervalSince1970: TimeInterval(ts))).description
                    }
                    return IGDBSearchResult(id: id, name: name, coverURL: coverURL, year: year)
                }

                if !results.isEmpty { completion(results); return }

                // Fallback: where name ~ (case-insensitive prefix match)
                var req2 = URLRequest(url: url)
                req2.httpMethod = "POST"
                req2.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req2.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
                req2.setValue("application/json", forHTTPHeaderField: "Accept")
                let safeLower = query.lowercased().replacingOccurrences(of: "\"", with: "\\\"")
                req2.httpBody = """
                fields name,cover.image_id,first_release_date;
                where name ~ *"\(safeLower)"*;
                limit 20;
                """.data(using: .utf8)
                URLSession.shared.dataTask(with: req2) { data2, _, _ in
                    guard let data2 = data2,
                          let games2 = try? JSONSerialization.jsonObject(with: data2) as? [[String: Any]]
                    else { completion([]); return }
                    let results2: [IGDBSearchResult] = games2.compactMap { game in
                        guard let id = game["id"] as? Int,
                              let name = game["name"] as? String else { return nil }
                        var coverURL: String? = nil
                        if let coverID = (game["cover"] as? [String: Any])?["image_id"] as? String {
                            coverURL = "https://images.igdb.com/igdb/image/upload/t_cover_small/\(coverID).jpg"
                        }
                        var year = ""
                        if let ts = game["first_release_date"] as? Int {
                            year = Calendar.current.component(.year, from: Date(timeIntervalSince1970: TimeInterval(ts))).description
                        }
                        return IGDBSearchResult(id: id, name: name, coverURL: coverURL, year: year)
                    }
                    completion(results2)
                }.resume()
            }.resume()
        }
    }

    static func fetchFromIGDBbySlug(slug: String, completion: @escaping (IGDBSearchResult?) -> Void) {
        guard !igdbClientID.isEmpty, !igdbClientSecret.isEmpty else { completion(nil); return }
        getIGDBToken { token in
            guard let token = token else { completion(nil); return }
            guard let url = URL(string: "https://api.igdb.com/v4/games") else { completion(nil); return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.httpBody = """
            fields id,name,first_release_date,cover.image_id;
            where slug = "\(slug)";
            limit 1;
            """.data(using: .utf8)
            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data = data,
                      let games = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let game = games.first,
                      let id = game["id"] as? Int,
                      let name = game["name"] as? String
                else { completion(nil); return }
                var year = ""
                if let ts = game["first_release_date"] as? Int {
                    year = Calendar.current.component(.year, from: Date(timeIntervalSince1970: TimeInterval(ts))).description
                }
                var coverURL: String? = nil
                if let coverID = (game["cover"] as? [String: Any])?["image_id"] as? String {
                    coverURL = "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/\(coverID).jpg"
                }
                completion(IGDBSearchResult(id: id, name: name, coverURL: coverURL, year: year))
            }.resume()
        }
    }

    static func fetchFromIGDBbyID(id: Int, completion: @escaping (GameMetadata?) -> Void) {
        guard !igdbClientID.isEmpty, !igdbClientSecret.isEmpty else { completion(nil); return }
        getIGDBToken { token in
            guard let token = token else { completion(nil); return }
            guard let url = URL(string: "https://api.igdb.com/v4/games") else { completion(nil); return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
            req.setValue("application/json", forHTTPHeaderField: "Accept")
            req.httpBody = """
            fields name,summary,genres.name,first_release_date,cover.image_id,artworks.image_id,screenshots.image_id;
            where id = \(id);
            limit 1;
            """.data(using: .utf8)

            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data = data,
                      let games = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let game = games.first
                else { completion(nil); return }

                let desc = game["summary"] as? String ?? ""
                let genres = (game["genres"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.prefix(2).joined(separator: ", ") ?? ""
                var year = ""
                if let ts = game["first_release_date"] as? Int {
                    year = Calendar.current.component(.year, from: Date(timeIntervalSince1970: TimeInterval(ts))).description
                }
                var coverURL: String? = nil
                if let coverID = (game["cover"] as? [String: Any])?["image_id"] as? String {
                    coverURL = "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/\(coverID).jpg"
                }
                var backgroundURL: String? = nil
                if let artworks = game["artworks"] as? [[String: Any]], let artID = artworks.first?["image_id"] as? String {
                    backgroundURL = "https://images.igdb.com/igdb/image/upload/t_1080p/\(artID).jpg"
                } else if let screenshots = game["screenshots"] as? [[String: Any]], let ssID = screenshots.first?["image_id"] as? String {
                    backgroundURL = "https://images.igdb.com/igdb/image/upload/t_1080p/\(ssID).jpg"
                }
                let screenshotURLs: [String] = (game["screenshots"] as? [[String: Any]] ?? [])
                    .compactMap { ($0["image_id"] as? String).map { "https://images.igdb.com/igdb/image/upload/t_screenshot_big/\($0).jpg" } }
                completion(GameMetadata(description: desc, genre: genres, releaseYear: year, ageRating: "", coverURL: coverURL, backgroundURL: backgroundURL, screenshotURLs: screenshotURLs, source: "IGDB"))
            }.resume()
        }
    }



    static func fetchIGDBartworks(for gameName: String, completion: @escaping ([[String: Any]]) -> Void) {
        getIGDBToken { token in
            guard let token = token else { completion([]); return }

            // Erst Game-ID holen
            guard let url = URL(string: "https://api.igdb.com/v4/games") else { completion([]); return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
            let safe = gameName.replacingOccurrences(of: "\"", with: "\\\"")
            req.httpBody = "search \"\(safe)\"; fields id; limit 1;".data(using: .utf8)

            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data = data,
                      let games = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let game = games.first,
                      let gameID = game["id"] as? Int
                else { completion([]); return }

                let group = DispatchGroup()
                var allImages: [[String: Any]] = []

                // Artworks laden
                group.enter()
                if let artURL = URL(string: "https://api.igdb.com/v4/artworks") {
                    var artReq = URLRequest(url: artURL)
                    artReq.httpMethod = "POST"
                    artReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    artReq.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
                    artReq.httpBody = "fields image_id; where game = \(gameID); limit 20;".data(using: .utf8)
                    URLSession.shared.dataTask(with: artReq) { data, _, _ in
                        if let data = data,
                           let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            allImages += items
                        }
                        group.leave()
                    }.resume()
                } else { group.leave() }

                // Screenshots laden
                group.enter()
                if let ssURL = URL(string: "https://api.igdb.com/v4/screenshots") {
                    var ssReq = URLRequest(url: ssURL)
                    ssReq.httpMethod = "POST"
                    ssReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                    ssReq.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
                    ssReq.httpBody = "fields image_id; where game = \(gameID); limit 20;".data(using: .utf8)
                    URLSession.shared.dataTask(with: ssReq) { data, _, _ in
                        if let data = data,
                           let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
                            allImages += items
                        }
                        group.leave()
                    }.resume()
                } else { group.leave() }

                group.notify(queue: .main) {
                    completion(allImages)
                }
            }.resume()
        }
    }

    static func fetchIGDBartworksByID(id: Int, completion: @escaping ([[String: Any]]) -> Void) {
        getIGDBToken { token in
            guard let token = token else { completion([]); return }
            let group = DispatchGroup()
            var allImages: [[String: Any]] = []

            group.enter()
            if let artURL = URL(string: "https://api.igdb.com/v4/artworks") {
                var artReq = URLRequest(url: artURL)
                artReq.httpMethod = "POST"
                artReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                artReq.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
                artReq.httpBody = "fields image_id; where game = \(id); limit 20;".data(using: .utf8)
                URLSession.shared.dataTask(with: artReq) { data, _, _ in
                    if let data = data, let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { allImages += items }
                    group.leave()
                }.resume()
            } else { group.leave() }

            group.enter()
            if let ssURL = URL(string: "https://api.igdb.com/v4/screenshots") {
                var ssReq = URLRequest(url: ssURL)
                ssReq.httpMethod = "POST"
                ssReq.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                ssReq.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
                ssReq.httpBody = "fields image_id; where game = \(id); limit 20;".data(using: .utf8)
                URLSession.shared.dataTask(with: ssReq) { data, _, _ in
                    if let data = data, let items = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] { allImages += items }
                    group.leave()
                }.resume()
            } else { group.leave() }

            group.notify(queue: .main) { completion(allImages) }
        }
    }

    // MARK: - RAWG

    static func fetchFromRAWG(gameName: String, completion: @escaping (GameMetadata?) -> Void) {
        let key = AppSettings.shared.rawgAPIKey
        let query = gameName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? gameName
        var urlStr = "https://api.rawg.io/api/games?search=\(query)&page_size=1"
        if !key.isEmpty { urlStr += "&key=\(key)" }
        guard let url = URL(string: urlStr) else { completion(nil); return }

        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let game = (json["results"] as? [[String: Any]])?.first
            else { completion(nil); return }

            let slug     = game["slug"] as? String ?? ""
            let cover    = game["background_image"] as? String
            let released = game["released"] as? String ?? ""
            let year     = String(released.prefix(4))
            let genres   = (game["genres"] as? [[String: Any]])?.compactMap { $0["name"] as? String }.prefix(2).joined(separator: ", ") ?? ""
            let esrb     = (game["esrb_rating"] as? [String: Any])?["name"] as? String ?? ""
            let ageRating: String
            switch esrb {
            case "Everyone":        ageRating = "Ohne Altersbeschränkung"
            case "Everyone 10+":    ageRating = "Ab 12 Jahren"
            case "Teen":            ageRating = "Ab 12 Jahren"
            case "Mature":          ageRating = "Ab 18 Jahren"
            case "Adults Only":     ageRating = "Ab 18 Jahren"
            default:                ageRating = esrb.isEmpty ? "" : "Ohne Altersbeschränkung"
            }

            var detailURL = "https://api.rawg.io/api/games/\(slug)"
            if !key.isEmpty { detailURL += "?key=\(key)" }
            guard let durl = URL(string: detailURL) else {
                completion(GameMetadata(description: "", genre: genres, releaseYear: year, ageRating: ageRating, coverURL: cover, backgroundURL: nil, source: "RAWG"))
                return
            }
            URLSession.shared.dataTask(with: durl) { data, _, _ in
                let desc = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })?["description_raw"] as? String ?? ""
                completion(GameMetadata(description: String(desc.prefix(600)), genre: genres, releaseYear: year, ageRating: ageRating, coverURL: cover, backgroundURL: nil, source: "RAWG"))
            }.resume()
        }.resume()
    }

    static func fetchSteamGridDBHeroes(for gameName: String, completion: @escaping ([String]) -> Void) {
        let key = AppSettings.shared.steamGridDBKey
        guard !key.isEmpty else { completion([]); return }
        let query = gameName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? gameName
        guard let url = URL(string: "https://www.steamgriddb.com/api/v2/search/autocomplete/\(query)") else { completion([]); return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let gameID = (json["data"] as? [[String: Any]])?.first?["id"] as? Int
            else { completion([]); return }

            guard let heroURL = URL(string: "https://www.steamgriddb.com/api/v2/heroes/game/\(gameID)") else { completion([]); return }
            var heroReq = URLRequest(url: heroURL)
            heroReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: heroReq) { data, _, _ in
                let items = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })?["data"] as? [[String: Any]] ?? []
                let urls = items.compactMap { $0["url"] as? String }
                completion(urls)
            }.resume()
        }.resume()
    }

    // MARK: - SteamGridDB

    static func fetchCoverFromSteamGridDB(gameName: String, completion: @escaping (String?) -> Void) {
        let key = AppSettings.shared.steamGridDBKey
        guard !key.isEmpty else { completion(nil); return }
        let query = gameName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? gameName
        guard let url = URL(string: "https://www.steamgriddb.com/api/v2/search/autocomplete/\(query)") else { completion(nil); return }
        var req = URLRequest(url: url)
        req.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let gameID = (json["data"] as? [[String: Any]])?.first?["id"] as? Int
            else { completion(nil); return }
            guard let gridURL = URL(string: "https://www.steamgriddb.com/api/v2/grids/game/\(gameID)?dimensions=600x900") else { completion(nil); return }
            var gridReq = URLRequest(url: gridURL)
            gridReq.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
            URLSession.shared.dataTask(with: gridReq) { data, _, _ in
                let url = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] })?["data"] as? [[String: Any]]
                completion(url?.first?["url"] as? String)
            }.resume()
        }.resume()
    }

    // MARK: - Steam

    static func fetchFromSteam(gameName: String, completion: @escaping (GameMetadata?) -> Void) {
        let query = gameName.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? gameName
        guard let url = URL(string: "https://store.steampowered.com/api/storesearch/?term=\(query)&l=german&cc=de") else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let appID = (json["items"] as? [[String: Any]])?.first?["id"] as? Int
            else { completion(nil); return }
            guard let durl = URL(string: "https://store.steampowered.com/api/appdetails?appids=\(appID)&l=german&cc=de") else { completion(nil); return }
            URLSession.shared.dataTask(with: durl) { data, _, _ in
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let appData = (json["\(appID)"] as? [String: Any])?["data"] as? [String: Any]
                else { completion(nil); return }
                let desc   = stripHTML(appData["short_description"] as? String ?? "")
                let genres = (appData["genres"] as? [[String: Any]])?.compactMap { $0["description"] as? String }.prefix(2).joined(separator: ", ") ?? ""
                let release = (appData["release_date"] as? [String: Any])?["date"] as? String ?? ""
                let year   = release.components(separatedBy: CharacterSet(charactersIn: " ,")).last ?? release
                let cover  = appData["header_image"] as? String
                let requiredAge = appData["required_age"] as? Int ?? 0
                let uskRating = (appData["ratings"] as? [String: Any]).flatMap { ($0["usk"] as? [String: Any])?["rating"] as? String } ?? ""
                let ageRating: String
                if !uskRating.isEmpty {
                    ageRating = uskRating == "0" ? "Ohne Altersbeschränkung" : "Ab \(uskRating) Jahren"
                } else {
                    switch requiredAge {
                    case 0:       ageRating = ""
                    case 1...6:   ageRating = "Ab 6 Jahren"
                    case 7...12:  ageRating = "Ab 12 Jahren"
                    case 13...16: ageRating = "Ab 16 Jahren"
                    default:      ageRating = "Ab 18 Jahren"
                    }
                }
                completion(GameMetadata(description: desc, genre: genres, releaseYear: year, ageRating: ageRating, coverURL: cover, backgroundURL: nil, source: "Steam"))
            }.resume()
        }.resume()
    }

    // MARK: - Cover herunterladen

    static func downloadCover(from urlString: String, for gameName: String, completion: @escaping (String?) -> Void) {
        guard let url = URL(string: urlString) else { completion(nil); return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, let image = NSImage(data: data) else { completion(nil); return }
            let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            let dir = support.appendingPathComponent("RogueLauncher/Covers")
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let safe = gameName.replacingOccurrences(of: "/", with: "-")
            let dest = dir.appendingPathComponent("\(safe).jpg")
            if let tiff = image.tiffRepresentation,
               let bmp  = NSBitmapImageRep(data: tiff),
               let jpg  = bmp.representation(using: .jpeg, properties: [.compressionFactor: 0.9]) {
                try? jpg.write(to: dest)
                completion(dest.path)
            } else { completion(nil) }
        }.resume()
    }

    static func stripHTML(_ html: String) -> String {
        guard let data = html.data(using: .utf8),
              let str  = try? NSAttributedString(data: data,
                  options: [.documentType: NSAttributedString.DocumentType.html,
                            .characterEncoding: String.Encoding.utf8.rawValue],
                  documentAttributes: nil)
        else { return html.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression) }
        return str.string.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Similar Games

struct SimilarGame: Identifiable {
    let id: Int
    let name: String
    let coverURL: String?
}

extension GameMetadataService {
    static func fetchSimilarGames(for gameName: String, completion: @escaping ([SimilarGame]) -> Void) {
        getIGDBToken { token in
            guard let token = token else { completion([]); return }

            // 1. Game-ID holen
            guard let url = URL(string: "https://api.igdb.com/v4/games") else { completion([]); return }
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
            req.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
            let safe = gameName.replacingOccurrences(of: "\"", with: "\\\"")
            req.httpBody = "search \"\(safe)\"; fields id,similar_games; limit 1;".data(using: .utf8)

            URLSession.shared.dataTask(with: req) { data, _, _ in
                guard let data = data,
                      let games = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                      let game = games.first,
                      let similarIDs = game["similar_games"] as? [Int],
                      !similarIDs.isEmpty
                else { completion([]); return }

                // 2. Details der ähnlichen Spiele holen
                let idList = similarIDs.prefix(9).map(String.init).joined(separator: ",")
                guard let url2 = URL(string: "https://api.igdb.com/v4/games") else { completion([]); return }
                var req2 = URLRequest(url: url2)
                req2.httpMethod = "POST"
                req2.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
                req2.setValue(igdbClientID, forHTTPHeaderField: "Client-ID")
                req2.httpBody = "fields name,cover.image_id; where id = (\(idList)); limit 9;".data(using: .utf8)

                URLSession.shared.dataTask(with: req2) { data, _, _ in
                    guard let data = data,
                          let results = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
                    else { completion([]); return }

                    let similar = results.compactMap { g -> SimilarGame? in
                        guard let id = g["id"] as? Int, let name = g["name"] as? String else { return nil }
                        let coverID = (g["cover"] as? [String: Any])?["image_id"] as? String
                        let coverURL = coverID.map { "https://images.igdb.com/igdb/image/upload/t_cover_big_2x/\($0).jpg" }
                        return SimilarGame(id: id, name: name, coverURL: coverURL)
                    }
                    completion(similar)
                }.resume()
            }.resume()
        }
    }
}
