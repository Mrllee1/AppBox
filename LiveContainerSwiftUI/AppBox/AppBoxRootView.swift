import SwiftUI

struct AppBoxRootView: View {
    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var store = AppBoxStore()
    @StateObject private var lockController = AppBoxLockController()
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
        Group {
            if lockController.isLocked {
                AppBoxLockScreen(
                    language: language,
                    skin: skin,
                    onUnlock: { lockController.requestUnlock(while: scenePhase) }
                )
                .transition(.opacity)
            } else {
                unlockedContent
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: lockController.isLocked)
        .preferredColorScheme(appearance.preferredColorScheme)
        .fullScreenCover(isPresented: $showSettings, onDismiss: {
            lockController.synchronizeProtectionState()
        }) {
            AppBoxSettingsView(language: $language, appearance: $appearance, skin: $skin)
                .environmentObject(store)
        }
        .fullScreenCover(isPresented: $showPassword, onDismiss: {
            lockController.synchronizeProtectionState()
        }) {
            AppBoxPasswordView(language: language, skin: skin, mode: .manage)
        }
        .fullScreenCover(item: $store.activeWebApp) { item in
            AppBoxWebAppView(item: item, language: language, skin: skin)
        }
        .sheet(item: $store.pendingInstallRequest, onDismiss: {
            store.finishInstallRequest()
        }) { request in
            AppBoxContainerInstallerView(sourceURL: request.sourceURL)
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                dismissSensitiveContent()
            }
            lockController.handleScenePhase(phase)
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

    private var unlockedContent: some View {
        ZStack(alignment: .top) {
            palette.background.ignoresSafeArea()

            NavigationView {
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
                                    .font(.body.weight(.medium))
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
                    .padding(.top, 16)
                    .padding(.bottom, 32)
                }
                .background(palette.background)
                .navigationTitle(AppBoxBrand.name(for: language))
                .navigationBarTitleDisplayMode(.inline)
                .searchable(
                    text: $query,
                    placement: .navigationBarDrawer(displayMode: .always),
                    prompt: copy.text("搜索应用", "Search apps")
                )
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        toolbarButton(
                            icon: .options,
                            label: copy.text("设置", "Settings")
                        ) { showSettings = true }
                    }
                    ToolbarItemGroup(placement: .navigationBarTrailing) {
                        toolbarButton(
                            icon: appearance == .dark ? .modeLight : .modeDark,
                            label: copy.text("切换外观", "Toggle appearance")
                        ) {
                            appearance = appearance == .dark ? .light : .dark
                        }
                        toolbarButton(
                            icon: .lock,
                            label: copy.text("隐私密码", "Privacy PIN")
                        ) { showPassword = true }
                        toolbarButton(
                            icon: .share,
                            label: copy.text("分享", "Share")
                        ) {
                            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                                showShare = true
                            }
                        }
                    }
                }
                .tint(palette.accent)
                .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: installedItems.map(\.id))
            }
            .navigationViewStyle(StackNavigationViewStyle())

            if let notice = store.notice {
                AppBoxNoticeView(text: noticeText(notice), palette: palette)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            if showShare {
                AppBoxShareView(language: language, skin: skin) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showShare = false }
                }
                .zIndex(100)
            }

            if let launchState = store.launchState {
                AppBoxLaunchTransitionView(
                    state: launchState,
                    language: language,
                    skin: skin
                )
                .transition(.scale(scale: 0.97).combined(with: .opacity))
                .zIndex(120)
            }
        }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: store.launchState != nil)
    }

    private func dismissSensitiveContent() {
        showSettings = false
        showShare = false
        showPassword = false
        store.activeWebApp = nil
        store.finishInstallRequest()
    }

    private var seriesTabs: some View {
        Picker(copy.text("应用系列", "App series"), selection: $selectedSeries) {
            ForEach(AppBoxSeries.allCases) { series in
                Text(copy.series(series))
                    .lineLimit(1)
                    .tag(series)
            }
        }
        .pickerStyle(.segmented)
        .labelsHidden()
        .tint(palette.accent)
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
                            canRemove: store.canRemove(item),
                            open: { Task { await store.launch(item, hostApps: sharedModel.apps) } },
                            remove: { Task { await store.remove(item) } }
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
                        installState: store.installStates[item.id]
                    ) {
                        if let state = store.installStates[item.id] {
                            if state.isCancellable {
                                store.cancelInstall(item)
                            } else if state.isActive || state == .completed {
                                return
                            } else {
                                store.startInstall(item, sharedModel: sharedModel)
                            }
                        } else if store.isInstalled(item, hostApps: sharedModel.apps) {
                            Task {
                                await store.launch(item, hostApps: sharedModel.apps)
                            }
                        } else {
                            store.startInstall(item, sharedModel: sharedModel)
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
        let columnCount = dynamicTypeSize.isAccessibilitySize ? 3 : 5
        return Array(repeating: GridItem(.flexible(minimum: 44), spacing: 9), count: columnCount)
    }

    private func toolbarButton(
        icon: AppBoxIcon,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: icon.rawValue)
        }
        .accessibilityLabel(label)
    }

    private func noticeText(_ notice: AppBoxNotice) -> String {
        switch notice {
        case .installed(let id):
            let name = AppBoxCatalog.item(id: id)?.name(for: language) ?? ""
            return copy.text("\(name) 已安装", "\(name) installed")
        case .installFailed(let message):
            return copy.text("安装失败：\(message)", "Installation failed: \(message)")
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
