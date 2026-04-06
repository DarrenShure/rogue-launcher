import Foundation
import Network
import Combine

enum PCStatus {
    case online, offline, checking
}

class PCStatusMonitor: ObservableObject {
    static let shared = PCStatusMonitor()
    @Published var status: PCStatus = .checking

    private var timer: Timer?

    private init() {
        checkStatus()
        // Alle 5 Sekunden prüfen
        timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            self?.checkStatus()
        }
    }

    func checkNow() {
        status = .checking
        checkStatus()
    }

    private func checkStatus() {
        // Während eines App-Wechsels Status nicht auf offline setzen
        if SessionTracker.shared.isSwitching {
            return
        }
        let ip = AppSettings.shared.pcIPAddress
        let port = AppSettings.shared.moonlightPort
        guard !ip.isEmpty else {
            DispatchQueue.main.async { self.status = .offline }
            return
        }
        let host = NWEndpoint.Host(ip)
        let nwPort = NWEndpoint.Port(rawValue: UInt16(port)) ?? 47989
        let connection = NWConnection(host: host, port: nwPort, using: .tcp)
        var resolved = false
        connection.stateUpdateHandler = { [weak self] state in
            guard !resolved else { return }
            switch state {
            case .ready:
                resolved = true
                DispatchQueue.main.async { self?.status = .online }
                connection.cancel()
            case .failed, .waiting:
                resolved = true
                DispatchQueue.main.async { self?.status = .offline }
                connection.cancel()
            default:
                break
            }
        }
        connection.start(queue: .global())
        DispatchQueue.global().asyncAfter(deadline: .now() + 3) {
            guard !resolved else { return }
            resolved = true
            connection.cancel()
            DispatchQueue.main.async { self.status = .offline }
        }
    }

    func sendWakeOnLan() {
        WakeOnLan.send(mac: AppSettings.shared.pcMACAddress)
    }
}

struct WakeOnLan {
    static func send(mac: String) {
        let clean = mac.replacingOccurrences(of: ":", with: "").replacingOccurrences(of: "-", with: "")
        guard clean.count == 12 else { return }
        var bytes = [UInt8](repeating: 0xFF, count: 6)
        var macBytes = [UInt8]()
        for i in stride(from: 0, to: 12, by: 2) {
            let start = clean.index(clean.startIndex, offsetBy: i)
            let end = clean.index(start, offsetBy: 2)
            if let byte = UInt8(clean[start..<end], radix: 16) { macBytes.append(byte) }
        }
        guard macBytes.count == 6 else { return }
        for _ in 0..<16 { bytes.append(contentsOf: macBytes) }
        let sock = socket(AF_INET, SOCK_DGRAM, IPPROTO_UDP)
        guard sock >= 0 else { return }
        var broadcastEnable: Int32 = 1
        setsockopt(sock, SOL_SOCKET, SO_BROADCAST, &broadcastEnable, socklen_t(MemoryLayout<Int32>.size))
        var addr = sockaddr_in()
        addr.sin_family = sa_family_t(AF_INET)
        addr.sin_port = UInt16(9).bigEndian
        addr.sin_addr.s_addr = INADDR_BROADCAST
        withUnsafePointer(to: &addr) { ptr in
            ptr.withMemoryRebound(to: sockaddr.self, capacity: 1) { sockPtr in
                _ = sendto(sock, bytes, bytes.count, 0, sockPtr, socklen_t(MemoryLayout<sockaddr_in>.size))
            }
        }
        close(sock)
    }
}
