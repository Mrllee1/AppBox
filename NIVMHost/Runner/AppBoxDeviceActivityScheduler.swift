import Combine
import DeviceActivity
import Foundation

@MainActor
final class AppBoxDeviceActivityScheduler: ObservableObject {
  @Published private(set) var lastError: String?

  private let center: DeviceActivityCenter
  private let defaults: UserDefaults
  private let fingerprintsKey = "Quietform.monitoring.scheduleFingerprints.v1"

  init(
    center: DeviceActivityCenter = DeviceActivityCenter(),
    defaults: UserDefaults = AppBoxSharedStore.defaults
  ) {
    self.center = center
    self.defaults = defaults
  }

  func synchronize(scheduleRules: [AppBoxScheduleRule]) {
    let plans = scheduleRules
      .filter(\.isEnabled)
      .flatMap(Self.monitoringPlans)
    let desiredNames = Set(plans.map(\.name))
    let activeNames = center.activities
      .map(\.rawValue)
      .filter { $0.hasPrefix(AppBoxSharedStore.scheduleActivityPrefix) }
    let staleNames = activeNames.filter { !desiredNames.contains($0) }
    if !staleNames.isEmpty {
      center.stopMonitoring(staleNames.map { DeviceActivityName($0) })
    }

    var fingerprints = storedFingerprints
    for staleName in staleNames { fingerprints.removeValue(forKey: staleName) }

    do {
      for plan in plans where fingerprints[plan.name] != plan.fingerprint || !activeNames.contains(plan.name) {
        try center.startMonitoring(
          DeviceActivityName(plan.name),
          during: DeviceActivitySchedule(
            intervalStart: plan.start,
            intervalEnd: plan.end,
            repeats: true
          )
        )
        fingerprints[plan.name] = plan.fingerprint
      }
      storedFingerprints = fingerprints.filter { desiredNames.contains($0.key) }
      lastError = nil
    } catch {
      lastError = error.localizedDescription
    }
  }

  @discardableResult
  func scheduleQuickSession(
    until endDate: Date,
    minutes: Int,
    calendar: Calendar = .current
  ) -> Bool {
    center.stopMonitoring([DeviceActivityName(AppBoxSharedStore.quickSessionActivityName)])
    guard minutes >= 15,
          let startDate = calendar.date(byAdding: .minute, value: -minutes, to: endDate) else {
      lastError = "专注时长至少需要 15 分钟"
      return false
    }

    let components: Set<Calendar.Component> = [.year, .month, .day, .hour, .minute, .second]
    let schedule = DeviceActivitySchedule(
      intervalStart: calendar.dateComponents(components, from: startDate),
      intervalEnd: calendar.dateComponents(components, from: endDate),
      repeats: false
    )

    do {
      try center.startMonitoring(
        DeviceActivityName(AppBoxSharedStore.quickSessionActivityName),
        during: schedule
      )
      lastError = nil
      return true
    } catch {
      lastError = error.localizedDescription
      return false
    }
  }

  func stopQuickSession() {
    center.stopMonitoring([DeviceActivityName(AppBoxSharedStore.quickSessionActivityName)])
  }

  private var storedFingerprints: [String: String] {
    get {
      guard let data = defaults.data(forKey: fingerprintsKey),
            let values = try? JSONDecoder().decode([String: String].self, from: data) else {
        return [:]
      }
      return values
    }
    set {
      guard let data = try? JSONEncoder().encode(newValue) else { return }
      defaults.set(data, forKey: fingerprintsKey)
    }
  }

  private struct MonitoringPlan {
    let name: String
    let start: DateComponents
    let end: DateComponents
    let fingerprint: String
  }

  private static func monitoringPlans(for rule: AppBoxScheduleRule) -> [MonitoringPlan] {
    let start = rule.startHour * 60 + rule.startMinute
    let end = rule.endHour * 60 + rule.endMinute
    let baseName = AppBoxSharedStore.scheduleActivityPrefix + rule.id
    let fingerprint = "\(start)-\(end)"

    if start == end {
      return [
        MonitoringPlan(
          name: baseName,
          start: DateComponents(hour: 0, minute: 0),
          end: DateComponents(hour: 23, minute: 59),
          fingerprint: fingerprint
        ),
      ]
    }

    if start < end {
      return [
        MonitoringPlan(
          name: baseName,
          start: DateComponents(hour: rule.startHour, minute: rule.startMinute),
          end: DateComponents(hour: rule.endHour, minute: rule.endMinute),
          fingerprint: fingerprint
        ),
      ]
    }

    var plans = [
      MonitoringPlan(
        name: baseName,
        start: DateComponents(hour: rule.startHour, minute: rule.startMinute),
        end: DateComponents(hour: 23, minute: 59),
        fingerprint: fingerprint + "-primary"
      ),
    ]
    if end > 0 {
      plans.append(
        MonitoringPlan(
          name: baseName + ".late",
          start: DateComponents(hour: 0, minute: 0),
          end: DateComponents(hour: rule.endHour, minute: rule.endMinute),
          fingerprint: fingerprint + "-late"
        )
      )
    }
    return plans
  }
}
