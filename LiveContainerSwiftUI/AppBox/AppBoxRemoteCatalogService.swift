import CryptoKit
import Foundation

protocol AppBoxCatalogFetching {
    func fetchCatalogGroups() async throws -> [AppBoxCatalogGroup]
}

struct AppBoxRemoteCatalogService: AppBoxCatalogFetching {
    private let session: URLSession
    private let endpointService: AppBoxRemoteEndpointResolving
    private let decoder = JSONDecoder()

    init(
        session: URLSession = .shared,
        endpointService: AppBoxRemoteEndpointResolving = AppBoxRemoteEndpointService.shared
    ) {
        self.session = session
        self.endpointService = endpointService
    }

    func fetchCatalogGroups() async throws -> [AppBoxCatalogGroup] {
        let catalogURL = await endpointService.catalogURL()
        let (data, response) = try await session.data(from: catalogURL)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            throw AppBoxRemoteCatalogError.invalidResponse
        }

        let envelope = try decoder.decode(AppBoxEncryptedEnvelope.self, from: data)
        let catalogData = try AppBoxCatalogCrypto.decrypt(envelope)
        let remoteCatalog = try decoder.decode(AppBoxRemoteCatalog.self, from: catalogData)
        let groups = AppBoxRemoteCatalogMapper.map(remoteCatalog)
        guard !groups.isEmpty else { throw AppBoxRemoteCatalogError.emptyCatalog }
        return groups
    }
}

enum AppBoxRemoteCatalogError: Error {
    case invalidResponse
    case emptyCatalog
    case invalidKey
    case invalidEnvelope
}

private struct AppBoxEncryptedEnvelope: Decodable {
    let v: Int
    let k: String
    let n: String
    let t: String
    let d: String
}

private struct AppBoxRemoteCatalog: Decodable {
    let v: Int
    let ts: String?
    let c: [AppBoxRemoteCategory]
}

private struct AppBoxRemoteCategory: Decodable {
    let id: String
    let n: String
    let g: [AppBoxRemoteGroup]
}

private struct AppBoxRemoteGroup: Decodable {
    let id: String
    let n: String
    let a: [AppBoxRemoteApp]
}

private struct AppBoxRemoteApp: Decodable {
    let id: String
    let n: String
    let t: String
    let icon: String
    let url: String?
    let b: String?
}

enum AppBoxClientCryptoConfig {
    static let clientKeyBase64 = "6btlrID18OytwUZ0s41atap+4WxlXr1xpebjrE04hnY="
}

private enum AppBoxCatalogCrypto {
    static func decrypt(_ envelope: AppBoxEncryptedEnvelope) throws -> Data {
        guard envelope.v == 1,
              let keyData = Data(base64Encoded: AppBoxClientCryptoConfig.clientKeyBase64) else {
            throw AppBoxRemoteCatalogError.invalidKey
        }

        let nonceData = try Data(appBoxBase64URLEncoded: envelope.n)
        let tagData = try Data(appBoxBase64URLEncoded: envelope.t)
        let cipherData = try Data(appBoxBase64URLEncoded: envelope.d)
        let nonce = try AES.GCM.Nonce(data: nonceData)
        let sealedBox = try AES.GCM.SealedBox(nonce: nonce, ciphertext: cipherData, tag: tagData)
        return try AES.GCM.open(sealedBox, using: SymmetricKey(data: keyData))
    }
}

private enum AppBoxRemoteCatalogMapper {
    static func map(_ catalog: AppBoxRemoteCatalog) -> [AppBoxCatalogGroup] {
        catalog.c.flatMap { category in
            category.g.compactMap { group in
                let items = group.a.compactMap { app in
                    item(from: app, category: category, group: group)
                }
                guard !items.isEmpty else { return nil }
                let series = series(for: category.id)
                let section = section(for: group.id)
                return AppBoxCatalogGroup(
                    id: "\(category.id).\(group.id)",
                    series: series,
                    section: section,
                    chineseName: group.n,
                    englishName: group.n,
                    items: items
                )
            }
        }
    }

    private static func item(
        from app: AppBoxRemoteApp,
        category: AppBoxRemoteCategory,
        group: AppBoxRemoteGroup
    ) -> AppBoxCatalogItem? {
        guard let iconURL = URL(string: app.icon) else { return nil }

        let series = series(for: category.id)
        let section = section(for: group.id)
        let source: AppBoxAppSource
        switch app.t.lowercased() {
        case "ipa":
            source = .ipa(downloadURL: app.url.flatMap(URL.init(string:)))
        case "web":
            guard let url = app.url.flatMap(URL.init(string:)) else { return nil }
            source = .web(entryURL: url)
        default:
            return nil
        }

        return AppBoxCatalogItem(
            id: app.id,
            bundleIdentifier: app.b,
            chineseName: app.n,
            englishName: app.n,
            series: series,
            section: section,
            icon: icon(for: app.t, groupID: group.id),
            iconStyle: style(for: category.id, groupID: group.id),
            remoteIconURL: iconURL,
            source: source
        )
    }

    private static func series(for categoryID: String) -> AppBoxSeries {
        switch categoryID.lowercased() {
        case "entertainment", "games", "game", "media":
            return .entertainment
        case "lifestyle", "life":
            return .lifestyle
        default:
            return .tools
        }
    }

    private static func section(for groupID: String) -> AppBoxSection {
        switch groupID.lowercased() {
        case "wallet", "tool", "tools", "productivity":
            return .productivity
        case "media", "video", "music":
            return .media
        case "social", "community", "chat":
            return .community
        case "game", "games", "casino":
            return .games
        default:
            return .lifestyle
        }
    }

    private static func icon(for type: String, groupID: String) -> AppBoxIcon {
        if type.lowercased() == "web" { return .cloud }

        switch groupID.lowercased() {
        case "wallet": return .bag
        case "games", "game", "casino": return .category
        case "media", "video": return .playCircle
        default: return .apps
        }
    }

    private static func style(for categoryID: String, groupID: String) -> AppBoxIconStyle {
        switch (categoryID.lowercased(), groupID.lowercased()) {
        case (_, "wallet"):
            return .blue
        case ("entertainment", _), (_, "games"), (_, "game"):
            return .gold
        case ("lifestyle", _):
            return .mint
        default:
            return .indigo
        }
    }
}

private extension Data {
    init(appBoxBase64URLEncoded value: String) throws {
        var base64 = value
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        let padding = base64.count % 4
        if padding > 0 {
            base64.append(String(repeating: "=", count: 4 - padding))
        }
        guard let data = Data(base64Encoded: base64) else {
            throw AppBoxRemoteCatalogError.invalidEnvelope
        }
        self = data
    }
}
