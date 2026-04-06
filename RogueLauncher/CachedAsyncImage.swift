import SwiftUI
import AppKit

/// Rate-limited image loader — max 8 concurrent requests, automatic retry
final class ImageLoader: ObservableObject {
    @Published var image: NSImage?
    private static let semaphore = DispatchSemaphore(value: 8)
    private var task: URLSessionDataTask?

    func load(_ url: URL?) {
        guard let url else { return }
        // Already cached in URLCache → decode immediately
        let req = URLRequest(url: url, cachePolicy: .returnCacheDataElseLoad, timeoutInterval: 15)
        if let cached = URLCache.shared.cachedResponse(for: req),
           let img = NSImage(data: cached.data) {
            DispatchQueue.main.async { self.image = img }
            return
        }
        DispatchQueue.global(qos: .utility).async {
            Self.semaphore.wait()
            defer { Self.semaphore.signal() }
            for attempt in 1...3 {
                var done = false
                let t = URLSession.shared.dataTask(with: req) { data, resp, _ in
                    if let data, let img = NSImage(data: data) {
                        DispatchQueue.main.async { self.image = img }
                    }
                    done = true
                }
                t.resume()
                self.task = t
                // Wait up to 12s per attempt
                var waited = 0.0
                while !done && waited < 12 { Thread.sleep(forTimeInterval: 0.1); waited += 0.1 }
                if self.image != nil { break }
                if attempt < 3 { Thread.sleep(forTimeInterval: Double(attempt) * 0.5) }
            }
        }
    }

    func cancel() { task?.cancel() }
}

struct CachedAsyncImage<Content: View, Placeholder: View>: View {
    private let url: URL?
    private let content: (Image) -> Content
    private let placeholder: () -> Placeholder
    @StateObject private var loader = ImageLoader()

    init(url: URL?,
         @ViewBuilder content: @escaping (Image) -> Content,
         @ViewBuilder placeholder: @escaping () -> Placeholder) {
        self.url = url
        self.content = content
        self.placeholder = placeholder
    }

    var body: some View {
        Group {
            if let img = loader.image {
                content(Image(nsImage: img))
            } else {
                placeholder()
            }
        }
        .onAppear { loader.load(url) }
        .onDisappear { loader.cancel() }
        .onChange(of: url) { _, newURL in loader.image = nil; loader.load(newURL) }
    }
}
