import SwiftUI
import UIKit

enum AppBoxSurface: Equatable {
  case privacy
  case box
}

enum AppBoxSurfaceRoute {
  static let activatedKey = "appbox.appCenterActivatedFromExternalIntent"

  static func initialSurface(
    arguments: [String] = ProcessInfo.processInfo.arguments,
    defaults: UserDefaults = .standard
  ) -> AppBoxSurface {
    if arguments.contains("--appbox-reset-surface") ||
      arguments.contains("--appbox-capture-privacy") {
      defaults.set(false, forKey: activatedKey)
      return .privacy
    }

    let forcesBox = arguments.contains("--appbox-force-surface") ||
      arguments.contains(where: { argument in
        argument.hasPrefix("--appbox-install-") ||
          argument.hasPrefix("--appbox-start-") ||
          argument == "--appbox-capture-launcher"
      })
    if forcesBox {
      defaults.set(true, forKey: activatedKey)
      return .box
    }

    return defaults.bool(forKey: activatedKey) ? .box : .privacy
  }

  static func surface(for url: URL) -> AppBoxSurface? {
    guard url.scheme?.lowercased() == "appbox" else {
      return nil
    }
    let host = (url.host ?? "").lowercased()
    let path = url.path
      .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
      .lowercased()
    let command = host.isEmpty ? path : host

    switch command {
    case "box", "open", "install", "native":
      return .box
    case "privacy", "focus":
      return .privacy
    case "playbox.guestapp.relaunch":
      return nil
    default:
      return nil
    }
  }
}

final class AppBoxSurfaceCoordinatorViewController: UIViewController {
  private let defaults: UserDefaults
  private var currentSurface: AppBoxSurface?
  private var currentController: UIViewController?

  init(defaults: UserDefaults = .standard) {
    self.defaults = defaults
    super.init(nibName: nil, bundle: nil)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    fatalError("init(coder:) has not been implemented")
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = .systemBackground
    let initialSurface = AppBoxSurfaceRoute.initialSurface(defaults: defaults)
    show(
      initialSurface,
      animated: false,
      persist: false
    )
    print("APPBOX_SURFACE initial=\(initialSurface == .privacy ? "privacy" : "box")")

    if ProcessInfo.processInfo.arguments.contains("--appbox-capture-privacy") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
        self?.captureScreenshot(fileName: "privacy-screen.png")
      }
    }
  }

  @discardableResult
  func handle(url: URL) -> Bool {
    guard url.scheme?.lowercased() == "appbox" else {
      return false
    }
    guard let surface = AppBoxSurfaceRoute.surface(for: url) else {
      // The relaunch URL intentionally preserves the currently activated face.
      return url.host?.lowercased() == "playbox.guestapp.relaunch"
    }
    show(surface, animated: view.window != nil, persist: true)
    print("APPBOX_SURFACE url=\(url.absoluteString) selected=\(surface == .privacy ? "privacy" : "box")")
    return true
  }

  private func captureScreenshot(fileName: String) {
    guard let window = view.window,
          let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      print("APPBOX_SURFACE screenshot_failed reason=no_window")
      return
    }

    let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
    guard let png = renderer.image(actions: { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }).pngData() else {
      print("APPBOX_SURFACE screenshot_failed reason=no_png")
      return
    }

    let directory = documents.appendingPathComponent("AppBoxTest", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
      try png.write(to: directory.appendingPathComponent(fileName), options: .atomic)
      print("APPBOX_SURFACE screenshot file=\(fileName) bytes=\(png.count)")
    } catch {
      print("APPBOX_SURFACE screenshot_failed error=\(error.localizedDescription)")
    }
  }

  private func show(
    _ surface: AppBoxSurface,
    animated: Bool,
    persist: Bool
  ) {
    guard surface != currentSurface else {
      return
    }

    if persist {
      defaults.set(surface == .box, forKey: AppBoxSurfaceRoute.activatedKey)
      defaults.synchronize()
    }

    let nextController: UIViewController
    switch surface {
    case .privacy:
      nextController = UIHostingController(rootView: AppBoxPrivacySurfaceView())
    case .box:
      nextController = AppBoxLauncherViewController()
    }

    addChild(nextController)
    nextController.view.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(nextController.view)
    NSLayoutConstraint.activate([
      nextController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      nextController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      nextController.view.topAnchor.constraint(equalTo: view.topAnchor),
      nextController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    nextController.didMove(toParent: self)

    let previousController = currentController
    currentController = nextController
    currentSurface = surface

    let finishTransition = {
      previousController?.willMove(toParent: nil)
      previousController?.view.removeFromSuperview()
      previousController?.removeFromParent()
    }

    guard animated, let previousController else {
      finishTransition()
      return
    }

    nextController.view.alpha = 0
    UIView.animate(
      withDuration: 0.22,
      animations: {
        nextController.view.alpha = 1
        previousController.view.alpha = 0
      },
      completion: { _ in
        previousController.view.alpha = 1
        finishTransition()
      }
    )
  }
}
