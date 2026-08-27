import UIKit
import PBPlayerKit

@objc(AppBoxHostDelegate)
final class AppBoxHostDelegate: UIResponder, UIApplicationDelegate, UIKitCompatible {
  private static let allowedPlayBoxImports: Set<String> = [
    "dyzb_gq.ipa",
    "dyzb_tf.ipa",
    "cg_3.9.1_104_20260609100813.ipa",
  ]

  var window: UIWindow?
  private var surfaceCoordinator: AppBoxSurfaceCoordinatorViewController?

  var keyWindow: UIWindow {
    if let window { return window }
    if let activeWindow = UIApplication.shared.connectedScenes
      .compactMap({ $0 as? UIWindowScene })
      .flatMap(\.windows)
      .first(where: \.isKeyWindow) {
      return activeWindow
    }
    fatalError("AppBox window has not been created")
  }

  var rootVC: UIViewController {
    guard let root = keyWindow.rootViewController else {
      fatalError("AppBox root controller has not been created")
    }
    return root
  }

  var currentVC: UIViewController {
    var controller = rootVC
    while let presented = controller.presentedViewController {
      controller = presented
    }
    if let navigation = controller as? UINavigationController,
       let visible = navigation.visibleViewController {
      return visible
    }
    if let tabs = controller as? UITabBarController,
       let selected = tabs.selectedViewController {
      return selected
    }
    return controller
  }

  func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    let window = UIWindow(frame: UIScreen.main.bounds)
    self.window = window
    if ProcessInfo.processInfo.arguments.contains("--appbox-playbox-developer") {
      PBPlayerKitBox.setupApp()
      guard let controllerClass = NSClassFromString("PBPlayerKit.DeveloperController") as? NSObject.Type,
            let controller = controllerClass.init() as? UIViewController else {
        print("APPBOX_PLAYBOX_DEVELOPER boot_failed reason=controller_missing")
        return false
      }
      let navigation = UINavigationController(rootViewController: controller)
      window.rootViewController = navigation
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        self.inspectDeveloperController(controller, navigation: navigation)
      }
    } else {
      let coordinator = AppBoxSurfaceCoordinatorViewController()
      surfaceCoordinator = coordinator
      window.rootViewController = coordinator
    }
    window.makeKeyAndVisible()
    if let url = launchOptions?[.url] as? URL {
      _ = surfaceCoordinator?.handle(url: url)
    }
    print("APPBOX_RUNTIME host_ready runtime=\(ProcessInfo.processInfo.arguments.contains("--appbox-playbox-developer") ? "playbox_developer" : "launcher")")
    return true
  }

  func application(
    _ application: UIApplication,
    open url: URL,
    options: [UIApplication.OpenURLOptionsKey: Any] = [:]
  ) -> Bool {
    surfaceCoordinator?.handle(url: url) ?? false
  }

  private func inspectDeveloperController(
    _ controller: UIViewController,
    navigation: UINavigationController
  ) {
    controller.loadViewIfNeeded()
    guard let table = findTableView(in: controller.view),
          let dataSource = table.dataSource else {
      print("APPBOX_PLAYBOX_DEVELOPER table_missing")
      return
    }
    let sectionCount = dataSource.numberOfSections?(in: table) ?? 1
    print("APPBOX_PLAYBOX_DEVELOPER table sections=\(sectionCount)")
    for section in 0..<sectionCount {
      let rows = dataSource.tableView(table, numberOfRowsInSection: section)
      for row in 0..<rows {
        let indexPath = IndexPath(row: row, section: section)
        let cell = dataSource.tableView(table, cellForRowAt: indexPath)
        print("APPBOX_PLAYBOX_DEVELOPER row section=\(section) row=\(row) text=\(viewText(in: cell).joined(separator: " | "))")
      }
    }
    let importFileName = playBoxImportFileName()
    if ProcessInfo.processInfo.arguments.contains("--appbox-playbox-open-local-picker") ||
        importFileName != nil {
      table.delegate?.tableView?(table, didSelectRowAt: IndexPath(row: 2, section: 0))
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
        let presented = navigation.presentedViewController ?? controller.presentedViewController
        let picker = presented as? UIDocumentPickerViewController
        print("APPBOX_PLAYBOX_DEVELOPER local_picker presented=\(String(describing: type(of: presented))) delegate=\(String(describing: type(of: picker?.delegate)))")
        guard let importFileName else { return }
        self.submitPlayBoxImport(fileName: importFileName, picker: picker)
      }
    }
  }

  private func playBoxImportFileName() -> String? {
    let arguments = ProcessInfo.processInfo.arguments
    guard let flagIndex = arguments.firstIndex(of: "--appbox-playbox-import"),
          arguments.indices.contains(flagIndex + 1) else {
      return nil
    }
    let fileName = arguments[flagIndex + 1]
    guard fileName == URL(fileURLWithPath: fileName).lastPathComponent,
          Self.allowedPlayBoxImports.contains(fileName) else {
      print("APPBOX_PLAYBOX_DEVELOPER import_rejected file=\(fileName)")
      return nil
    }
    return fileName
  }

  private func submitPlayBoxImport(
    fileName: String,
    picker: UIDocumentPickerViewController?
  ) {
    guard let picker, let delegate = picker.delegate else {
      print("APPBOX_PLAYBOX_DEVELOPER import_failed file=\(fileName) reason=picker_missing")
      return
    }
    guard let documents = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      print("APPBOX_PLAYBOX_DEVELOPER import_failed file=\(fileName) reason=documents_missing")
      return
    }
    let source = documents
      .appendingPathComponent("AppBoxImports", isDirectory: true)
      .appendingPathComponent(fileName)
    guard FileManager.default.fileExists(atPath: source.path) else {
      print("APPBOX_PLAYBOX_DEVELOPER import_failed file=\(fileName) reason=file_missing")
      return
    }
    print("APPBOX_PLAYBOX_DEVELOPER import_submitting file=\(fileName)")
    delegate.documentPicker?(picker, didPickDocumentsAt: [source])
  }

  private func findTableView(in view: UIView) -> UITableView? {
    if let table = view as? UITableView { return table }
    for subview in view.subviews {
      if let table = findTableView(in: subview) { return table }
    }
    return nil
  }

  private func viewText(in view: UIView) -> [String] {
    var result: [String] = []
    if let label = view as? UILabel, let text = label.text, !text.isEmpty {
      result.append(text)
    }
    for subview in view.subviews {
      result.append(contentsOf: viewText(in: subview))
    }
    return result
  }
}
