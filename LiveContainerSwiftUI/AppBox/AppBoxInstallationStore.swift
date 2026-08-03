import Foundation

protocol AppBoxLocalInstallPersisting: AnyObject {
    var installedIDs: Set<String> { get }
    @discardableResult func install(_ id: String) -> Bool
    @discardableResult func remove(_ id: String) -> Bool
}

final class AppBoxLocalInstallStore: AppBoxLocalInstallPersisting {
    private(set) var installedIDs: Set<String>

    private let defaults: UserDefaults
    private let key: String

    init(
        defaults: UserDefaults = .standard,
        key: String = "appbox.local.installedIDs",
        legacyKey: String = "appbox.simulator.installedIDs"
    ) {
        self.defaults = defaults
        self.key = key

        let current = Set(defaults.stringArray(forKey: key) ?? [])
        let legacy = Set(defaults.stringArray(forKey: legacyKey) ?? [])
        installedIDs = current.union(legacy)
        persistIfNeeded()
    }

    @discardableResult
    func install(_ id: String) -> Bool {
        guard installedIDs.insert(id).inserted else { return false }
        persistIfNeeded()
        return true
    }

    @discardableResult
    func remove(_ id: String) -> Bool {
        guard installedIDs.remove(id) != nil else { return false }
        persistIfNeeded()
        return true
    }

    private func persistIfNeeded() {
        let value = installedIDs.sorted()
        guard defaults.stringArray(forKey: key) != value else { return }
        defaults.set(value, forKey: key)
    }
}
