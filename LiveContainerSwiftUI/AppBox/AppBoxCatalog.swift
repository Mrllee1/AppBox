import Foundation

enum AppBoxCatalog {
    static let fallbackItems: [AppBoxCatalogItem] = [
        ipa(
            "tianya_selected",
            "app.nqyqstm6mu.tianya",
            "天涯精选",
            "Tianya Select",
            .tools,
            .community,
            .apps,
            .blue,
            "https://pub-d768a0879cb24ceaa4a0cfe8b73ee372.r2.dev/ty1.ipa"
        ),
        ipa("focus", "com.appbox.focus", "专注清单", "Focus List", .tools, .productivity, .checkSquare, .blue),
        ipa("scan", "com.appbox.scan", "轻扫文档", "Quick Scan", .tools, .productivity, .scanner, .indigo),
        ipa("vault", "com.appbox.vault", "隐私文件", "Private Files", .tools, .productivity, .shield, .graphite),
        ipa("notes", "com.appbox.notes", "灵感便签", "Idea Notes", .tools, .productivity, .edit, .coral),
        ipa("cloud", "com.appbox.cloud", "云端空间", "Cloud Space", .tools, .productivity, .cloud, .mint),
        web("web-whiteboard", "在线白板", "Excalidraw", .tools, .productivity, .edit, .indigo, "https://excalidraw.com"),
        web("web-wikipedia", "维基百科", "Wikipedia", .tools, .productivity, .news, .teal, "https://www.wikipedia.org"),
        ipa("music", "com.appbox.music", "轻听音乐", "Easy Music", .tools, .media, .music, .rose),
        ipa("player", "com.appbox.player", "万能播放", "Media Player", .tools, .media, .playCircle, .teal),
        ipa("podcast", "com.appbox.podcast", "播客电台", "Podcasts", .tools, .media, .playlist, .gold),
        ipa("chat", "com.appbox.chat", "即时消息", "Messages", .entertainment, .community, .commentDots, .mint),
        ipa("moments", "com.appbox.moments", "好友动态", "Moments", .entertainment, .community, .profileCircle, .blue),
        ipa("video", "com.appbox.video", "短视频", "Short Video", .entertainment, .media, .cameraVideo, .coral),
        ipa("cinema", "com.appbox.cinema", "掌上影院", "Pocket Cinema", .entertainment, .media, .play, .graphite),
        web("web-2048", "数字方块", "2048", .entertainment, .games, .category, .gold, "https://play2048.co"),
        ipa("puzzle", "com.appbox.puzzle", "益智方块", "Puzzle Blocks", .entertainment, .games, .category, .indigo),
        ipa("arcade", "com.appbox.arcade", "街机合集", "Arcade", .entertainment, .games, .apps, .gold),
        ipa("weather", "com.appbox.weather", "实时天气", "Weather", .lifestyle, .lifestyle, .cloud, .blue),
        ipa("travel", "com.appbox.travel", "轻松出行", "Travel", .lifestyle, .lifestyle, .locationPin, .coral),
        ipa("fitness", "com.appbox.fitness", "健康运动", "Fitness", .lifestyle, .lifestyle, .lightning, .mint),
        ipa("reader", "com.appbox.reader", "每日阅读", "Daily Reader", .lifestyle, .productivity, .news, .teal)
    ]

    static var items: [AppBoxCatalogItem] { fallbackItems }

    static var fallbackGroups: [AppBoxCatalogGroup] {
        groups(from: fallbackItems)
    }

    static func groups(series: AppBoxSeries, query: String, language: AppBoxLanguage) -> [AppBoxCatalogGroup] {
        filter(groups: fallbackGroups, series: series, query: query)
    }

    static func groups(from items: [AppBoxCatalogItem]) -> [AppBoxCatalogGroup] {
        AppBoxSeries.allCases.flatMap { series in
            AppBoxSection.allCases.compactMap { section in
                let sectionItems = items.filter { $0.series == series && $0.section == section }
                guard !sectionItems.isEmpty else { return nil }
                let names = groupNames(for: section)
                return AppBoxCatalogGroup(
                    id: "\(series.rawValue).\(section.rawValue)",
                    series: series,
                    section: section,
                    chineseName: names.chinese,
                    englishName: names.english,
                    items: sectionItems
                )
            }
        }
    }

    static func filter(
        groups: [AppBoxCatalogGroup],
        series: AppBoxSeries,
        query: String
    ) -> [AppBoxCatalogGroup] {
        let normalizedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        return groups.compactMap { group in
            guard !normalizedQuery.isEmpty || group.series == series else { return nil }
            let filteredItems = group.items.filter { item in
                let matchesSeries = normalizedQuery.isEmpty ? item.series == series : true
                let matchesQuery = normalizedQuery.isEmpty ||
                    item.chineseName.localizedCaseInsensitiveContains(normalizedQuery) ||
                    item.englishName.localizedCaseInsensitiveContains(normalizedQuery) ||
                    (item.bundleIdentifier?.localizedCaseInsensitiveContains(normalizedQuery) ?? false) ||
                    (item.source.webEntryURL?.host?.localizedCaseInsensitiveContains(normalizedQuery) ?? false)
                return matchesSeries && matchesQuery
            }

            return filteredItems.isEmpty ? nil : group.replacingItems(filteredItems)
        }
    }

    static func item(id: String) -> AppBoxCatalogItem? {
        fallbackItems.first { $0.id == id }
    }

    private static func groupNames(for section: AppBoxSection) -> (chinese: String, english: String) {
        switch section {
        case .productivity: return ("效率工具", "Productivity")
        case .media: return ("影音娱乐", "Media")
        case .community: return ("社交通讯", "Community")
        case .games: return ("休闲游戏", "Games")
        case .lifestyle: return ("生活服务", "Lifestyle")
        }
    }

    private static func ipa(
        _ id: String,
        _ bundleIdentifier: String,
        _ chineseName: String,
        _ englishName: String,
        _ series: AppBoxSeries,
        _ section: AppBoxSection,
        _ icon: AppBoxIcon,
        _ iconStyle: AppBoxIconStyle,
        _ downloadURL: String? = nil
    ) -> AppBoxCatalogItem {
        let resolvedDownloadURL: URL?
        if let downloadURL {
            guard let url = URL(string: downloadURL), url.scheme == "https" else {
                preconditionFailure("Invalid AppBox IPA URL: \(downloadURL)")
            }
            resolvedDownloadURL = url
        } else {
            resolvedDownloadURL = nil
        }

        return AppBoxCatalogItem(
            id: id,
            bundleIdentifier: bundleIdentifier,
            chineseName: chineseName,
            englishName: englishName,
            series: series,
            section: section,
            icon: icon,
            iconStyle: iconStyle,
            source: .ipa(downloadURL: resolvedDownloadURL)
        )
    }

    private static func web(
        _ id: String,
        _ chineseName: String,
        _ englishName: String,
        _ series: AppBoxSeries,
        _ section: AppBoxSection,
        _ icon: AppBoxIcon,
        _ iconStyle: AppBoxIconStyle,
        _ entryURL: String
    ) -> AppBoxCatalogItem {
        guard let url = URL(string: entryURL), url.scheme == "https" else {
            preconditionFailure("Invalid AppBox H5 URL: \(entryURL)")
        }
        return AppBoxCatalogItem(
            id: id,
            bundleIdentifier: nil,
            chineseName: chineseName,
            englishName: englishName,
            series: series,
            section: section,
            icon: icon,
            iconStyle: iconStyle,
            source: .web(entryURL: url)
        )
    }
}
