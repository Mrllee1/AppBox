import Foundation

enum AppBoxRuntimePolicy {
    private static let codeEntitlements: [String: Any] = {
        guard let entitlementXML = getLCEntitlementXML(),
              let data = entitlementXML.data(using: .utf8),
              let plist = try? PropertyListSerialization.propertyList(from: data, options: [], format: nil),
              let entitlements = plist as? [String: Any] else {
            return [:]
        }
        return entitlements
    }()

    static var allowsDistributionSigning: Bool {
        Bundle.main.object(forInfoDictionaryKey: "AppBoxAllowsDistributionSigning") as? Bool ?? false
    }

    static var applicationIdentifier: String? {
        if let identifier = codeEntitlements["application-identifier"] as? String,
           !identifier.isEmpty {
            return identifier
        }
        return Bundle.main.object(forInfoDictionaryKey: "AppBoxApplicationIdentifier") as? String
    }

    static var getTaskAllow: Bool {
        codeEntitlements["get-task-allow"] as? Bool ?? false
    }
}
