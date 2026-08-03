import Foundation

@MainActor
final class AppBoxStore: ObservableObject {
    @Published private(set) var localInstalledIDs: Set<String>
    @Published private(set) var installingIDs: Set<String> = []
    @Published var pendingInstallRequest: AppBoxInstallRequest?
    @Published var activeWebApp: AppBoxCatalogItem?
    @Published private(set) var launchState: AppBoxLaunchState?
    @Published var notice: AppBoxNotice?

    private let bridge: any AppBoxContainerBridging
    private let localInstallStore: any AppBoxLocalInstallPersisting
    private let webDataManager: any AppBoxWebDataManaging

    init(
        defaults: UserDefaults = .standard,
        bridge: (any AppBoxContainerBridging)? = nil,
        localInstallStore: (any AppBoxLocalInstallPersisting)? = nil,
        webDataManager: (any AppBoxWebDataManaging)? = nil
    ) {
        self.bridge = bridge ?? AppBoxContainerBridge()
        let resolvedLocalStore = localInstallStore ?? AppBoxLocalInstallStore(defaults: defaults)
        self.localInstallStore = resolvedLocalStore
        self.webDataManager = webDataManager ?? AppBoxWebDataStore.shared
        localInstalledIDs = resolvedLocalStore.installedIDs
    }

    func isInstalled(_ item: AppBoxCatalogItem, hostApps: [LCAppModel]) -> Bool {
        switch item.source {
        case .web:
            return localInstalledIDs.contains(item.id)
        case .ipa:
            if bridge.isInstalled(item, in: hostApps) { return true }
#if targetEnvironment(simulator)
            return localInstalledIDs.contains(item.id)
#else
            return false
#endif
        }
    }

    func installedItems(hostApps: [LCAppModel]) -> [AppBoxCatalogItem] {
        AppBoxCatalog.items.filter { isInstalled($0, hostApps: hostApps) }
    }

    func install(_ item: AppBoxCatalogItem, hostApps: [LCAppModel]) async {
        guard pendingInstallRequest == nil,
              !isInstalled(item, hostApps: hostApps),
              !installingIDs.contains(item.id) else { return }
        installingIDs.insert(item.id)

        switch item.source {
        case .web:
            defer { installingIDs.remove(item.id) }
            if localInstallStore.install(item.id) {
                localInstalledIDs = localInstallStore.installedIDs
            }
            notice = .installed(item.id)

        case .ipa(let downloadURL):
#if targetEnvironment(simulator)
            defer { installingIDs.remove(item.id) }
            try? await Task.sleep(nanoseconds: 850_000_000)
            guard !Task.isCancelled else { return }
            if localInstallStore.install(item.id) {
                localInstalledIDs = localInstallStore.installedIDs
            }
            notice = .installed(item.id)
#else
            guard downloadURL != nil else {
                installingIDs.remove(item.id)
                notice = .missingDownloadURL
                return
            }
            pendingInstallRequest = .catalog(item: item)
#endif
        }
    }

    func launch(_ item: AppBoxCatalogItem, hostApps: [LCAppModel]) async {
        guard launchState == nil else { return }
        guard isInstalled(item, hostApps: hostApps) else {
            notice = .notInstalled
            return
        }

        notice = nil
        launchState = AppBoxLaunchState(item: item, phase: .preparing)

        do {
            try await advanceLaunch(to: .verifying, after: 300_000_000)
            try await advanceLaunch(to: .launching, after: 400_000_000)
            try await advanceLaunch(to: .ready, after: 420_000_000)
            try await Task.sleep(nanoseconds: 220_000_000)
            try Task.checkCancellation()
            launchState = nil

            if case .web = item.source {
                activeWebApp = item
                return
            }

            if try await bridge.launch(item, in: hostApps) { return }
#if targetEnvironment(simulator)
            notice = .launched(item.id)
#else
            notice = .notInstalled
#endif
        } catch is CancellationError {
            launchState = nil
        } catch {
            launchState = nil
            notice = .launchFailed(error.localizedDescription)
        }
    }

    private func advanceLaunch(to phase: AppBoxLaunchPhase, after delay: UInt64) async throws {
        try await Task.sleep(nanoseconds: delay)
        try Task.checkCancellation()
        guard launchState != nil else { throw CancellationError() }
        launchState?.phase = phase
    }

    func canRemove(_ item: AppBoxCatalogItem) -> Bool {
        if item.source.isWeb { return true }
#if targetEnvironment(simulator)
        return true
#else
        return false
#endif
    }

    func remove(_ item: AppBoxCatalogItem) async {
        guard canRemove(item), localInstalledIDs.contains(item.id) else { return }

        do {
            if item.source.isWeb {
                try await webDataManager.removeData(for: item)
            }
            if localInstallStore.remove(item.id) {
                localInstalledIDs = localInstallStore.installedIDs
            }
        } catch {
            notice = .launchFailed(error.localizedDescription)
        }
    }

    func requestExternalInstall(url: URL? = nil) {
        let request = AppBoxInstallRequest.external(url: url)
        guard pendingInstallRequest == nil else { return }
        pendingInstallRequest = request
    }

    func finishInstallRequest() {
        installingIDs.removeAll()
        pendingInstallRequest = nil
    }
}
