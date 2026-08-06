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

    init(
        id: String = UUID().uuidString,
        name: String,
        trigger: Trigger,
        isEnabled: Bool = true,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.trigger = trigger
        self.isEnabled = isEnabled
        self.createdAt = createdAt
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
        self.startHour = startHour
        self.startMinute = startMinute
        self.endHour = endHour
        self.endMinute = endMinute
        self.isEnabled = isEnabled
        self.createdAt = createdAt
    }

    var startTotalMinutes: Int {
        (startHour * 60) + startMinute
    }

    var endTotalMinutes: Int {
        (endHour * 60) + endMinute
    }

    func contains(_ date: Date, calendar: Calendar = .current) -> Bool {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        let currentMinute = ((components.hour ?? 0) * 60) + (components.minute ?? 0)

        if startTotalMinutes == endTotalMinutes {
            return true
        }

        if startTotalMinutes < endTotalMinutes {
            return currentMinute >= startTotalMinutes && currentMinute < endTotalMinutes
        }

        return currentMinute >= startTotalMinutes || currentMinute < endTotalMinutes
    }
}

@MainActor
final class AppBoxFocusAutomationStore: ObservableObject {
    @Published private(set) var placeRules: [AppBoxPlaceRule] {
        didSet { persistPlaceRules() }
    }

    @Published private(set) var scheduleRules: [AppBoxScheduleRule] {
        didSet { persistScheduleRules() }
    }

    private let defaults: UserDefaults
    private let placeRulesKey = "AppBox.focus.placeRules.v1"
    private let scheduleRulesKey = "AppBox.focus.scheduleRules.v1"

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        placeRules = Self.loadPlaceRules(from: defaults, key: placeRulesKey)
        scheduleRules = Self.loadScheduleRules(from: defaults, key: scheduleRulesKey)
    }

    var enabledPlaceCount: Int {
        placeRules.filter(\.isEnabled).count
    }

    var enabledScheduleCount: Int {
        scheduleRules.filter(\.isEnabled).count
    }

    func addPlaceRule(name: String, trigger: AppBoxPlaceRule.Trigger) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ruleName = trimmedName.isEmpty ? "当前位置" : trimmedName
        placeRules.insert(AppBoxPlaceRule(name: ruleName, trigger: trigger), at: 0)
    }

    func togglePlaceRule(_ rule: AppBoxPlaceRule) {
        guard let index = placeRules.firstIndex(where: { $0.id == rule.id }) else { return }
        placeRules[index].isEnabled.toggle()
    }

    func removePlaceRule(_ rule: AppBoxPlaceRule) {
        placeRules.removeAll { $0.id == rule.id }
    }

    func addScheduleRule(name: String, startHour: Int, startMinute: Int, endHour: Int, endMinute: Int) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let ruleName = trimmedName.isEmpty ? "专注日程" : trimmedName
        scheduleRules.insert(
            AppBoxScheduleRule(
                name: ruleName,
                startHour: startHour.clamped(to: 0...23),
                startMinute: startMinute.clamped(to: 0...59),
                endHour: endHour.clamped(to: 0...23),
                endMinute: endMinute.clamped(to: 0...59)
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

    private func persistPlaceRules() {
        persist(placeRules, key: placeRulesKey)
    }

    private func persistScheduleRules() {
        persist(scheduleRules, key: scheduleRulesKey)
    }

    private func persist<T: Encodable>(_ value: T, key: String) {
        guard let data = try? JSONEncoder().encode(value) else { return }
        defaults.set(data, forKey: key)
    }

    private static func loadPlaceRules(from defaults: UserDefaults, key: String) -> [AppBoxPlaceRule] {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode([AppBoxPlaceRule].self, from: data) else {
            return []
        }
        return value
    }

    private static func loadScheduleRules(from defaults: UserDefaults, key: String) -> [AppBoxScheduleRule] {
        guard let data = defaults.data(forKey: key),
              let value = try? JSONDecoder().decode([AppBoxScheduleRule].self, from: data) else {
            return []
        }
        return value
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
