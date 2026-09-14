import CryptoKit
import Foundation
import Security
import UIKit

enum TempMailAPIError: LocalizedError {
  case unavailable
  case invalidResponse
  case authenticationFailed
  case server(String)

  var errorDescription: String? {
    switch self {
    case .unavailable:
      return "暂时无法连接邮箱服务，请检查网络后重试。"
    case .invalidResponse:
      return "邮箱服务返回了无法识别的数据。"
    case .authenticationFailed:
      return "无法初始化匿名邮箱会话，请稍后重试。"
    case let .server(message):
      return message.isEmpty ? "操作失败，请稍后重试。" : message
    }
  }
}

private struct TempMailAuthSession {
  let userID: String
  let accessToken: String
  let refreshToken: String
  let recoveryToken: String
}

@MainActor
final class TempMailAPIClient {
  private enum SecretKey {
    static let userID = "user_id"
    static let accessToken = "access_token"
    static let refreshToken = "refresh_token"
    static let recoveryToken = "device_recovery_token"
    static let stableID = "stable_recovery_id"
    static let deviceID = "device_id"
  }

  private let httpSession: URLSession
  private var currentBaseIndex = 0
  private var serverClockOffset: TimeInterval = 0
  private var sessionBootstrapTask: Task<TempMailAuthSession, Error>?

  private let baseURLs: [URL] = [
    URL(string: "https://api.dannia.asia")!,
    URL(string: "https://api.haoche.asia")!,
    URL(string: "https://api.xn--49sy1df7a0y6c.cn")!,
    URL(string: "https://api.xn--tqqy4c53cd3f3xbly3b1jaw3hsuod4tv70e6fq.tech")!,
  ]

  private let apiAESKey = Data(hex: "84d76a52788a6c3c9bff5f9a4084f84d")

  init(session: URLSession? = nil) {
    if let session {
      httpSession = session
    } else {
      let configuration = URLSessionConfiguration.ephemeral
      configuration.timeoutIntervalForRequest = 12
      configuration.timeoutIntervalForResource = 20
      configuration.waitsForConnectivity = true
      configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
      httpSession = URLSession(configuration: configuration)
    }
  }

  func domains() async throws -> [String] {
    let response = try await authenticatedRequest(path: "/api/temp-emails/domains", payload: [:])
    let data = try successData(from: response)
    return (data["domains"] as? [Any] ?? []).compactMap { $0 as? String }.filter { !$0.isEmpty }
  }

  func mailboxes() async throws -> [TempMailbox] {
    let response = try await authenticatedRequest(path: "/api/temp-emails/list", payload: [:])
    let data = try successData(from: response)
    return (data["list"] as? [[String: Any]] ?? []).compactMap(parseMailbox)
  }

  func createMailbox(localPart: String?, domain: String) async throws -> TempMailbox {
    var payload: [String: Any] = ["domain": domain]
    if let localPart = localPart?.trimmingCharacters(in: .whitespacesAndNewlines), !localPart.isEmpty {
      payload["local_part"] = localPart.lowercased()
    }
    let response = try await authenticatedRequest(path: "/api/temp-emails/create", payload: payload)
    let data = try successData(from: response)
    guard let mailbox = parseMailbox(data) else { throw TempMailAPIError.invalidResponse }
    return mailbox
  }

  func deleteMailbox(id: Int) async throws {
    let response = try await authenticatedRequest(path: "/api/temp-emails/\(id)/delete", payload: [:])
    _ = try successData(from: response, acceptsEmptyData: true)
  }

  func messages(mailboxID: Int, page: Int = 1, perPage: Int = 50) async throws -> ([TempMailMessage], Int) {
    let response = try await authenticatedRequest(
      path: "/api/temp-emails/\(mailboxID)/messages",
      payload: ["page": page, "per_page": perPage]
    )
    let data = try successData(from: response)
    let messages = (data["list"] as? [[String: Any]] ?? []).compactMap(parseMessage)
    return (messages, intValue(data["total"]))
  }

  func message(id: Int) async throws -> TempMailMessageDetail {
    let response = try await authenticatedRequest(path: "/api/temp-emails/messages/\(id)/detail", payload: [:])
    let data = try successData(from: response)
    guard let detail = parseMessageDetail(data) else { throw TempMailAPIError.invalidResponse }
    return detail
  }

  func attachment(messageID: Int, index: Int) async throws -> TempMailDownloadedAttachment {
    let response = try await authenticatedRequest(
      path: "/api/temp-emails/messages/\(messageID)/attachments/\(index)",
      payload: [:]
    )
    let data = try successData(from: response)
    guard let encoded = stringValue(data["data_base64"]),
          let decoded = Data(base64Encoded: encoded) else {
      throw TempMailAPIError.invalidResponse
    }
    return TempMailDownloadedAttachment(
      filename: stringValue(data["filename"]) ?? "attachment-\(index + 1)",
      contentType: stringValue(data["content_type"]) ?? "application/octet-stream",
      data: decoded
    )
  }

  func markMessageRead(id: Int) async throws {
    let response = try await authenticatedRequest(path: "/api/temp-emails/messages/\(id)/read", payload: [:])
    _ = try successData(from: response, acceptsEmptyData: true)
  }

  func deleteMessage(id: Int) async throws {
    let response = try await authenticatedRequest(path: "/api/temp-emails/messages/\(id)/delete", payload: [:])
    _ = try successData(from: response, acceptsEmptyData: true)
  }

  private func authenticatedRequest(path: String, payload: [String: Any]) async throws -> [String: Any] {
    var auth = try await ensureSession()
    var result = try await encryptedRequest(path: path, payload: payload, auth: auth)
    if result.statusCode == 401 {
      auth = try await refreshSession(using: auth)
      result = try await encryptedRequest(path: path, payload: payload, auth: auth)
    }
    return result.body
  }

  private func ensureSession() async throws -> TempMailAuthSession {
    if let userID = TempMailKeychain.read(SecretKey.userID), !userID.isEmpty,
       let accessToken = TempMailKeychain.read(SecretKey.accessToken), !accessToken.isEmpty,
       let refreshToken = TempMailKeychain.read(SecretKey.refreshToken), !refreshToken.isEmpty {
      return TempMailAuthSession(
        userID: userID,
        accessToken: accessToken,
        refreshToken: refreshToken,
        recoveryToken: TempMailKeychain.read(SecretKey.recoveryToken) ?? ""
      )
    }

    if let sessionBootstrapTask {
      return try await sessionBootstrapTask.value
    }
    let task = Task { try await startGuestSession() }
    sessionBootstrapTask = task
    defer { sessionBootstrapTask = nil }
    return try await task.value
  }

  private func startGuestSession() async throws -> TempMailAuthSession {
    let stableID = persistentIdentifier(for: SecretKey.stableID)
    let deviceID = persistentIdentifier(for: SecretKey.deviceID)
    let installKey = "tempMail.installInstanceID"
    let installID: String
    if let existing = UserDefaults.standard.string(forKey: installKey), !existing.isEmpty {
      installID = existing
    } else {
      installID = UUID().uuidString.lowercased()
      UserDefaults.standard.set(installID, forKey: installKey)
    }

    let idempotencyDefaultsKey = "tempMail.guestBootstrapIdempotencyKey"
    let idempotencyKey: String
    if let existing = UserDefaults.standard.string(forKey: idempotencyDefaultsKey), !existing.isEmpty {
      idempotencyKey = existing
    } else {
      idempotencyKey = UUID().uuidString.lowercased()
      UserDefaults.standard.set(idempotencyKey, forKey: idempotencyDefaultsKey)
    }

    let device = UIDevice.current
    var payload: [String: Any] = [
      "idempotency_key": idempotencyKey,
      "device_id": deviceID,
      "stable_recovery_id": stableID,
      "installation_id": stableID,
      "install_instance_id": installID,
      "device_fingerprint": SHA256.hash(data: Data("appbox-ios-\(stableID)".utf8)).hexString,
      "device_info": [
        "platform": "ios",
        "model": device.model,
        "system_version": device.systemVersion,
        "app_version": Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0",
        "client": "temp-mail",
      ],
    ]
    if let recovery = TempMailKeychain.read(SecretKey.recoveryToken), !recovery.isEmpty {
      payload["device_recovery_token"] = recovery
    }

    var finalBody: [String: Any]?
    for attempt in 0..<4 {
      let result = try await plainRequest(
        path: "/api/auth/guest/start",
        payload: payload,
        deviceID: deviceID
      )
      if (result["success"] as? Bool) == true {
        finalBody = result
        break
      }
      let errorCode = result["error_code"] as? String ?? ""
      if errorCode.contains("IN_PROGRESS"), attempt < 3 {
        try await Task.sleep(for: .milliseconds(350 * (attempt + 1)))
        continue
      }
      throw TempMailAPIError.server(result["message"] as? String ?? "匿名会话初始化失败")
    }

    guard let finalBody,
          let data = finalBody["data"] as? [String: Any],
          let user = data["user"] as? [String: Any],
          let userID = stringValue(user["user_id"]), !userID.isEmpty,
          let accessToken = stringValue(data["token"]), !accessToken.isEmpty,
          let refreshToken = stringValue(data["refresh_token"]), !refreshToken.isEmpty else {
      throw TempMailAPIError.authenticationFailed
    }
    let recoveryToken = stringValue(data["device_recovery_token"]) ?? ""
    try saveSession(
      userID: userID,
      accessToken: accessToken,
      refreshToken: refreshToken,
      recoveryToken: recoveryToken
    )
    UserDefaults.standard.removeObject(forKey: idempotencyDefaultsKey)
    return TempMailAuthSession(
      userID: userID,
      accessToken: accessToken,
      refreshToken: refreshToken,
      recoveryToken: recoveryToken
    )
  }

  private func refreshSession(using current: TempMailAuthSession) async throws -> TempMailAuthSession {
    let deviceID = persistentIdentifier(for: SecretKey.deviceID)
    do {
      let response = try await plainRequest(
        path: "/api/auth/session/refresh",
        payload: [
          "refresh_token": current.refreshToken,
          "device_id": deviceID,
          "device_info": ["platform": "ios", "client": "temp-mail"],
        ],
        deviceID: deviceID
      )
      guard (response["success"] as? Bool) == true,
            let data = response["data"] as? [String: Any],
            let user = data["user"] as? [String: Any],
            let userID = stringValue(user["user_id"]), !userID.isEmpty,
            let accessToken = stringValue(data["token"]), !accessToken.isEmpty,
            let refreshToken = stringValue(data["refresh_token"]), !refreshToken.isEmpty else {
        throw TempMailAPIError.authenticationFailed
      }
      let recoveryToken = stringValue(data["device_recovery_token"]) ?? current.recoveryToken
      try saveSession(
        userID: userID,
        accessToken: accessToken,
        refreshToken: refreshToken,
        recoveryToken: recoveryToken
      )
      return TempMailAuthSession(
        userID: userID,
        accessToken: accessToken,
        refreshToken: refreshToken,
        recoveryToken: recoveryToken
      )
    } catch {
      TempMailKeychain.delete(SecretKey.userID)
      TempMailKeychain.delete(SecretKey.accessToken)
      TempMailKeychain.delete(SecretKey.refreshToken)
      return try await startGuestSession()
    }
  }

  private func saveSession(
    userID: String,
    accessToken: String,
    refreshToken: String,
    recoveryToken: String
  ) throws {
    guard TempMailKeychain.write(userID, for: SecretKey.userID),
          TempMailKeychain.write(accessToken, for: SecretKey.accessToken),
          TempMailKeychain.write(refreshToken, for: SecretKey.refreshToken) else {
      throw TempMailAPIError.authenticationFailed
    }
    if !recoveryToken.isEmpty {
      guard TempMailKeychain.write(recoveryToken, for: SecretKey.recoveryToken) else {
        throw TempMailAPIError.authenticationFailed
      }
    }
  }

  private func persistentIdentifier(for key: String) -> String {
    if let existing = TempMailKeychain.read(key), UUID(uuidString: existing) != nil {
      return existing
    }
    let created = UUID().uuidString.lowercased()
    _ = TempMailKeychain.write(created, for: key)
    return created
  }

  private func plainRequest(
    path: String,
    payload: [String: Any],
    deviceID: String
  ) async throws -> [String: Any] {
    let body = try JSONSerialization.data(withJSONObject: payload)
    var lastError: Error = TempMailAPIError.unavailable
    for index in orderedBaseIndexes() {
      do {
        var request = URLRequest(url: baseURLs[index].appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-Platform-ID")
        request.setValue(deviceID, forHTTPHeaderField: "X-Device-Id")
        request.setValue("TempMail-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = body
        let (data, response) = try await httpSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TempMailAPIError.invalidResponse }
        updateClock(from: http)
        guard (200...499).contains(http.statusCode),
              let object = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          throw TempMailAPIError.invalidResponse
        }
        currentBaseIndex = index
        return object
      } catch {
        lastError = error
      }
    }
    throw lastError
  }

  private func encryptedRequest(
    path: String,
    payload: [String: Any],
    auth: TempMailAuthSession
  ) async throws -> (body: [String: Any], statusCode: Int) {
    var lastError: Error = TempMailAPIError.unavailable
    for index in orderedBaseIndexes() {
      do {
        var authenticatedPayload = payload
        authenticatedPayload["uid"] = auth.userID
        authenticatedPayload["token"] = auth.accessToken
        authenticatedPayload["platform_id"] = 1
        authenticatedPayload["plat"] = "ios"
        authenticatedPayload["platform"] = "ios"
        let payloadData = try JSONSerialization.data(withJSONObject: authenticatedPayload)
        guard let encrypted = AppBoxAssetCrypto.encryptTempMailAPIData(payloadData) else {
          throw TempMailAPIError.invalidResponse
        }
        let encryptedString = encrypted.base64EncodedString()
        let timestamp = Int(Date().addingTimeInterval(serverClockOffset).timeIntervalSince1970)
        let nonce = try secureNonce()
        let signature = hmacHex("data=\(encryptedString)&timestamp=\(timestamp)&nonce=\(nonce)")
        let requestBody = try JSONSerialization.data(withJSONObject: [
          "data": encryptedString,
          "timestamp": String(timestamp),
          "signature": signature,
          "nonce": nonce,
        ])

        var request = URLRequest(url: baseURLs[index].appending(path: path))
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("1", forHTTPHeaderField: "X-Platform-ID")
        request.setValue(persistentIdentifier(for: SecretKey.deviceID), forHTTPHeaderField: "X-Device-Id")
        request.setValue("TempMail-iOS/1.0", forHTTPHeaderField: "User-Agent")
        request.httpBody = requestBody
        let (data, response) = try await httpSession.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw TempMailAPIError.invalidResponse }
        updateClock(from: http)
        guard let outer = try JSONSerialization.jsonObject(with: data) as? [String: Any] else {
          throw TempMailAPIError.invalidResponse
        }
        let decoded = try decryptEnvelope(outer)
        currentBaseIndex = index
        return (decoded, http.statusCode)
      } catch {
        lastError = error
      }
    }
    throw lastError
  }

  private func decryptEnvelope(_ envelope: [String: Any]) throws -> [String: Any] {
    guard let encryptedString = envelope["data"] as? String,
          let encrypted = Data(base64Encoded: encryptedString),
          let signature = envelope["signature"] as? String,
          let nonce = envelope["nonce"] as? String else {
      // Development environments can still return a plain JSON error.
      if envelope["success"] != nil { return envelope }
      throw TempMailAPIError.invalidResponse
    }
    let timestamp = intValue(envelope["timestamp"])
    guard timestamp > 0,
          hmacHex("data=\(encryptedString)&timestamp=\(timestamp)&nonce=\(nonce)") == signature.lowercased(),
          abs(Int(Date().addingTimeInterval(serverClockOffset).timeIntervalSince1970) - timestamp) <= 90,
          var decrypted = AppBoxAssetCrypto.decryptTempMailAPIData(encrypted) else {
      throw TempMailAPIError.invalidResponse
    }
    if boolValue(envelope["compressed"]) {
      guard let uncompressed = AppBoxAssetCrypto.gunzipTempMailAPIData(decrypted) else {
        throw TempMailAPIError.invalidResponse
      }
      decrypted = uncompressed
    }
    guard let object = try JSONSerialization.jsonObject(with: decrypted) as? [String: Any] else {
      throw TempMailAPIError.invalidResponse
    }
    return object
  }

  private func successData(
    from response: [String: Any],
    acceptsEmptyData: Bool = false
  ) throws -> [String: Any] {
    guard (response["success"] as? Bool) == true else {
      throw TempMailAPIError.server(stringValue(response["message"]) ?? "操作失败，请稍后重试。")
    }
    if let data = response["data"] as? [String: Any] { return data }
    if acceptsEmptyData { return [:] }
    throw TempMailAPIError.invalidResponse
  }

  private func orderedBaseIndexes() -> [Int] {
    guard !baseURLs.isEmpty else { return [] }
    return (0..<baseURLs.count).map { (currentBaseIndex + $0) % baseURLs.count }
  }

  private func updateClock(from response: HTTPURLResponse) {
    guard let value = response.value(forHTTPHeaderField: "Date") else { return }
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "EEE',' dd MMM yyyy HH':'mm':'ss z"
    guard let serverDate = formatter.date(from: value) else { return }
    serverClockOffset = serverDate.timeIntervalSinceNow
  }

  private func secureNonce() throws -> String {
    var bytes = [UInt8](repeating: 0, count: 16)
    guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
      throw TempMailAPIError.unavailable
    }
    return bytes.map { String(format: "%02x", $0) }.joined()
  }

  private func hmacHex(_ value: String) -> String {
    let code = HMAC<SHA256>.authenticationCode(for: Data(value.utf8), using: SymmetricKey(data: apiAESKey))
    return Data(code).hexString
  }

  private func parseMailbox(_ raw: [String: Any]) -> TempMailbox? {
    let id = intValue(raw["id"])
    guard id > 0, let address = stringValue(raw["address"]), !address.isEmpty else { return nil }
    return TempMailbox(
      id: id,
      address: address,
      localPart: stringValue(raw["local_part"]) ?? address.split(separator: "@").first.map(String.init) ?? "",
      domain: stringValue(raw["domain"]) ?? address.split(separator: "@").dropFirst().first.map(String.init) ?? "",
      status: intValue(raw["status"], fallback: 1),
      createdAt: stringValue(raw["created_at"]),
      updatedAt: stringValue(raw["updated_at"])
    )
  }

  private func parseMessage(_ raw: [String: Any]) -> TempMailMessage? {
    let id = intValue(raw["id"])
    guard id > 0 else { return nil }
    return TempMailMessage(
      id: id,
      fromAddress: stringValue(raw["from_addr"]) ?? "",
      subject: stringValue(raw["subject"]) ?? "",
      preview: stringValue(raw["text_preview"]) ?? "",
      hasAttachments: boolValue(raw["has_attachments"]),
      isRead: intValue(raw["is_read"]) == 1,
      createdAt: stringValue(raw["created_at"])
    )
  }

  private func parseMessageDetail(_ raw: [String: Any]) -> TempMailMessageDetail? {
    let id = intValue(raw["id"])
    guard id > 0 else { return nil }
    let attachments = (raw["attachments"] as? [[String: Any]] ?? []).compactMap { item -> TempMailAttachment? in
      let index = intValue(item["index"], fallback: -1)
      guard index >= 0 else { return nil }
      return TempMailAttachment(
        index: index,
        filename: stringValue(item["filename"]) ?? "",
        contentType: stringValue(item["content_type"]) ?? "application/octet-stream",
        size: max(0, intValue(item["size"]))
      )
    }
    return TempMailMessageDetail(
      id: id,
      fromAddress: stringValue(raw["from_addr"]) ?? "",
      toAddress: stringValue(raw["to_addr"]) ?? "",
      subject: stringValue(raw["subject"]) ?? "",
      text: stringValue(raw["text"]) ?? "",
      html: stringValue(raw["html"]) ?? "",
      raw: stringValue(raw["raw"]) ?? "",
      attachments: attachments,
      isRead: intValue(raw["is_read"]) == 1,
      createdAt: stringValue(raw["created_at"])
    )
  }

  private func stringValue(_ value: Any?) -> String? {
    switch value {
    case let value as String: return value
    case let value as NSNumber: return value.stringValue
    default: return nil
    }
  }

  private func intValue(_ value: Any?, fallback: Int = 0) -> Int {
    switch value {
    case let value as Int: return value
    case let value as NSNumber: return value.intValue
    case let value as String: return Int(value) ?? fallback
    default: return fallback
    }
  }

  private func boolValue(_ value: Any?) -> Bool {
    switch value {
    case let value as Bool: return value
    case let value as NSNumber: return value.boolValue
    case let value as String: return value == "1" || value.lowercased() == "true"
    default: return false
    }
  }
}

private enum TempMailKeychain {
  private static var service: String {
    (Bundle.main.bundleIdentifier ?? "com.tianya.appbox") + ".temp-mail"
  }

  static func read(_ key: String) -> String? {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
      kSecReturnData as String: true,
      kSecMatchLimit as String: kSecMatchLimitOne,
    ]
    var result: CFTypeRef?
    guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
          let data = result as? Data else { return nil }
    return String(data: data, encoding: .utf8)
  }

  @discardableResult
  static func write(_ value: String, for key: String) -> Bool {
    let base: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    let data = Data(value.utf8)
    let update: [String: Any] = [
      kSecValueData as String: data,
      kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
    ]
    let status = SecItemUpdate(base as CFDictionary, update as CFDictionary)
    if status == errSecSuccess { return true }
    var insert = base
    insert.merge(update) { _, new in new }
    return SecItemAdd(insert as CFDictionary, nil) == errSecSuccess
  }

  static func delete(_ key: String) {
    let query: [String: Any] = [
      kSecClass as String: kSecClassGenericPassword,
      kSecAttrService as String: service,
      kSecAttrAccount as String: key,
    ]
    SecItemDelete(query as CFDictionary)
  }
}

private extension Data {
  init(hex: String) {
    self.init()
    var index = hex.startIndex
    while index < hex.endIndex {
      let next = hex.index(index, offsetBy: 2)
      if let byte = UInt8(hex[index..<next], radix: 16) { append(byte) }
      index = next
    }
  }

  var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}

private extension Digest {
  var hexString: String {
    map { String(format: "%02x", $0) }.joined()
  }
}
