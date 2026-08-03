import Foundation

@MainActor
final class AppBoxStore: ObservableObject {
    @Published private(set) var simulatedInstalledIDs: Set<String>
    @Published private(set) var installingIDs: Set<String> = []
    @Published var pendingInstallRequest: AppBoxInstallRequest?
    @Published var notice: AppBoxNotice?

    private let defaults: UserDefaults
    private let installedIDsKey = "appbox.simulator.installedIDs"
    private let bridge: any AppBoxContainerBridging

    init(
        defaults: UserDefaults = .standard,
        bridge: (any AppBoxContainerBridging)? = nil
    ) {
        self.defaults = defaults
        self.bridge = bridge ?? AppBoxContainerBridge()
#if targetEnvironment(simulator)
        simulatedInstalledIDs = Set(defaults.stringArray(forKey: installedIDsKey) ?? [])
#else
        simulatedInstalledIDs = []
#endif
    }

    func isInstalled(_ item: AppBoxCatalogItem, hostApps: [LCAppModel]) -> Bool {
        bridge.isInstalled(item, in: hostApps) || simulatedInstalledIDs.contains(item.id)
    }

    func installedItems(hostApps: [LCAppModel]) -> [AppBoxCatalogItem] {
        AppBoxCatalog.items.filter { isInstalled($0, hostApps: hostApps) }
    }

    func install(_ item: AppBoxCatalogItem, hostApps: [LCAppModel]) async {
        guard pendingInstallRequest == nil,
              !isInstalled(item, hostApps: hostApps),
              !installingIDs.contains(item.id) else { return }
        installingIDs.insert(item.id)

#if targetEnvironment(simulator)
        defer { installingIDs.remove(item.id) }
        try? await Task.sleep(nanoseconds: 850_000_000)
        guard !Task.isCancelled else { return }
        if simulatedInstalledIDs.insert(item.id).inserted {
            persistSimulatedInstalledIDs()
        }
        notice = .installed(item.id)
#else
        guard item.downloadURL != nil else {
            installingIDs.remove(item.id)
            notice = .missingDownloadURL
            return
        }
        pendingInstallRequest = .catalog(item: item)
#endif
    }

    func launch(_ item: AppBoxCatalogItem, hostApps: [LCAppModel]) async {
        do {
            if try await bridge.launch(item, in: hostApps) { return }
#if targetEnvironment(simulator)
            guard simulatedInstalledIDs.contains(item.id) else {
                notice = .notInstalled
                return
            }
            notice = .launched(item.id)
#else
            notice = .notInstalled
#endif
        } catch {
            notice = .launchFailed(error.localizedDescription)
        }
    }

    func removeSimulatedInstall(_ item: AppBoxCatalogItem) {
#if targetEnvironment(simulator)
        if simulatedInstalledIDs.remove(item.id) != nil {
            persistSimulatedInstalledIDs()
        }
#endif
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

    private func persistSimulatedInstalledIDs() {
        let value = simulatedInstalledIDs.sorted()
        guard defaults.stringArray(forKey: installedIDsKey) != value else { return }
        defaults.set(value, forKey: installedIDsKey)
    }
}
