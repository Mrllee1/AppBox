import Combine
import CoreLocation
import Foundation

enum AppBoxSharedStore {
  static let groupIdentifier = "group.com.tianya.appbox"
  static let selectionKey = "AppBox.visibility.selection.v2"
  static let restrictionKey = "Quietform.restrictions.isActive"
  static let manualRestrictionKey = "Quietform.restrictions.manual"
  static let quickSessionEndKey = "Quietform.restrictions.quickSessionEnd"
  static let scheduleRulesKey = "AppBox.focus.scheduleRules.v2"
  static let placeRulesKey = "AppBox.focus.placeRules.v2"
  static let managedStoreName = "quietform.focus"
  static let scheduleActivityPrefix = "quietform.schedule."
  static let quickSessionActivityName = "quietform.quick-session"

  static var defaults: UserDefaults {
    UserDefaults(suiteName: groupIdentifier) ?? .standard
  }

  static func migrateStandardValuesIfNeeded(keys: [String]) {
    guard let shared = UserDefaults(suiteName: groupIdentifier) else { return }
    for key in keys where shared.object(forKey: key) == nil {
      guard let value = UserDefaults.standard.object(forKey: key) else { continue }
      shared.set(value, forKey: key)
    }
  }
}

enum AppBoxWeekday: Int, CaseIterable, Codable, Identifiable {
  case sunday = 1
  case monday
  case tuesday
  case wednesday
  case thursday
  case friday
  case saturday

  var id: Int { rawValue }

  var shortChinese: String {
    switch self {
    case .monday: return "一"
    case .tuesday: return "二"
    case .wednesday: return "三"
    case .thursday: return "四"
    case .friday: return "五"
    case .saturday: return "六"
    case .sunday: return "日"
    }
  }

  var shortEnglish: String {
    switch self {
    case .monday: return "M"
    case .tuesday: return "T"
    case .wednesday: return "W"
    case .thursday: return "T"
    case .friday: return "F"
    case .saturday: return "S"
    case .sunday: return "S"
    }
  }

  static var ordered: [AppBoxWeekday] {
    [.monday, .tuesday, .wednesday, .thursday, .friday, .saturday, .sunday]
  }
}

struct AppBoxPlaceRule: Identifiable, Codable, Equatable {
  enum Trigger: String, Codable, CaseIterable, Identifiable {
    case leave
    case arrive

    var id: String { rawValue }
  }

  let id: String
  var name: String
  var trigger: Trigger
  var isEnabled: Bool
  var createdAt: Date
  var latitude: Double
  var longitude: Double
  var radiusMeters: Double
  var lastTriggeredAt: Date?

  init(
    id: String = UUID().uuidString,
    name: String,
    trigger: Trigger,
    isEnabled: Bool = true,
    createdAt: Date = Date(),
    coordinate: CLLocationCoordinate2D,
    radiusMeters: Double,
    lastTriggeredAt: Date? = nil
  ) {
    self.id = id
    self.name = name
    self.trigger = trigger
    self.isEnabled = isEnabled
    self.createdAt = createdAt
    latitude = coordinate.latitude
    longitude = coordinate.longitude
    self.radiusMeters = min(max(radiusMeters, 100), 1_000)
    self.lastTriggeredAt = lastTriggeredAt
  }

  var coordinate: CLLocationCoordinate2D {
    CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
  }
}

struct AppBoxScheduleRule: Identifiable, Codable, Equatable {
  let id: String
  var name: String
  var startHour: Int
  var startMinute: Int
  var endHour: Int
  var endMinute: Int
  var weekdays: Set<Int>
  var isEnabled: Bool
  var createdAt: Date

  init(
    id: String = UUID().uuidString,
    name: String,
    startHour: Int,
    startMinute: Int,
    endHour: Int,
    endMinute: Int,
    weekdays: Set<Int> = Set(1...7),
    isEnabled: Bool = true,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.startHour = min(max(startHour, 0), 23)
    self.startMinute = min(max(startMinute, 0), 59)
    self.endHour = min(max(endHour, 0), 23)
    self.endMinute = min(max(endMinute, 0), 59)
    self.weekdays = weekdays.isEmpty ? Set(1...7) : weekdays
    self.isEnabled = isEnabled
    self.createdAt = createdAt
  }

  private enum CodingKeys: String, CodingKey {
    case id
    case name
    case startHour
    case startMinute
    case endHour
    case endMinute
    case weekdays
    case isEnabled
    case createdAt
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    id = try container.decode(String.self, forKey: .id)
    name = try container.decode(String.self, forKey: .name)
    startHour = min(max(try container.decode(Int.self, forKey: .startHour), 0), 23)
    startMinute = min(max(try container.decode(Int.self, forKey: .startMinute), 0), 59)
    endHour = min(max(try container.decode(Int.self, forKey: .endHour), 0), 23)
    endMinute = min(max(try container.decode(Int.self, forKey: .endMinute), 0), 59)
    weekdays = try container.decodeIfPresent(Set<Int>.self, forKey: .weekdays) ?? Set(1...7)
    if weekdays.isEmpty { weekdays = Set(1...7) }
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    createdAt = try container.decode(Date.self, forKey: .createdAt)
  }

  func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
    let components = calendar.dateComponents([.weekday, .hour, .minute], from: date)
    let now = (components.hour ?? 0) * 60 + (components.minute ?? 0)
    let start = startHour * 60 + startMinute
    let end = endHour * 60 + endMinute
    let weekday = components.weekday ?? AppBoxWeekday.monday.rawValue

    if start == end { return weekdays.contains(weekday) }
    if start < end {
      return weekdays.contains(weekday) && now >= start && now < end
    }
    if now >= start { return weekdays.contains(weekday) }
    let previousWeekday = weekday == 1 ? 7 : weekday - 1
    return now < end && weekdays.contains(previousWeekday)
  }
}

@MainActor
final class AppBoxFocusAutomationStore: ObservableObject {
  static let maximumScheduleRules = 8

  @Published private(set) var placeRules: [AppBoxPlaceRule] {
    didSet { persist(placeRules, key: placeRulesKey) }
  }
  @Published private(set) var scheduleRules: [AppBoxScheduleRule] {
    didSet { persist(scheduleRules, key: scheduleRulesKey) }
  }

  private let defaults: UserDefaults
  private let placeRulesKey = AppBoxSharedStore.placeRulesKey
  private let scheduleRulesKey = AppBoxSharedStore.scheduleRulesKey

  convenience init() {
    AppBoxSharedStore.migrateStandardValuesIfNeeded(
      keys: [AppBoxSharedStore.placeRulesKey, AppBoxSharedStore.scheduleRulesKey]
    )
    self.init(defaults: AppBoxSharedStore.defaults)
  }

  init(defaults: UserDefaults) {
    self.defaults = defaults
    placeRules = Self.load([AppBoxPlaceRule].self, from: defaults, key: placeRulesKey) ?? []
    scheduleRules = Self.load([AppBoxScheduleRule].self, from: defaults, key: scheduleRulesKey) ?? []
  }

  func addPlaceRule(
    name: String,
    trigger: AppBoxPlaceRule.Trigger,
    coordinate: CLLocationCoordinate2D,
    radiusMeters: Double
  ) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    placeRules.insert(
      AppBoxPlaceRule(
        name: trimmed.isEmpty ? "当前位置" : trimmed,
        trigger: trigger,
        coordinate: coordinate,
        radiusMeters: radiusMeters
      ),
      at: 0
    )
  }

  func togglePlaceRule(_ rule: AppBoxPlaceRule) {
    guard let index = placeRules.firstIndex(where: { $0.id == rule.id }) else { return }
    placeRules[index].isEnabled.toggle()
  }

  func removePlaceRule(_ rule: AppBoxPlaceRule) {
    placeRules.removeAll { $0.id == rule.id }
  }

  func markPlaceRuleTriggered(_ rule: AppBoxPlaceRule, at date: Date = Date()) {
    guard let index = placeRules.firstIndex(where: { $0.id == rule.id }) else { return }
    placeRules[index].lastTriggeredAt = date
  }

  func addScheduleRule(
    name: String,
    startHour: Int,
    startMinute: Int,
    endHour: Int,
    endMinute: Int,
    weekdays: Set<Int> = Set(1...7)
  ) {
    guard scheduleRules.count < Self.maximumScheduleRules else { return }
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    scheduleRules.insert(
      AppBoxScheduleRule(
        name: trimmed.isEmpty ? "专注日程" : trimmed,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute,
        weekdays: weekdays
      ),
      at: 0
    )
  }

  func toggleScheduleRule(_ rule: AppBoxScheduleRule) {
    guard let index = scheduleRules.firstIndex(where: { $0.id == rule.id }) else { return }
    scheduleRules[index].isEnabled.toggle()
  }

  func removeScheduleRule(_ rule: AppBoxScheduleRule) {
    scheduleRules.removeAll { $0.id == rule.id }
  }

  func activeSchedule(at date: Date = Date()) -> AppBoxScheduleRule? {
    scheduleRules.first { $0.isEnabled && $0.contains(date) }
  }

  private func persist<T: Encodable>(_ value: T, key: String) {
    guard let data = try? JSONEncoder().encode(value) else { return }
    defaults.set(data, forKey: key)
  }

  private static func load<T: Decodable>(
    _ type: T.Type,
    from defaults: UserDefaults,
    key: String
  ) -> T? {
    guard let data = defaults.data(forKey: key) else { return nil }
    return try? JSONDecoder().decode(type, from: data)
  }
}
