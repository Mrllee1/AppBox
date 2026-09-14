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

    let configuration = URLSessionConfiguration.ephemeral
    configuration.timeoutIntervalForRequest = 60
    configuration.timeoutIntervalForResource = 900
    let session = URLSession(configuration: configuration, delegate: self, delegateQueue: nil)
    self.session = session
    emit(.status("正在下载 \(descriptor.displayName) 的运行包…"))
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
      throw RuntimeError("应用缺少必要的运行组件")
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

    emit(.status("身份与运行组件已验证，正在写入独立应用空间…"))
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
