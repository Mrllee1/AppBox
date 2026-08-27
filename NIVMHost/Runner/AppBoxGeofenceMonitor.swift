import CoreLocation
import Foundation

@MainActor
final class AppBoxGeofenceMonitor: NSObject, ObservableObject {
  static let shared = AppBoxGeofenceMonitor()

  @Published private(set) var authorizationStatus: CLAuthorizationStatus
  @Published private(set) var currentLocation: CLLocation?
  @Published private(set) var isRequestingLocation = false
  @Published private(set) var monitoredRuleIDs: Set<String> = []
  @Published private(set) var lastError: String?

  var onRuleTriggered: ((AppBoxPlaceRule) -> Void)?

  private let manager = CLLocationManager()
  private let identifierPrefix = "quietform.place."
  private var latestRules: [AppBoxPlaceRule] = []
  private var rulesByIdentifier: [String: AppBoxPlaceRule] = [:]

  override init() {
    authorizationStatus = manager.authorizationStatus
    super.init()
    manager.delegate = self
    manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
    manager.distanceFilter = 50
  }

  var isAlwaysAuthorized: Bool { authorizationStatus == .authorizedAlways }
  var canRequestAuthorization: Bool {
    authorizationStatus == .notDetermined || authorizationStatus == .authorizedWhenInUse
  }

  func requestAlwaysAuthorization() {
    authorizationStatus = manager.authorizationStatus
    switch authorizationStatus {
    case .notDetermined:
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse:
      manager.requestAlwaysAuthorization()
    case .authorizedAlways:
      synchronize(rules: latestRules)
    case .denied, .restricted:
      lastError = "定位权限未开启，请前往系统设置允许访问。"
    @unknown default:
      lastError = "当前无法获取定位权限。"
    }
  }

  func requestCurrentLocation() {
    authorizationStatus = manager.authorizationStatus
    guard CLLocationManager.locationServicesEnabled() else {
      lastError = "系统定位服务未开启。"
      return
    }

    switch authorizationStatus {
    case .notDetermined:
      isRequestingLocation = true
      manager.requestWhenInUseAuthorization()
    case .authorizedWhenInUse, .authorizedAlways:
      isRequestingLocation = true
      manager.requestLocation()
    case .denied, .restricted:
      lastError = "定位权限未开启，请前往系统设置允许访问。"
    @unknown default:
      lastError = "当前无法获取定位信息。"
    }
  }

  func synchronize(rules: [AppBoxPlaceRule]) {
    latestRules = rules
    authorizationStatus = manager.authorizationStatus
    stopManagedRegions()

    guard CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self) else {
      monitoredRuleIDs = []
      rulesByIdentifier = [:]
      lastError = "当前设备不支持地点自动化。"
      return
    }
    guard authorizationStatus == .authorizedAlways else {
      monitoredRuleIDs = []
      rulesByIdentifier = [:]
      return
    }

    let activeRules = Array(rules.filter(\.isEnabled).prefix(20))
    rulesByIdentifier = Dictionary(uniqueKeysWithValues: activeRules.map { (identifier(for: $0), $0) })

    for rule in activeRules {
      let maximum = manager.maximumRegionMonitoringDistance
      let radius = maximum > 0 ? min(rule.radiusMeters, maximum) : rule.radiusMeters
      let region = CLCircularRegion(
        center: rule.coordinate,
        radius: min(max(radius, 100), 1_000),
        identifier: identifier(for: rule)
      )
      region.notifyOnEntry = rule.trigger == .arrive
      region.notifyOnExit = rule.trigger == .leave
      manager.startMonitoring(for: region)
    }
    refreshMonitoredRuleIDs()
    lastError = nil
  }

  private func stopManagedRegions() {
    for region in manager.monitoredRegions where region.identifier.hasPrefix(identifierPrefix) {
      manager.stopMonitoring(for: region)
    }
  }

  private func refreshMonitoredRuleIDs() {
    monitoredRuleIDs = Set(
      manager.monitoredRegions
        .map(\.identifier)
        .filter { $0.hasPrefix(identifierPrefix) }
        .map { String($0.dropFirst(identifierPrefix.count)) }
    )
  }

  private func identifier(for rule: AppBoxPlaceRule) -> String {
    identifierPrefix + rule.id
  }

  private func handle(region: CLRegion, trigger: AppBoxPlaceRule.Trigger) {
    guard let rule = rulesByIdentifier[region.identifier],
          rule.isEnabled,
          rule.trigger == trigger else { return }
    onRuleTriggered?(rule)
  }
}

extension AppBoxGeofenceMonitor: CLLocationManagerDelegate {
  nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
    Task { @MainActor in
      authorizationStatus = manager.authorizationStatus
      if authorizationStatus == .authorizedWhenInUse, isRequestingLocation {
        manager.requestLocation()
      }
      if authorizationStatus != .authorizedWhenInUse && authorizationStatus != .authorizedAlways {
        isRequestingLocation = false
      }
      synchronize(rules: latestRules)
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    guard let location = locations.last else { return }
    Task { @MainActor in
      currentLocation = location
      isRequestingLocation = false
      lastError = nil
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    Task { @MainActor in
      isRequestingLocation = false
      lastError = error.localizedDescription
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
    Task { @MainActor in handle(region: region, trigger: .arrive) }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
    Task { @MainActor in handle(region: region, trigger: .leave) }
  }

  nonisolated func locationManager(
    _ manager: CLLocationManager,
    monitoringDidFailFor region: CLRegion?,
    withError error: Error
  ) {
    Task { @MainActor in
      if let region, region.identifier.hasPrefix(identifierPrefix) {
        monitoredRuleIDs.remove(String(region.identifier.dropFirst(identifierPrefix.count)))
      }
      lastError = error.localizedDescription
    }
  }

  nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
    Task { @MainActor in refreshMonitoredRuleIDs() }
  }
}
