import Foundation

@MainActor
final class AppBoxStore: ObservableObject {
    @Published private(set) var localInstalledIDs: Set<String>
    @Published private(set) var installStates: [String: AppBoxInstallState] = [:]
    @Published var pendingInstallRequest: AppBoxInstallRequest?
    @Published var activeWebApp: AppBoxCatalogItem?
    @Published private(set) var launchState: AppBoxLaunchState?
    @Published var notice: AppBoxNotice?

    private let bridge: any AppBoxContainerBridging
    private let localInstallStore: any AppBoxLocalInstallPersisting
    private let webDataManager: any AppBoxWebDataManaging
    private var installTasks: [String: Task<Void, Never>] = [:]
    private var installTokens: [String: UUID] = [:]

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

    func startInstall(_ item: AppBoxCatalogItem, sharedModel: SharedModel) {
        guard !isInstalled(item, hostApps: sharedModel.apps),
              installStates[item.id]?.isActive != true else { return }

        let token = UUID()
        installTokens[item.id] = token
        notice = nil
        switch item.source {
        case .web:
            if localInstallStore.install(item.id) {
                localInstalledIDs = localInstallStore.installedIDs
            }
            completeInstall(item, token: token)

        case .ipa(let downloadURL):
            guard downloadURL != nil else {
                installTokens[item.id] = nil
                installStates[item.id] = .failed(message: "No download URL configured")
                notice = .missingDownloadURL
                return
            }
            installStates[item.id] = .downloading(progress: 0)
            installTasks[item.id] = Task { [weak self, weak sharedModel] in
                guard let self, let sharedModel else { return }
                await self.performIPAInstall(item, sharedModel: sharedModel, token: token)
            }
        }
    }

    func cancelInstall(_ item: AppBoxCatalogItem) {
        guard installStates[item.id]?.isCancellable == true else { return }
        installTokens[item.id] = nil
        installTasks[item.id]?.cancel()
        installTasks[item.id] = nil
        bridge.cancelInstall(for: item)
        installStates[item.id] = nil
    }

    private func performIPAInstall(
        _ item: AppBoxCatalogItem,
        sharedModel: SharedModel,
        token: UUID
    ) async {
        do {
#if targetEnvironment(simulator)
            for step in 1...10 {
                try await Task.sleep(nanoseconds: 300_000_000)
                try Task.checkCancellation()
                updateInstallState(.downloading(progress: Double(step) / 10), for: item.id, token: token)
            }
            updateInstallState(.processing, for: item.id, token: token)
            try await Task.sleep(nanoseconds: 500_000_000)
            try Task.checkCancellation()
            if localInstallStore.install(item.id) {
                localInstalledIDs = localInstallStore.installedIDs
            }
#else
            let installedApp = try await bridge.install(item) { [weak self] state in
                self?.updateInstallState(state, for: item.id, token: token)
            }
            try Task.checkCancellation()
            guard installTokens[item.id] == token else { return }
            if !sharedModel.apps.contains(where: { $0.bundleIdentifier == installedApp.bundleIdentifier }) {
                sharedModel.apps.append(installedApp)
            }
#endif
            completeInstall(item, token: token)
        } catch is CancellationError {
            guard installTokens[item.id] == token else { return }
            installStates[item.id] = nil
            installTokens[item.id] = nil
            installTasks[item.id] = nil
        } catch {
            guard installTokens[item.id] == token else { return }
            installStates[item.id] = .failed(message: error.localizedDescription)
            installTokens[item.id] = nil
            installTasks[item.id] = nil
            notice = .installFailed(error.localizedDescription)
        }
    }

    private func updateInstallState(_ state: AppBoxInstallState, for itemID: String, token: UUID) {
        guard installTokens[itemID] == token else { return }
        installStates[itemID] = state
    }

    private func completeInstall(_ item: AppBoxCatalogItem, token: UUID) {
        guard installTokens[item.id] == token else { return }
        installStates[item.id] = .completed
        notice = .installed(item.id)
        installTasks[item.id] = nil

        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 650_000_000)
            guard let self, self.installTokens[item.id] == token else { return }
            self.installStates[item.id] = nil
            self.installTokens[item.id] = nil
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
        pendingInstallRequest = nil
    }
}
