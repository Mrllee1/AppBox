import SwiftUI

struct AppBoxRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var store = AppBoxStore()
    @AppStorage("appbox.language") private var language: AppBoxLanguage = .simplifiedChinese
    @AppStorage("appbox.appearance") private var appearance: AppBoxAppearance = .system
    @AppStorage("appbox.skin") private var skin: AppBoxSkin = .sky

    @State private var selectedSeries: AppBoxSeries = .tools
    @State private var query = ""
    @State private var showSettings = false
    @State private var showShare = false
    @State private var showPassword = false

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    private var installedItems: [AppBoxCatalogItem] { store.installedItems(hostApps: sharedModel.apps) }

    var body: some View {
        ZStack(alignment: .top) {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                    .padding(.horizontal, AppBoxLayout.pagePadding)
                    .padding(.top, 6)
                AppBoxSearchBar(
                    text: $query,
                    placeholder: copy.text("搜索应用", "Search apps"),
                    palette: palette
                )
                .padding(.horizontal, AppBoxLayout.pagePadding)
                .padding(.top, 8)
                .padding(.bottom, 20)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppBoxLayout.sectionSpacing) {
                        if !installedItems.isEmpty {
                            installedSection
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        seriesTabs

                        let groups = AppBoxCatalog.groups(series: selectedSeries, query: query, language: language)
                        if groups.isEmpty {
                            VStack(spacing: 10) {
                                AppBoxGlyph(icon: .search)
                                    .frame(width: 28, height: 28)
                                Text(copy.text("没有找到应用", "No apps found"))
                                    .font(.system(size: 15, weight: .medium))
                            }
                            .foregroundColor(palette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 52)
                        } else {
                            ForEach(groups) { group in
                                catalogSection(group)
                            }
                        }
                    }
                    .padding(.horizontal, AppBoxLayout.pagePadding)
                    .padding(.bottom, 32)
                }
                .animation(.easeInOut(duration: 0.22), value: installedItems.map(\.id))
            }

            if let notice = store.notice {
                AppBoxNoticeView(text: noticeText(notice), palette: palette)
                    .padding(.top, 58)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            if showShare {
                AppBoxShareView(language: language, skin: skin) {
                    withAnimation(.easeOut(duration: 0.18)) { showShare = false }
                }
                .zIndex(100)
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
        .fullScreenCover(isPresented: $showSettings) {
            AppBoxSettingsView(language: $language, appearance: $appearance, skin: $skin)
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showPassword) {
            AppBoxPasswordView(language: language, skin: skin, mode: .unlock)
        }
        .sheet(item: $store.pendingInstallRequest, onDismiss: {
            store.finishInstallRequest()
        }) { request in
            AppBoxContainerInstallerView(sourceURL: request.sourceURL)
        }
        .onOpenURL { url in
            guard let sourceURL = installSource(from: url) else { return }
            store.requestExternalInstall(url: sourceURL)
        }
        .onChange(of: store.notice) { notice in
            guard let notice else { return }
            Task {
                try? await Task.sleep(nanoseconds: 1_700_000_000)
                if store.notice == notice {
                    withAnimation { store.notice = nil }
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            AppBoxIconButton(
                icon: .options,
                accessibilityLabel: copy.text("设置", "Settings"),
                palette: palette
            ) { showSettings = true }
            Text(copy.text("应用中心", "App Center"))
                .font(.system(size: 21, weight: .semibold))
                .foregroundColor(palette.primaryText)
            Spacer(minLength: 8)
            HStack(spacing: 0) {
                AppBoxIconButton(
                    icon: appearance == .dark ? .modeLight : .modeDark,
                    accessibilityLabel: copy.text("切换外观", "Toggle appearance"),
                    palette: palette
                ) {
                    appearance = appearance == .dark ? .light : .dark
                }
                AppBoxIconButton(
                    icon: .lock,
                    accessibilityLabel: copy.text("隐私密码", "Privacy PIN"),
                    palette: palette
                ) { showPassword = true }
                AppBoxIconButton(
                    icon: .share,
                    accessibilityLabel: copy.text("分享", "Share"),
                    palette: palette
                ) {
                    withAnimation(.easeOut(duration: 0.18)) { showShare = true }
                }
            }
            .padding(.horizontal, 2)
            .appBoxGlassControl(palette, radius: 20, isInteractive: false)
        }
        .frame(height: 44)
    }

    private var seriesTabs: some View {
        HStack(spacing: 4) {
            ForEach(AppBoxSeries.allCases) { series in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) { selectedSeries = series }
                } label: {
                    Text(copy.series(series))
                        .font(.system(size: 14, weight: selectedSeries == series ? .semibold : .medium))
                        .foregroundColor(selectedSeries == series ? palette.accent : palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                        .frame(maxWidth: .infinity)
                        .frame(height: 36)
                        .background(selectedSeries == series ? palette.accentSoft : Color.clear)
                        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedSeries == series ? .isSelected : [])
            }
        }
        .padding(4)
        .appBoxGlassControl(palette, radius: 12, isInteractive: false)
    }

    private var installedSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            AppBoxSectionHeading(
                title: copy.text("已安装", "Installed"),
                palette: palette
            )

            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 14) {
                    ForEach(installedItems) { item in
                        AppBoxInstalledTile(
                            item: item,
                            copy: copy,
                            palette: palette,
                            open: { Task { await store.launch(item, hostApps: sharedModel.apps) } },
                            remove: { store.removeSimulatedInstall(item) }
                        )
                    }
                }
            }

            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, 2)
    }

    private func catalogSection(_ group: AppBoxCatalogGroup) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            AppBoxSectionHeading(
                title: copy.section(group.section),
                palette: palette
            )
            LazyVGrid(columns: gridColumns, spacing: 18) {
                ForEach(group.items) { item in
                    AppBoxAppCell(
                        item: item,
                        copy: copy,
                        palette: palette,
                        isInstalled: store.isInstalled(item, hostApps: sharedModel.apps),
                        isInstalling: store.installingIDs.contains(item.id)
                    ) {
                        Task {
                            if store.isInstalled(item, hostApps: sharedModel.apps) {
                                await store.launch(item, hostApps: sharedModel.apps)
                            } else {
                                await store.install(item, hostApps: sharedModel.apps)
                            }
                        }
                    }
                }
            }
            Rectangle()
                .fill(palette.divider)
                .frame(height: 1)
        }
        .padding(.horizontal, 2)
    }

    private var gridColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 44), spacing: 9), count: 5)
    }

    private func noticeText(_ notice: AppBoxNotice) -> String {
        switch notice {
        case .installed(let id):
            let name = AppBoxCatalog.item(id: id)?.name(for: language) ?? ""
            return copy.text("\(name) 已安装", "\(name) installed")
        case .launched(let id):
            let name = AppBoxCatalog.item(id: id)?.name(for: language) ?? ""
            return copy.text("正在启动 \(name)", "Opening \(name)")
        case .missingDownloadURL:
            return copy.text("当前应用尚未配置下载地址", "No download URL configured")
        case .notInstalled:
            return copy.text("应用尚未安装", "App is not installed")
        case .launchFailed(let message):
            return message
        case .pinSaved:
            return copy.text("密码已保存", "PIN saved")
        case .pinMismatch:
            return copy.text("两次密码不一致", "PINs do not match")
        case .pinRemoved:
            return copy.text("密码已移除", "PIN removed")
        }
    }

    private func installSource(from url: URL) -> URL? {
        if url.isFileURL { return url }
        guard url.host?.lowercased() == "install",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let value = components.queryItems?.first(where: { $0.name == "url" })?.value else {
            return nil
        }
        return URL(string: value)
    }
}

struct AppBoxContainerInstallerView: View {
    let sourceURL: URL?

    @EnvironmentObject private var sharedModel: SharedModel
    @StateObject private var searchContext = SearchContext()
    @State private var didDispatch = false

    var body: some View {
        LCAppListView(searchContext: searchContext)
            .onAppear {
                guard !didDispatch, let sourceURL else { return }
                didDispatch = true
                sharedModel.selectedTab = .apps
                DispatchQueue.main.async {
                    if sourceURL.isFileURL {
                        sharedModel.deepLink = sourceURL
                    } else {
                        var components = URLComponents()
                        components.scheme = "appbox"
                        components.host = "install"
                        components.queryItems = [URLQueryItem(name: "url", value: sourceURL.absoluteString)]
                        sharedModel.deepLink = components.url
                    }
                }
            }
    }
}
