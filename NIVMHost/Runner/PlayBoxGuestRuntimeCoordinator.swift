import CryptoKit
import Foundation
import ZIPFoundation

struct PlayBoxGuestDescriptor: Codable, Hashable {
  let id: String
  let storageIdentifier: String
  let displayName: String
  let expectedBundleIdentifier: String
  let expectedVersion: String
  let expectedBuild: String
  let infoURLKey: String
  let injectedFileName: String
  let installArgument: String
  let categoryID: String
  let categoryName: String
  let groupID: String
  let groupName: String
  let localIconName: String?
  let iconURL: URL?
  let packageURL: URL?
  let expectedIPASHA256: String?
  let nivmURL: URL?
  let expectedNIVMSHA256: String?

  /// Source-built Flutter guests use the signed sidecar archive produced by
  /// AppBox's Flutter pipeline. Converted PlayBox guests embed raw
  /// `rocketship.nivm` inside the IPA and expose that raw file as `nivmURL`.
  var usesFlutterSidecar: Bool {
    nivmURL?.lastPathComponent.lowercased().hasSuffix(".nivm.zip") == true
  }

  init(
    id: String,
    storageIdentifier: String,
    displayName: String,
    expectedBundleIdentifier: String,
    expectedVersion: String,
    expectedBuild: String,
    localIconName: String? = nil,
    infoURLKey: String = "",
    injectedFileName: String = "",
    installArgument: String = "",
    categoryID: String = "supported",
    categoryName: String = "已支持",
    groupID: String = "apps",
    groupName: String = "应用",
    iconURL: URL? = nil,
    packageURL: URL? = nil,
    expectedIPASHA256: String? = nil,
    nivmURL: URL? = nil,
    expectedNIVMSHA256: String? = nil
  ) {
    self.id = id
    self.storageIdentifier = storageIdentifier
    self.displayName = displayName
    self.expectedBundleIdentifier = expectedBundleIdentifier
    self.expectedVersion = expectedVersion
    self.expectedBuild = expectedBuild
    self.infoURLKey = infoURLKey
    self.injectedFileName = injectedFileName
    self.installArgument = installArgument
    self.categoryID = categoryID
    self.categoryName = categoryName
    self.groupID = groupID
    self.groupName = groupName
    self.localIconName = localIconName
    self.iconURL = iconURL
    self.packageURL = packageURL
    self.expectedIPASHA256 = expectedIPASHA256?.lowercased()
    self.nivmURL = nivmURL
    self.expectedNIVMSHA256 = expectedNIVMSHA256?.lowercased()
  }

  static let tianya348 = PlayBoxGuestDescriptor(
    id: "tianya-348",
    storageIdentifier: "tianya_348",
    displayName: "天涯 20.0.0+348",
    expectedBundleIdentifier: "com.laodeng.worldcupapp",
    expectedVersion: "20.0.0",
    expectedBuild: "348",
    localIconName: "guest_tianya",
    infoURLKey: "AppBoxTianya348GuestURL",
    injectedFileName: "tianya-348-playbox.ipa",
    installArgument: "--appbox-install-tianya-348"
  )

  static let adultDouyin = PlayBoxGuestDescriptor(
    id: "adult-douyin",
    storageIdentifier: "com.amk2ns2n9j.alan2is71",
    displayName: "成人抖音",
    expectedBundleIdentifier: "com.amk2ns2n9j.alan2is71",
    expectedVersion: "3.1.5",
    expectedBuild: "315",
    localIconName: "guest_adult_douyin",
    infoURLKey: "AppBoxPlayBoxGuestURL",
    injectedFileName: "playbox-guest.ipa",
    installArgument: "--appbox-install-playbox-guest"
  )

  static let dyzbOfficial = PlayBoxGuestDescriptor(
    id: "dyzb-gq",
    storageIdentifier: "dyzb_gq",
    displayName: "DYZB 官签",
    expectedBundleIdentifier: "ady.DYZB168dyzb.app",
    expectedVersion: "8.5.5",
    expectedBuild: "8.5.5",
    localIconName: "guest_dyzb_gq",
    infoURLKey: "AppBoxDYZBGQGuestURL",
    injectedFileName: "dyzb-gq-playbox.ipa",
    installArgument: "--appbox-install-dyzb-gq"
  )

  static let dyzbTestFlight = PlayBoxGuestDescriptor(
    id: "dyzb-tf",
    storageIdentifier: "dyzb_tf",
    displayName: "DYZB TF",
    expectedBundleIdentifier: "ady.DYZB168dyzb.app",
    expectedVersion: "8.5.5",
    expectedBuild: "8.5.5",
    localIconName: "guest_dyzb_tf",
    infoURLKey: "AppBoxDYZBTFGuestURL",
    injectedFileName: "dyzb-tf-playbox.ipa",
    installArgument: "--appbox-install-dyzb-tf"
  )

  static let chungong = PlayBoxGuestDescriptor(
    id: "chungong-3-9-1",
    storageIdentifier: "chungong_3_9_1",
    displayName: "春宫",
    expectedBundleIdentifier: "com.cg.client.pro",
    expectedVersion: "3.9.1",
    expectedBuild: "104",
    localIconName: "guest_chungong",
    infoURLKey: "AppBoxChungongGuestURL",
    injectedFileName: "chungong-playbox.ipa",
    installArgument: "--appbox-install-chungong"
  )

  static let igXiongmao = PlayBoxGuestDescriptor(
    id: "ig-xiongmao",
    storageIdentifier: "ig_xiongmao",
    displayName: "成人抖音 3188.tv",
    expectedBundleIdentifier: "com.igvideo.jingdong",
    expectedVersion: "3.1.3",
    expectedBuild: "313",
    localIconName: "guest_ig_xiongmao",
    infoURLKey: "AppBoxIGXiongmaoGuestURL",
    injectedFileName: "ig-xiongmao-playbox.ipa",
    installArgument: "--appbox-install-ig-xiongmao"
  )

  static let catalog: [PlayBoxGuestDescriptor] = [
    .tianya348,
    .adultDouyin,
    .dyzbOfficial,
    .dyzbTestFlight,
    .chungong,
    .igXiongmao,
  ]
}

struct PreparedPlayBoxGuest {
  let descriptor: PlayBoxGuestDescriptor
  let bundleIdentifier: String
  let displayName: String
  let version: String
  let build: String
  let ipaSHA256: String
  let appBundleURL: URL
  let executableURL: URL
  let nivmURL: URL
}

final class PlayBoxGuestRuntimeCoordinator: NSObject, URLSessionDownloadDelegate {
  enum Event {
    case status(String)
    case progress(Double)
    case ready(PreparedPlayBoxGuest)
    case failure(String)
  }

  static let maximumDownloadSize: Int64 = 500 * 1024 * 1024
  static let maximumExtractedSize: Int64 = 900 * 1024 * 1024

  let descriptor: PlayBoxGuestDescriptor
  var onEvent: ((Event) -> Void)?

  private var session: URLSession?
  private var terminalEventEmitted = false

  init(descriptor: PlayBoxGuestDescriptor) {
    self.descriptor = descriptor
  }

  func prepare(from remoteURL: URL) {
    terminalEventEmitted = false
    session?.invalidateAndCancel()

    if prepareInjectedArtifactIfRequested() {
      return
    }

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 900
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    self.session = session
    emit(.status("正在下载 \(descriptor.displayName) 的 PlayBox 运行包…"))
    session.downloadTask(with: remoteURL).resume()
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData bytesWritten: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    guard totalBytesExpectedToWrite > 0 else { return }
    if totalBytesExpectedToWrite > Self.maximumDownloadSize {
      downloadTask.cancel()
      fail("IPA 超过 500 MB 限制")
      return
    }
    emit(.progress(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)))
  }

  func urlSession(
    _ session: URLSession,
    downloadTask: URLSessionDownloadTask,
    didFinishDownloadingTo location: URL
  ) {
    prepareDownloadedIPA(at: location)
  }

  func urlSession(
    _ session: URLSession,
    task: URLSessionTask,
    didCompleteWithError error: Error?
  ) {
    guard let error, (error as NSError).code != NSURLErrorCancelled else { return }
    fail(error.localizedDescription)
  }

  private func prepareInjectedArtifactIfRequested() -> Bool {
    guard !descriptor.installArgument.isEmpty,
          ProcessInfo.processInfo.arguments.contains(descriptor.installArgument),
          let documents = FileManager.default.urls(
            for: .documentDirectory,
            in: .userDomainMask
          ).first else {
      return false
    }

    let injectedIPA = documents
      .appendingPathComponent("AppBoxTest", isDirectory: true)
      .appendingPathComponent(descriptor.injectedFileName)
    guard FileManager.default.fileExists(atPath: injectedIPA.path) else {
      fail("测试 IPA 未注入：\(descriptor.injectedFileName)")
      return true
    }

    emit(.status("检测到 USB 注入的 \(descriptor.displayName) PlayBox 包，正在验证并安装…"))
    DispatchQueue.global(qos: .userInitiated).async { [weak self] in
      self?.prepareDownloadedIPA(at: injectedIPA)
    }
    return true
  }

  private func prepareDownloadedIPA(at sourceURL: URL) {
    do {
      let payload = try validateAndInstallIPA(at: sourceURL)
      terminalEventEmitted = true
      emit(.ready(payload))
      session?.finishTasksAndInvalidate()
    } catch {
      fail(error.localizedDescription)
    }
  }

  private func validateAndInstallIPA(at sourceURL: URL) throws -> PreparedPlayBoxGuest {
    emit(.status("正在计算 \(descriptor.displayName) IPA SHA-256 并安全解包…"))
    let fileManager = FileManager.default
    let support = try fileManager.url(
      for: .applicationSupportDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let packageRoot = support
      .appendingPathComponent("PlayBoxImports", isDirectory: true)
      .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try fileManager.createDirectory(at: packageRoot, withIntermediateDirectories: true)
    let ipaURL = packageRoot.appendingPathComponent("guest.ipa")
    try fileManager.copyItem(at: sourceURL, to: ipaURL)

    guard try resourceSize(of: ipaURL) <= Self.maximumDownloadSize else {
      throw RuntimeError("IPA 超过 500 MB 限制")
    }
    let ipaSHA256 = try sha256(ofFile: ipaURL)
    if let expected = descriptor.expectedIPASHA256,
       ipaSHA256.caseInsensitiveCompare(expected) != .orderedSame {
      throw RuntimeError("IPA SHA-256 不匹配，已拒绝安装")
    }
    let archive = try Archive(url: ipaURL, accessMode: .read)
    let extractRoot = packageRoot.appendingPathComponent("Extracted", isDirectory: true)
    try fileManager.createDirectory(at: extractRoot, withIntermediateDirectories: true)

    var totalExtractedSize: Int64 = 0
    for entry in archive {
      guard entry.path == "Payload/" || entry.path.hasPrefix("Payload/"),
            !entry.path.contains("../"),
            !entry.path.hasPrefix("/") else {
        throw RuntimeError("IPA 包含非法路径：\(entry.path)")
      }
      guard entry.type != .symlink else {
        throw RuntimeError("IPA 不允许包含符号链接")
      }
      totalExtractedSize += Int64(entry.uncompressedSize)
      guard totalExtractedSize <= Self.maximumExtractedSize else {
        throw RuntimeError("IPA 解包后超过 900 MB 限制")
      }
      try archive.extract(entry, to: extractRoot.appendingPathComponent(entry.path))
    }

    let payloadDirectory = extractRoot.appendingPathComponent("Payload", isDirectory: true)
    let appBundles = try fileManager.contentsOfDirectory(
      at: payloadDirectory,
      includingPropertiesForKeys: nil
    ).filter { $0.pathExtension == "app" }
    guard appBundles.count == 1, let extractedApp = appBundles.first else {
      throw RuntimeError("IPA 必须只包含一个 Payload/*.app")
    }
    guard let info = NSDictionary(contentsOf: extractedApp.appendingPathComponent("Info.plist")),
          let bundleIdentifier = info["CFBundleIdentifier"] as? String,
          let executableName = info["CFBundleExecutable"] as? String,
          let version = info["CFBundleShortVersionString"] as? String,
          let build = info["CFBundleVersion"] as? String else {
      throw RuntimeError("无法读取 guest Info.plist")
    }
    guard bundleIdentifier == descriptor.expectedBundleIdentifier else {
      throw RuntimeError("拒绝 bundle ID：\(bundleIdentifier)")
    }
    guard version == descriptor.expectedVersion, build == descriptor.expectedBuild else {
      throw RuntimeError("拒绝 guest 版本：\(version) (\(build))")
    }

    let executableURL = extractedApp.appendingPathComponent(executableName)
    let nivmURL = extractedApp.appendingPathComponent("rocketship.nivm")
    guard fileManager.fileExists(atPath: executableURL.path) else {
      throw RuntimeError("guest 缺少可执行文件：\(executableName)")
    }
    guard fileManager.fileExists(atPath: nivmURL.path) else {
      throw RuntimeError("guest 缺少 PlayBox rocketship.nivm")
    }
    let nivmHeader = try Data(contentsOf: nivmURL, options: [.mappedIfSafe]).prefix(4)
    guard nivmHeader == Data([0x4e, 0x49, 0x56, 0x4d]) else {
      throw RuntimeError("rocketship.nivm 文件头无效")
    }
    if let expected = descriptor.expectedNIVMSHA256 {
      let nivmSHA256 = try sha256(ofFile: nivmURL)
      guard nivmSHA256.caseInsensitiveCompare(expected) == .orderedSame else {
        throw RuntimeError("rocketship.nivm SHA-256 不匹配，已拒绝安装")
      }
    }

    emit(.status("身份与 NIVM 已验证，正在写入 AppBox 独立 guest 沙盒…"))
    let documents = try fileManager.url(
      for: .documentDirectory,
      in: .userDomainMask,
      appropriateFor: nil,
      create: true
    )
    let applications = documents.appendingPathComponent("Applications", isDirectory: true)
    try fileManager.createDirectory(at: applications, withIntermediateDirectories: true)
    let installedApp = applications.appendingPathComponent(
      "\(descriptor.storageIdentifier).app",
      isDirectory: true
    )
    if fileManager.fileExists(atPath: installedApp.path) {
      try fileManager.removeItem(at: installedApp)
    }
    try fileManager.moveItem(at: extractedApp, to: installedApp)

    return PreparedPlayBoxGuest(
      descriptor: descriptor,
      bundleIdentifier: bundleIdentifier,
      displayName: (info["CFBundleDisplayName"] as? String) ?? descriptor.displayName,
      version: version,
      build: build,
      ipaSHA256: ipaSHA256,
      appBundleURL: installedApp,
      executableURL: installedApp.appendingPathComponent(executableName),
      nivmURL: installedApp.appendingPathComponent("rocketship.nivm")
    )
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
