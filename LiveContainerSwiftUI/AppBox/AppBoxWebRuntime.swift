import Foundation
import WebKit

@MainActor
protocol AppBoxWebDataManaging: AnyObject {
    func removeData(for item: AppBoxCatalogItem) async throws
}

@MainActor
final class AppBoxWebDataStore: AppBoxWebDataManaging {
    static let shared = AppBoxWebDataStore()

    private let defaults: UserDefaults
    private let identifiersKey = "appbox.web.dataStoreIdentifiers"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func websiteDataStore(for itemID: String) -> WKWebsiteDataStore {
        guard #available(iOS 17.0, *) else {
            return .default()
        }
        return WKWebsiteDataStore(forIdentifier: identifier(for: itemID))
    }

    func removeData(for item: AppBoxCatalogItem) async throws {
        guard let entryURL = item.source.webEntryURL else { return }

        if #available(iOS 17.0, *) {
            guard let identifier = existingIdentifier(for: item.id) else { return }
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                WKWebsiteDataStore.remove(forIdentifier: identifier) { error in
                    if let error {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                }
            }
            removeIdentifier(for: item.id)
            return
        }

        guard let host = entryURL.host?.lowercased() else { return }
        let store = WKWebsiteDataStore.default()
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let records = await withCheckedContinuation { continuation in
            store.fetchDataRecords(ofTypes: dataTypes) { continuation.resume(returning: $0) }
        }
        let matchingRecords = records.filter { record in
            let displayName = record.displayName.lowercased()
            return host == displayName || host.hasSuffix(".\(displayName)")
        }
        guard !matchingRecords.isEmpty else { return }
        await withCheckedContinuation { continuation in
            store.removeData(ofTypes: dataTypes, for: matchingRecords) {
                continuation.resume()
            }
        }
    }

    private func identifier(for itemID: String) -> UUID {
        if let identifier = existingIdentifier(for: itemID) {
            return identifier
        }
        let identifier = UUID()
        var identifiers = storedIdentifiers
        identifiers[itemID] = identifier.uuidString
        defaults.set(identifiers, forKey: identifiersKey)
        return identifier
    }

    private func existingIdentifier(for itemID: String) -> UUID? {
        guard let value = storedIdentifiers[itemID] else { return nil }
        return UUID(uuidString: value)
    }

    private func removeIdentifier(for itemID: String) {
        var identifiers = storedIdentifiers
        guard identifiers.removeValue(forKey: itemID) != nil else { return }
        defaults.set(identifiers, forKey: identifiersKey)
    }

    private var storedIdentifiers: [String: String] {
        defaults.dictionary(forKey: identifiersKey) as? [String: String] ?? [:]
    }
}
