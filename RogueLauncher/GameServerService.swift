import Foundation

class GameServerService {

    // MARK: - Crafty

    static func craftyRequest(
        path: String,
        method: String = "GET",
        body: [String: Any]? = nil,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        let settings = AppSettings.shared
        guard !settings.craftyURL.isEmpty, !settings.craftyAPIKey.isEmpty,
              let url = URL(string: "\(settings.craftyURL)/api/v2\(path)") else {
            completion(.failure(NSError(domain: "Crafty", code: 0, userInfo: [NSLocalizedDescriptionKey: "Crafty nicht konfiguriert"])))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(settings.craftyAPIKey)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 8
        if let body = body { req.httpBody = try? JSONSerialization.data(withJSONObject: body) }

        let session = URLSession(configuration: .default, delegate: SelfSignedDelegate(), delegateQueue: nil)
        session.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                completion(.failure(NSError(domain: "Crafty", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültige Antwort"])))
                return
            }
            completion(.success(json))
        }.resume()
    }

    static func craftyServerStatus(serverID: String, completion: @escaping (ServerStatus) -> Void) {
        craftyRequest(path: "/servers/\(serverID)/stats") { result in
            switch result {
            case .success(let json):
                if let dict = json as? [String: Any],
                   let data = dict["data"] as? [String: Any],
                   let running = data["running"] as? Bool {
                    DispatchQueue.main.async { completion(running ? .online : .offline) }
                } else {
                    DispatchQueue.main.async { completion(.unknown) }
                }
            case .failure:
                DispatchQueue.main.async { completion(.unknown) }
            }
        }
    }

    static func craftyServerAction(serverID: String, action: String, completion: @escaping (Bool) -> Void) {
        // action: "start_server", "stop_server", "restart_server"
        craftyRequest(path: "/servers/\(serverID)/action/\(action)", method: "POST") { result in
            switch result {
            case .success: DispatchQueue.main.async { completion(true) }
            case .failure: DispatchQueue.main.async { completion(false) }
            }
        }
    }

    static func craftySendCommand(serverID: String, command: String, completion: @escaping (Bool) -> Void) {
        craftyRequest(path: "/servers/\(serverID)/stdin", method: "POST", body: ["command": command]) { result in
            switch result {
            case .success: DispatchQueue.main.async { completion(true) }
            case .failure: DispatchQueue.main.async { completion(false) }
            }
        }
    }

    // MARK: - Nitrado

    static func nitradoRequest(
        path: String,
        method: String = "GET",
        body: [String: String]? = nil,
        completion: @escaping (Result<Any, Error>) -> Void
    ) {
        let settings = AppSettings.shared
        guard !settings.nitradoAPIToken.isEmpty,
              let url = URL(string: "https://api.nitrado.net\(path)") else {
            completion(.failure(NSError(domain: "Nitrado", code: 0, userInfo: [NSLocalizedDescriptionKey: "Nitrado nicht konfiguriert"])))
            return
        }
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue("Bearer \(settings.nitradoAPIToken)", forHTTPHeaderField: "Authorization")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.timeoutInterval = 10
        if let body = body {
            req.httpBody = body.map { "\($0.key)=\($0.value)" }.joined(separator: "&").data(using: .utf8)
            req.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        }

        URLSession.shared.dataTask(with: req) { data, _, error in
            if let error = error { completion(.failure(error)); return }
            guard let data = data,
                  let json = try? JSONSerialization.jsonObject(with: data) else {
                completion(.failure(NSError(domain: "Nitrado", code: 1, userInfo: [NSLocalizedDescriptionKey: "Ungültige Antwort"])))
                return
            }
            completion(.success(json))
        }.resume()
    }

    struct NitradoServerDetails {
        var status: ServerStatus
        var game: String
        var slots: Int
        var map: String
        var version: String
        var memoryMB: Int
        var players: [String] // player names
    }

    static func nitradoServerStatus(serverID: String, completion: @escaping (ServerStatus) -> Void) {
        nitradoRequest(path: "/services/\(serverID)/gameservers") { result in
            switch result {
            case .success(let json):
                if let dict = json as? [String: Any],
                   let data = dict["data"] as? [String: Any],
                   let gs = data["gameserver"] as? [String: Any],
                   let status = gs["status"] as? String {
                    DispatchQueue.main.async {
                        switch status {
                        case "started": completion(.online)
                        case "stopped": completion(.offline)
                        case "restarting": completion(.starting)
                        default: completion(.unknown)
                        }
                    }
                } else {
                    DispatchQueue.main.async { completion(.unknown) }
                }
            case .failure:
                DispatchQueue.main.async { completion(.unknown) }
            }
        }
    }

    static func nitradoServerDetails(serverID: String, completion: @escaping (NitradoServerDetails?) -> Void) {
        nitradoRequest(path: "/services/\(serverID)/gameservers") { result in
            guard case .success(let json) = result,
                  let dict = json as? [String: Any],
                  let data = dict["data"] as? [String: Any],
                  let gs = data["gameserver"] as? [String: Any]
            else { DispatchQueue.main.async { completion(nil) }; return }

            let statusStr = gs["status"] as? String ?? ""
            let status: ServerStatus = statusStr == "started" ? .online : statusStr == "stopped" ? .offline : .unknown
            let game = gs["game"] as? String ?? (gs["game_human"] as? String ?? "")
            let slots = gs["slots"] as? Int ?? 0
            let map = (gs["query"] as? [String: Any])?["map"] as? String ?? ""
            let version = (gs["query"] as? [String: Any])?["version"] as? String ?? ""
            let memoryMB = gs["memory"] as? Int ?? 0
            let playerList = ((gs["query"] as? [String: Any])?["player_list"] as? [[String: Any]] ?? [])
                .compactMap { $0["name"] as? String }

            DispatchQueue.main.async {
                completion(NitradoServerDetails(status: status, game: game, slots: slots,
                    map: map, version: version, memoryMB: memoryMB, players: playerList))
            }
        }
    }

    static func nitradoGetSettings(serverID: String, completion: @escaping ([String: Any]?) -> Void) {
        nitradoRequest(path: "/services/\(serverID)/gameservers/settings") { result in
            guard case .success(let json) = result,
                  let dict = json as? [String: Any],
                  let data = dict["data"] as? [String: Any],
                  let settings = data["settings"] as? [String: Any]
            else { DispatchQueue.main.async { completion(nil) }; return }
            DispatchQueue.main.async { completion(settings) }
        }
    }

    static func nitradoSetSetting(serverID: String, category: String, key: String, value: String, completion: @escaping (Bool) -> Void) {
        nitradoRequest(path: "/services/\(serverID)/gameservers/settings",
                       method: "POST",
                       body: ["category": category, "key": key, "value": value]) { result in
            DispatchQueue.main.async {
                if case .success = result { completion(true) } else { completion(false) }
            }
        }
    }

    static func nitradoServerAction(serverID: String, action: String, completion: @escaping (Bool) -> Void) {
        // action: "restart", "stop"
        nitradoRequest(path: "/services/\(serverID)/gameservers/\(action)", method: "POST") { result in
            switch result {
            case .success: DispatchQueue.main.async { completion(true) }
            case .failure: DispatchQueue.main.async { completion(false) }
            }
        }
    }
}
