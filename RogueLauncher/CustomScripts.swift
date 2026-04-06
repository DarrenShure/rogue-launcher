import SwiftUI

// MARK: - Model

struct CustomScript: Codable, Identifiable {
    var id = UUID()
    var name: String
    var path: String
    var symbol: String = "terminal"
    var showInTopNav: Bool = true
}

// MARK: - Store

class CustomScriptStore: ObservableObject {
    static let shared = CustomScriptStore()
    @Published var scripts: [CustomScript] = []
    private let key = "customScripts"

    init() { load() }

    func load() {
        if let data = UserDefaults.standard.data(forKey: key),
           let decoded = try? JSONDecoder().decode([CustomScript].self, from: data) {
            scripts = decoded
        }
    }

    func save() {
        if let data = try? JSONEncoder().encode(scripts) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    func add(_ script: CustomScript) {
        scripts.append(script)
        save()
    }

    func delete(at offsets: IndexSet) {
        scripts.remove(atOffsets: offsets)
        save()
    }

    func run(_ script: CustomScript, completion: @escaping (Bool, String) -> Void) {
        guard let url = URL(string: "\(HelperAPI.shared.baseURL)/script/run") else {
            completion(false, "Ungültige URL"); return
        }
        let body: [String: Any] = ["path": script.path, "timeout": 60]
        guard let httpBody = try? JSONSerialization.data(withJSONObject: body) else {
            completion(false, "Serialisierungsfehler"); return
        }
        var req = URLRequest(url: url, timeoutInterval: 65)
        req.httpMethod = "POST"
        req.httpBody = httpBody
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let s = AppSettings.shared
        if !s.helperUser.isEmpty, let creds = "\(s.helperUser):\(s.helperPassword)".data(using: .utf8) {
            req.setValue("Basic \(creds.base64EncodedString())", forHTTPHeaderField: "Authorization")
        }
        HelperAPI.shared.dataTask(with: req) { data, _, error in
            DispatchQueue.main.async {
                if let error = error { completion(false, error.localizedDescription); return }
                guard let data = data,
                      let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
                    completion(false, "Keine Antwort"); return
                }
                let status = json["status"] as? String ?? "error"
                let stdout = json["stdout"] as? String ?? ""
                let stderr = json["stderr"] as? String ?? ""
                let output = [stdout, stderr].filter { !$0.isEmpty }.joined(separator: "\n")
                completion(status == "ok", output.isEmpty ? status : output)
            }
        }.resume()
    }
}
