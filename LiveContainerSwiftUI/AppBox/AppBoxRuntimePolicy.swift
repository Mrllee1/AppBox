import Foundation

enum AppBoxRuntimePolicy {
    static var allowsDistributionSigning: Bool {
        Bundle.main.object(forInfoDictionaryKey: "AppBoxAllowsDistributionSigning") as? Bool ?? false
    }
}
