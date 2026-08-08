import Foundation

@MainActor
final class AppBoxStore: ObservableObject {
    @Published private(set) var localInstalledIDs: Set<String>
    @Published private(set) var installStates: [String: AppBoxInstallState] = [:]
    @Published private(set) var catalogGroups: [AppBoxCatalogGroup]
    @Published var pendingInstallRequest: AppBoxInstallRequest?
    @Published var activeWebApp: AppBoxCatalogItem?
    @Published private(set) var launchState: AppBoxLaunchState?
    @Published var notice: AppBoxNotice?

    private let bridge: any AppBoxContainerBridging
    private let localInstallStore: any AppBoxLocalInstallPersisting
    private let webDataManager: any AppBoxWebDataManaging
    private let catalogService: any AppBoxCatalogFetching
    private var didAttemptCatalogRefresh = false
    private var installTasks: [String: Task<Void, Never>] = [:]
    private var installTokens: [String: UUID] = [:]
    private var launchAfterInstallIDs: Set<String> = []

    init(
        defaults: UserDefaults = .standard,
        bridge: (any AppBoxContainerBridging)? = nil,
        localInstallStore: (any AppBoxLocalInstallPersisting)? = nil,
        webDataManager: (any AppBoxWebDataManaging)? = nil,
        catalogService: (any AppBoxCatalogFetching)? = nil
    ) {
        self.bridge = bridge ?? AppBoxContainerBridge()
        let resolvedLocalStore = localInstallStore ?? AppBoxLocalInstallStore(defaults: defaults)
        self.localInstallStore = resolvedLocalStore
        self.webDataManager = webDataManager ?? AppBoxWebDataStore.shared
        self.catalogService = catalogService ?? AppBoxRemoteCatalogService()
        self.catalogGroups = []
        localInstalledIDs = resolvedLocalStore.installedIDs
    }

    private var catalogItems: [AppBoxCatalogItem] {
        catalogGroups.flatMap(\.items)
    }

    var catalogSeries: [AppBoxSeries] {
        catalogGroups.reduce(into: [AppBoxSeries]()) { result, group in
            if !result.contains(where: { $0.id == group.series.id }) {
                result.append(group.series)
            }
        }
    }

    func refreshCatalogIfNeeded() async {
        guard !didAttemptCatalogRefresh else { return }
        didAttemptCatalogRefresh = true
        await refreshCatalog()
    }

    func refreshCatalog() async {
        recordRuntimeState("catalog-refresh-start")
        do {
            catalogGroups = try await catalogService.fetchCatalogGroups()
            recordRuntimeState("catalog-refresh-success|groups=\(catalogGroups.count)|items=\(catalogItems.count)")
        } catch {
            catalogGroups = []
            recordRuntimeState("catalog-refresh-failed|\(error.localizedDescription)|items=0")
        }
    }

    func catalogGroups(seriesID: String?, query: String, language: AppBoxLanguage) -> [AppBoxCatalogGroup] {
        AppBoxCatalog.filter(groups: catalogGroups, seriesID: seriesID, query: query)
    }

    func item(id: String) -> AppBoxCatalogItem? {
        catalogItems.first { $0.id == id }
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
        catalogItems.filter { isInstalled($0, hostApps: hostApps) }
    }

    func startInstall(
        _ item: AppBoxCatalogItem,
        sharedModel: SharedModel,
        launchAfterInstall: Bool = false
    ) {
        guard !isInstalled(item, hostApps: sharedModel.apps),
              installStates[item.id]?.isActive != true else { return }
        recordRuntimeState("install-start|\(item.id)|launchAfter=\(launchAfterInstall)")

        let token = UUID()
        installTokens[item.id] = token
        if launchAfterInstall {
            launchAfterInstallIDs.insert(item.id)
        } else {
            launchAfterInstallIDs.remove(item.id)
        }
        notice = nil
        switch item.source {
        case .web:
            if localInstallStore.install(item.id) {
                localInstalledIDs = localInstallStore.installedIDs
            }
            completeInstall(item, token: token)
            if launchAfterInstall {
                launchAfterInstallIDs.remove(item.id)
                Task { [weak self, weak sharedModel] in
                    guard let self, let sharedModel else { return }
                    try? await Task.sleep(nanoseconds: 300_000_000)
                    await self.launch(item, hostApps: sharedModel.apps)
                }
            }

        case .ipa(let downloadURL):
            guard downloadURL != nil else {
                installTokens[item.id] = nil
                launchAfterInstallIDs.remove(item.id)
                installStates[item.id] = .failed(message: "No download URL configured")
                notice = .missingDownloadURL
                recordRuntimeState("install-missing-url|\(item.id)")
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
        launchAfterInstallIDs.remove(item.id)
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
            recordRuntimeState("ipa-install-performing|\(item.id)")
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
            recordRuntimeState("ipa-install-success|\(item.id)|bundle=\(installedApp.bundleIdentifier)")
#endif
            completeInstall(item, token: token)
            if launchAfterInstallIDs.remove(item.id) != nil {
                try await Task.sleep(nanoseconds: 450_000_000)
                try Task.checkCancellation()
                await launch(item, hostApps: sharedModel.apps)
            }
        } catch is CancellationError {
            recordRuntimeState("install-cancelled|\(item.id)")
            guard installTokens[item.id] == token else { return }
            installStates[item.id] = nil
            installTokens[item.id] = nil
            launchAfterInstallIDs.remove(item.id)
            installTasks[item.id] = nil
        } catch {
            recordRuntimeState("install-failed|\(item.id)|\(error.localizedDescription)")
            guard installTokens[item.id] == token else { return }
            installStates[item.id] = .failed(message: error.localizedDescription)
            installTokens[item.id] = nil
            launchAfterInstallIDs.remove(item.id)
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

    func handleExternalIntent(_ intent: AppBoxExternalIntent, sharedModel: SharedModel) async {
        recordRuntimeState("external-start|\(intent.debugDescription)")
        await refreshCatalogIfNeeded()

        switch intent {
        case .install(let sourceURL):
            recordRuntimeState("external-install|\(sourceURL?.absoluteString ?? "picker")")
            requestExternalInstall(url: sourceURL)
        case .openItem(let id, let launchAfterInstall):
            guard let item = item(id: id) else {
                notice = .notInstalled
                recordRuntimeState("external-open-missing|\(id)")
                return
            }
            recordRuntimeState("external-open-resolved|\(item.id)")
            await openOrInstall(item, sharedModel: sharedModel, launchAfterInstall: launchAfterInstall)
        case .native(let payload):
            guard let id = AppBoxNativeRouteResolver.itemID(for: payload, items: catalogItems),
                  let item = item(id: id) else {
                notice = .notInstalled
                recordRuntimeState("external-native-missing|appID=\(payload.appID ?? "nil")|items=\(catalogItems.count)")
                return
            }
            recordRuntimeState("external-native-resolved|\(item.id)|items=\(catalogItems.count)")
            await openOrInstall(item, sharedModel: sharedModel, launchAfterInstall: true)
        }
    }

    private func openOrInstall(
        _ item: AppBoxCatalogItem,
        sharedModel: SharedModel,
        launchAfterInstall: Bool
    ) async {
        if isInstalled(item, hostApps: sharedModel.apps) {
            recordRuntimeState("open-installed|\(item.id)")
            await launch(item, hostApps: sharedModel.apps)
        } else {
            recordRuntimeState("open-needs-install|\(item.id)")
            startInstall(item, sharedModel: sharedModel, launchAfterInstall: launchAfterInstall)
        }
    }

    func launch(_ item: AppBoxCatalogItem, hostApps: [LCAppModel]) async {
        guard launchState == nil else { return }
        guard isInstalled(item, hostApps: hostApps) else {
            notice = .notInstalled
            recordRuntimeState("launch-not-installed|\(item.id)")
            return
        }

        notice = nil
        launchState = AppBoxLaunchState(item: item, phase: .preparing)
        recordRuntimeState("launch-start|\(item.id)")

        do {
            try await advanceLaunch(to: .verifying, after: 300_000_000)
            try await advanceLaunch(to: .launching, after: 400_000_000)
            try await advanceLaunch(to: .ready, after: 420_000_000)
            try await Task.sleep(nanoseconds: 220_000_000)
            try Task.checkCancellation()
            launchState = nil

            if case .web = item.source {
                activeWebApp = item
                recordRuntimeState("launch-web|\(item.id)")
                return
            }

            if try await bridge.launch(item, in: hostApps) {
                recordRuntimeState("launch-guest-dispatched|\(item.id)")
                return
            }
#if targetEnvironment(simulator)
            notice = .launched(item.id)
#else
            notice = .notInstalled
            recordRuntimeState("launch-guest-missing|\(item.id)")
#endif
        } catch is CancellationError {
            launchState = nil
            recordRuntimeState("launch-cancelled|\(item.id)")
        } catch {
            launchState = nil
            notice = .launchFailed(error.localizedDescription)
            recordRuntimeState("launch-failed|\(item.id)|\(error.localizedDescription)")
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

    private func recordRuntimeState(_ state: String) {
        let defaults = UserDefaults.standard
        defaults.set(state, forKey: "AppBox.lastRuntimeState")
        defaults.set(Date(), forKey: "AppBox.lastRuntimeStateDate")
        defaults.synchronize()
    }
}

private extension AppBoxExternalIntent {
    var debugDescription: String {
        switch self {
        case .install(let url):
            return "install:\(url?.absoluteString ?? "picker")"
        case .openItem(let id, let launchAfterInstall):
            return "open:\(id):launch=\(launchAfterInstall)"
        case .native(let payload):
            return "native:appID=\(payload.appID ?? "nil"):platform=\(payload.platform ?? "nil")"
        }
    }
}
