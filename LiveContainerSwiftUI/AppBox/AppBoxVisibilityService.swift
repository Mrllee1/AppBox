import FamilyControls
import Foundation
import ManagedSettings

@MainActor
final class AppBoxVisibilityService: ObservableObject {
    @Published private(set) var authorizationStatus: AuthorizationStatus
    @Published var selection: FamilyActivitySelection {
        didSet {
            persistSelection()
            lastError = nil
            if isHidden { applySelection() }
        }
    }
    @Published private(set) var isHidden: Bool
    @Published private(set) var lastError: String?

    private let authorizationCenter: AuthorizationCenter
    private let settingsStore: ManagedSettingsStore
    private let defaults: UserDefaults
    private let selectionKey = "AppBox.visibility.selection.v2"
    private let hiddenKey = "AppBox.visibility.isHidden"

    init(
        authorizationCenter: AuthorizationCenter = .shared,
        settingsStore: ManagedSettingsStore = ManagedSettingsStore(),
        defaults: UserDefaults = .standard
    ) {
        self.authorizationCenter = authorizationCenter
        self.settingsStore = settingsStore
        self.defaults = defaults
        authorizationStatus = authorizationCenter.authorizationStatus
        selection = Self.loadSelection(from: defaults, key: selectionKey)
        isHidden = defaults.bool(forKey: hiddenKey)

        if isHidden { applySelection() }
    }

    var isAuthorized: Bool {
        if authorizationStatus == .approved {
            return true
        }
        if #available(iOS 26.4, *), authorizationStatus == .approvedWithDataAccess {
            return true
        }
        return false
    }

    var selectedApplicationCount: Int {
        max(selection.applications.count, selection.applicationTokens.count)
    }

    var selectedCategoryCount: Int {
        selection.categoryTokens.count
    }

    var selectedWebDomainCount: Int {
        selection.webDomainTokens.count
    }

    var hasSelection: Bool {
        selectedApplicationCount > 0 || selectedCategoryCount > 0 || selectedWebDomainCount > 0
    }

    var canHideSelection: Bool {
        isAuthorized && hasSelection
    }

    func refreshAuthorizationStatus() {
        authorizationStatus = authorizationCenter.authorizationStatus
    }

    @discardableResult
    func requestAuthorizationIfNeeded() async -> Bool {
        refreshAuthorizationStatus()
        if isAuthorized { return true }

        do {
            if #available(iOS 16.0, *) {
                try await authorizationCenter.requestAuthorization(for: .individual)
            } else {
                try await withCheckedThrowingContinuation { continuation in
                    authorizationCenter.requestAuthorization { result in
                        continuation.resume(with: result)
                    }
                }
            }
            refreshAuthorizationStatus()
            lastError = isAuthorized ? nil : "Screen Time authorization was not approved."
        } catch {
            refreshAuthorizationStatus()
            lastError = error.localizedDescription
        }

        return isAuthorized
    }

    func hideSelection() async {
        guard await requestAuthorizationIfNeeded() else { return }
        guard hasSelection else {
            lastError = "No apps selected."
            return
        }

        applySelection()
        isHidden = true
        defaults.set(true, forKey: hiddenKey)
        lastError = nil
    }

    func restoreAll() {
        settingsStore.application.blockedApplications = nil
        settingsStore.shield.applications = nil
        settingsStore.shield.applicationCategories = nil
        settingsStore.shield.webDomains = nil
        settingsStore.shield.webDomainCategories = nil
        isHidden = false
        defaults.set(false, forKey: hiddenKey)
        lastError = nil
    }

    func clearSelection() {
        selection = FamilyActivitySelection(includeEntireCategory: false)
        restoreAll()
    }

    private func applySelection() {
        let applications = selection.applications
        settingsStore.application.blockedApplications = applications.isEmpty ? nil : applications

        let categoryTokens = selection.categoryTokens
        settingsStore.shield.applicationCategories = categoryTokens.isEmpty ? nil : .specific(categoryTokens)

        let webDomainTokens = selection.webDomainTokens
        settingsStore.shield.webDomains = webDomainTokens.isEmpty ? nil : webDomainTokens
    }

    private func persistSelection() {
        do {
            let data = try JSONEncoder().encode(selection)
            defaults.set(data, forKey: selectionKey)
        } catch {
            lastError = error.localizedDescription
        }
    }

    private static func loadSelection(from defaults: UserDefaults, key: String) -> FamilyActivitySelection {
        guard let data = defaults.data(forKey: key),
              let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
            return FamilyActivitySelection(includeEntireCategory: false)
        }
        return selection
    }
}
