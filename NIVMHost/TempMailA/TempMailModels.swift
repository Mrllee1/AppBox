import Foundation
import SwiftUI

enum TempMailTab: Hashable {
  case address
  case inbox
  case manage
}

enum TempMailAppearanceMode: String, CaseIterable, Identifiable {
  case system
  case light
  case dark

  var id: String { rawValue }

  var title: String {
    switch self {
    case .system: return "跟随系统"
    case .light: return "浅色"
    case .dark: return "深色"
    }
  }

  var systemImage: String {
    switch self {
    case .system: return "circle.lefthalf.filled"
    case .light: return "sun.max.fill"
    case .dark: return "moon.fill"
    }
  }

  var colorScheme: ColorScheme? {
    switch self {
    case .system: return nil
    case .light: return .light
    case .dark: return .dark
    }
  }

  var userInterfaceStyle: UIUserInterfaceStyle {
    switch self {
    case .system: return .unspecified
    case .light: return .light
    case .dark: return .dark
    }
  }
}

enum TempMailLoadPhase: Equatable {
  case loading
  case ready
  case failed(String)
}

struct TempMailbox: Identifiable, Hashable {
  let id: Int
  let address: String
  let localPart: String
  let domain: String
  let status: Int
  let createdAt: String?
  let updatedAt: String?
}

struct TempMailMessage: Identifiable, Hashable {
  let id: Int
  let fromAddress: String
  let subject: String
  let preview: String
  let hasAttachments: Bool
  let isRead: Bool
  let createdAt: String?

  var senderTitle: String {
    let value = fromAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !value.isEmpty else { return "未知发件人" }
    if let angle = value.firstIndex(of: "<") {
      let name = value[..<angle].trimmingCharacters(in: .whitespacesAndNewlines)
      if !name.isEmpty { return name.trimmingCharacters(in: CharacterSet(charactersIn: "\"'")) }
    }
    return value
  }

  var senderInitial: String {
    senderTitle.first.map { String($0).uppercased() } ?? "?"
  }

  var displaySubject: String {
    subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : subject
  }

  var displayPreview: String {
    let value = preview.trimmingCharacters(in: .whitespacesAndNewlines)
    return value
  }

  var relativeDateLabel: String {
    guard let createdAt, let date = TempMailDateParser.date(from: createdAt) else { return "" }
    let calendar = Calendar.current
    if calendar.isDateInToday(date) {
      return date.formatted(date: .omitted, time: .shortened)
    }
    if calendar.isDateInYesterday(date) { return "昨天" }
    return date.formatted(.dateTime.month(.twoDigits).day(.twoDigits))
  }
}

struct TempMailAttachment: Identifiable, Hashable {
  let index: Int
  let filename: String
  let contentType: String
  let size: Int

  var id: Int { index }

  var displayName: String {
    let value = filename.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? "附件 \(index + 1)" : value
  }

  var sizeLabel: String {
    ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
  }

  var systemImage: String {
    let value = contentType.lowercased()
    if value.hasPrefix("image/") { return "photo" }
    if value == "application/pdf" { return "doc.richtext" }
    if value.hasPrefix("audio/") { return "waveform" }
    if value.hasPrefix("video/") { return "play.rectangle" }
    if value.contains("zip") || value.contains("compressed") { return "archivebox" }
    return "doc"
  }
}

struct TempMailDownloadedAttachment {
  let filename: String
  let contentType: String
  let data: Data
}

struct TempMailMessageDetail: Identifiable, Hashable {
  let id: Int
  let fromAddress: String
  let toAddress: String
  let subject: String
  let text: String
  let html: String
  let raw: String
  let attachments: [TempMailAttachment]
  let isRead: Bool
  let createdAt: String?

  var senderTitle: String {
    TempMailMessage(
      id: id,
      fromAddress: fromAddress,
      subject: subject,
      preview: text,
      hasAttachments: !attachments.isEmpty,
      isRead: isRead,
      createdAt: createdAt
    ).senderTitle
  }

  var senderEmail: String {
    let value = fromAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    if let start = value.lastIndex(of: "<"), let end = value.lastIndex(of: ">"), start < end {
      return String(value[value.index(after: start)..<end]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
    return value
  }

  var senderInitial: String {
    senderTitle.first.map { String($0).uppercased() } ?? "?"
  }

  var displaySubject: String {
    subject.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "（无主题）" : subject
  }

  var dateLabel: String {
    guard let createdAt, let date = TempMailDateParser.date(from: createdAt) else { return "" }
    return date.formatted(date: .abbreviated, time: .shortened)
  }

  var fullDateLabel: String {
    guard let createdAt, let date = TempMailDateParser.date(from: createdAt) else { return "未知" }
    return date.formatted(.dateTime.year().month(.wide).day().hour().minute())
  }

  var copyableContent: String {
    let plain = text.trimmingCharacters(in: .whitespacesAndNewlines)
    if !plain.isEmpty { return plain }
    return html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
      .replacingOccurrences(of: "&nbsp;", with: " ")
      .replacingOccurrences(of: "\\s+", with: " ", options: .regularExpression)
      .trimmingCharacters(in: .whitespacesAndNewlines)
  }
}

enum TempMailDateParser {
  private static let fractional: ISO8601DateFormatter = {
    let formatter = ISO8601DateFormatter()
    formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
    return formatter
  }()

  private static let standard = ISO8601DateFormatter()

  static func date(from value: String) -> Date? {
    fractional.date(from: value) ?? standard.date(from: value)
  }
}

enum TempMailPalette {
  static let green = Color(red: 24 / 255, green: 202 / 255, blue: 136 / 255)
  static let darkGreen = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 57 / 255, green: 224 / 255, blue: 169 / 255, alpha: 1)
        : UIColor(red: 1 / 255, green: 156 / 255, blue: 121 / 255, alpha: 1)
    }
  )
  static let softGreen = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 23 / 255, green: 66 / 255, blue: 54 / 255, alpha: 1)
        : UIColor(red: 230 / 255, green: 1, blue: 246 / 255, alpha: 1)
    }
  )
  static let blue = Color(red: 108 / 255, green: 150 / 255, blue: 242 / 255)
  static let danger = Color(red: 1, green: 79 / 255, blue: 79 / 255)
  static let premium = Color(red: 1, green: 180 / 255, blue: 19 / 255)

  static let background = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 48 / 255, green: 50 / 255, blue: 52 / 255, alpha: 1)
        : UIColor(red: 234 / 255, green: 238 / 255, blue: 242 / 255, alpha: 1)
    }
  )

  static let surface = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 60 / 255, green: 62 / 255, blue: 64 / 255, alpha: 1)
        : .white
    }
  )

  static let secondaryText = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 166 / 255, green: 174 / 255, blue: 178 / 255, alpha: 1)
        : UIColor(red: 150 / 255, green: 151 / 255, blue: 159 / 255, alpha: 1)
    }
  )

  static let envelope = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 238 / 255, green: 243 / 255, blue: 241 / 255, alpha: 1)
        : .white
    }
  )

  static let envelopeShadowPlate = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 39 / 255, green: 41 / 255, blue: 43 / 255, alpha: 1)
        : UIColor(red: 218 / 255, green: 224 / 255, blue: 229 / 255, alpha: 1)
    }
  )

  static let envelopeFoldTop = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 71 / 255, green: 73 / 255, blue: 76 / 255, alpha: 1)
        : .white
    }
  )

  static let envelopeFoldBottom = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 34 / 255, green: 35 / 255, blue: 37 / 255, alpha: 1)
        : UIColor(red: 229 / 255, green: 229 / 255, blue: 229 / 255, alpha: 1)
    }
  )

  static let paperPrimary = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 69 / 255, green: 71 / 255, blue: 73 / 255, alpha: 1)
        : .white
    }
  )

  static let paperSecondary = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 81 / 255, green: 83 / 255, blue: 86 / 255, alpha: 1)
        : UIColor(red: 234 / 255, green: 238 / 255, blue: 242 / 255, alpha: 1)
    }
  )

  static let letterLine = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor(red: 162 / 255, green: 166 / 255, blue: 169 / 255, alpha: 1)
        : UIColor(red: 150 / 255, green: 151 / 255, blue: 159 / 255, alpha: 1)
    }
  )

  static let whisperBorder = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark
        ? UIColor.white.withAlphaComponent(0.10)
        : UIColor.black.withAlphaComponent(0.08)
    }
  )

  static let shadowColor = Color(
    uiColor: UIColor { traits in
      traits.userInterfaceStyle == .dark ? UIColor.black : UIColor(red: 33 / 255, green: 47 / 255, blue: 55 / 255, alpha: 1)
    }
  )
}

extension View {
  func tempMailCard(radius: CGFloat = 17) -> some View {
    background(TempMailPalette.surface, in: RoundedRectangle(cornerRadius: radius, style: .continuous))
  }
}
