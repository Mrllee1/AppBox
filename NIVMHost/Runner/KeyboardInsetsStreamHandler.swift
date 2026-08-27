import Flutter
import QuartzCore
import UIKit

final class KeyboardInsetsStreamHandler: NSObject, FlutterStreamHandler {
  private var eventSink: FlutterEventSink?
  private var displayLink: CADisplayLink?
  private var isObserving = false

  private var animationStartTime: CFTimeInterval = 0
  private var animationDuration: TimeInterval = 0
  private var animationBeginBottom: CGFloat = 0
  private var animationEndBottom: CGFloat = 0
  private var animationCurve: UInt = UInt(UIView.AnimationCurve.easeInOut.rawValue)
  private var lastBottom: CGFloat = 0

  func onListen(withArguments arguments: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
    eventSink = events
    startObserving()
    emit(bottom: currentKeyboardBottom(), progress: 1, running: false, duration: 0)
    return nil
  }

  func onCancel(withArguments arguments: Any?) -> FlutterError? {
    eventSink = nil
    stopDisplayLink()
    stopObserving()
    return nil
  }

  private func startObserving() {
    guard !isObserving else { return }
    isObserving = true
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleKeyboardFrameChange(_:)),
      name: UIResponder.keyboardWillChangeFrameNotification,
      object: nil
    )
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(handleKeyboardFrameChange(_:)),
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  private func stopObserving() {
    guard isObserving else { return }
    isObserving = false
    NotificationCenter.default.removeObserver(
      self,
      name: UIResponder.keyboardWillChangeFrameNotification,
      object: nil
    )
    NotificationCenter.default.removeObserver(
      self,
      name: UIResponder.keyboardWillHideNotification,
      object: nil
    )
  }

  @objc private func handleKeyboardFrameChange(_ notification: Notification) {
    guard let userInfo = notification.userInfo else { return }
    let beginFrame = (userInfo[UIResponder.keyboardFrameBeginUserInfoKey] as? NSValue)?.cgRectValue
    let endFrame = (userInfo[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
    guard let endFrame else { return }
    let isHiding = notification.name == UIResponder.keyboardWillHideNotification

    animationBeginBottom =
      beginFrame.flatMap { isValidKeyboardFrame($0) ? keyboardBottom(forScreenFrame: $0) : nil } ??
      lastBottom
    animationEndBottom =
      isValidKeyboardFrame(endFrame) ? keyboardBottom(forScreenFrame: endFrame) : (isHiding ? 0 : lastBottom)
    animationDuration =
      (userInfo[UIResponder.keyboardAnimationDurationUserInfoKey] as? NSNumber)?.doubleValue ?? 0.25
    animationCurve =
      (userInfo[UIResponder.keyboardAnimationCurveUserInfoKey] as? NSNumber)?.uintValue ??
      UInt(UIView.AnimationCurve.easeInOut.rawValue)

    stopDisplayLink()

    guard animationDuration > 0.01,
          abs(animationBeginBottom - animationEndBottom) > 0.5
    else {
      emit(bottom: animationEndBottom, progress: 1, running: false, duration: animationDuration)
      return
    }

    animationStartTime = CACurrentMediaTime()
    emit(bottom: animationBeginBottom, progress: 0, running: true, duration: animationDuration)

    let link = CADisplayLink(target: self, selector: #selector(handleDisplayLink(_:)))
    link.add(to: .main, forMode: .common)
    displayLink = link
  }

  @objc private func handleDisplayLink(_ link: CADisplayLink) {
    let elapsed = max(0, CACurrentMediaTime() - animationStartTime)
    let linearProgress = min(1, elapsed / max(animationDuration, 0.001))
    let easedProgress = easedKeyboardProgress(linearProgress)
    let bottom = animationBeginBottom + (animationEndBottom - animationBeginBottom) * CGFloat(easedProgress)
    emit(
      bottom: bottom,
      progress: linearProgress,
      running: linearProgress < 1,
      duration: animationDuration
    )
    if linearProgress >= 1 {
      stopDisplayLink()
      emit(bottom: animationEndBottom, progress: 1, running: false, duration: animationDuration)
    }
  }

  private func stopDisplayLink() {
    displayLink?.invalidate()
    displayLink = nil
  }

  private func currentKeyboardBottom() -> CGFloat {
    return lastBottom
  }

  private func keyboardBottom(forScreenFrame screenFrame: CGRect) -> CGFloat {
    guard let window = keyWindow() else { return max(0, UIScreen.main.bounds.maxY - screenFrame.minY) }
    let frame = window.convert(screenFrame, from: nil)
    return max(0, window.bounds.maxY - frame.minY)
  }

  private func isValidKeyboardFrame(_ frame: CGRect) -> Bool {
    return !frame.isNull &&
      !frame.isInfinite &&
      frame.width > 1 &&
      frame.height > 1
  }

  private func keyWindow() -> UIWindow? {
    return UIApplication.shared.connectedScenes
      .compactMap { $0 as? UIWindowScene }
      .flatMap { $0.windows }
      .first { $0.isKeyWindow }
  }

  private func easedKeyboardProgress(_ progress: Double) -> Double {
    let t = min(1, max(0, progress))
    switch Int(animationCurve) {
    case UIView.AnimationCurve.linear.rawValue:
      return t
    case UIView.AnimationCurve.easeIn.rawValue:
      return t * t
    case UIView.AnimationCurve.easeOut.rawValue:
      return 1 - pow(1 - t, 3)
    case UIView.AnimationCurve.easeInOut.rawValue:
      return t * t * (3 - 2 * t)
    default:
      // iOS keyboard often uses a private curve value. Ease-out cubic is closest
      // to the perceived keyboard settle without overshooting Flutter layout.
      return 1 - pow(1 - t, 3)
    }
  }

  private func emit(
    bottom: CGFloat,
    progress: Double,
    running: Bool,
    duration: TimeInterval
  ) {
    let safeBottom = max(0, bottom)
    lastBottom = safeBottom
    eventSink?([
      "bottom": Double(safeBottom),
      "progress": min(1, max(0, progress)),
      "running": running,
      "durationMs": Int(max(0, duration) * 1000),
    ])
  }

  deinit {
    stopDisplayLink()
    stopObserving()
  }
}
