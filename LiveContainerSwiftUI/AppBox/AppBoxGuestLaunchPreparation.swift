import Foundation

enum AppBoxGuestLaunchPreparation {
    static func prepareUserDefaults() {
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "LCWaitForDebugger")
        defaults.removeObject(forKey: "LCNeedToAcquireJIT")
        defaults.removeObject(forKey: "LCKeepSelectedWhenQuit")
        defaults.synchronize()
    }
}
