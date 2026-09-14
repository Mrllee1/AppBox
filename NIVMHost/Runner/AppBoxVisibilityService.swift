import Combine
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
      if isRestrictionActive {
        applySelection()
      }
    }
  }
  @Published private(set) var isRestrictionActive: Bool
  @Published private(set) var quickSessionEnd: Date?
  @Published private(set) var lastError: String?

  private let authorizationCenter: AuthorizationCenter
  private let settingsStore: ManagedSettingsStore
  private let defaults: UserDefaults
  private let selectionKey = AppBoxSharedStore.selectionKey
  private let restrictionKey = AppBoxSharedStore.restrictionKey
  private let legacyHiddenKey = "AppBox.visibility.isHidden"
  private let namedStoreMigrationKey = "Quietform.managedStore.namedMigration.v1"

  init(
    authorizationCenter: AuthorizationCenter = .shared,
    settingsStore: ManagedSettingsStore = ManagedSettingsStore(
      named: ManagedSettingsStore.Name(AppBoxSharedStore.managedStoreName)
    ),
    defaults: UserDefaults = AppBoxSharedStore.defaults
  ) {
    AppBoxSharedStore.migrateStandardValuesIfNeeded(
      keys: [
        AppBoxSharedStore.selectionKey,
        AppBoxSharedStore.restrictionKey,
        AppBoxSharedStore.manualRestrictionKey,
        AppBoxSharedStore.quickSessionEndKey,
      ]
    )
    self.authorizationCenter = authorizationCenter
    self.settingsStore = settingsStore
    self.defaults = defaults
    authorizationStatus = authorizationCenter.authorizationStatus
    selection = Self.loadSelection(from: defaults, key: selectionKey)
    let hasLegacyState = defaults.object(forKey: legacyHiddenKey) != nil
      || UserDefaults.standard.object(forKey: legacyHiddenKey) != nil
    isRestrictionActive = defaults.object(forKey: restrictionKey) as? Bool
      ?? defaults.bool(forKey: legacyHiddenKey)
    quickSessionEnd = defaults.object(forKey: AppBoxSharedStore.quickSessionEndKey) as? Date

    if !defaults.bool(forKey: namedStoreMigrationKey) {
      ManagedSettingsStore().clearAllSettings()
      defaults.set(true, forKey: namedStoreMigrationKey)
    }

    // Clear the previous Home Screen hiding state once during migration, then
    // reapply only the system shielding behavior accepted for focus controls.
    if hasLegacyState {
      settingsStore.clearAllSettings()
      defaults.removeObject(forKey: legacyHiddenKey)
      UserDefaults.standard.removeObject(forKey: legacyHiddenKey)
      defaults.set(isRestrictionActive, forKey: restrictionKey)
    }

    if isRestrictionActive {
      applySelection()
    }
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
    selection.applicationTokens.count
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

  var isQuickSessionActive: Bool {
    guard let quickSessionEnd else { return false }
    return quickSessionEnd > Date()
  }

  var isManualRestrictionActive: Bool {
    defaults.bool(forKey: AppBoxSharedStore.manualRestrictionKey)
  }

  func refreshAuthorizationStatus() {
    authorizationStatus = authorizationCenter.authorizationStatus
  }

  func refreshSharedState(at date: Date = Date()) {
    let storedEnd = defaults.object(forKey: AppBoxSharedStore.quickSessionEndKey) as? Date
    if let storedEnd, storedEnd <= date {
      defaults.removeObject(forKey: AppBoxSharedStore.quickSessionEndKey)
      quickSessionEnd = nil
    } else {
      quickSessionEnd = storedEnd
    }
    isRestrictionActive = defaults.bool(forKey: restrictionKey)
  }

  @discardableResult
  func requestAuthorizationIfNeeded() async -> Bool {
    refreshAuthorizationStatus()
    if isAuthorized {
      return true
    }

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
      lastError = isAuthorized ? nil : "未获得屏幕使用时间授权"
    } catch {
      refreshAuthorizationStatus()
      lastError = error.localizedDescription
    }
    return isAuthorized
  }

  func activateRestrictions() async {
    guard await requestAuthorizationIfNeeded() else {
      return
    }
    guard hasSelection else {
      lastError = "请先选择需要限制的 App"
      return
    }

    defaults.set(true, forKey: AppBoxSharedStore.manualRestrictionKey)
    defaults.removeObject(forKey: AppBoxSharedStore.quickSessionEndKey)
    quickSessionEnd = nil
    applySelection()
    isRestrictionActive = true
    defaults.set(true, forKey: restrictionKey)
    lastError = nil
  }

  @discardableResult
  func startQuickSession(minutes: Int, now: Date = Date()) async -> Date? {
    guard await requestAuthorizationIfNeeded() else { return nil }
    guard hasSelection else {
      lastError = "请先选择需要限制的 App"
      return nil
    }

    let duration = max(15, minutes)
    guard let end = Calendar.current.date(byAdding: .minute, value: duration, to: now) else {
      lastError = "无法创建专注时段"
      return nil
    }
    defaults.set(false, forKey: AppBoxSharedStore.manualRestrictionKey)
    defaults.set(end, forKey: AppBoxSharedStore.quickSessionEndKey)
    quickSessionEnd = end
    applySelection()
    isRestrictionActive = true
    defaults.set(true, forKey: restrictionKey)
    lastError = nil
    return end
  }

  func activateAutomatedRestrictions() async {
    guard await requestAuthorizationIfNeeded(), hasSelection else { return }
    applySelection()
    isRestrictionActive = true
    defaults.set(true, forKey: restrictionKey)
    lastError = nil
  }

  func reconcileScheduleState(isActive: Bool) async {
    if isActive {
      await activateAutomatedRestrictions()
      return
    }
    guard !isManualRestrictionActive, !isQuickSessionActive else { return }
    settingsStore.clearAllSettings()
    isRestrictionActive = false
    defaults.set(false, forKey: restrictionKey)
    lastError = nil
  }

  func restoreAll() {
    settingsStore.clearAllSettings()
    defaults.set(false, forKey: AppBoxSharedStore.manualRestrictionKey)
    defaults.removeObject(forKey: AppBoxSharedStore.quickSessionEndKey)
    quickSessionEnd = nil
    isRestrictionActive = false
    defaults.set(false, forKey: restrictionKey)
    lastError = nil
  }

  func clearSelection() {
    selection = FamilyActivitySelection(includeEntireCategory: false)
    restoreAll()
  }

  private func applySelection() {
    let applications = selection.applicationTokens
    settingsStore.shield.applications = applications.isEmpty ? nil : applications

    let categories = selection.categoryTokens
    settingsStore.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)

    let webDomains = selection.webDomainTokens
    settingsStore.shield.webDomains = webDomains.isEmpty ? nil : webDomains
  }

  private func persistSelection() {
    do {
      defaults.set(try JSONEncoder().encode(selection), forKey: selectionKey)
    } catch {
      lastError = error.localizedDescription
    }
  }

  private static func loadSelection(
    from defaults: UserDefaults,
    key: String
  ) -> FamilyActivitySelection {
    guard let data = defaults.data(forKey: key),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return FamilyActivitySelection(includeEntireCategory: false)
    }
    return selection
  }
}
