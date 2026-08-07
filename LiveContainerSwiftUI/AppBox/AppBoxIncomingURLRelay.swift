import Foundation

enum AppBoxIncomingURLRelay {
    private static let pendingURLKey = "AppBox.pendingExternalURL"

    static func forward(_ url: URL, source: String = "unknown") {
        DispatchQueue.main.async {
            let defaults = UserDefaults.standard
            defaults.set(url.absoluteString, forKey: "AppBox.lastIncomingURL")
            defaults.set(Date(), forKey: "AppBox.lastIncomingURLDate")
            defaults.set(source, forKey: "AppBox.lastIncomingURLSource")
            defaults.set(url.absoluteString, forKey: pendingURLKey)
            defaults.synchronize()
            DataManager.shared.model.deepLink = url
        }
    }

    static func forwardFirstURLFromProcessArguments(_ arguments: [String] = ProcessInfo.processInfo.arguments) {
        guard let url = firstExternalURL(in: arguments) else { return }
        forward(url, source: "process-arguments")
    }

    static func consumePendingURL() -> URL? {
        let defaults = UserDefaults.standard
        guard let rawValue = defaults.string(forKey: pendingURLKey),
              let url = URL(string: rawValue) else { return nil }
        defaults.removeObject(forKey: pendingURLKey)
        defaults.synchronize()
        return url
    }

    private static func firstExternalURL(in arguments: [String]) -> URL? {
        arguments.lazy.compactMap(URL.init(string:)).first { url in
            url.isFileURL || AppBoxDeepLinkParser.parse(url) != nil
        }
    }
}
