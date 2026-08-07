import UIKit
import SwiftUI
import Intents

@objc class AppDelegate: UIResponder, UIApplicationDelegate {
    private var appBoxAutomationStore: AppBoxFocusAutomationStore?
    private var appBoxVisibilityService: AppBoxVisibilityService?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? ) -> Bool {
        application.shortcutItems = nil
        UserDefaults.standard.removeObject(forKey: "LCNeedToAcquireJIT")
        recordLaunchDiagnostics(launchOptions: launchOptions)
        if let url = launchOptions?[.url] as? URL {
            AppBoxIncomingURLRelay.forward(url, source: "launch-options")
        }
        AppBoxIncomingURLRelay.forwardFirstURLFromProcessArguments()
        
        NotificationCenter.default.addObserver(forName: UIApplication.willTerminateNotification, object: nil, queue: .main) { _ in
            // Fix launching app if user opens JIT waiting dialog and kills the app. Won't trigger normally.
            if DataManager.shared.model.isJITModalOpen && !UserDefaults.standard.bool(forKey: "LCKeepSelectedWhenQuit"){
                UserDefaults.standard.removeObject(forKey: "selected")
                UserDefaults.standard.removeObject(forKey: "selectedContainer")
            }
        }
        
        // allow new scene pop up as a new fullscreen window
        method_exchangeImplementations(
            class_getInstanceMethod(UIApplication.self, #selector(UIApplication.requestSceneSessionActivation(_ :userActivity:options:errorHandler:)))!,
            class_getInstanceMethod(UIApplication.self, #selector(UIApplication.hook_requestSceneSessionActivation(_:userActivity:options:errorHandler:)))!)

        // remove symbol caches if user upgraded iOS
        if let lastIOSBuildVersion = LCUtils.appGroupUserDefault.string(forKey: "LCLastIOSBuildVersion"),
           let currentVersion = UIDevice.current.buildVersion,
           lastIOSBuildVersion == currentVersion {
            
        } else {
            LCUtils.appGroupUserDefault.removeObject(forKey: "symbolOffsetCache")
            LCUtils.appGroupUserDefault.setValue(UIDevice.current.buildVersion, forKey: "LCLastIOSBuildVersion")
        }

        Task { @MainActor in
            configureAppBoxGeofenceAutomation()
        }
        
        return true
    }

    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey: Any] = [:]) -> Bool {
        AppBoxIncomingURLRelay.forward(url, source: "app-delegate-open-url")
        return true
    }

    func application(
        _ application: UIApplication,
        continue userActivity: NSUserActivity,
        restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void
    ) -> Bool {
        guard let url = userActivity.webpageURL else { return false }
        AppBoxIncomingURLRelay.forward(url, source: "app-delegate-user-activity")
        return true
    }
    
    func application(_ application: UIApplication, configurationForConnecting connectingSceneSession: UISceneSession, options: UIScene.ConnectionOptions) -> UISceneConfiguration {
        let configuration = UISceneConfiguration(name: nil, sessionRole: connectingSceneSession.role)
        configuration.delegateClass = SceneDelegate.self
        return configuration
    }
    
    func application(_ application: UIApplication, handlerFor intent: INIntent) -> Any? {
        switch intent {
        case is ViewAppIntent: return ViewAppIntentHandler()
        default:
            return nil
        }
    }

    private func recordLaunchDiagnostics(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: "AppBox.lastApplicationLaunchDate")
        defaults.set(ProcessInfo.processInfo.arguments, forKey: "AppBox.lastProcessArguments")
        if let launchOptions {
            defaults.set(launchOptions.keys.map(\.rawValue), forKey: "AppBox.lastLaunchOptionKeys")
        } else {
            defaults.removeObject(forKey: "AppBox.lastLaunchOptionKeys")
        }
        defaults.synchronize()
    }

    @MainActor
    private func configureAppBoxGeofenceAutomation() {
        let automationStore = AppBoxFocusAutomationStore()
        let visibilityService = AppBoxVisibilityService()
        appBoxAutomationStore = automationStore
        appBoxVisibilityService = visibilityService

        let monitor = AppBoxGeofenceMonitor.shared
        monitor.onRuleTriggered = { [weak self] rule in
            Task { @MainActor in
                guard let self else { return }
                automationStore.markPlaceRuleTriggered(rule)
                await visibilityService.hideSelection()
            }
        }
        monitor.synchronize(rules: automationStore.placeRules)
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate, ObservableObject { // Make SceneDelegate conform ObservableObject
    var window: UIWindow?

    func scene(_ scene: UIScene, willConnectTo session: UISceneSession, options connectionOptions: UIScene.ConnectionOptions) {
        self.window = (scene as? UIWindowScene)?.keyWindow
        recordSceneDiagnostics(connectionOptions: connectionOptions)
        if let url = connectionOptions.urlContexts.first?.url {
            forwardAppBoxURL(url, source: "scene-connect-url")
        } else if let url = connectionOptions.userActivities.first?.webpageURL {
            forwardAppBoxURL(url, source: "scene-connect-user-activity")
        }
    }

    func scene(_ scene: UIScene, openURLContexts URLContexts: Set<UIOpenURLContext>) {
        guard let url = URLContexts.first?.url else { return }
        forwardAppBoxURL(url, source: "scene-open-url")
    }

    func scene(_ scene: UIScene, continue userActivity: NSUserActivity) {
        guard let url = userActivity.webpageURL else { return }
        forwardAppBoxURL(url, source: "scene-user-activity")
    }

    private func forwardAppBoxURL(_ url: URL, source: String) {
        AppBoxIncomingURLRelay.forward(url, source: source)
    }

    private func recordSceneDiagnostics(connectionOptions: UIScene.ConnectionOptions) {
        let defaults = UserDefaults.standard
        defaults.set(Date(), forKey: "AppBox.lastSceneConnectionDate")
        defaults.set(connectionOptions.urlContexts.map(\.url.absoluteString), forKey: "AppBox.lastSceneURLContexts")
        defaults.set(connectionOptions.userActivities.compactMap(\.webpageURL?.absoluteString), forKey: "AppBox.lastSceneWebpageURLs")
        defaults.synchronize()
    }
    
}


@objc extension UIApplication {
    
    func hook_requestSceneSessionActivation(
        _ sceneSession: UISceneSession?,
        userActivity: NSUserActivity?,
        options: UIScene.ActivationRequestOptions?,
        errorHandler: ((any Error) -> Void)? = nil
    ) {
        var newOptions = options
        if newOptions == nil {
            newOptions = UIScene.ActivationRequestOptions()
        }
        newOptions!._setRequestFullscreen(UIScreen.main.bounds == self.keyWindow!.bounds)
        self.hook_requestSceneSessionActivation(sceneSession, userActivity: userActivity, options: newOptions, errorHandler: errorHandler)
    }
    
}

public class ViewAppIntentHandler: NSObject, ViewAppIntentHandling
{
    public func provideAppOptionsCollection(for intent: ViewAppIntent, with completion: @escaping (INObjectCollection<App>?, Error?) -> Void)
    {
        completion(INObjectCollection(items:[]), nil)
    }
}
