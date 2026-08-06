import CoreLocation
import Foundation

@MainActor
final class AppBoxLocationPermissionService: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: CLAuthorizationStatus

    private let manager = CLLocationManager()

    override init() {
        authorizationStatus = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var canRequestAuthorization: Bool {
        authorizationStatus == .notDetermined
    }

    func requestAlwaysAuthorization() {
        authorizationStatus = manager.authorizationStatus
        guard authorizationStatus == .notDetermined else { return }
        manager.requestAlwaysAuthorization()
    }
}

extension AppBoxLocationPermissionService: CLLocationManagerDelegate {
    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        Task { @MainActor in
            authorizationStatus = manager.authorizationStatus
        }
    }
}
