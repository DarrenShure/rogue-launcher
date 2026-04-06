import Foundation

// MARK: - Helper API

class HelperAPI {
    static let shared = HelperAPI()

    // URLSession die selbstsignierte Zertifikate akzeptiert
    private let session = URLSession(
        configuration: .default,
        delegate: SelfSignedDelegate(),
        delegateQueue: nil
    )

    var baseURL: String {
        let s = AppSettings.shared
        let host = s.helperHost.isEmpty ? s.pcIPAddress : s.helperHost
        let port = s.helperPort.isEmpty ? "9876" : s.helperPort
        return "https://\(host):\(port)"
    }

    func request(_ path: String, method: String = "GET", body: [String: Any]? = nil) -> URLRequest? {
        let s = AppSettings.shared
        guard let url = URL(string: "\(baseURL)\(path)") else { return nil }
        var req = URLRequest(url: url, timeoutInterval: 10)
        req.httpMethod = method
        if let body = body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        if !s.helperUser.isEmpty {
            let creds = "\(s.helperUser):\(s.helperPassword)"
            if let data = creds.data(using: .utf8) {
                req.setValue("Basic \(data.base64EncodedString())", forHTTPHeaderField: "Authorization")
            }
        }
        return req
    }

    func dataTask(with request: URLRequest, completionHandler: @escaping (Data?, URLResponse?, Error?) -> Void) -> URLSessionDataTask {
        return session.dataTask(with: request, completionHandler: completionHandler)
    }

    var isConfigured: Bool {
        let s = AppSettings.shared
        return !s.helperHost.isEmpty || !s.pcIPAddress.isEmpty
    }

    func fetchScripts(completion: @escaping ([HelperScript]) -> Void) {
        guard let req = request("/scripts") else { completion([]); return }
        dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let list = try? JSONDecoder().decode([HelperScript].self, from: data) else {
                DispatchQueue.main.async { completion([]) }
                return
            }
            DispatchQueue.main.async { completion(list) }
        }.resume()
    }
}

struct HelperScript: Codable, Identifiable, Hashable {
    var id: String { path }
    var name: String
    var path: String
}
