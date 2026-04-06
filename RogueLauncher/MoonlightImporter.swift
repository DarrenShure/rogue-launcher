import Foundation
import Security

struct MoonlightApp: Identifiable {
    let id = UUID()
    let name: String
}

class MoonlightImporter {

    // MARK: - App-Liste direkt aus Moonlight plist lesen

    static func fetchApps(ip: String, port: Int = 47989, completion: @escaping ([MoonlightApp], String?) -> Void) {
        // Erst lokal aus plist lesen – das ist zuverlässig und braucht kein Netzwerk
        let local = loadAppsFromPlist()
        if !local.isEmpty {
            completion(local, nil)
            return
        }

        // Fallback: Netzwerk-API
        fetchFromNetwork(ip: ip, port: port, completion: completion)
    }

    static func loadAppsFromPlist() -> [MoonlightApp] {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
        guard let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else { return [] }

        var apps: [String] = []
        var hostIndex = 1
        while dict["hosts.\(hostIndex).apps.size"] != nil {
            let appCount = (dict["hosts.\(hostIndex).apps.size"] as? Int) ?? 0
            for appIndex in 1...max(appCount, 1) {
                if let name = dict["hosts.\(hostIndex).apps.\(appIndex).name"] as? String {
                    let hidden = (dict["hosts.\(hostIndex).apps.\(appIndex).hidden"] as? Int) ?? 0
                    if hidden == 0 { apps.append(name) }
                }
            }
            hostIndex += 1
        }
        return apps.map { MoonlightApp(name: $0) }
    }

    // MARK: - Zertifikat & Key aus plist laden (als NSData/bytes)

    struct CertKeyPair { let certPEM: String; let keyPEM: String }

    static func loadMoonlightCert() -> CertKeyPair? {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
        guard let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else { return nil }

        // certificate und key sind als NSData mit PEM-Inhalt gespeichert
        if let certData = dict["certificate"] as? Data,
           let keyData  = dict["key"] as? Data,
           let certStr  = String(data: certData, encoding: .utf8),
           let keyStr   = String(data: keyData, encoding: .utf8) {
            return CertKeyPair(certPEM: certStr, keyPEM: keyStr)
        }
        return nil
    }

    // MARK: - MAC aus plist laden

    static func loadMACAddress() -> String? {
        let plistPath = NSHomeDirectory() + "/Library/Preferences/com.moonlight-stream.Moonlight.plist"
        guard let dict = NSDictionary(contentsOfFile: plistPath) as? [String: Any] else { return nil }
        // hosts.1.mac ist NSData mit 6 bytes
        if let macData = dict["hosts.1.mac"] as? Data, macData.count == 6 {
            return macData.map { String(format: "%02X", $0) }.joined(separator: ":")
        }
        return nil
    }

    // MARK: - Netzwerk-Fallback

    private static func fetchFromNetwork(ip: String, port: Int, completion: @escaping ([MoonlightApp], String?) -> Void) {
        guard !ip.isEmpty else {
            completion([], "Keine IP-Adresse konfiguriert.")
            return
        }
        let certInfo = loadMoonlightCert()
        guard let url = URL(string: "https://\(ip):\(port)/applist") else {
            completion([], "Ungültige URL.")
            return
        }
        let delegate = SunshineSessionDelegate(certPEM: certInfo?.certPEM, keyPEM: certInfo?.keyPEM)
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 8
        let session = URLSession(configuration: config, delegate: delegate, delegateQueue: nil)
        session.dataTask(with: url) { data, _, error in
            if let error = error {
                completion([], "Netzwerkfehler: \(error.localizedDescription)")
                return
            }
            guard let data = data else { completion([], "Keine Daten."); return }
            let apps = parseAppList(data: data)
            completion(apps, apps.isEmpty ? "Keine Apps erhalten." : nil)
        }.resume()
    }

    static func parseAppList(data: Data) -> [MoonlightApp] {
        let p = AppListXMLParser()
        let xml = XMLParser(data: data); xml.delegate = p; xml.parse()
        return p.apps.map { MoonlightApp(name: $0) }
    }
}

// MARK: - XML Parser

class AppListXMLParser: NSObject, XMLParserDelegate {
    var apps: [String] = []
    private var current = ""; private var capture = false
    func parser(_ parser: XMLParser, didStartElement el: String, namespaceURI: String?,
                qualifiedName: String?, attributes: [String: String] = [:]) {
        if ["AppTitle", "title", "name"].contains(el) { capture = true; current = "" }
    }
    func parser(_ parser: XMLParser, foundCharacters s: String) { if capture { current += s } }
    func parser(_ parser: XMLParser, didEndElement el: String, namespaceURI: String?, qualifiedName: String?) {
        if capture {
            let n = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !n.isEmpty { apps.append(n) }
            capture = false
        }
    }
}

// MARK: - Session Delegate

class SunshineSessionDelegate: NSObject, URLSessionDelegate {
    let certPEM: String?; let keyPEM: String?
    init(certPEM: String?, keyPEM: String?) { self.certPEM = certPEM; self.keyPEM = keyPEM }

    func urlSession(_ session: URLSession, didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        if challenge.protectionSpace.authenticationMethod == NSURLAuthenticationMethodServerTrust,
           let trust = challenge.protectionSpace.serverTrust {
            completionHandler(.useCredential, URLCredential(trust: trust))
        } else {
            completionHandler(.performDefaultHandling, nil)
        }
    }
}
