import CryptoKit
import Foundation

protocol AppBoxRemoteEndpointResolving {
    func catalogURL() async -> URL
}

final class AppBoxRemoteEndpointService: AppBoxRemoteEndpointResolving {
    static let shared = AppBoxRemoteEndpointService()

    private let configURLs: [URL]
    private let defaults: UserDefaults
    private let fallbackBaseURL: URL
    private let session: URLSession
    private var resolvedBaseURL: URL?

    init(
        configURLs: [URL] = AppBoxRemoteEndpointDefaults.configURLs,
        fallbackBaseURL: URL = URL(string: "https://666999.lol")!,
        defaults: UserDefaults = .standard,
        session: URLSession = .shared
    ) {
        self.configURLs = configURLs
        self.defaults = defaults
        self.fallbackBaseURL = fallbackBaseURL
        self.session = session
    }

    func catalogURL() async -> URL {
        let baseURL = await resolveBaseURL()
        return appending("/api/v1/appbox/catalog", to: baseURL)
    }

    private func resolveBaseURL() async -> URL {
        if let resolvedBaseURL { return resolvedBaseURL }

        if let cached = defaults.string(forKey: AppBoxRemoteEndpointDefaults.selectedBaseURLKey).flatMap(URL.init(string:)),
           await probe(cached) {
            resolvedBaseURL = cached
            return cached
        }

        let remoteCandidates = (try? await loadRemoteCandidates()) ?? []
        if !remoteCandidates.isEmpty {
            defaults.set(remoteCandidates.map(\.absoluteString), forKey: AppBoxRemoteEndpointDefaults.cachedBaseURLsKey)
        }

        if let selected = await firstReachable(in: remoteCandidates) {
            cacheSelected(selected)
            return selected
        }

        let cachedCandidates = defaults.stringArray(forKey: AppBoxRemoteEndpointDefaults.cachedBaseURLsKey)?
            .compactMap(URL.init(string:)) ?? []
        if let selected = await firstReachable(in: cachedCandidates) {
            cacheSelected(selected)
            return selected
        }

        resolvedBaseURL = fallbackBaseURL
        return fallbackBaseURL
    }

    private func loadRemoteCandidates() async throws -> [URL] {
        await withTaskGroup(of: [URL].self) { group in
            for url in configURLs {
                group.addTask { [session] in
                    (try? await Self.fetchRemoteConfig(from: url, session: session)) ?? []
                }
            }

            while let result = await group.next() {
                if !result.isEmpty {
                    group.cancelAll()
                    return result
                }
            }

            return []
        }
    }

    private static func fetchRemoteConfig(from url: URL, session: URLSession) async throws -> [URL] {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        var queryItems = components?.queryItems ?? []
        queryItems.append(URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970 * 1000))))
        components?.queryItems = queryItems
        let resolvedURL = components?.url ?? url

        var request = URLRequest(url: resolvedURL)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.timeoutInterval = 10
        request.setValue("AppBox/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("*/*", forHTTPHeaderField: "Accept")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode),
              let body = String(data: data, encoding: .utf8) else {
            return []
        }

        let plain = try AppBoxRemoteConfigCrypto.decryptPackedBase64(body.trimmingCharacters(in: .whitespacesAndNewlines))
        return try AppBoxRemoteConfigParser.parse(plain)
    }

    private func firstReachable(in candidates: [URL]) async -> URL? {
        let uniqueCandidates = candidates.reduce(into: [URL]()) { result, url in
            let normalized = normalizedBaseURL(url)
            if !result.contains(normalized) { result.append(normalized) }
        }

        for url in uniqueCandidates {
            if await probe(url) { return url }
        }
        return nil
    }

    private func probe(_ baseURL: URL) async -> Bool {
        var request = URLRequest(url: appending("/health", to: baseURL))
        request.timeoutInterval = 6
        request.setValue("AppBox/1.0", forHTTPHeaderField: "User-Agent")
        do {
            let (_, response) = try await session.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200...399).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }

    private func cacheSelected(_ url: URL) {
        let normalized = normalizedBaseURL(url)
        resolvedBaseURL = normalized
        defaults.set(normalized.absoluteString, forKey: AppBoxRemoteEndpointDefaults.selectedBaseURLKey)
    }

    private func normalizedBaseURL(_ url: URL) -> URL {
        var components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        components?.path = ""
        components?.query = nil
        components?.fragment = nil
        return components?.url ?? url
    }

    private func appending(_ path: String, to baseURL: URL) -> URL {
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
        let basePath = components?.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")) ?? ""
        let nextPath = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components?.path = "/" + [basePath, nextPath].filter { !$0.isEmpty }.joined(separator: "/")
        return components?.url ?? baseURL.appendingPathComponent(nextPath)
    }
}

private enum AppBoxRemoteEndpointDefaults {
    static let selectedBaseURLKey = "appbox.remoteEndpoint.selectedBaseURL"
    static let cachedBaseURLsKey = "appbox.remoteEndpoint.cachedBaseURLs"

    static let configURLs = [
        URL(string: "https://raw.githubusercontent.com/yasuo185239-beep/appbox-config/main/version.json")!,
        URL(string: "https://cdn.jsdelivr.net/gh/yasuo185239-beep/appbox-config@main/version.json")!,
        URL(string: "https://fastly.jsdelivr.net/gh/yasuo185239-beep/appbox-config@main/version.json")!,
        URL(string: "https://gcore.jsdelivr.net/gh/yasuo185239-beep/appbox-config@main/version.json")!
    ]
}

private enum AppBoxRemoteConfigCrypto {
    static func decryptPackedBase64(_ value: String) throws -> Data {
        guard let keyData = Data(base64Encoded: AppBoxClientCryptoConfig.clientKeyBase64),
              let packed = Data(base64Encoded: value),
              packed.count > 28 else {
            throw AppBoxRemoteConfigError.invalidEnvelope
        }

        let nonceData = packed.prefix(12)
        let tagData = packed.suffix(16)
        let cipherData = packed.dropFirst(12).dropLast(16)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherData, tag: tagData)
        return try AES.GCM.open(sealedBox, using: SymmetricKey(data: keyData))
    }
}

private enum AppBoxRemoteConfigParser {
    static func parse(_ data: Data) throws -> [URL] {
        let decoder = JSONDecoder()
        if let list = try? decoder.decode([String].self, from: data) {
            return list.compactMap(URL.init(string:))
        }
        let config = try decoder.decode(AppBoxRemoteConfig.self, from: data)
        return config.api.compactMap { entry in
            switch entry {
            case .url(let value):
                return URL(string: value)
            case .object(let value):
                guard value.enabled else { return nil }
                return URL(string: value.baseUrl)
            }
        }
    }
}

private struct AppBoxRemoteConfig: Decodable {
    let v: Int
    let api: [AppBoxRemoteAPIEntry]
}

private enum AppBoxRemoteAPIEntry: Decodable {
    case url(String)
    case object(AppBoxRemoteAPIObject)

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(String.self) {
            self = .url(value)
            return
        }
        self = .object(try container.decode(AppBoxRemoteAPIObject.self))
    }
}

private struct AppBoxRemoteAPIObject: Decodable {
    let baseUrl: String
    let enabled: Bool

    private enum CodingKeys: String, CodingKey {
        case baseUrl
        case enabled
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseUrl = try container.decode(String.self, forKey: .baseUrl)
        enabled = try container.decodeIfPresent(Bool.self, forKey: .enabled) ?? true
    }
}

private enum AppBoxRemoteConfigError: Error {
    case invalidEnvelope
}
