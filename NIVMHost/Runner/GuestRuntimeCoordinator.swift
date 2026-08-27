import CryptoKit
import Foundation
import ZIPFoundation

struct PreparedGuestPayload {
  let bundleIdentifier: String
  let version: String
  let build: String
  let ipaSHA256: String
  let nivmSHA256: String
  let flutterEngine: String
  let appBundleURL: URL
  let appFrameworkBinaryURL: URL
  let flutterAssetsURL: URL
  let nivmBundleURL: URL
  let macho: GuestMachOLayout
}

final class GuestRuntimeCoordinator: NSObject, URLSessionDownloadDelegate {
  enum Event {
    case status(String)
    case progress(Double, String)
    case ready(PreparedGuestPayload)
    case failure(String)
  }

  static let expectedBundleIdentifier = "app.nqyqstm6mu.tianya"
  static let expectedFlutterEngine = "59aa584fdf100e6c78c785d8a5b565d1de4b48ab"
  static let expectedNIVMRuntime = "flutter_debug_arm64_simulator"
  static let maximumDownloadSize: Int64 = 300 * 1024 * 1024
  static let maximumExtractedNIVMSize: Int64 = 400 * 1024 * 1024

  var onEvent: ((Event) -> Void)?

  private enum DownloadKind {
    case ipa(URL)
    case nivm(URL)

    var label: String {
      switch self {
      case .ipa: return "完整 IPA"
      case .nivm: return "专用 NIVM"
      }
    }
  }

  private struct ValidatedIPA {
    let bundleIdentifier: String
    let version: String
    let build: String
    let ipaSHA256: String
    let flutterEngine: String
    let packageRoot: URL
    let appBundleURL: URL
    let appFrameworkBinaryURL: URL
    let flutterAssetsURL: URL
    let macho: GuestMachOLayout
  }

  private struct NIVMManifest: Decodable {
    let formatVersion: Int
    let runtime: String
    let targetBundleIdentifier: String
    let targetVersion: String
    let targetBuild: String
    let flutterEngine: String
    let sourceIpaSHA256: String
    let kernelSHA256: String
  }

  private var session: URLSession?
  private var downloadKind: DownloadKind?
  private var validatedIPA: ValidatedIPA?
  private var terminalEventEmitted = false
  private var explicitNIVMURL: URL?
  private var expectedIPASHA256: String?
  private var expectedNIVMSHA256: String?

  func prepare(
    from remoteURL: URL,
    nivmURL: URL? = nil,
    expectedIPASHA256: String? = nil,
    expectedNIVMSHA256: String? = nil
  ) {
    session?.invalidateAndCancel()
    validatedIPA = nil
    terminalEventEmitted = false
    explicitNIVMURL = nivmURL
    self.expectedIPASHA256 = expectedIPASHA256?.lowercased()
    self.expectedNIVMSHA256 = expectedNIVMSHA256?.lowercased()

    if prepareInjectedArtifactsIfPresent() {
      return
    }

    downloadKind = .ipa(remoteURL)

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 900
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    self.session = session
    emit(.status("正在下载完整的指定 IPA…"))
    session.downloadTask(with: remoteURL).resume()
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesExpectedToWrite > 0, let kind = downloadKind else { return }
    if totalBytesExpectedToWrite > Self.maximumDownloadSize {
      downloadTask.cancel()
      fail("\(kind.label) 超过 300 MB 限制")
      return
    }
    emit(.progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), kind.label))
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    guard let kind = downloadKind else {
      fail("下载状态丢失")
      return
    }

    do {
      switch kind {
      case .ipa(let ipaURL):
        let validated = try validateAndPrepareIPA(downloadedFile: location)
        validatedIPA = validated
        let nivmURL = try explicitNIVMURL ?? sidecarURL(for: ipaURL)
        downloadKind = .nivm(nivmURL)
        emit(.status("IPA 验证成功，正在下载与其 SHA-256 绑定的 NIVM…"))
        session.downloadTask(with: nivmURL).resume()

      case .nivm:
        guard let validatedIPA else {
          throw RuntimeError("NIVM 下载前缺少已验证 IPA")
        }
        let payload = try validateAndPrepareNIVM(downloadedFile: location, ipa: validatedIPA)
        terminalEventEmitted = true
        emit(.ready(payload))
        session.finishTasksAndInvalidate()
      }
    } catch {
      fail(error.localizedDescription)
    }
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let error, (error as NSError).code != NSURLErrorCancelled else { return }
    fail(error.localizedDescription)
  }

  private func validateAndPrepareIPA(downloadedFile: URL) throws -> ValidatedIPA {
    emit(.status("IPA 下载完成，正在计算 SHA-256…"))
    let fileManager = FileManager.default
    let support = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let packageRoot = support
      .appendingPathComponent("Guests", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: packageRoot, withIntermediateDirectories: true)
    let ipaURL = packageRoot.appendingPathComponent("guest.ipa")
    try fileManager.copyItem(at: downloadedFile, to: ipaURL)

    guard try resourceSize(of: ipaURL) <= Self.maximumDownloadSize else {
      throw RuntimeError("IPA 超过 300 MB 限制")
    }
    let ipaSHA256 = try sha256(ofFile: ipaURL)
    if let expectedIPASHA256,
       ipaSHA256.caseInsensitiveCompare(expectedIPASHA256) != .orderedSame {
      throw RuntimeError("IPA SHA-256 与在线目录不匹配")
    }

    emit(.status("正在安全解包 IPA Payload…"))
    let archive = try Archive(url: ipaURL, accessMode: .read)
    let extractRoot = packageRoot.appendingPathComponent("Extracted", isDirectory: true)
    try fileManager.createDirectory(at: extractRoot, withIntermediateDirectories: true)
    for entry in archive {
      guard entry.path == "Payload/" || entry.path.hasPrefix("Payload/"),
            !entry.path.contains("../"),
            !entry.path.hasPrefix("/") else {
        throw RuntimeError("IPA 包含非法路径：\(entry.path)")
      }
      guard entry.type != .symlink else {
        throw RuntimeError("IPA 不允许包含符号链接")
      }
      try archive.extract(entry, to: extractRoot.appendingPathComponent(entry.path))
    }

    let payloadDirectory = extractRoot.appendingPathComponent("Payload", isDirectory: true)
    let appBundles = try fileManager.contentsOfDirectory(
      at: payloadDirectory,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "app" }
    guard appBundles.count == 1, let appBundle = appBundles.first else {
      throw RuntimeError("IPA 必须只包含一个 Payload/*.app")
    }
    guard let info = NSDictionary(contentsOf: appBundle.appendingPathComponent("Info.plist")),
          let bundleIdentifier = info["CFBundleIdentifier"] as? String,
          let version = info["CFBundleShortVersionString"] as? String,
          let build = info["CFBundleVersion"] as? String else {
      throw RuntimeError("无法读取 guest Info.plist")
    }
    guard bundleIdentifier == Self.expectedBundleIdentifier else {
      throw RuntimeError("拒绝 bundle ID：\(bundleIdentifier)")
    }

    let appFramework = appBundle.appendingPathComponent("Frameworks/App.framework")
    let appBinary = appFramework.appendingPathComponent("App")
    let flutterInfoURL = appBundle.appendingPathComponent("Frameworks/Flutter.framework/Info.plist")
    guard let flutterInfo = NSDictionary(contentsOf: flutterInfoURL),
          let flutterEngine = flutterInfo["FlutterEngine"] as? String else {
      throw RuntimeError("不是受支持的 Flutter Release IPA")
    }
    guard flutterEngine == Self.expectedFlutterEngine else {
      throw RuntimeError("Flutter engine 不匹配：\(flutterEngine)")
    }

    emit(.status("正在解析 Flutter AOT Mach-O…"))
    let macho = try GuestMachOParser(url: appBinary).parse()
    let assets = appFramework.appendingPathComponent("flutter_assets", isDirectory: true)
    guard fileManager.fileExists(atPath: assets.path) else {
      throw RuntimeError("Guest 缺少 flutter_assets")
    }

    return ValidatedIPA(
      bundleIdentifier: bundleIdentifier,
      version: version,
      build: build,
      ipaSHA256: ipaSHA256,
      flutterEngine: flutterEngine,
      packageRoot: packageRoot,
      appBundleURL: appBundle,
      appFrameworkBinaryURL: appBinary,
      flutterAssetsURL: assets,
      macho: macho
    )
  }

  private func validateAndPrepareNIVM(
    downloadedFile: URL,
    ipa: ValidatedIPA
  ) throws -> PreparedGuestPayload {
    emit(.status("NIVM 下载完成，正在校验运行清单…"))
    let fileManager = FileManager.default
    let nivmArchiveURL = ipa.packageRoot.appendingPathComponent("guest.nivm.zip")
    try fileManager.copyItem(at: downloadedFile, to: nivmArchiveURL)
    let nivmSHA256 = try sha256(ofFile: nivmArchiveURL)
    if let expectedNIVMSHA256,
       nivmSHA256.caseInsensitiveCompare(expectedNIVMSHA256) != .orderedSame {
      throw RuntimeError("NIVM SHA-256 与在线目录不匹配")
    }

    let archive = try Archive(url: nivmArchiveURL, accessMode: .read)
    let extractRoot = ipa.packageRoot.appendingPathComponent("NIVM", isDirectory: true)
    try fileManager.createDirectory(at: extractRoot, withIntermediateDirectories: true)
    var totalUncompressedSize: Int64 = 0
    for entry in archive {
      let allowedPath = entry.path == "manifest.json" ||
        entry.path == "Guest.bundle/" ||
        entry.path.hasPrefix("Guest.bundle/")
      guard allowedPath, !entry.path.contains("../"), !entry.path.hasPrefix("/") else {
        throw RuntimeError("NIVM 包含非法路径：\(entry.path)")
      }
      guard entry.type != .symlink else {
        throw RuntimeError("NIVM 不允许包含符号链接")
      }
      totalUncompressedSize += Int64(entry.uncompressedSize)
      guard totalUncompressedSize <= Self.maximumExtractedNIVMSize else {
        throw RuntimeError("NIVM 解包后超过 400 MB 限制")
      }
      try archive.extract(entry, to: extractRoot.appendingPathComponent(entry.path))
    }

    let manifestURL = extractRoot.appendingPathComponent("manifest.json")
    let manifest = try JSONDecoder().decode(
      NIVMManifest.self,
      from: Data(contentsOf: manifestURL, options: [.mappedIfSafe])
    )
    guard manifest.formatVersion == 1 else {
      throw RuntimeError("不支持 NIVM 格式版本：\(manifest.formatVersion)")
    }
    guard manifest.runtime == Self.expectedNIVMRuntime else {
      throw RuntimeError("不支持 NIVM 运行时：\(manifest.runtime)")
    }
    guard manifest.targetBundleIdentifier == ipa.bundleIdentifier,
          manifest.targetVersion == ipa.version,
          manifest.targetBuild == ipa.build else {
      throw RuntimeError("NIVM 应用身份或版本与 IPA 不匹配")
    }
    guard manifest.flutterEngine == ipa.flutterEngine else {
      throw RuntimeError("NIVM Flutter engine 与 IPA 不匹配")
    }
    guard manifest.sourceIpaSHA256.lowercased() == ipa.ipaSHA256 else {
      throw RuntimeError("NIVM 与下载的 IPA SHA-256 不匹配")
    }

    let guestBundleURL = extractRoot.appendingPathComponent("Guest.bundle", isDirectory: true)
    let infoURL = guestBundleURL.appendingPathComponent("Info.plist")
    guard let bundleInfo = NSDictionary(contentsOf: infoURL),
          bundleInfo["CFBundleIdentifier"] as? String == "io.appbox.guest.tianya",
          bundleInfo["FLTAssetsPath"] as? String == "flutter_assets" else {
      throw RuntimeError("NIVM Guest.bundle 元数据无效")
    }
    let kernelURL = guestBundleURL.appendingPathComponent("flutter_assets/kernel_blob.bin")
    guard fileManager.fileExists(atPath: kernelURL.path) else {
      throw RuntimeError("NIVM 缺少 kernel_blob.bin")
    }
    guard try sha256(ofFile: kernelURL) == manifest.kernelSHA256.lowercased() else {
      throw RuntimeError("NIVM kernel SHA-256 校验失败")
    }

    // Install at a stable path relative to the current app container. The
    // container UUID can change when a development build is replaced.
    let documents = try fileManager.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let applications = documents.appendingPathComponent("Applications", isDirectory: true)
    let installedRoot = applications.appendingPathComponent(
      "\(Self.expectedBundleIdentifier).runtime",
      isDirectory: true
    )
    let installedBundle = installedRoot.appendingPathComponent("Guest.bundle", isDirectory: true)
    try fileManager.createDirectory(at: applications, withIntermediateDirectories: true)
    if fileManager.fileExists(atPath: installedRoot.path) {
      try fileManager.removeItem(at: installedRoot)
    }
    try fileManager.createDirectory(at: installedRoot, withIntermediateDirectories: true)
    try fileManager.copyItem(at: guestBundleURL, to: installedBundle)

    let installedMetadata: [String: Any] = [
      "CFBundleIdentifier": ipa.bundleIdentifier,
      "CFBundleShortVersionString": ipa.version,
      "CFBundleVersion": ipa.build,
      "IPA_SHA256": ipa.ipaSHA256,
      "NIVM_SHA256": nivmSHA256,
      "FlutterEngine": ipa.flutterEngine,
    ]
    guard (installedMetadata as NSDictionary).write(
      to: installedRoot.appendingPathComponent("Installed.plist"),
      atomically: true
    ) else {
      throw RuntimeError("无法保存 pornhub_client 安装元数据")
    }

    return PreparedGuestPayload(
      bundleIdentifier: ipa.bundleIdentifier,
      version: ipa.version,
      build: ipa.build,
      ipaSHA256: ipa.ipaSHA256,
      nivmSHA256: nivmSHA256,
      flutterEngine: ipa.flutterEngine,
      appBundleURL: ipa.appBundleURL,
      appFrameworkBinaryURL: ipa.appFrameworkBinaryURL,
      flutterAssetsURL: ipa.flutterAssetsURL,
      nivmBundleURL: installedBundle,
      macho: ipa.macho
    )
  }

  private func sidecarURL(for ipaURL: URL) throws -> URL {
    guard var components = URLComponents(url: ipaURL, resolvingAgainstBaseURL: false) else {
      throw RuntimeError("无法生成 NIVM 地址")
    }
    let directory = (components.path as NSString).deletingLastPathComponent
    let fileName = ((components.path as NSString).lastPathComponent as NSString)
      .deletingPathExtension
    components.path = (directory as NSString).appendingPathComponent("\(fileName).nivm.zip")
    guard let result = components.url else {
      throw RuntimeError("无法生成 NIVM 地址")
    }
    return result
  }

  private func prepareInjectedArtifactsIfPresent() -> Bool {
    guard ProcessInfo.processInfo.arguments.contains("--use-injected-guest") ||
            ProcessInfo.processInfo.arguments.contains("--appbox-install-pornhub-guest") else {
      return false
    }
    guard let documents = FileManager.default.urls(
      for: .documentDirectory,
      in: .userDomainMask
    ).first else {
      return false
    }
    let testRoot = documents.appendingPathComponent("AppBoxTest", isDirectory: true)
    let ipaURL = testRoot.appendingPathComponent("guest.ipa")
    let nivmURL = testRoot.appendingPathComponent("guest.nivm.zip")
    guard FileManager.default.fileExists(atPath: ipaURL.path),
          FileManager.default.fileExists(atPath: nivmURL.path) else {
      return false
    }

    emit(.status("检测到 USB 注入测试包，正在验证 IPA + NIVM…"))
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      guard let self else { return }
      do {
        let ipa = try self.validateAndPrepareIPA(downloadedFile: ipaURL)
        let payload = try self.validateAndPrepareNIVM(downloadedFile: nivmURL, ipa: ipa)
        self.terminalEventEmitted = true
        self.emit(.ready(payload))
      } catch {
        self.fail(error.localizedDescription)
      }
    }
    return true
  }

  private func resourceSize(of url: URL) throws -> Int64 {
    let values = try url.resourceValues(forKeys: [.fileSizeKey])
    return Int64(values.fileSize ?? 0)
  }

  private func sha256(ofFile url: URL) throws -> String {
    let handle = try FileHandle(forReadingFrom: url)
    defer { try? handle.close() }
    var hasher = SHA256()
    while true {
      let data = try autoreleasepool {
        try handle.read(upToCount: 1024 * 1024)
      }
      guard let data, !data.isEmpty else { break }
      hasher.update(data: data)
    }
    return hasher.finalize().map { String(format: "%02x", $0) }.joined()
  }

  private func fail(_ message: String) {
    guard !terminalEventEmitted else { return }
    terminalEventEmitted = true
    session?.invalidateAndCancel()
    emit(.failure(message))
  }

  private func emit(_ event: Event) {
    DispatchQueue.main.async { [weak self] in self?.onEvent?(event) }
  }

  private struct RuntimeError: LocalizedError {
    let message: String
    init(_ message: String) { self.message = message }
    var errorDescription: String? { message }
  }
}
