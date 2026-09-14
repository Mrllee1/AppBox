import DeviceActivity
import FamilyControls
import Foundation
import ManagedSettings

final class QuietformFocusMonitor: DeviceActivityMonitor {
  override func intervalDidStart(for activity: DeviceActivityName) {
    super.intervalDidStart(for: activity)
    QuietformMonitorEnforcement.reconcile()
  }

  override func intervalDidEnd(for activity: DeviceActivityName) {
    super.intervalDidEnd(for: activity)
    if activity.rawValue == QuietformMonitorStorage.quickSessionActivityName {
      QuietformMonitorStorage.defaults.removeObject(forKey: QuietformMonitorStorage.quickSessionEndKey)
      DeviceActivityCenter().stopMonitoring([activity])
    }
    QuietformMonitorEnforcement.reconcile()
  }
}

private enum QuietformMonitorStorage {
  static let groupIdentifier = "group.com.tianya.appbox"
  static let selectionKey = "AppBox.visibility.selection.v2"
  static let restrictionKey = "Quietform.restrictions.isActive"
  static let manualRestrictionKey = "Quietform.restrictions.manual"
  static let quickSessionEndKey = "Quietform.restrictions.quickSessionEnd"
  static let scheduleRulesKey = "AppBox.focus.scheduleRules.v2"
  static let quickSessionActivityName = "quietform.quick-session"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: groupIdentifier) ?? .standard
  }
}

private enum QuietformMonitorEnforcement {
  static func reconcile(at date: Date = Date(), calendar: Calendar = .current) {
    let defaults = QuietformMonitorStorage.defaults
    let selection = loadSelection(defaults: defaults)
    let manualActive = defaults.bool(forKey: QuietformMonitorStorage.manualRestrictionKey)
    let quickSessionEnd = defaults.object(forKey: QuietformMonitorStorage.quickSessionEndKey) as? Date
    let quickSessionActive = (quickSessionEnd ?? .distantPast) > date
    if quickSessionEnd != nil, !quickSessionActive {
      defaults.removeObject(forKey: QuietformMonitorStorage.quickSessionEndKey)
    }

    let scheduleActive = loadSchedules(defaults: defaults).contains {
      $0.isEnabled && $0.contains(date, calendar: calendar)
    }
    let shouldRestrict = manualActive || quickSessionActive || scheduleActive
    let hasSelection = !selection.applicationTokens.isEmpty
      || !selection.categoryTokens.isEmpty
      || !selection.webDomainTokens.isEmpty
    let store = ManagedSettingsStore(
      named: ManagedSettingsStore.Name("quietform.focus")
    )

    guard shouldRestrict, hasSelection else {
      store.clearAllSettings()
      defaults.set(false, forKey: QuietformMonitorStorage.restrictionKey)
      return
    }

    let applications = selection.applicationTokens
    store.shield.applications = applications.isEmpty ? nil : applications
    let categories = selection.categoryTokens
    store.shield.applicationCategories = categories.isEmpty ? nil : .specific(categories)
    let webDomains = selection.webDomainTokens
    store.shield.webDomains = webDomains.isEmpty ? nil : webDomains
    defaults.set(true, forKey: QuietformMonitorStorage.restrictionKey)
  }

  private static func loadSelection(defaults: UserDefaults) -> FamilyActivitySelection {
    guard let data = defaults.data(forKey: QuietformMonitorStorage.selectionKey),
          let selection = try? JSONDecoder().decode(FamilyActivitySelection.self, from: data) else {
      return FamilyActivitySelection(includeEntireCategory: false)
    }
    return selection
  }

  private static func loadSchedules(defaults: UserDefaults) -> [QuietformMonitorScheduleRule] {
    guard let data = defaults.data(forKey: QuietformMonitorStorage.scheduleRulesKey),
          let rules = try? JSONDecoder().decode([QuietformMonitorScheduleRule].self, from: data) else {
      return []
    }
    return rules
  }
}

private struct QuietformMonitorScheduleRule: Decodable {
  let startHour: Int
  let startMinute: Int
  let endHour: Int
  let endMinute: Int
  let weekdays: Set<Int>
  let isEnabled: Bool

  private enum CodingKeys: String, CodingKey {
    case startHour
    case startMinute
    case endHour
    case endMinute
    case weekdays
    case isEnabled
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    startHour = try container.decode(Int.self, forKey: .startHour)
    startMinute = try container.decode(Int.self, forKey: .startMinute)
    endHour = try container.decode(Int.self, forKey: .endHour)
    endMinute = try container.decode(Int.self, forKey: .endMinute)
    weekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? Set(1...7)
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
  }

  func contains(_ date: Date, calendar: Calendar) -> Bool {
    let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
    let weekday = components.weekday ?? 2
    let minute = (components.hour ?? 0) * 60 + (components.minute ?? 0)
    let start = startHour * 60 + startMinute
    let end = endHour * 60 + endMinute

    if start == end { return weekdays.contains(weekday) }
    if start < end {
      return weekdays.contains(weekday) && minute >= start && minute < end
    }
    if minute >= start { return weekdays.contains(weekday) }
    let previousWeekday = weekday == 1 ? 7 : weekday - 1
    return minute < end && weekdays.contains(previousWeekday)
  }
}
