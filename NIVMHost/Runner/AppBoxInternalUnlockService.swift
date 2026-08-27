#if APPBOX_INTERNAL_UNLOCK
import Foundation

struct AppBoxInternalUnlockService {
  private struct RedeemRequest: Encodable {
    let code: String
    let installId: String
    let appVersion: String
    let appBuild: String
  }

  private struct RedeemResponse: Decodable {
    let success: Bool
    let unlock: Bool
  }

  private enum UnlockError: LocalizedError {
    case invalidCode
    case rateLimited
    case unavailable

    var errorDescription: String? {
      switch self {
      case .invalidCode:
        return "验证码错误或已失效。"
      case .rateLimited:
        return "尝试次数过多，请十分钟后再试。"
      case .unavailable:
        return "暂时无法验证，请检查网络后重试。"
      }
    }
  }

  private let session: URLSession

  init(session: URLSession = .shared) {
    self.session = session
  }

  func redeem(code: String) async throws {
    guard let baseURL = baseURL(),
          let url = URL(string: "/api/v1/appbox/internal-unlock/redeem", relativeTo: baseURL)?.absoluteURL else {
      throw UnlockError.unavailable
    }

    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
    let payload = RedeemRequest(
      code: code,
      installId: installIdentifier(),
      appVersion: version,
      appBuild: build
    )
    var request = URLRequest(url: url)
    request.httpMethod = "POST"
    request.timeoutInterval = 10
    request.cachePolicy = .reloadIgnoringLocalCacheData
    request.setValue("application/json", forHTTPHeaderField: "Content-Type")
    request.setValue("Quietform-Internal/\(version)", forHTTPHeaderField: "User-Agent")
    request.httpBody = try JSONEncoder().encode(payload)

    do {
      let (data, response) = try await session.data(for: request)
      guard let httpResponse = response as? HTTPURLResponse else {
        throw UnlockError.unavailable
      }
      switch httpResponse.statusCode {
      case 200...299:
        let result = try JSONDecoder().decode(RedeemResponse.self, from: data)
        guard result.success, result.unlock else { throw UnlockError.invalidCode }
      case 400, 401:
        throw UnlockError.invalidCode
      case 429:
        throw UnlockError.rateLimited
      default:
        throw UnlockError.unavailable
      }
    } catch let error as UnlockError {
      throw error
    } catch {
      throw UnlockError.unavailable
    }
  }

  private func baseURL() -> URL? {
    let configured = (Bundle.main.object(forInfoDictionaryKey: "AppBoxVerificationBaseURL") as? String)?
      .trimmingCharacters(in: .whitespacesAndNewlines)
    if let configured, !configured.isEmpty, let url = URL(string: configured) {
      return url
    }
    return nil
  }

  private func installIdentifier() -> String {
    let key = "appbox.internalUnlockInstallIdentifier"
    if let existing = UserDefaults.standard.string(forKey: key), UUID(uuidString: existing) != nil {
      return existing
    }
    let identifier = UUID().uuidString.lowercased()
    UserDefaults.standard.set(identifier, forKey: key)
    return identifier
  }
}
#endif
