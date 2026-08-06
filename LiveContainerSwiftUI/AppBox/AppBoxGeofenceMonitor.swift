import CoreLocation
import Foundation
import UIKit

@MainActor
final class AppBoxGeofenceMonitor: NSObject, ObservableObject {
    static let shared = AppBoxGeofenceMonitor()

    @Published private(set) var authorizationStatus: CLAuthorizationStatus
    @Published private(set) var currentLocation: CLLocation?
    @Published private(set) var isRequestingLocation = false
    @Published private(set) var monitoredRuleIDs: Set<String> = []
    @Published private(set) var lastError: String?
    @Published private(set) var lastEventDescription: String?

    var onRuleTriggered: ((AppBoxPlaceRule) -> Void)?

    private let manager = CLLocationManager()
    private let identifierPrefix = "appbox.place."
    private var rulesByIdentifier: [String: AppBoxPlaceRule] = [:]
    private var latestRules: [AppBoxPlaceRule] = []

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 50
    }

    var canRequestAuthorization: Bool {
        authorizationStatus == .notDetermined || authorizationStatus == .authorizedWhenInUse
    }

    var isAlwaysAuthorized: Bool {
        authorizationStatus == .authorizedAlways
    }

    var canMonitorRegions: Bool {
        CLLocationManager.isMonitoringAvailable(for: CLCircularRegion.self)
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
        case .restricted, .denied:
            lastError = "Location permission is denied."
        @unknown default:
            lastError = "Location permission is unavailable."
        }
    }

    func requestCurrentLocation() {
        authorizationStatus = manager.authorizationStatus

        guard CLLocationManager.locationServicesEnabled() else {
            lastError = "Location services are disabled."
            return
        }

        switch authorizationStatus {
        case .notDetermined:
            isRequestingLocation = true
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            isRequestingLocation = true
            manager.requestLocation()
        case .restricted, .denied:
            isRequestingLocation = false
            lastError = "Location permission is denied."
        @unknown default:
            isRequestingLocation = false
            lastError = "Location permission is unavailable."
        }
    }

    func synchronize(rules: [AppBoxPlaceRule]) {
        latestRules = rules
        authorizationStatus = manager.authorizationStatus
        stopManagedRegions()

        guard canMonitorRegions else {
            rulesByIdentifier = [:]
            monitoredRuleIDs = []
            lastError = "Geofence monitoring is unavailable on this device."
            return
        }

        guard authorizationStatus == .authorizedAlways else {
            rulesByIdentifier = [:]
            monitoredRuleIDs = []
            return
        }

        let activeRules = rules
            .filter { $0.isEnabled && $0.coordinate != nil }
            .prefix(20)

        rulesByIdentifier = Dictionary(
            uniqueKeysWithValues: activeRules.map { (identifier(for: $0), $0) }
        )

        for rule in activeRules {
            guard let region = region(for: rule) else { continue }
            manager.startMonitoring(for: region)
        }

        refreshMonitoredRuleIDs()
        lastError = nil
    }

    private func region(for rule: AppBoxPlaceRule) -> CLCircularRegion? {
        guard let coordinate = rule.coordinate else { return nil }

        let maxDistance = manager.maximumRegionMonitoringDistance
        let supportedRadius = maxDistance > 0 ? min(rule.radiusMeters, maxDistance) : rule.radiusMeters
        let region = CLCircularRegion(
            center: coordinate,
            radius: supportedRadius.clamped(to: 100...1000),
            identifier: identifier(for: rule)
        )
        region.notifyOnEntry = rule.trigger == .arrive
        region.notifyOnExit = rule.trigger == .leave
        return region
    }

    private func stopManagedRegions() {
        for region in manager.monitoredRegions where region.identifier.hasPrefix(identifierPrefix) {
            manager.stopMonitoring(for: region)
        }
        monitoredRuleIDs = []
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
        "\(identifierPrefix)\(rule.id)"
    }

    private func handle(region: CLRegion, trigger: AppBoxPlaceRule.Trigger) {
        guard region.identifier.hasPrefix(identifierPrefix),
              let rule = rulesByIdentifier[region.identifier],
              rule.isEnabled,
              rule.trigger == trigger else { return }

        lastEventDescription = "\(rule.name) \(trigger.rawValue)"
        UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        onRuleTriggered?(rule)
    }
}

extension AppBoxGeofenceMonitor: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus

            if authorizationStatus == .authorizedWhenInUse {
                manager.requestAlwaysAuthorization()
            }

            if authorizationStatus == .authorizedWhenInUse || authorizationStatus == .authorizedAlways {
                if isRequestingLocation {
                    manager.requestLocation()
                }
            } else {
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
        Task { @MainActor in
            handle(region: region, trigger: .arrive)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        Task { @MainActor in
            handle(region: region, trigger: .leave)
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        Task { @MainActor in
            if let region, region.identifier.hasPrefix(identifierPrefix) {
                monitoredRuleIDs.remove(String(region.identifier.dropFirst(identifierPrefix.count)))
            }
            lastError = error.localizedDescription
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didStartMonitoringFor region: CLRegion) {
        Task { @MainActor in
            refreshMonitoredRuleIDs()
        }
    }
}

private extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        min(max(self, range.lowerBound), range.upperBound)
    }
}
