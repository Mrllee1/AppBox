import Foundation

@MainActor
protocol AppBoxContainerBridging {
    func isInstalled(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) -> Bool
    func install(
        _ item: AppBoxCatalogItem,
        progress: @escaping @MainActor (AppBoxInstallState) -> Void
    ) async throws -> LCAppModel
    func cancelInstall(for item: AppBoxCatalogItem)
    func launch(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) async throws -> Bool
}

@MainActor
struct AppBoxContainerBridge: AppBoxContainerBridging {
    private let installer: any AppBoxIPAInstalling

    init(installer: (any AppBoxIPAInstalling)? = nil) {
        self.installer = installer ?? AppBoxIPAInstallService()
    }

    func hostApp(for item: AppBoxCatalogItem, in apps: [LCAppModel]) -> LCAppModel? {
        guard case .ipa = item.source,
              let bundleIdentifier = item.bundleIdentifier else { return nil }
        return apps.first { $0.bundleIdentifier == bundleIdentifier }
    }

    func isInstalled(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) -> Bool {
        hostApp(for: item, in: apps) != nil
    }

    func install(
        _ item: AppBoxCatalogItem,
        progress: @escaping @MainActor (AppBoxInstallState) -> Void
    ) async throws -> LCAppModel {
        guard let sourceURL = item.source.ipaDownloadURL,
              let bundleIdentifier = item.bundleIdentifier else {
            throw AppBoxIPAInstallError.invalidResponse
        }
        return try await installer.install(
            AppBoxIPAInstallRequest(
                id: item.id,
                sourceURL: sourceURL,
                expectedBundleIdentifier: bundleIdentifier
            ),
            progress: progress
        )
    }

    func cancelInstall(for item: AppBoxCatalogItem) {
        installer.cancel(requestID: item.id)
    }

    func launch(_ item: AppBoxCatalogItem, in apps: [LCAppModel]) async throws -> Bool {
        guard let app = hostApp(for: item, in: apps) else { return false }
        AppBoxGuestLaunchPreparation.prepareUserDefaults()
        try await app.runApp()
        return true
    }
}
