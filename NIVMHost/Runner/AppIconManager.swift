import Flutter
import UIKit

protocol AppIconSystemClient: AnyObject {
  var supportsAlternateIcons: Bool { get }
  var currentAlternateIconName: String? { get }
  var isForegroundReady: Bool { get }
  var applicationStateRawValue: Int { get }
  var registeredIconNames: [String] { get }
  var osVersion: String { get }

  func setAlternateIconName(
    _ name: String?,
    completion: @escaping (Error?) -> Void
  )
}

final class UIApplicationAppIconSystem: AppIconSystemClient {
  var supportsAlternateIcons: Bool {
    UIApplication.shared.supportsAlternateIcons
  }

  var currentAlternateIconName: String? {
    UIApplication.shared.alternateIconName
  }

  var isForegroundReady: Bool {
    guard UIApplication.shared.applicationState == .active else {
      return false
    }

    let windowScenes = UIApplication.shared.connectedScenes.compactMap {
      $0 as? UIWindowScene
    }
    if windowScenes.isEmpty {
      return true
    }
    return windowScenes.contains {
      $0.activationState == .foregroundActive
        && $0.windows.contains(where: \.isKeyWindow)
    }
  }

  var applicationStateRawValue: Int {
    UIApplication.shared.applicationState.rawValue
  }

  var registeredIconNames: [String] {
    guard let icons = Bundle.main.infoDictionary?["CFBundleIcons"]
            as? [String: Any],
          let alternateIcons = icons["CFBundleAlternateIcons"]
            as? [String: Any] else {
      return []
    }
    return alternateIcons.keys.sorted()
  }

  var osVersion: String {
    UIDevice.current.systemVersion
  }

  func setAlternateIconName(
    _ name: String?,
    completion: @escaping (Error?) -> Void
  ) {
    UIApplication.shared.setAlternateIconName(name, completionHandler: completion)
  }
}

/// Serializes the complete iOS alternate-icon transaction.
///
/// iOS 26 presents icon confirmation outside the app process. One user action
/// must therefore produce exactly one UIApplication request. The actual
/// `alternateIconName` value is the only success criterion.
final class AppIconManager {
  private enum Phase: String {
    case idle
    case waitingForForeground
    case requestingSystem
    case waitingForForegroundReturn
  }

  private final class PendingRequest {
    let iconId: String
    let nativeName: String?
    let result: FlutterResult
    var systemRequestSent = false
    var systemCompletionReceived = false
    var systemError: NSError?
    var timeoutWorkItem: DispatchWorkItem?

    init(iconId: String, nativeName: String?, result: @escaping FlutterResult) {
      self.iconId = iconId
      self.nativeName = nativeName
      self.result = result
    }
  }

  private let nativeNamesById: [String: String] = [
    "wechat": "AppIconWeChat",
    "qq": "AppIconQQ",
    "alipay": "AppIconAlipay",
    "toutiao": "AppIconToutiao",
    "douyin": "AppIconDouyin",
    "xiaohongshu": "AppIconXiaohongshu",
    "telegram": "AppIconTelegram",
  ]

  private lazy var idsByNativeName: [String: String] = {
    Dictionary(uniqueKeysWithValues: nativeNamesById.map { ($0.value, $0.key) })
  }()

  private let system: AppIconSystemClient
  private let notificationCenter: NotificationCenter
  private let requestTimeout: TimeInterval
  private let systemBusyCooldown: TimeInterval
  private var notificationTokens: [NSObjectProtocol] = []
  private var pendingRequest: PendingRequest?
  private var phase = Phase.idle
  private var retryNotBefore = Date.distantPast

  init(
    system: AppIconSystemClient = UIApplicationAppIconSystem(),
    notificationCenter: NotificationCenter = .default,
    requestTimeout: TimeInterval = 60,
    systemBusyCooldown: TimeInterval = 8
  ) {
    self.system = system
    self.notificationCenter = notificationCenter
    self.requestTimeout = requestTimeout
    self.systemBusyCooldown = systemBusyCooldown

    notificationTokens.append(
      notificationCenter.addObserver(
        forName: UIApplication.didBecomeActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.handleDidBecomeActive()
      }
    )
    notificationTokens.append(
      notificationCenter.addObserver(
        forName: UIApplication.willResignActiveNotification,
        object: nil,
        queue: .main
      ) { [weak self] _ in
        self?.handleWillResignActive()
      }
    )
  }

  deinit {
    notificationTokens.forEach(notificationCenter.removeObserver)
    pendingRequest?.timeoutWorkItem?.cancel()
  }

  func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    DispatchQueue.main.async {
      switch call.method {
      case "isSupported":
        result(self.system.supportsAlternateIcons)
      case "getCurrentIcon":
        result(self.currentIconId)
      case "getState":
        result(self.stateDetails())
      case "setIcon":
        self.setIcon(call.arguments, result: result)
      default:
        result(FlutterMethodNotImplemented)
      }
    }
  }

  private var currentIconId: String {
    guard let nativeName = system.currentAlternateIconName else {
      return "default"
    }
    return idsByNativeName[nativeName] ?? "default"
  }

  private func setIcon(_ rawArguments: Any?, result: @escaping FlutterResult) {
    guard system.supportsAlternateIcons else {
      result(error(
        code: "ICON_UNSUPPORTED",
        message: "当前设备不支持更换应用图标。"
      ))
      return
    }

    guard let arguments = rawArguments as? [String: Any],
          let iconId = arguments["iconId"] as? String,
          iconId == "default" || nativeNamesById[iconId] != nil else {
      result(error(
        code: "ICON_INVALID_ARGUMENT",
        message: "应用图标标识无效。",
        extra: ["arguments": String(describing: rawArguments)]
      ))
      return
    }

    if iconId == currentIconId {
      result(nil)
      return
    }

    guard pendingRequest == nil else {
      result(error(
        code: "ICON_CHANGE_IN_PROGRESS",
        message: "已有图标切换正在处理，请等待系统确认完成。"
      ))
      return
    }

    let now = Date()
    guard now >= retryNotBefore else {
      result(error(
        code: "ICON_SYSTEM_COOLDOWN",
        message: "iOS 图标服务刚刚繁忙，请等待几秒后再试。",
        extra: [
          "retryAfterMilliseconds":
            Int(retryNotBefore.timeIntervalSince(now) * 1_000),
        ]
      ))
      return
    }

    let nativeName = iconId == "default" ? nil : nativeNamesById[iconId]
    if let nativeName,
       !system.registeredIconNames.contains(nativeName) {
      result(error(
        code: "ICON_RESOURCE_MISSING",
        message: "安装包中缺少所选图标资源，请更新应用。",
        extra: ["requestedIconName": nativeName]
      ))
      return
    }

    let request = PendingRequest(
      iconId: iconId,
      nativeName: nativeName,
      result: result
    )
    pendingRequest = request
    scheduleTimeout(for: request)

    log(
      "request created id=\(iconId) native=\(nativeName ?? "default") "
        + "current=\(system.currentAlternateIconName ?? "default") "
        + "foregroundReady=\(system.isForegroundReady)"
    )

    if system.isForegroundReady {
      sendSystemRequest(request)
    } else {
      phase = .waitingForForeground
      log("request waiting for foreground id=\(iconId)")
    }
  }

  private func sendSystemRequest(_ request: PendingRequest) {
    guard pendingRequest === request,
          !request.systemRequestSent else {
      return
    }

    request.systemRequestSent = true
    phase = .requestingSystem
    log(
      "system request start id=\(request.iconId) "
        + "native=\(request.nativeName ?? "default")"
    )

    system.setAlternateIconName(request.nativeName) { [weak self, weak request] error in
      DispatchQueue.main.async {
        guard let self,
              let request,
              self.pendingRequest === request else {
          return
        }
        self.handleSystemCompletion(error, request: request)
      }
    }
  }

  private func handleSystemCompletion(
    _ error: Error?,
    request: PendingRequest
  ) {
    request.systemCompletionReceived = true
    if let error {
      request.systemError = error as NSError
      log(
        "system request completed with error id=\(request.iconId) "
          + "domain=\(request.systemError?.domain ?? "unknown") "
          + "code=\(request.systemError?.code ?? -1) "
          + "current=\(system.currentAlternateIconName ?? "default")"
      )
    } else {
      log(
        "system request completed id=\(request.iconId) "
          + "current=\(system.currentAlternateIconName ?? "default")"
      )
    }

    if currentIconId == request.iconId {
      finishSuccess(request)
      return
    }

    if !system.isForegroundReady {
      phase = .waitingForForegroundReturn
      log("request waiting for system overlay to close id=\(request.iconId)")
      return
    }

    finishMismatch(request)
  }

  private func handleWillResignActive() {
    guard let request = pendingRequest,
          request.systemRequestSent else {
      return
    }
    phase = .waitingForForegroundReturn
    log("application resigned active during request id=\(request.iconId)")
  }

  private func handleDidBecomeActive() {
    guard let request = pendingRequest else {
      return
    }

    log(
      "application became active id=\(request.iconId) "
        + "sent=\(request.systemRequestSent) "
        + "current=\(system.currentAlternateIconName ?? "default")"
    )

    if !request.systemRequestSent {
      guard system.isForegroundReady else {
        log("foreground notification arrived before scene was ready")
        return
      }
      sendSystemRequest(request)
      return
    }

    if currentIconId == request.iconId {
      finishSuccess(request)
      return
    }

    guard request.systemCompletionReceived else {
      phase = .requestingSystem
      log("application active; waiting for system completion id=\(request.iconId)")
      return
    }

    finishMismatch(request)
  }

  private func finishMismatch(_ request: PendingRequest) {
    if let systemError = request.systemError {
      let code = iconErrorCode(for: systemError)
      if code == "ICON_SYSTEM_BUSY" {
        retryNotBefore = Date().addingTimeInterval(systemBusyCooldown)
      }
      finishFailure(
        request,
        code: code,
        message: iconErrorMessage(for: code, error: systemError),
        extra: nativeErrorDetails(systemError)
      )
      return
    }

    finishFailure(
      request,
      code: "ICON_STATE_MISMATCH",
      message: "iOS 未应用所选图标，请重新选择。",
      extra: [
        "actualNativeName": system.currentAlternateIconName ?? "default",
      ]
    )
  }

  private func scheduleTimeout(for request: PendingRequest) {
    let workItem = DispatchWorkItem { [weak self, weak request] in
      guard let self,
            let request,
            self.pendingRequest === request else {
        return
      }

      if self.currentIconId == request.iconId {
        self.finishSuccess(request)
        return
      }

      self.finishFailure(
        request,
        code: "ICON_CHANGE_TIMEOUT",
        message: "等待 iOS 图标确认超时，请重新选择。",
        extra: [
          "actualNativeName":
            self.system.currentAlternateIconName ?? "default",
        ]
      )
    }
    request.timeoutWorkItem = workItem
    DispatchQueue.main.asyncAfter(
      deadline: .now() + requestTimeout,
      execute: workItem
    )
  }

  private func finishSuccess(_ request: PendingRequest) {
    guard pendingRequest === request else {
      return
    }
    request.timeoutWorkItem?.cancel()
    pendingRequest = nil
    phase = .idle
    log(
      "request success id=\(request.iconId) "
        + "current=\(system.currentAlternateIconName ?? "default")"
    )
    request.result(nil)
  }

  private func finishFailure(
    _ request: PendingRequest,
    code: String,
    message: String,
    extra: [String: Any] = [:]
  ) {
    guard pendingRequest === request else {
      return
    }
    request.timeoutWorkItem?.cancel()
    pendingRequest = nil
    phase = .idle
    log(
      "request failed id=\(request.iconId) code=\(code) "
        + "current=\(system.currentAlternateIconName ?? "default")"
    )

    var details = extra
    details["requestedIconId"] = request.iconId
    details["requestedIconName"] = request.nativeName ?? "default"
    details["currentIconId"] = currentIconId
    request.result(error(code: code, message: message, extra: details))
  }

  private func iconErrorCode(for error: NSError) -> String {
    if error.domain == NSPOSIXErrorDomain && error.code == 35 {
      return "ICON_SYSTEM_BUSY"
    }
    return "ICON_CHANGE_FAILED"
  }

  private func iconErrorMessage(for code: String, error: NSError) -> String {
    switch code {
    case "ICON_SYSTEM_BUSY":
      return "iOS 暂时未能打开图标确认窗口，请等待几秒后再试。"
    default:
      return error.localizedDescription
    }
  }

  private func nativeErrorDetails(_ error: NSError) -> [String: Any] {
    [
      "nativeErrorDomain": error.domain,
      "nativeErrorCode": error.code,
      "nativeDescription": error.localizedDescription,
    ]
  }

  private func stateDetails() -> [String: Any] {
    let retryAfter = max(0, retryNotBefore.timeIntervalSinceNow)
    return [
      "supported": system.supportsAlternateIcons,
      "currentIconId": currentIconId,
      "currentNativeName": system.currentAlternateIconName ?? "default",
      "requestInFlight": pendingRequest != nil,
      "phase": phase.rawValue,
      "foregroundReady": system.isForegroundReady,
      "applicationState": system.applicationStateRawValue,
      "registeredIcons": system.registeredIconNames,
      "osVersion": system.osVersion,
      "retryAfterMilliseconds": Int(retryAfter * 1_000),
    ]
  }

  private func error(
    code: String,
    message: String,
    extra: [String: Any] = [:]
  ) -> FlutterError {
    var details = stateDetails()
    extra.forEach { details[$0.key] = $0.value }
    return FlutterError(code: code, message: message, details: details)
  }

  private func log(_ message: String) {
    NSLog("%@", "[AppIcon] \(message)")
  }
}
