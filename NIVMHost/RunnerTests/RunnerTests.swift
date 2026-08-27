import Flutter
import UIKit
import XCTest
@testable import Runner

class RunnerTests: XCTestCase {
  private final class FakeAppIconSystem: AppIconSystemClient {
    var supportsAlternateIcons = true
    var currentAlternateIconName: String?
    var isForegroundReady = true
    var applicationStateRawValue = UIApplication.State.active.rawValue
    var registeredIconNames = [
      "AppIconWeChat",
      "AppIconQQ",
      "AppIconAlipay",
      "AppIconToutiao",
      "AppIconDouyin",
      "AppIconXiaohongshu",
      "AppIconTelegram",
    ]
    var osVersion = "26.2"
    var requestedNames: [String?] = []
    var onSet: ((String?, @escaping (Error?) -> Void) -> Void)?

    func setAlternateIconName(
      _ name: String?,
      completion: @escaping (Error?) -> Void
    ) {
      requestedNames.append(name)
      onSet?(name, completion)
    }
  }

  func testFreshAppBoxLaunchUsesPrivacySurface() {
    let suiteName = "AppBoxSurfaceTests.fresh.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(arguments: ["AppBox"], defaults: defaults),
      .privacy
    )
  }

  func testForcedBoxLaunchPersistsTheActivatedSurface() {
    let suiteName = "AppBoxSurfaceTests.box.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }

    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(
        arguments: ["AppBox", "--appbox-force-surface"],
        defaults: defaults
      ),
      .box
    )
    XCTAssertTrue(defaults.bool(forKey: AppBoxSurfaceRoute.activatedKey))
    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(arguments: ["AppBox"], defaults: defaults),
      .box
    )
  }

  func testPrivacyCaptureLaunchResetsTheActivatedSurface() {
    let suiteName = "AppBoxSurfaceTests.capture.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    defaults.set(true, forKey: AppBoxSurfaceRoute.activatedKey)

    XCTAssertEqual(
      AppBoxSurfaceRoute.initialSurface(
        arguments: ["AppBox", "--appbox-capture-privacy"],
        defaults: defaults
      ),
      .privacy
    )
    XCTAssertFalse(defaults.bool(forKey: AppBoxSurfaceRoute.activatedKey))
  }

  func testAppBoxURLsRouteABFacesWithoutHijackingGuestRelaunch() {
    XCTAssertEqual(AppBoxSurfaceRoute.surface(for: URL(string: "appbox://box")!), .box)
    XCTAssertEqual(AppBoxSurfaceRoute.surface(for: URL(string: "appbox://open?id=tianya")!), .box)
    XCTAssertEqual(AppBoxSurfaceRoute.surface(for: URL(string: "appbox://privacy")!), .privacy)
    XCTAssertNil(AppBoxSurfaceRoute.surface(for: URL(string: "appbox://playbox.guestapp.relaunch")!))
    XCTAssertNil(AppBoxSurfaceRoute.surface(for: URL(string: "https://3601.help")!))
  }

  func testAlternateIconUsesOneSystemRequest() {
    let system = FakeAppIconSystem()
    let manager = AppIconManager(system: system)
    let completed = expectation(description: "icon changed")

    system.onSet = { name, completion in
      XCTAssertEqual(name, "AppIconQQ")
      system.currentAlternateIconName = name
      completion(nil)
    }

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "qq"]
      )
    ) { value in
      XCTAssertNil(value)
      completed.fulfill()
    }

    wait(for: [completed], timeout: 1)
    XCTAssertEqual(system.requestedNames.count, 1)
  }

  func testDefaultIconPassesNilToUIApplication() {
    let system = FakeAppIconSystem()
    system.currentAlternateIconName = "AppIconQQ"
    let manager = AppIconManager(system: system)
    let completed = expectation(description: "default restored")

    system.onSet = { name, completion in
      XCTAssertNil(name)
      system.currentAlternateIconName = nil
      completion(nil)
    }

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "default"]
      )
    ) { value in
      XCTAssertNil(value)
      completed.fulfill()
    }

    wait(for: [completed], timeout: 1)
    XCTAssertEqual(system.requestedNames.count, 1)
  }

  func testSystemBusyDoesNotRetry() {
    let system = FakeAppIconSystem()
    let manager = AppIconManager(
      system: system,
      systemBusyCooldown: 0
    )
    let completed = expectation(description: "busy returned")

    system.onSet = { _, completion in
      completion(NSError(
        domain: NSPOSIXErrorDomain,
        code: 35,
        userInfo: nil
      ))
    }

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "douyin"]
      )
    ) { value in
      let error = value as? FlutterError
      XCTAssertEqual(error?.code, "ICON_SYSTEM_BUSY")
      completed.fulfill()
    }

    wait(for: [completed], timeout: 1)
    XCTAssertEqual(system.requestedNames.count, 1)
  }

  func testNativeStateWinsWhenSystemCallbackReportsError() {
    let system = FakeAppIconSystem()
    let manager = AppIconManager(system: system)
    let completed = expectation(description: "applied state accepted")

    system.onSet = { name, completion in
      system.currentAlternateIconName = name
      completion(NSError(
        domain: NSPOSIXErrorDomain,
        code: 5,
        userInfo: nil
      ))
    }

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "wechat"]
      )
    ) { value in
      XCTAssertNil(value)
      completed.fulfill()
    }

    wait(for: [completed], timeout: 1)
    XCTAssertEqual(system.requestedNames.count, 1)
  }

  func testInactiveRequestWaitsForForeground() {
    let system = FakeAppIconSystem()
    system.isForegroundReady = false
    system.applicationStateRawValue = UIApplication.State.inactive.rawValue
    let center = NotificationCenter()
    let manager = AppIconManager(
      system: system,
      notificationCenter: center
    )
    let completed = expectation(description: "request completed")
    let foregrounded = expectation(description: "foreground requested")

    system.onSet = { name, completion in
      system.currentAlternateIconName = name
      completion(nil)
      foregrounded.fulfill()
    }

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "telegram"]
      )
    ) { value in
      XCTAssertNil(value)
      completed.fulfill()
    }

    DispatchQueue.main.async {
      XCTAssertTrue(system.requestedNames.isEmpty)
      system.isForegroundReady = true
      system.applicationStateRawValue = UIApplication.State.active.rawValue
      center.post(
        name: UIApplication.didBecomeActiveNotification,
        object: nil
      )
    }

    wait(for: [foregrounded, completed], timeout: 1)
    XCTAssertEqual(system.requestedNames.count, 1)
  }

  func testConcurrentRequestIsRejected() {
    let system = FakeAppIconSystem()
    let manager = AppIconManager(system: system)
    let firstStarted = expectation(description: "first request started")
    let secondCompleted = expectation(description: "second rejected")
    var firstCompletion: ((Error?) -> Void)?

    system.onSet = { _, completion in
      firstCompletion = completion
      firstStarted.fulfill()
    }

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "qq"]
      )
    ) { _ in }

    wait(for: [firstStarted], timeout: 1)

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "wechat"]
      )
    ) { value in
      let error = value as? FlutterError
      XCTAssertEqual(error?.code, "ICON_CHANGE_IN_PROGRESS")
      secondCompleted.fulfill()
    }

    wait(for: [secondCompleted], timeout: 1)
    XCTAssertEqual(system.requestedNames.count, 1)

    system.currentAlternateIconName = "AppIconQQ"
    firstCompletion?(nil)
  }

  func testForegroundReturnWaitsForSystemCompletion() {
    let system = FakeAppIconSystem()
    let center = NotificationCenter()
    let manager = AppIconManager(
      system: system,
      notificationCenter: center
    )
    let started = expectation(description: "request started")
    let completed = expectation(description: "request completed")
    var systemCompletion: ((Error?) -> Void)?
    var flutterResultCount = 0

    system.onSet = { _, completion in
      systemCompletion = completion
      started.fulfill()
    }

    manager.handle(
      FlutterMethodCall(
        methodName: "setIcon",
        arguments: ["iconId": "alipay"]
      )
    ) { value in
      flutterResultCount += 1
      XCTAssertNil(value)
      completed.fulfill()
    }

    wait(for: [started], timeout: 1)
    center.post(
      name: UIApplication.willResignActiveNotification,
      object: nil
    )
    center.post(
      name: UIApplication.didBecomeActiveNotification,
      object: nil
    )
    XCTAssertEqual(flutterResultCount, 0)

    system.currentAlternateIconName = "AppIconAlipay"
    systemCompletion?(nil)
    wait(for: [completed], timeout: 1)
    XCTAssertEqual(flutterResultCount, 1)
    XCTAssertEqual(system.requestedNames.count, 1)
  }
}
