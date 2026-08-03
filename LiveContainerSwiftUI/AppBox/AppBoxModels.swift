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
    case options = "IconaMoonOptions"
    case modeDark = "IconaMoonModeDark"
    case modeLight = "IconaMoonModeLight"
    case lock = "IconaMoonLock"
    case share = "IconaMoonShare"
    case search = "IconaMoonSearch"
    case close = "IconaMoonClose"
    case closeCircle = "IconaMoonCloseCircle"
    case check = "IconaMoonCheck"
    case checkCircle = "IconaMoonCheckCircle"
    case arrowRight = "IconaMoonArrowRight"
    case apps = "IconaMoonApps"
    case edit = "IconaMoonEdit"
    case fileAdd = "IconaMoonFileAdd"
    case shield = "IconaMoonShield"
    case shieldYes = "IconaMoonShieldYes"
    case eye = "IconaMoonEye"
    case eyeOff = "IconaMoonEyeOff"
    case cameraImage = "IconaMoonCameraImage"
    case link = "IconaMoonLink"
    case trash = "IconaMoonTrash"
    case checkSquare = "IconaMoonCheckSquare"
    case scanner = "IconaMoonScanner"
    case cloud = "IconaMoonCloud"
    case music = "IconaMoonMusic"
    case playCircle = "IconaMoonPlayCircle"
    case playlist = "IconaMoonPlaylist"
    case commentDots = "IconaMoonCommentDots"
    case profileCircle = "IconaMoonProfileCircle"
    case cameraVideo = "IconaMoonCameraVideo"
    case play = "IconaMoonPlay"
    case category = "IconaMoonCategory"
    case locationPin = "IconaMoonLocationPin"
    case lightning = "IconaMoonLightning"
    case news = "IconaMoonNews"
}

struct AppBoxCatalogItem: Identifiable, Hashable {
    let id: String
    let bundleIdentifier: String
    let chineseName: String
    let englishName: String
    let series: AppBoxSeries
    let section: AppBoxSection
    let icon: AppBoxIcon
    let iconStyle: AppBoxIconStyle
    let downloadURL: URL?

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
    let itemID: String?
    let sourceURL: URL?

    static func catalog(item: AppBoxCatalogItem) -> AppBoxInstallRequest {
        AppBoxInstallRequest(id: "catalog.\(item.id)", itemID: item.id, sourceURL: item.downloadURL)
    }

    static func external(url: URL?) -> AppBoxInstallRequest {
        AppBoxInstallRequest(id: "external.\(url?.absoluteString ?? "picker")", itemID: nil, sourceURL: url)
    }
}

enum AppBoxNotice: Equatable {
    case installed(String)
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
