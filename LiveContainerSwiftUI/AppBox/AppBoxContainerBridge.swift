import Foundation

@MainActor
protocol AppBoxContainerBridging {
    func isInstalled(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) -> Bool
    func launch(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) async throws -> Bool
}

@MainActor
struct AppBoxContainerBridge: AppBoxContainerBridging {
    func hostApp(for item: AppBoxCatalogItem, in apps: [LCAppModel]) -> LCAppModel? {
        apps.first { $0.bundleIdentifier == item.bundleIdentifier }
    }

    func isInstalled(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) -> Bool {
        hostApp(for: item, in: apps) != nil
    }

    func launch(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) async throws -> Bool {
        guard let app = hostApp(for: item, in: apps) else { return false }
        try await app.runApp()
        return true
    }
}
