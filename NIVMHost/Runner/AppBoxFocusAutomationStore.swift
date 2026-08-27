import CoreLocation
import Foundation

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
  var isEnabled: Bool
  var createdAt: Date

  init(
    id: String = UUID().uuidString,
    name: String,
    startHour: Int,
    startMinute: Int,
    endHour: Int,
    endMinute: Int,
    isEnabled: Bool = true,
    createdAt: Date = Date()
  ) {
    self.id = id
    self.name = name
    self.startHour = min(max(startHour, 0), 23)
    self.startMinute = min(max(startMinute, 0), 59)
    self.endHour = min(max(endHour, 0), 23)
    self.endMinute = min(max(endMinute, 0), 59)
    self.isEnabled = isEnabled
    self.createdAt = createdAt
  }

  func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
    let components = calendar.dateComponents([.hour, .minute], from: date)
    let now = (components.hour ?? 0) * 60 + (components.minute ?? 0)
    let start = startHour * 60 + startMinute
    let end = endHour * 60 + endMinute

    if start == end { return true }
    if start < end { return now >= start && now < end }
    return now >= start || now < end
  }
}

@MainActor
final class AppBoxFocusAutomationStore: ObservableObject {
  @Published private(set) var placeRules: [AppBoxPlaceRule] {
    didSet { persist(placeRules, key: placeRulesKey) }
  }
  @Published private(set) var scheduleRules: [AppBoxScheduleRule] {
    didSet { persist(scheduleRules, key: scheduleRulesKey) }
  }

  private let defaults: UserDefaults
  private let placeRulesKey = "AppBox.focus.placeRules.v2"
  private let scheduleRulesKey = "AppBox.focus.scheduleRules.v2"

  init(defaults: UserDefaults = .standard) {
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
    endMinute: Int
  ) {
    let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
    scheduleRules.insert(
      AppBoxScheduleRule(
        name: trimmed.isEmpty ? "专注日程" : trimmed,
        startHour: startHour,
        startMinute: startMinute,
        endHour: endHour,
        endMinute: endMinute
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
