import Darwin
import UIKit

@_silgen_name("AppBoxLaunchSelectedPlayBoxGuestInProcess")
private func AppBoxLaunchSelectedPlayBoxGuestInProcess() -> Int32

final class AppBoxLauncherViewController: UIViewController {
  private let pornhubCoordinator = GuestRuntimeCoordinator()
  private let catalogService = AppBoxCatalogService()
  private let launchedVersionsURL: URL = {
    let directory = FileManager.default.urls(
      for: .applicationSupportDirectory,
      in: .userDomainMask
    ).first!
    return directory.appendingPathComponent("AppBoxLaunchedVersions.plist")
  }()
  private lazy var launchedVersions: [String: String] = loadLaunchedVersions()
  private var catalogSections: [AppBoxRuntimeCatalogSection] = []
  private var playBoxCoordinators: [String: PlayBoxGuestRuntimeCoordinator] = [:]
  private let pornhubButton = UIButton(type: .system)
  private var playBoxButtons: [String: UIButton] = [:]
  private var installedPlayBoxGuests: [String: PreparedPlayBoxGuest] = [:]
  private let scrollView = UIScrollView()
  private let refreshControl = UIRefreshControl()
  private let contentStack = UIStackView()
  private let installedCardContainer = UIView()
  private var installedTileControls: [UIControl] = []
  private let launchOverlay = UIView()
  private let launchPanel = UIView()
  private let launchIconView = UIImageView()
  private let launchTitleLabel = UILabel()
  private let launchProgressView = UIProgressView(progressViewStyle: .default)
  private let launchDetailLabel = UILabel()
  private let backgroundGradient = CAGradientLayer()
  private var pornhubInstalled = false
  private var relaunchExitScheduled = false
  private var pendingCatalogInstallID: String?
  private var pendingCatalogStartID: String?
  private var autoStartCatalogID: String?
  private var activeCatalogID: String?
  private var buttonProgressWorkItem: DispatchWorkItem?
  private var pendingButtonProgress: (button: UIButton, progress: Float)?
  private var lastButtonProgressRenderTime: CFTimeInterval = 0
  private var displayedButtonProgress: Float = 0
  private var launchWorkItems: [DispatchWorkItem] = []
  private var launchInProgress = false
  private var catalogRefreshInFlight = false
  private var catalogLoadFailed = false

  private var catalogApps: [PlayBoxGuestDescriptor] {
    catalogSections.flatMap(\.apps)
  }

  private var playBoxCatalogApps: [PlayBoxGuestDescriptor] {
    catalogApps.filter { !$0.usesFlutterSidecar }
  }

  private var flutterCatalogApp: PlayBoxGuestDescriptor? {
    catalogApps.first(where: \.usesFlutterSidecar)
  }

  override func viewDidLoad() {
    super.viewDidLoad()
    configureBackground()
    rebuildCoordinators()
    configureGridButton(pornhubButton, title: "安装")
    pornhubButton.addAction(UIAction { [weak self] _ in
      guard let self else { return }
      guard let descriptor = self.flutterCatalogApp else {
        self.showFailure("在线目录中找不到天涯")
        return
      }
      self.pornhubInstalled ? self.startPornhub() : self.downloadPornhub(descriptor)
    }, for: .touchUpInside)
    configureUI()
    pornhubCoordinator.onEvent = { [weak self] event in self?.handlePornhub(event) }
    refreshInstalledState()
    handleLaunchArguments()
    Task { await refreshRemoteCatalog() }
  }

  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    backgroundGradient.frame = view.bounds
  }

  private func handleLaunchArguments() {
    let arguments = ProcessInfo.processInfo.arguments
    let installPrefix = "--appbox-install-catalog-id="
    let startPrefix = "--appbox-start-catalog-id="
    let installAndStartPrefix = "--appbox-install-and-start-catalog-id="
    if let argument = arguments.first(where: { $0.hasPrefix(installAndStartPrefix) }) {
      let appID = String(argument.dropFirst(installAndStartPrefix.count))
      pendingCatalogInstallID = appID
      autoStartCatalogID = appID
    } else if let argument = arguments.first(where: { $0.hasPrefix(installPrefix) }) {
      pendingCatalogInstallID = String(argument.dropFirst(installPrefix.count))
    } else if let argument = arguments.first(where: { $0.hasPrefix(startPrefix) }) {
      pendingCatalogStartID = String(argument.dropFirst(startPrefix.count))
    }

    if arguments.contains("--appbox-install-pornhub-guest") {
      downloadPornhub()
    } else if let descriptor = playBoxCatalogApps.first(where: {
      arguments.contains($0.installArgument)
    }) {
      installInjectedPlayBoxGuest(descriptor)
    } else if arguments.contains("--appbox-start-pornhub-guest") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
        self?.startPornhub()
      }
    } else if let descriptor = playBoxCatalogApps.first(where: {
      arguments.contains("--appbox-start-\($0.id)")
    }) {
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
        self?.startPlayBox(descriptor)
      }
    }

    if arguments.contains("--appbox-capture-launcher") {
      DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
        self?.captureLauncherScreenshot()
      }
    }
  }

  private func configureUI() {
    contentStack.translatesAutoresizingMaskIntoConstraints = false
    contentStack.axis = .vertical
    contentStack.spacing = 10

    scrollView.translatesAutoresizingMaskIntoConstraints = false
    scrollView.alwaysBounceVertical = true
    scrollView.contentInset = UIEdgeInsets(top: 8, left: 0, bottom: 28, right: 0)
    scrollView.showsVerticalScrollIndicator = false
    refreshControl.tintColor = UIColor.white.withAlphaComponent(0.76)
    refreshControl.addAction(UIAction { [weak self] _ in
      Task { await self?.refreshRemoteCatalog() }
    }, for: .valueChanged)
    scrollView.refreshControl = refreshControl
    scrollView.addSubview(contentStack)
    view.addSubview(scrollView)
    configureLaunchOverlay()
    NSLayoutConstraint.activate([
      scrollView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
      scrollView.trailingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.trailingAnchor),
      scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      contentStack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 14),
      contentStack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -14),
      contentStack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor),
      contentStack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor),
      contentStack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -28),
    ])
    renderCatalog()
  }

  private func renderCatalog() {
    contentStack.arrangedSubviews.forEach {
      contentStack.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }
    playBoxButtons.removeAll()

    contentStack.addArrangedSubview(makeHeader())
    contentStack.addArrangedSubview(installedCardContainer)
    refreshInstalledCard()

    if catalogSections.isEmpty {
      contentStack.addArrangedSubview(makeCatalogPlaceholder(failed: catalogLoadFailed))
    }

    for (sectionIndex, section) in catalogSections.enumerated() {
      let tiles = section.apps.enumerated().map { index, descriptor in
        makeGuestTile(descriptor, index: index)
      }
      contentStack.addArrangedSubview(makeSectionCard(
        title: section.title,
        color: sectionColor(index: sectionIndex, title: section.title),
        tiles: tiles
      ))
    }
  }

  private func configureBackground() {
    view.backgroundColor = UIColor(red: 0.045, green: 0.061, blue: 0.096, alpha: 1)
    backgroundGradient.colors = [
      UIColor(red: 0.075, green: 0.105, blue: 0.17, alpha: 1).cgColor,
      UIColor(red: 0.055, green: 0.075, blue: 0.125, alpha: 1).cgColor,
      UIColor(red: 0.035, green: 0.047, blue: 0.078, alpha: 1).cgColor,
    ]
    backgroundGradient.locations = [0, 0.46, 1]
    backgroundGradient.startPoint = CGPoint(x: 0.15, y: 0)
    backgroundGradient.endPoint = CGPoint(x: 0.85, y: 1)
    view.layer.insertSublayer(backgroundGradient, at: 0)
  }

  private func makeHeader() -> UIView {
    let titleLabel = UILabel()
    titleLabel.text = "天涯盒子"
    titleLabel.textColor = .white
    titleLabel.font = .systemFont(ofSize: 25, weight: .bold)

    let detailLabel = UILabel()
    detailLabel.textColor = UIColor.white.withAlphaComponent(0.52)
    detailLabel.font = .systemFont(ofSize: 12.5, weight: .medium)
    detailLabel.text = "精选应用，一盒尽享"

    let header = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
    header.axis = .vertical
    header.spacing = 3
    header.isLayoutMarginsRelativeArrangement = true
    header.layoutMargins = UIEdgeInsets(top: 2, left: 4, bottom: 5, right: 4)
    return header
  }

  private func makeCatalogPlaceholder(failed: Bool) -> UIView {
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.color = UIColor.white.withAlphaComponent(0.82)

    let title = UILabel()
    title.text = failed ? "应用列表加载失败" : "正在加载精选应用…"
    title.textColor = UIColor.white.withAlphaComponent(0.92)
    title.font = .systemFont(ofSize: 15, weight: .semibold)
    title.textAlignment = .center

    let detail = UILabel()
    detail.text = failed ? "请检查网络后点击重试" : "首次加载完成后，返回盒子会立即显示"
    detail.textColor = UIColor.white.withAlphaComponent(0.48)
    detail.font = .systemFont(ofSize: 12, weight: .medium)
    detail.textAlignment = .center

    var views: [UIView] = []
    if failed {
      let retry = UIButton(type: .system)
      retry.setTitle("重新加载", for: .normal)
      retry.setTitleColor(.white, for: .normal)
      retry.titleLabel?.font = .systemFont(ofSize: 13, weight: .semibold)
      retry.backgroundColor = UIColor.white.withAlphaComponent(0.14)
      retry.layer.cornerRadius = 15
      retry.heightAnchor.constraint(equalToConstant: 32).isActive = true
      retry.widthAnchor.constraint(equalToConstant: 104).isActive = true
      retry.addAction(UIAction { [weak self] _ in
        Task { await self?.refreshRemoteCatalog() }
      }, for: .touchUpInside)
      views = [title, detail, retry]
    } else {
      spinner.startAnimating()
      views = [spinner, title, detail]
    }

    let stack = UIStackView(arrangedSubviews: views)
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 8

    let card = UIView()
    card.backgroundColor = UIColor(red: 0.095, green: 0.13, blue: 0.21, alpha: 0.96)
    card.layer.cornerRadius = 20
    card.layer.borderWidth = 1
    card.layer.borderColor = UIColor.white.withAlphaComponent(0.07).cgColor
    card.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 18),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -18),
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 24),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -24),
    ])
    return card
  }

  private func configureLaunchOverlay() {
    launchOverlay.translatesAutoresizingMaskIntoConstraints = false
    launchOverlay.backgroundColor = UIColor.black.withAlphaComponent(0.58)
    launchOverlay.isHidden = true
    launchOverlay.alpha = 0
    launchOverlay.accessibilityViewIsModal = true

    launchPanel.translatesAutoresizingMaskIntoConstraints = false
    launchPanel.backgroundColor = UIColor(red: 0.035, green: 0.052, blue: 0.10, alpha: 0.985)
    launchPanel.layer.cornerRadius = 21
    launchPanel.layer.borderWidth = 1
    launchPanel.layer.borderColor = UIColor.white.withAlphaComponent(0.045).cgColor
    launchPanel.layer.shadowColor = UIColor.black.cgColor
    launchPanel.layer.shadowOpacity = 0.34
    launchPanel.layer.shadowRadius = 24
    launchPanel.layer.shadowOffset = CGSize(width: 0, height: 12)

    launchIconView.translatesAutoresizingMaskIntoConstraints = false
    launchIconView.contentMode = .scaleAspectFill
    launchIconView.tintColor = .white
    launchIconView.backgroundColor = UIColor.white.withAlphaComponent(0.08)
    launchIconView.layer.cornerRadius = 15
    launchIconView.layer.borderWidth = 1
    launchIconView.layer.borderColor = UIColor.white.withAlphaComponent(0.28).cgColor
    launchIconView.clipsToBounds = true
    NSLayoutConstraint.activate([
      launchIconView.widthAnchor.constraint(equalToConstant: 66),
      launchIconView.heightAnchor.constraint(equalToConstant: 66),
    ])

    launchTitleLabel.textColor = UIColor.white.withAlphaComponent(0.96)
    launchTitleLabel.font = .systemFont(ofSize: 17, weight: .bold)
    launchTitleLabel.textAlignment = .center
    launchTitleLabel.numberOfLines = 1
    launchTitleLabel.adjustsFontSizeToFitWidth = true
    launchTitleLabel.minimumScaleFactor = 0.78

    launchProgressView.translatesAutoresizingMaskIntoConstraints = false
    launchProgressView.progress = 0
    launchProgressView.progressTintColor = UIColor(red: 0.16, green: 0.64, blue: 1, alpha: 1)
    launchProgressView.trackTintColor = UIColor(red: 0.045, green: 0.12, blue: 0.25, alpha: 1)
    launchProgressView.layer.cornerRadius = 3
    launchProgressView.clipsToBounds = true
    launchProgressView.transform = CGAffineTransform(scaleX: 1, y: 2.35)

    let shield = UIImageView(image: UIImage(systemName: "shield.fill"))
    shield.translatesAutoresizingMaskIntoConstraints = false
    shield.tintColor = UIColor(red: 0.05, green: 0.78, blue: 0.39, alpha: 1)
    shield.contentMode = .scaleAspectFit
    NSLayoutConstraint.activate([
      shield.widthAnchor.constraint(equalToConstant: 21),
      shield.heightAnchor.constraint(equalToConstant: 21),
    ])

    launchDetailLabel.textColor = UIColor(red: 0.05, green: 0.80, blue: 0.40, alpha: 1)
    launchDetailLabel.font = .systemFont(ofSize: 14, weight: .semibold)
    launchDetailLabel.numberOfLines = 1
    launchDetailLabel.adjustsFontSizeToFitWidth = true
    launchDetailLabel.minimumScaleFactor = 0.76

    let detailRow = UIStackView(arrangedSubviews: [shield, launchDetailLabel])
    detailRow.axis = .horizontal
    detailRow.alignment = .center
    detailRow.spacing = 8

    let stack = UIStackView(arrangedSubviews: [launchIconView, launchTitleLabel, launchProgressView, detailRow])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 17
    stack.setCustomSpacing(15, after: launchIconView)
    stack.setCustomSpacing(20, after: launchTitleLabel)
    launchIconView.setContentHuggingPriority(.required, for: .horizontal)
    detailRow.setContentHuggingPriority(.required, for: .horizontal)
    launchProgressView.widthAnchor.constraint(equalTo: stack.widthAnchor).isActive = true

    launchPanel.addSubview(stack)
    launchOverlay.addSubview(launchPanel)
    view.addSubview(launchOverlay)
    let responsiveWidth = launchPanel.widthAnchor.constraint(equalTo: view.widthAnchor, constant: -70)
    responsiveWidth.priority = .defaultHigh
    NSLayoutConstraint.activate([
      launchOverlay.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      launchOverlay.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      launchOverlay.topAnchor.constraint(equalTo: view.topAnchor),
      launchOverlay.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      launchPanel.centerXAnchor.constraint(equalTo: launchOverlay.centerXAnchor),
      launchPanel.centerYAnchor.constraint(equalTo: launchOverlay.centerYAnchor, constant: -10),
      launchPanel.leadingAnchor.constraint(greaterThanOrEqualTo: launchOverlay.leadingAnchor, constant: 30),
      launchPanel.trailingAnchor.constraint(lessThanOrEqualTo: launchOverlay.trailingAnchor, constant: -30),
      launchPanel.widthAnchor.constraint(lessThanOrEqualToConstant: 350),
      responsiveWidth,
      stack.leadingAnchor.constraint(equalTo: launchPanel.leadingAnchor, constant: 27),
      stack.trailingAnchor.constraint(equalTo: launchPanel.trailingAnchor, constant: -27),
      stack.topAnchor.constraint(equalTo: launchPanel.topAnchor, constant: 23),
      stack.bottomAnchor.constraint(equalTo: launchPanel.bottomAnchor, constant: -25),
    ])
  }

  private func makeSectionCard(title: String, color: UIColor, tiles: [UIView]) -> UIView {
    let titleLabel = UILabel()
    titleLabel.text = title
    titleLabel.textColor = .white
    titleLabel.font = .systemFont(ofSize: 19, weight: .bold)

    let grid = UIStackView()
    grid.axis = .vertical
    grid.spacing = 10
    for offset in stride(from: 0, to: tiles.count, by: 5) {
      let row = UIStackView()
      row.axis = .horizontal
      row.alignment = .top
      row.distribution = .fillEqually
      row.spacing = 6
      let end = min(offset + 5, tiles.count)
      for tile in tiles[offset..<end] { row.addArrangedSubview(tile) }
      if end - offset < 5 {
        for _ in 0..<(5 - (end - offset)) { row.addArrangedSubview(UIView()) }
      }
      grid.addArrangedSubview(row)
    }

    let stack = UIStackView(arrangedSubviews: [titleLabel, grid])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.spacing = 11
    let card = UIView()
    card.backgroundColor = color
    card.layer.cornerRadius = 20
    card.layer.borderWidth = 1
    card.layer.borderColor = UIColor.white.withAlphaComponent(0.08).cgColor
    card.addSubview(stack)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(equalTo: card.leadingAnchor, constant: 13),
      stack.trailingAnchor.constraint(equalTo: card.trailingAnchor, constant: -13),
      stack.topAnchor.constraint(equalTo: card.topAnchor, constant: 14),
      stack.bottomAnchor.constraint(equalTo: card.bottomAnchor, constant: -14),
    ])
    return card
  }

  private func refreshInstalledCard() {
    installedCardContainer.subviews.forEach { $0.removeFromSuperview() }
    installedTileControls.removeAll()

    let installedApps = catalogApps.filter { descriptor in
      descriptor.usesFlutterSidecar
        ? pornhubInstalled
        : installedPlayBoxGuests[descriptor.id] != nil
    }
    installedCardContainer.isHidden = installedApps.isEmpty
    guard !installedApps.isEmpty else { return }

    let card = makeSectionCard(
      title: "已安装",
      color: UIColor(red: 0.095, green: 0.19, blue: 0.30, alpha: 1),
      tiles: installedApps.map(makeInstalledTile)
    )
    card.translatesAutoresizingMaskIntoConstraints = false
    installedCardContainer.addSubview(card)
    NSLayoutConstraint.activate([
      card.leadingAnchor.constraint(equalTo: installedCardContainer.leadingAnchor),
      card.trailingAnchor.constraint(equalTo: installedCardContainer.trailingAnchor),
      card.topAnchor.constraint(equalTo: installedCardContainer.topAnchor),
      card.bottomAnchor.constraint(equalTo: installedCardContainer.bottomAnchor),
    ])
  }

  private func launchedVersionToken(for descriptor: PlayBoxGuestDescriptor) -> String {
    "\(descriptor.expectedVersion)+\(descriptor.expectedBuild)"
  }

  private func hasLaunchedInstalledApp(_ descriptor: PlayBoxGuestDescriptor) -> Bool {
    launchedVersions[descriptor.id] == launchedVersionToken(for: descriptor)
  }

  private func markInstalledAppLaunched(_ descriptor: PlayBoxGuestDescriptor?) {
    guard let descriptor else { return }
    let versionToken = launchedVersionToken(for: descriptor)
    guard launchedVersions[descriptor.id] != versionToken else { return }
    launchedVersions[descriptor.id] = versionToken
    do {
      try FileManager.default.createDirectory(
        at: launchedVersionsURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
      )
      let data = try PropertyListSerialization.data(
        fromPropertyList: launchedVersions,
        format: .binary,
        options: 0
      )
      try data.write(to: launchedVersionsURL, options: .atomic)
      refreshInstalledCard()
      print("APPBOX_RUNTIME first_launch_recorded id=\(descriptor.id) version=\(versionToken)")
    } catch {
      launchedVersions.removeValue(forKey: descriptor.id)
      print("APPBOX_RUNTIME first_launch_record_failed id=\(descriptor.id) error=\(error.localizedDescription)")
    }
  }

  private func loadLaunchedVersions() -> [String: String] {
    guard let data = try? Data(contentsOf: launchedVersionsURL),
          let propertyList = try? PropertyListSerialization.propertyList(
            from: data,
            options: [],
            format: nil
          ),
          let versions = propertyList as? [String: String] else { return [:] }
    return versions
  }

  private func makeInstalledTile(_ descriptor: PlayBoxGuestDescriptor) -> UIView {
    let icon = descriptor.usesFlutterSidecar
      ? UIImage(named: "guest_pornhub") ?? UIImage(systemName: "play.rectangle.fill")
      : descriptor.localIconName.flatMap(UIImage.init(named:))
        ?? UIImage(systemName: "play.square.stack.fill")
    let iconView = UIImageView(image: icon)
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFill
    iconView.tintColor = .white
    iconView.backgroundColor = UIColor.black.withAlphaComponent(0.24)
    iconView.layer.cornerRadius = 13
    iconView.layer.borderWidth = 1
    iconView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
    iconView.clipsToBounds = true
    if let iconURL = descriptor.iconURL { loadIcon(iconURL, into: iconView) }

    let iconContainer = UIView()
    iconContainer.addSubview(iconView)
    NSLayoutConstraint.activate([
      iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
      iconView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
      iconView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
      iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor),
      iconView.heightAnchor.constraint(equalToConstant: 56),
    ])

    let statusDot = UIView()
    statusDot.translatesAutoresizingMaskIntoConstraints = false
    statusDot.backgroundColor = UIColor(red: 0.28, green: 0.62, blue: 1, alpha: 1)
    statusDot.layer.cornerRadius = 2.5
    statusDot.isHidden = hasLaunchedInstalledApp(descriptor)
    NSLayoutConstraint.activate([
      statusDot.widthAnchor.constraint(equalToConstant: 5),
      statusDot.heightAnchor.constraint(equalToConstant: 5),
    ])

    let nameLabel = UILabel()
    nameLabel.text = descriptor.displayName
    nameLabel.textColor = UIColor.white.withAlphaComponent(0.92)
    nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
    nameLabel.numberOfLines = 1
    nameLabel.lineBreakMode = .byTruncatingTail
    nameLabel.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)

    let nameRow = UIStackView(arrangedSubviews: [statusDot, nameLabel])
    nameRow.axis = .horizontal
    nameRow.alignment = .center
    nameRow.spacing = 3
    nameRow.distribution = .fill

    let stack = UIStackView(arrangedSubviews: [iconContainer, nameRow])
    stack.translatesAutoresizingMaskIntoConstraints = false
    stack.axis = .vertical
    stack.alignment = .center
    stack.spacing = 6
    // The whole tile is the launch target. If the inner stack participates in
    // hit testing, UIKit delivers the touch to that plain view instead of the
    // surrounding UIControl and `.touchUpInside` never fires.
    stack.isUserInteractionEnabled = false

    let control = UIControl()
    control.addSubview(stack)
    control.accessibilityLabel = "启动\(descriptor.displayName)"
    control.accessibilityTraits = .button
    control.addAction(UIAction { [weak self] _ in
      guard let self else { return }
      descriptor.usesFlutterSidecar
        ? self.startPornhub()
        : self.startPlayBox(descriptor)
    }, for: .touchUpInside)
    control.addAction(UIAction { action in
      guard let control = action.sender as? UIControl else { return }
      UIView.animate(withDuration: 0.1) {
        control.alpha = 0.72
        control.transform = CGAffineTransform(scaleX: 0.96, y: 0.96)
      }
    }, for: .touchDown)
    control.addAction(UIAction { action in
      guard let control = action.sender as? UIControl else { return }
      UIView.animate(withDuration: 0.14) {
        control.alpha = 1
        control.transform = .identity
      }
    }, for: [.touchUpInside, .touchUpOutside, .touchCancel, .touchDragExit])
    installedTileControls.append(control)
    NSLayoutConstraint.activate([
      stack.leadingAnchor.constraint(greaterThanOrEqualTo: control.leadingAnchor),
      stack.trailingAnchor.constraint(lessThanOrEqualTo: control.trailingAnchor),
      stack.centerXAnchor.constraint(equalTo: control.centerXAnchor),
      stack.topAnchor.constraint(equalTo: control.topAnchor),
      stack.bottomAnchor.constraint(equalTo: control.bottomAnchor),
    ])
    return control
  }

  private func makePornhubTile(_ descriptor: PlayBoxGuestDescriptor, index: Int) -> UIView {
    return makeTile(
      name: descriptor.displayName,
      image: UIImage(named: "guest_pornhub") ?? UIImage(systemName: "play.rectangle.fill"),
      remoteIconURL: descriptor.iconURL,
      button: pornhubButton
    )
  }

  private func makeGuestTile(_ descriptor: PlayBoxGuestDescriptor, index: Int) -> UIView {
    if descriptor.usesFlutterSidecar {
      return makePornhubTile(descriptor, index: index)
    }
    let button = UIButton(type: .system)
    configureGridButton(button, title: "安装")
    button.addAction(UIAction { [weak self] _ in
      guard let self else { return }
      self.installedPlayBoxGuests[descriptor.id] == nil
        ? self.downloadPlayBox(descriptor)
        : self.startPlayBox(descriptor)
    }, for: .touchUpInside)
    playBoxButtons[descriptor.id] = button
    return makeTile(
      name: descriptor.displayName,
      image: descriptor.localIconName.flatMap(UIImage.init(named:))
        ?? UIImage(systemName: "play.square.stack.fill"),
      remoteIconURL: descriptor.iconURL,
      button: button
    )
  }

  private func makeTile(
    name: String,
    image: UIImage?,
    remoteIconURL: URL?,
    button: UIButton
  ) -> UIView {
    let iconView = UIImageView(image: image)
    iconView.translatesAutoresizingMaskIntoConstraints = false
    iconView.contentMode = .scaleAspectFill
    iconView.tintColor = .white
    iconView.backgroundColor = UIColor.black.withAlphaComponent(0.24)
    iconView.layer.cornerRadius = 13
    iconView.layer.borderWidth = 1
    iconView.layer.borderColor = UIColor.white.withAlphaComponent(0.12).cgColor
    iconView.clipsToBounds = true
    if let remoteIconURL { loadIcon(remoteIconURL, into: iconView) }

    let iconContainer = UIView()
    iconContainer.addSubview(iconView)
    NSLayoutConstraint.activate([
      iconView.centerXAnchor.constraint(equalTo: iconContainer.centerXAnchor),
      iconView.topAnchor.constraint(equalTo: iconContainer.topAnchor),
      iconView.bottomAnchor.constraint(equalTo: iconContainer.bottomAnchor),
      iconView.widthAnchor.constraint(equalTo: iconView.heightAnchor),
      iconView.heightAnchor.constraint(equalToConstant: 56),
    ])

    let nameLabel = UILabel()
    nameLabel.text = name
    nameLabel.textColor = .white
    nameLabel.font = .systemFont(ofSize: 12, weight: .semibold)
    nameLabel.numberOfLines = 2
    nameLabel.textAlignment = .center
    nameLabel.adjustsFontSizeToFitWidth = true
    nameLabel.minimumScaleFactor = 0.78
    nameLabel.heightAnchor.constraint(equalToConstant: 32).isActive = true

    let stack = UIStackView(arrangedSubviews: [iconContainer, nameLabel, button])
    stack.axis = .vertical
    stack.spacing = 4
    return stack
  }

  private func configureGridButton(_ button: UIButton, title: String) {
    setButtonPresentation(button, title: title, loading: false)
    button.setTitleColor(.white, for: .normal)
    button.setTitleColor(UIColor.white.withAlphaComponent(0.55), for: .disabled)
    button.titleLabel?.font = .systemFont(ofSize: 13.5, weight: .semibold)
    button.backgroundColor = UIColor.white.withAlphaComponent(0.18)
    button.layer.cornerRadius = 15
    button.heightAnchor.constraint(equalToConstant: 30).isActive = true
    let spinner = UIActivityIndicatorView(style: .medium)
    spinner.tag = 3107
    spinner.translatesAutoresizingMaskIntoConstraints = false
    spinner.color = .white
    spinner.transform = CGAffineTransform(scaleX: 0.68, y: 0.68)
    spinner.hidesWhenStopped = true
    button.addSubview(spinner)
    NSLayoutConstraint.activate([
      spinner.leadingAnchor.constraint(equalTo: button.leadingAnchor, constant: 5),
      spinner.centerYAnchor.constraint(equalTo: button.centerYAnchor),
    ])
  }

  private func setButtonPresentation(
    _ button: UIButton,
    title: String,
    loading: Bool
  ) {
    if button.title(for: .normal) != title {
      UIView.performWithoutAnimation {
        button.setTitle(title, for: .normal)
        button.setTitle(title, for: .disabled)
        button.setTitle(title, for: .highlighted)
        button.layoutIfNeeded()
      }
    }
    let spinner = button.viewWithTag(3107) as? UIActivityIndicatorView
    if loading && spinner?.isAnimating != true {
      spinner?.startAnimating()
    } else if !loading && spinner?.isAnimating == true {
      spinner?.stopAnimating()
    }
    let insets = loading
      ? UIEdgeInsets(top: 0, left: 16, bottom: 0, right: 0)
      : .zero
    if button.contentEdgeInsets != insets {
      button.contentEdgeInsets = insets
    }
  }

  private func sectionColor(index: Int, title: String) -> UIColor {
    if title.contains("直播") || title.contains("棋牌") {
      return UIColor(red: 0.14, green: 0.29, blue: 0.34, alpha: 1)
    }
    let colors = [
      UIColor(red: 0.17, green: 0.24, blue: 0.43, alpha: 1),
      UIColor(red: 0.14, green: 0.29, blue: 0.34, alpha: 1),
      UIColor(red: 0.25, green: 0.20, blue: 0.38, alpha: 1),
      UIColor(red: 0.25, green: 0.25, blue: 0.31, alpha: 1),
    ]
    return colors[index % colors.count]
  }

  private func loadIcon(_ url: URL, into imageView: UIImageView) {
    URLSession.shared.dataTask(with: url) { data, _, _ in
      guard let data else { return }
      let image = UIImage(data: data)
        ?? AppBoxAssetCrypto.decryptImageData(data).flatMap(UIImage.init(data:))
      guard let image else { return }
      DispatchQueue.main.async { imageView.image = image }
    }.resume()
  }

  private func rebuildCoordinators() {
    playBoxCoordinators = Dictionary(uniqueKeysWithValues: playBoxCatalogApps.map { descriptor in
      let coordinator = PlayBoxGuestRuntimeCoordinator(descriptor: descriptor)
      coordinator.onEvent = { [weak self] event in
        self?.handlePlayBox(event, descriptor: descriptor)
      }
      return (descriptor.id, coordinator)
    })
  }

  private func refreshRemoteCatalog() async {
    guard !catalogRefreshInFlight else {
      await MainActor.run { self.refreshControl.endRefreshing() }
      return
    }
    catalogRefreshInFlight = true
    do {
      let sections = try await catalogService.fetch()
      await MainActor.run {
        self.catalogRefreshInFlight = false
        self.catalogLoadFailed = false
        self.refreshControl.endRefreshing()
        let changed = self.catalogSections != sections
        self.catalogSections = sections
        if changed {
          self.rebuildCoordinators()
          self.renderCatalog()
        }
        self.refreshInstalledState()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) { [weak self] in
          guard let self, self.activeCatalogID == nil else { return }
          self.refreshInstalledState()
        }
        print("APPBOX_CATALOG remote_ready sections=\(sections.count) apps=\(self.catalogApps.count)")
        self.performPendingCatalogAction()
      }
    } catch {
      await MainActor.run {
        self.catalogRefreshInFlight = false
        self.catalogLoadFailed = true
        self.refreshControl.endRefreshing()
        if self.catalogSections.isEmpty {
          self.renderCatalog()
        }
        print("APPBOX_CATALOG unavailable error=\(error.localizedDescription)")
      }
    }
  }

  private func performPendingCatalogAction() {
    if let appID = pendingCatalogInstallID {
      pendingCatalogInstallID = nil
      guard let descriptor = catalogApps.first(where: { $0.id == appID }) else {
        showFailure("在线目录中找不到应用 \(appID)")
        return
      }
      descriptor.usesFlutterSidecar
        ? downloadPornhub(descriptor)
        : downloadPlayBox(descriptor)
      return
    }
    if let appID = pendingCatalogStartID {
      pendingCatalogStartID = nil
      guard let descriptor = catalogApps.first(where: { $0.id == appID }) else {
        showFailure("在线目录中找不到应用 \(appID)")
        return
      }
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
        descriptor.usesFlutterSidecar
          ? self?.startPornhub()
          : self?.startPlayBox(descriptor)
      }
    }
  }

  private func downloadPornhub(_ descriptor: PlayBoxGuestDescriptor? = nil) {
    let configured = configuredURL(key: "AppBoxPornhubGuestURL", fallbackKey: "AppBoxGuestURL")
    guard let url = descriptor?.packageURL ?? configured else {
      showFailure("天涯下载地址无效")
      return
    }
    activeCatalogID = descriptor?.id ?? flutterCatalogApp?.id
    setButtonPresentation(pornhubButton, title: "下载中", loading: true)
    setBusy(true, message: "正在下载天涯…")
    pornhubCoordinator.prepare(
      from: url,
      nivmURL: descriptor?.nivmURL,
      expectedIPASHA256: descriptor?.expectedIPASHA256,
      expectedNIVMSHA256: descriptor?.expectedNIVMSHA256
    )
  }

  private func downloadPlayBox(_ descriptor: PlayBoxGuestDescriptor) {
    let configured = configuredURL(
      key: descriptor.infoURLKey,
      fallbackKey: descriptor.id == PlayBoxGuestDescriptor.adultDouyin.id ? "AppBoxGuestURL" : nil
    )
    guard let url = descriptor.packageURL ?? configured else {
      showFailure("\(descriptor.displayName) 下载地址无效")
      return
    }
    activeCatalogID = descriptor.id
    if let button = playBoxButtons[descriptor.id] {
      setButtonPresentation(button, title: "下载中", loading: true)
    }
    setBusy(true, message: "正在下载 \(descriptor.displayName)…")
    playBoxCoordinators[descriptor.id]?.prepare(from: url)
  }

  private func installInjectedPlayBoxGuest(_ descriptor: PlayBoxGuestDescriptor) {
    activeCatalogID = descriptor.id
    if let button = playBoxButtons[descriptor.id] {
      setButtonPresentation(button, title: "安装中", loading: true)
    }
    setBusy(true, message: "正在验证 USB 注入的 \(descriptor.displayName)…")
    playBoxCoordinators[descriptor.id]?.prepare(from: URL(string: "http://127.0.0.1/")!)
  }

  private func configuredURL(key: String, fallbackKey: String?) -> URL? {
    let primary = (Bundle.main.object(forInfoDictionaryKey: key) as? String)
      .flatMap { $0.isEmpty ? nil : $0 }
    let fallback = fallbackKey.flatMap {
      (Bundle.main.object(forInfoDictionaryKey: $0) as? String)
        .flatMap { $0.isEmpty ? nil : $0 }
    }
    guard let configured = primary ?? fallback,
          let url = URL(string: configured),
          ["http", "https"].contains(url.scheme?.lowercased() ?? "") else { return nil }
    return url
  }

  private func handlePornhub(_ event: GuestRuntimeCoordinator.Event) {
    switch event {
    case .status(let message):
      cancelButtonProgressRender()
      setButtonPresentation(pornhubButton, title: compactLoadingTitle(message), loading: true)
      print("APPBOX_FLUTTER_RUNTIME \(message)")
    case .progress(let value, let artifact):
      let overallProgress = artifact.contains("NIVM")
        ? 0.82 + (Float(value) * 0.16)
        : 0.02 + (Float(value) * 0.78)
      renderButtonProgress(pornhubButton, progress: overallProgress)
    case .ready(let payload):
      cancelButtonProgressRender()
      pornhubInstalled = true
      UserDefaults.standard.set(payload.ipaSHA256, forKey: "AppBoxPornhubGuestIPAHash")
      setButtonPresentation(pornhubButton, title: "启动", loading: false)
      setBusy(false, message: "天涯 \(payload.version) (\(payload.build)) 已下载")
      activeCatalogID = nil
      refreshInstalledCard()
      print("APPBOX_FLUTTER_RUNTIME guest_ready version=\(payload.version)+\(payload.build) sha256=\(payload.ipaSHA256)")
      if autoStartCatalogID == flutterCatalogApp?.id {
        autoStartCatalogID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
          self?.startPornhub()
        }
      }
    case .failure(let message):
      cancelButtonProgressRender()
      setButtonPresentation(
        pornhubButton,
        title: pornhubInstalled ? "启动" : "重试",
        loading: false
      )
      showFailure(message)
    }
  }

  private func handlePlayBox(
    _ event: PlayBoxGuestRuntimeCoordinator.Event,
    descriptor: PlayBoxGuestDescriptor
  ) {
    switch event {
    case .status(let message):
      cancelButtonProgressRender()
      if let button = playBoxButtons[descriptor.id] {
        setButtonPresentation(button, title: compactLoadingTitle(message), loading: true)
      }
      print("APPBOX_PLAYBOX_RUNTIME guest=\(descriptor.id) \(message)")
    case .progress(let value):
      if let button = playBoxButtons[descriptor.id] {
        renderButtonProgress(button, progress: Float(value))
      }
    case .ready(let payload):
      cancelButtonProgressRender()
      installedPlayBoxGuests[descriptor.id] = payload
      UserDefaults.standard.set(
        payload.ipaSHA256,
        forKey: "AppBoxPlayBoxGuestIPAHash.\(descriptor.id)"
      )
      if let button = playBoxButtons[descriptor.id] {
        setButtonPresentation(button, title: "启动", loading: false)
      }
      setBusy(false, message: "\(descriptor.displayName) \(payload.version) (\(payload.build)) 已下载")
      activeCatalogID = nil
      refreshInstalledCard()
      print("APPBOX_PLAYBOX_RUNTIME guest_ready id=\(descriptor.id) version=\(payload.version)+\(payload.build) sha256=\(payload.ipaSHA256)")
      if autoStartCatalogID == descriptor.id {
        autoStartCatalogID = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) { [weak self] in
          self?.startPlayBox(descriptor)
        }
      }
    case .failure(let message):
      cancelButtonProgressRender()
      if let button = playBoxButtons[descriptor.id] {
        setButtonPresentation(
          button,
          title: installedPlayBoxGuests[descriptor.id] == nil ? "重试" : "启动",
          loading: false
        )
      }
      showFailure(message)
    }
  }

  private func setBusy(_ busy: Bool, message _: String) {
    pornhubButton.isEnabled = !busy
    playBoxButtons.values.forEach { $0.isEnabled = !busy }
    installedTileControls.forEach { $0.isEnabled = !busy }
    if busy {
      cancelButtonProgressRender()
      displayedButtonProgress = 0
    } else {
      pornhubButton.isEnabled = true
      playBoxButtons.values.forEach { $0.isEnabled = true }
      installedTileControls.forEach { $0.isEnabled = true }
    }
  }

  private func showFailure(_ message: String) {
    cancelButtonProgressRender()
    if launchInProgress {
      finishLaunchFeedback()
    }
    activeCatalogID = nil
    pornhubButton.isEnabled = true
    playBoxButtons.values.forEach { $0.isEnabled = true }
    installedTileControls.forEach { $0.isEnabled = true }
    if presentedViewController == nil, view.window != nil {
      let alert = UIAlertController(title: "操作失败", message: message, preferredStyle: .alert)
      alert.addAction(UIAlertAction(title: "知道了", style: .default))
      present(alert, animated: true)
    }
    print("APPBOX_RUNTIME guest_failed error=\(message)")
  }

  private func setLaunchControlsEnabled(_ enabled: Bool) {
    pornhubButton.isEnabled = enabled
    playBoxButtons.values.forEach { $0.isEnabled = enabled }
    installedTileControls.forEach { $0.isEnabled = enabled }
    scrollView.isScrollEnabled = enabled
    refreshControl.isEnabled = enabled
  }

  private func showLaunchOverlay(for descriptor: PlayBoxGuestDescriptor?) {
    let fallbackImage = descriptor?.usesFlutterSidecar == true
      ? UIImage(named: "guest_pornhub") ?? UIImage(systemName: "play.rectangle.fill")
      : descriptor?.localIconName.flatMap(UIImage.init(named:))
        ?? UIImage(systemName: "play.square.stack.fill")
    launchIconView.image = fallbackImage
    if let iconURL = descriptor?.iconURL {
      loadIcon(iconURL, into: launchIconView)
    }
    let name = descriptor?.displayName ?? "天涯"
    launchTitleLabel.text = "\(name) 启动中..."
    launchProgressView.setProgress(0.08, animated: false)
    launchDetailLabel.text = "网络安全防护启动中 8%"
    launchOverlay.isHidden = false
    launchOverlay.alpha = 0
    launchPanel.transform = CGAffineTransform(scaleX: 0.965, y: 0.965)
    view.bringSubviewToFront(launchOverlay)
    UIView.animate(
      withDuration: 0.18,
      delay: 0,
      options: [.curveEaseOut, .beginFromCurrentState]
    ) {
      self.launchOverlay.alpha = 1
      self.launchPanel.transform = .identity
    }
  }

  private func updateLaunchProgress(
    _ progress: Float,
    detail: String,
    showsPercentage: Bool = true
  ) {
    launchProgressView.setProgress(progress, animated: true)
    launchDetailLabel.text = showsPercentage ? "\(detail) \(Int(progress * 100))%" : detail
    UIAccessibility.post(notification: .announcement, argument: launchDetailLabel.text)
  }

  private func scheduleLaunchStep(
    after delay: TimeInterval,
    progress: Float,
    detail: String
  ) {
    let item = DispatchWorkItem { [weak self] in
      guard let self, self.launchInProgress else { return }
      self.updateLaunchProgress(progress, detail: detail)
    }
    launchWorkItems.append(item)
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
  }

  private func finishLaunchFeedback() {
    launchWorkItems.forEach { $0.cancel() }
    launchWorkItems.removeAll()
    launchInProgress = false
    setLaunchControlsEnabled(true)
    UIView.animate(
      withDuration: 0.16,
      delay: 0,
      options: [.curveEaseIn, .beginFromCurrentState]
    ) {
      self.launchOverlay.alpha = 0
    } completion: { _ in
      self.launchOverlay.isHidden = true
      self.launchPanel.transform = .identity
    }
  }

  private func refreshInstalledState() {
    pornhubInstalled = hasInstalledPornhubGuest()
    if activeCatalogID == nil || activeCatalogID != flutterCatalogApp?.id {
      setButtonPresentation(
        pornhubButton,
        title: pornhubInstalled ? "启动" : "安装",
        loading: false
      )
    }
    pornhubButton.isEnabled = true

    installedPlayBoxGuests.removeAll()
    for descriptor in playBoxCatalogApps {
      let guest = installedPlayBoxGuest(descriptor)
      installedPlayBoxGuests[descriptor.id] = guest
      if activeCatalogID != descriptor.id, let button = playBoxButtons[descriptor.id] {
        setButtonPresentation(button, title: guest == nil ? "安装" : "启动", loading: false)
        button.isEnabled = true
      }
    }
    refreshInstalledCard()
    if launchInProgress {
      setLaunchControlsEnabled(false)
    }
  }

  private func compactLoadingTitle(_ message: String) -> String {
    if message.contains("下载") { return "下载中" }
    return "安装中"
  }

  private func renderButtonProgress(_ button: UIButton, progress: Float) {
    let clamped = max(displayedButtonProgress, min(0.99, max(0.01, progress)))
    pendingButtonProgress = (button, clamped)
    let now = CACurrentMediaTime()
    let delay = max(0, 0.10 - (now - lastButtonProgressRenderTime))
    guard delay > 0 else {
      flushButtonProgressRender()
      return
    }
    guard buttonProgressWorkItem == nil else { return }
    let item = DispatchWorkItem { [weak self] in
      self?.flushButtonProgressRender()
    }
    buttonProgressWorkItem = item
    DispatchQueue.main.asyncAfter(deadline: .now() + delay, execute: item)
  }

  private func flushButtonProgressRender() {
    buttonProgressWorkItem?.cancel()
    buttonProgressWorkItem = nil
    guard let pending = pendingButtonProgress else { return }
    pendingButtonProgress = nil
    displayedButtonProgress = pending.progress
    lastButtonProgressRenderTime = CACurrentMediaTime()
    let percent = max(1, min(99, Int(pending.progress * 100)))
    setButtonPresentation(pending.button, title: "\(percent)%", loading: true)
  }

  private func cancelButtonProgressRender() {
    buttonProgressWorkItem?.cancel()
    buttonProgressWorkItem = nil
    pendingButtonProgress = nil
  }

  private func hasInstalledPornhubGuest() -> Bool {
    guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return false
    }
    let root = documents.appendingPathComponent(
      "Applications/\(GuestRuntimeCoordinator.expectedBundleIdentifier).runtime"
    )
    return FileManager.default.fileExists(atPath: root.appendingPathComponent("Guest.bundle/Info.plist").path) &&
      FileManager.default.fileExists(atPath: root.appendingPathComponent("Guest.bundle/flutter_assets/kernel_blob.bin").path)
  }

  private func installedPlayBoxGuest(
    _ descriptor: PlayBoxGuestDescriptor
  ) -> PreparedPlayBoxGuest? {
    guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return nil
    }
    let app = documents.appendingPathComponent(
      "Applications/\(descriptor.storageIdentifier).app",
      isDirectory: true
    )
    guard let info = NSDictionary(contentsOf: app.appendingPathComponent("Info.plist")),
          info["CFBundleIdentifier"] as? String == descriptor.expectedBundleIdentifier,
          let executableName = info["CFBundleExecutable"] as? String,
          let version = info["CFBundleShortVersionString"] as? String,
          version == descriptor.expectedVersion,
          let build = info["CFBundleVersion"] as? String,
          build == descriptor.expectedBuild else { return nil }
    let executable = app.appendingPathComponent(executableName)
    let nivm = app.appendingPathComponent("rocketship.nivm")
    guard FileManager.default.fileExists(atPath: executable.path),
          FileManager.default.fileExists(atPath: nivm.path) else { return nil }
    return PreparedPlayBoxGuest(
      descriptor: descriptor,
      bundleIdentifier: descriptor.expectedBundleIdentifier,
      displayName: (info["CFBundleDisplayName"] as? String) ?? descriptor.displayName,
      version: version,
      build: build,
      ipaSHA256: UserDefaults.standard.string(
        forKey: "AppBoxPlayBoxGuestIPAHash.\(descriptor.id)"
      ) ?? "installed",
      appBundleURL: app,
      executableURL: executable,
      nivmURL: nivm
    )
  }

  private func startPornhub() {
    guard hasInstalledPornhubGuest() else {
      refreshInstalledState()
      showFailure("天涯尚未下载")
      return
    }
    requestGuestLaunch(runtimeKind: "flutter", descriptor: nil)
  }

  private func startPlayBox(_ descriptor: PlayBoxGuestDescriptor) {
    guard let guest = installedPlayBoxGuests[descriptor.id] else {
      refreshInstalledState()
      showFailure("\(descriptor.displayName) 尚未下载")
      return
    }
    requestGuestLaunch(runtimeKind: "playbox", descriptor: guest.descriptor)
  }

  private func requestGuestLaunch(
    runtimeKind: String,
    descriptor: PlayBoxGuestDescriptor?
  ) {
    guard !launchInProgress else { return }
    guard preparePlayBoxContinuationMarker(playBox: descriptor != nil) else {
      showFailure("无法准备 AppBox 自动续启标记")
      return
    }
    let defaults = UserDefaults.standard
    defaults.set(runtimeKind, forKey: "AppBoxGuestRuntimeKind")
    defaults.set(UUID().uuidString, forKey: "AppBoxGuestLaunchToken")
    if let descriptor {
      defaults.set(descriptor.expectedBundleIdentifier, forKey: "AppBoxPlayBoxGuestBundleIdentifier")
      defaults.set(descriptor.storageIdentifier, forKey: "AppBoxPlayBoxGuestStorageIdentifier")
    }
    defaults.synchronize()
    launchInProgress = true
    setLaunchControlsEnabled(false)
    let visibleDescriptor = descriptor ?? flutterCatalogApp
    showLaunchOverlay(for: visibleDescriptor)
    scheduleLaunchStep(after: 0.18, progress: 0.28, detail: "正在启动安全环境运行")
    scheduleLaunchStep(after: 0.42, progress: 0.58, detail: "正在载入应用资源")
    scheduleLaunchStep(after: 0.68, progress: 0.82, detail: "正在准备应用窗口")

    let shouldCapture = ProcessInfo.processInfo.arguments.contains("--appbox-capture-launch-progress")
    if shouldCapture {
      let captureItem = DispatchWorkItem { [weak self] in
        self?.captureLauncherScreenshot(fileName: "launch-progress.png")
      }
      launchWorkItems.append(captureItem)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.48, execute: captureItem)
    }

    let launchItem = DispatchWorkItem { [weak self] in
      guard let self, self.launchInProgress else { return }
      self.updateLaunchProgress(0.94, detail: "首次启动正在初始化，请稍候", showsPercentage: false)
      let startItem = DispatchWorkItem { [weak self] in
        guard let self, self.launchInProgress else { return }
        self.performGuestLaunch(runtimeKind: runtimeKind, descriptor: visibleDescriptor)
      }
      self.launchWorkItems.append(startItem)
      DispatchQueue.main.asyncAfter(deadline: .now() + 0.14, execute: startItem)
    }
    launchWorkItems.append(launchItem)
    DispatchQueue.main.asyncAfter(
      deadline: .now() + (shouldCapture ? 1.35 : 0.78),
      execute: launchItem
    )
  }

  private func performGuestLaunch(
    runtimeKind: String,
    descriptor: PlayBoxGuestDescriptor?
  ) {
    let defaults = UserDefaults.standard
    if runtimeKind == "playbox" {
      let launchResult = AppBoxLaunchSelectedPlayBoxGuestInProcess()
      print("APPBOX_RUNTIME in_process_guest_result=\(launchResult)")
      defaults.removeObject(forKey: "AppBoxGuestLaunchToken")
      defaults.removeObject(forKey: "AppBoxPlayBoxGuestLaunchToken")
      defaults.synchronize()
      _ = preparePlayBoxContinuationMarker(playBox: false)
      if launchResult == 0 {
        markInstalledAppLaunched(descriptor)
        return
      }
      finishLaunchFeedback()
      showFailure("PlayBox guest 启动失败；请重新打开 AppBox 后重试")
      return
    }

    let relaunchURL = URL(string: "appbox://playbox.guestapp.relaunch")!
    var completionCount = 0
    let completion: (Bool) -> Void = { [weak self] accepted in
      print("APPBOX_RUNTIME relaunch_requested runtime=\(runtimeKind) accepted=\(accepted)")
      guard let self else { return }
      completionCount += 1
      if accepted, !self.relaunchExitScheduled {
        self.markInstalledAppLaunched(descriptor)
        self.relaunchExitScheduled = true
        UIApplication.shared.perform(NSSelectorFromString("suspend"))
        exit(0)
      } else if completionCount >= 2, !self.relaunchExitScheduled {
        self.showFailure("无法自动进入应用，请重试")
      }
    }
    UIApplication.shared.open(relaunchURL, options: [:], completionHandler: completion)
    UIApplication.shared.open(relaunchURL, options: [:], completionHandler: completion)
  }

  private func preparePlayBoxContinuationMarker(playBox: Bool) -> Bool {
    guard let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else {
      return false
    }
    let directory = documents.appendingPathComponent("AppBoxTest", isDirectory: true)
    let marker = directory.appendingPathComponent("playbox-relaunch-continuation")
    do {
      if playBox {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data(UUID().uuidString.utf8).write(to: marker, options: .atomic)
      } else if FileManager.default.fileExists(atPath: marker.path) {
        try FileManager.default.removeItem(at: marker)
      }
      return true
    } catch {
      print("APPBOX_RUNTIME continuation_marker_failed error=\(error.localizedDescription)")
      return false
    }
  }

  private func captureLauncherScreenshot(fileName: String = "launcher-screen.png") {
    guard let window = view.window else { return }
    let buttonState = catalogApps.map { descriptor in
      let button = descriptor.usesFlutterSidecar ? pornhubButton : playBoxButtons[descriptor.id]
      return "\(descriptor.id):\(button?.title(for: .normal) ?? "nil"):\(button?.isEnabled == true)"
    }.joined(separator: ",")
    print("APPBOX_RUNTIME launcher_button_state \(buttonState)")
    let installedHitState = installedTileControls.map { control in
      let center = CGPoint(x: control.bounds.midX, y: control.bounds.midY)
      let point = control.convert(center, to: window)
      let hitView = window.hitTest(point, with: nil)
      return "\(control.accessibilityLabel ?? "unknown"):\(hitView === control)"
    }.joined(separator: ",")
    print("APPBOX_RUNTIME installed_tile_hit_state \(installedHitState)")
    let renderer = UIGraphicsImageRenderer(bounds: window.bounds)
    guard let png = renderer.image(actions: { _ in
      window.drawHierarchy(in: window.bounds, afterScreenUpdates: true)
    }).pngData(),
          let documents = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first else { return }
    let directory = documents.appendingPathComponent("AppBoxTest", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    do {
      try png.write(to: directory.appendingPathComponent(fileName), options: .atomic)
      print("APPBOX_RUNTIME launcher_screenshot file=\(fileName) bytes=\(png.count)")
    } catch {
      print("APPBOX_RUNTIME launcher_screenshot_failed error=\(error.localizedDescription)")
    }
  }
}
