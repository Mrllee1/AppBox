import Foundation

enum AppBoxLanguage: String, CaseIterable, Identifiable {
    case simplifiedChinese
    case english

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .simplifiedChinese: return "简体中文"
        case .english: return "English"
        }
    }
}

enum AppBoxBrand {
    static let chineseName = "天涯盒子"
    static let englishName = "Tianya Box"

    static func name(for language: AppBoxLanguage) -> String {
        language == .simplifiedChinese ? chineseName : englishName
    }
}

enum AppBoxAppearance: String, CaseIterable, Identifiable {
    case system
    case light
    case dark

    var id: String { rawValue }
}

enum AppBoxSkin: String, CaseIterable, Identifiable {
    case sky
    case mint
    case coral

    var id: String { rawValue }
}

enum AppBoxSeries: String, CaseIterable, Identifiable {
    case tools
    case entertainment
    case lifestyle

    var id: String { rawValue }
}

enum AppBoxSection: String, CaseIterable, Identifiable {
    case productivity
    case media
    case community
    case games
    case lifestyle

    var id: String { rawValue }
}

enum AppBoxIconStyle: String {
    case blue
    case indigo
    case mint
    case coral
    case gold
    case graphite
    case teal
    case rose
}

enum AppBoxIcon: String {
    case options = "slider.horizontal.3"
    case modeDark = "moon"
    case modeLight = "sun.max"
    case lock = "lock"
    case share = "square.and.arrow.up"
    case search = "magnifyingglass"
    case close = "xmark"
    case closeCircle = "xmark.circle.fill"
    case check = "checkmark"
    case checkCircle = "checkmark.circle.fill"
    case stop = "stop.fill"
    case warning = "exclamationmark"
    case arrowRight = "chevron.right"
    case apps = "square.grid.2x2"
    case edit = "square.and.pencil"
    case fileAdd = "doc.badge.plus"
    case shield = "lock.shield"
    case shieldYes = "checkmark.shield.fill"
    case faceID = "faceid"
    case touchID = "touchid"
    case opticID = "opticid"
    case eye = "eye"
    case eyeOff = "eye.slash"
    case cameraImage = "photo"
    case link = "link"
    case trash = "trash"
    case checkSquare = "checklist"
    case scanner = "doc.viewfinder"
    case cloud = "icloud"
    case music = "music.note"
    case playCircle = "play.circle"
    case playlist = "music.note.list"
    case commentDots = "ellipsis.message"
    case profileCircle = "person.crop.circle"
    case cameraVideo = "video"
    case play = "play.fill"
    case category = "square.grid.3x3"
    case locationPin = "shippingbox.fill"
    case lightning = "bolt.fill"
    case news = "newspaper"
}

enum AppBoxAppSource: Hashable {
    case ipa(downloadURL: URL?)
    case web(entryURL: URL)

    var ipaDownloadURL: URL? {
        guard case .ipa(let downloadURL) = self else { return nil }
        return downloadURL
    }

    var webEntryURL: URL? {
        guard case .web(let entryURL) = self else { return nil }
        return entryURL
    }

    var isWeb: Bool {
        webEntryURL != nil
    }
}

enum AppBoxInstallState: Equatable {
    case downloading(progress: Double)
    case processing
    case completed
    case failed(message: String)

    var isActive: Bool {
        switch self {
        case .downloading, .processing:
            return true
        case .completed, .failed:
            return false
        }
    }

    var isCancellable: Bool {
        if case .downloading = self { return true }
        return false
    }
}

struct AppBoxCatalogItem: Identifiable, Hashable {
    let id: String
    let bundleIdentifier: String?
    let chineseName: String
    let englishName: String
    let series: AppBoxSeries
    let section: AppBoxSection
    let icon: AppBoxIcon
    let iconStyle: AppBoxIconStyle
    let source: AppBoxAppSource

    func name(for language: AppBoxLanguage) -> String {
        language == .simplifiedChinese ? chineseName : englishName
    }
}

struct AppBoxCatalogGroup: Identifiable {
    let section: AppBoxSection
    let items: [AppBoxCatalogItem]

    var id: AppBoxSection { section }
}

struct AppBoxInstallRequest: Identifiable, Equatable {
    let id: String
    let sourceURL: URL?

    static func external(url: URL?) -> AppBoxInstallRequest {
        AppBoxInstallRequest(id: "external.\(url?.absoluteString ?? "picker")", sourceURL: url)
    }
}

enum AppBoxLaunchPhase: Equatable {
    case preparing
    case verifying
    case launching
    case ready

    var progress: Double {
        switch self {
        case .preparing: return 0.14
        case .verifying: return 0.48
        case .launching: return 0.82
        case .ready: return 1
        }
    }
}

struct AppBoxLaunchState: Identifiable, Equatable {
    let item: AppBoxCatalogItem
    var phase: AppBoxLaunchPhase

    var id: String { item.id }
}

enum AppBoxNotice: Equatable {
    case installed(String)
    case installFailed(String)
    case launched(String)
    case missingDownloadURL
    case notInstalled
    case launchFailed(String)
    case pinSaved
    case pinMismatch
    case pinRemoved
}

struct AppBoxCopy {
    let language: AppBoxLanguage

    func text(_ chinese: String, _ english: String) -> String {
        language == .simplifiedChinese ? chinese : english
    }

    func series(_ value: AppBoxSeries) -> String {
        switch value {
        case .tools: return text("工具系列", "Tools")
        case .entertainment: return text("娱乐系列", "Entertainment")
        case .lifestyle: return text("生活系列", "Lifestyle")
        }
    }

    func section(_ value: AppBoxSection) -> String {
        switch value {
        case .productivity: return text("效率工具", "Productivity")
        case .media: return text("影音娱乐", "Media")
        case .community: return text("社交通讯", "Community")
        case .games: return text("休闲游戏", "Games")
        case .lifestyle: return text("生活服务", "Lifestyle")
        }
    }

    func appearance(_ value: AppBoxAppearance) -> String {
        switch value {
        case .system: return text("跟随系统", "System")
        case .light: return text("浅色", "Light")
        case .dark: return text("深色", "Dark")
        }
    }

    func skin(_ value: AppBoxSkin) -> String {
        switch value {
        case .sky: return text("晴空", "Sky")
        case .mint: return text("薄荷", "Mint")
        case .coral: return text("珊瑚", "Coral")
        }
    }
}
