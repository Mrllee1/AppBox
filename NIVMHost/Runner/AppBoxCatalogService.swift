import CryptoKit
import Foundation

struct AppBoxRuntimeCatalogSection: Codable, Hashable {
  let id: String
  let title: String
  let apps: [PlayBoxGuestDescriptor]
}

final class AppBoxCatalogService {
  private let session: URLSession
  private let decoder = JSONDecoder()

  init(session: URLSession = .shared) {
    self.session = session
  }

  func fetch() async throws -> [AppBoxRuntimeCatalogSection] {
    guard let baseURL = configuredBaseURL() else { throw CatalogError.invalidURL }
    do {
      let data = try await fetchCatalogData(baseURL: baseURL)
      let envelope = try decoder.decode(EncryptedEnvelope.self, from: data)
      let decrypted = try decrypt(envelope)
      let catalog = try decoder.decode(RemoteCatalog.self, from: decrypted)
      let sections = map(catalog)
      guard !sections.isEmpty else { throw CatalogError.empty }
      return sections
    } catch {
      let details = error as NSError
      print(
        "APPBOX_CATALOG request_failed base=\(baseURL.absoluteString) " +
        "domain=\(details.domain) code=\(details.code) error=\(details.localizedDescription)"
      )
      throw error
    }
  }

  private func configuredBaseURL() -> URL? {
    guard let configured = Bundle.main.object(forInfoDictionaryKey: "AppBoxCatalogBaseURL") as? String else {
      return nil
    }
    let value = configured.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return nil }
    return URL(string: value)
  }

  private func fetchCatalogData(baseURL: URL) async throws -> Data {
    var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)
    components?.path = "/api/v1/appbox/catalog"
    components?.queryItems = [URLQueryItem(name: "t", value: String(Int(Date().timeIntervalSince1970)))]
    guard let url = components?.url else { throw CatalogError.invalidURL }
    var request = URLRequest(url: url)
    request.timeoutInterval = 8
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("AppBox-NIVM/1.0", forHTTPHeaderField: "User-Agent")
    let (data, response) = try await session.data(for: request)
    guard let response = response as? HTTPURLResponse,
          (200...299).contains(response.statusCode) else {
      throw CatalogError.invalidResponse
    }
    return data
  }

  private func decrypt(_ envelope: EncryptedEnvelope) throws -> Data {
    guard envelope.v == 1,
          let key = ClientCrypto.key() else {
      throw CatalogError.invalidEnvelope
    }
    let nonce = try AES.GCM.Nonce(data: Data(base64URL: envelope.n))
    let sealedBox = try AES.GCM.SealedBox(
      nonce: nonce,
      ciphertext: Data(base64URL: envelope.d),
      tag: Data(base64URL: envelope.t)
    )
    return try AES.GCM.open(sealedBox, using: SymmetricKey(data: key))
  }

  private func map(_ catalog: RemoteCatalog) -> [AppBoxRuntimeCatalogSection] {
    catalog.c.flatMap { category in
      category.g.compactMap { group in
        let apps = group.a.compactMap { app -> PlayBoxGuestDescriptor? in
          guard app.t.lowercased() == "ipa",
                let bundleIdentifier = app.b,
                let version = app.ver,
                let build = app.build,
                let packageValue = app.url,
                let packageURL = URL(string: packageValue),
                let nivmValue = app.nu,
                let nivmURL = URL(string: nivmValue),
                let packageSHA256 = app.h,
                let nivmSHA256 = app.nh,
                Self.isSHA256(packageSHA256),
                Self.isSHA256(nivmSHA256),
                let iconURL = URL(string: app.icon) else {
            return nil
          }
          return PlayBoxGuestDescriptor(
            id: app.id,
            storageIdentifier: Self.storageIdentifier(app.id),
            displayName: app.n,
            expectedBundleIdentifier: bundleIdentifier,
            expectedVersion: version,
            expectedBuild: build,
            categoryID: category.id,
            categoryName: category.n,
            groupID: group.id,
            groupName: group.n,
            iconURL: iconURL,
            packageURL: packageURL,
            expectedIPASHA256: packageSHA256,
            nivmURL: nivmURL,
            expectedNIVMSHA256: nivmSHA256
          )
        }
        guard !apps.isEmpty else { return nil }
        return AppBoxRuntimeCatalogSection(
          id: "\(category.id).\(group.id)",
          title: group.n,
          apps: apps
        )
      }
    }
  }

  private static func isSHA256(_ value: String) -> Bool {
    value.count == 64 && value.allSatisfy { $0.isHexDigit }
  }

  private static func storageIdentifier(_ id: String) -> String {
    let value = id.unicodeScalars.map { scalar in
      CharacterSet.alphanumerics.contains(scalar) ? String(scalar) : "_"
    }.joined()
    return String(value.prefix(80))
  }
}

private enum ClientCrypto {
  private static let fallbackKeyBase64 = "6btlrID18OytwUZ0s41atap+4WxlXr1xpebjrE04hnY="

  static func key() -> Data? {
    let configured = Bundle.main.object(forInfoDictionaryKey: "AppBoxClientAESKey") as? String
    let value = configured.flatMap { $0.isEmpty ? nil : $0 } ?? fallbackKeyBase64
    guard let key = Data(base64Encoded: value), key.count == 32 else {
      return Data(base64Encoded: fallbackKeyBase64)
    }
    return key
  }
}

private struct EncryptedEnvelope: Decodable {
  let v: Int
  let n: String
  let t: String
  let d: String
}

private struct RemoteCatalog: Decodable {
  let c: [RemoteCategory]
}

private struct RemoteCategory: Decodable {
  let id: String
  let n: String
  let g: [RemoteGroup]
}

private struct RemoteGroup: Decodable {
  let id: String
  let n: String
  let a: [RemoteApp]
}

private struct RemoteApp: Decodable {
  let id: String
  let n: String
  let t: String
  let icon: String
  let url: String?
  let b: String?
  let h: String?
  let nu: String?
  let nh: String?
  let ver: String?
  let build: String?
}

private enum CatalogError: LocalizedError {
  case invalidURL
  case invalidResponse
  case invalidEnvelope
  case empty

  var errorDescription: String? {
    switch self {
    case .invalidURL: return "目录地址无效"
    case .invalidResponse: return "目录服务器响应无效"
    case .invalidEnvelope: return "目录签名信封无效"
    case .empty: return "目录中没有可运行的 NIVM 应用"
    }
  }
}

private extension Data {
  init(base64URL value: String) throws {
    var value = value
      .replacingOccurrences(of: "-", with: "+")
      .replacingOccurrences(of: "_", with: "/")
    let remainder = value.count % 4
    if remainder != 0 {
      value += String(repeating: "=", count: 4 - remainder)
    }
    guard let data = Data(base64Encoded: value) else {
      throw CatalogError.invalidEnvelope
    }
    self = data
  }
}
