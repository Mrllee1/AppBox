import Foundation

struct AppBoxNativePayload: Equatable {
    let data: String?
    let type: String?
    let appID: String?
    let platform: String?
    let appNumber: String?
    let channel: String?
    let referrer: String?
}

enum AppBoxExternalIntent: Equatable {
    case install(URL?)
    case openItem(id: String, launchAfterInstall: Bool)
    case native(AppBoxNativePayload)
}

enum AppBoxDeepLinkParser {
    static func parse(_ url: URL) -> AppBoxExternalIntent? {
        if url.isFileURL {
            return .install(url)
        }

        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            return nil
        }

        let host = (url.host ?? "").lowercased()
        let pathCommand = url.path.trimmingCharacters(in: CharacterSet(charactersIn: "/")).lowercased()
        let command = host.isEmpty ? pathCommand : host

        switch command {
        case "install":
            return .install(queryValue("url", in: components).flatMap(URL.init(string:)))
        case "open":
            guard let id = queryValue("id", in: components) else { return nil }
            return .openItem(id: id, launchAfterInstall: queryBool("launch", in: components) ?? true)
        case "native":
            return .native(
                AppBoxNativePayload(
                    data: queryValue("data", in: components),
                    type: queryValue("type", in: components),
                    appID: queryValue("appId", in: components) ?? queryValue("app_id", in: components),
                    platform: queryValue("plat", in: components),
                    appNumber: queryValue("appNo", in: components) ?? queryValue("app_no", in: components),
                    channel: queryValue("channel", in: components),
                    referrer: queryValue("referrer", in: components)
                )
            )
        default:
            return nil
        }
    }

    private static func queryValue(_ name: String, in components: URLComponents) -> String? {
        components.queryItems?.first { $0.name == name }?.value
    }

    private static func queryBool(_ name: String, in components: URLComponents) -> Bool? {
        guard let value = queryValue(name, in: components)?.lowercased() else { return nil }
        return ["1", "true", "yes"].contains(value)
    }
}

enum AppBoxNativeRouteResolver {
    static func itemID(for payload: AppBoxNativePayload, items: [AppBoxCatalogItem]) -> String? {
        if let data = payload.data,
           let direct = items.first(where: { $0.id == data }) {
            return direct.id
        }

        if let appID = payload.appID,
           let direct = items.first(where: { $0.id == appID }) {
            return direct.id
        }

        switch payload.appID {
        case "3101":
            if items.contains(where: { $0.id == "tianya_selected" }) {
                return "tianya_selected"
            }
            return nil
        default:
            return nil
        }
    }
}
