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

    @State private var selectedSeriesID = ""
    @State private var query = ""
    @State private var showSettings = false
    @State private var showShare = false
    @State private var showPassword = false
    @State private var passwordAllowsDecoyManagement = false
    @State private var pendingExternalIntent: AppBoxExternalIntent?

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    private var installedItems: [AppBoxCatalogItem] { store.installedItems(hostApps: sharedModel.apps) }

    var body: some View {
        Group {
            if lockController.isLocked {
                AppBoxLockScreen(
                    language: language,
                    skin: skin,
                    allowsDecoyUnlock: lockController.allowsDecoyUnlock,
                    onUnlock: handleUnlock
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
            AppBoxPasswordView(
                language: language,
                skin: skin,
                mode: .manage,
                allowsDecoyManagement: passwordAllowsDecoyManagement,
                onProtectionChange: { _ in lockController.synchronizeProtectionState() }
            )
        }
        .fullScreenCover(item: $store.activeWebApp) { item in
            AppBoxWebAppView(item: item, language: language, skin: skin)
        }
        .sheet(item: $store.pendingInstallRequest, onDismiss: {
            store.finishInstallRequest()
        }) { request in
            AppBoxContainerInstallerView(sourceURL: request.sourceURL)
                .appBoxImporterPresentation()
        }
        .onChange(of: scenePhase) { phase in
            if phase != .active {
                dismissSensitiveContent()
            } else {
                consumePendingExternalURL()
            }
            lockController.handleScenePhase(phase)
        }
        .onOpenURL { url in
            handleExternalURL(url)
        }
        .onChange(of: sharedModel.deepLink) { url in
            consumeSharedDeepLink(url)
        }
        .task {
            await store.refreshCatalogIfNeeded()
            selectDefaultSeriesIfNeeded()
            consumeSharedDeepLink(sharedModel.deepLink)
            consumePendingExternalURL()
        }
        .onChange(of: store.catalogSeries.map(\.id)) { _ in
            selectDefaultSeriesIfNeeded()
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

    @ViewBuilder
    private var unlockedContent: some View {
        switch lockController.currentSpace {
        case .real:
            appCenterContent
        case .focus:
            focusSpace(isDecoy: false)
        case .decoy:
            AppBoxDecoySpaceView(language: language, skin: skin)
        case nil:
            focusSpace(isDecoy: false)
        }
    }

    private func focusSpace(isDecoy: Bool) -> some View {
        AppBoxFocusSpaceView(
            language: $language,
            appearance: $appearance,
            skin: $skin,
            isDecoy: isDecoy,
            isPrivacyEnabled: lockController.protectionEnabled,
            canManagePassword: !isDecoy,
            openPassword: { openPassword(allowsDecoyManagement: true) },
            openShare: {
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    showShare = true
                }
            }
        )
        .overlay(alignment: .top) {
            if let notice = store.notice {
                AppBoxNoticeView(text: noticeText(notice), palette: palette)
                    .padding(.top, 8)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .overlay {
            if showShare {
                AppBoxShareView(language: language, skin: skin) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) { showShare = false }
                }
                .zIndex(100)
            }
        }
    }

    private var appCenterContent: some View {
        ZStack(alignment: .top) {
            palette.background.ignoresSafeArea()

            VStack(spacing: 10) {
                appCenterHeader

                AppBoxSearchBar(
                    text: $query,
                    placeholder: copy.text("搜索应用", "Search apps"),
                    palette: palette
                )
                .padding(.horizontal, AppBoxLayout.pagePadding)

                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppBoxLayout.sectionSpacing) {
                        if !installedItems.isEmpty {
                            installedSection
                                .transition(.move(edge: .top).combined(with: .opacity))
                        }

                        seriesTabs

                        let groups = store.catalogGroups(
                            seriesID: selectedCatalogSeriesID,
                            query: query,
                            language: language
                        )
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
            }
            .padding(.top, 8)
            .background(palette.background)
            .animation(reduceMotion ? nil : .easeInOut(duration: 0.22), value: installedItems.map(\.id))

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

    private var appCenterHeader: some View {
        ZStack {
            Text(AppBoxBrand.name(for: language))
                .font(.headline.weight(.semibold))
                .foregroundColor(palette.primaryText)
                .lineLimit(1)

            HStack(spacing: 4) {
                topIconButton(
                    icon: .options,
                    label: copy.text("设置", "Settings")
                ) { showSettings = true }

                Spacer(minLength: 12)

                topIconButton(
                    icon: appearance == .dark ? .modeLight : .modeDark,
                    label: copy.text("切换外观", "Toggle appearance")
                ) {
                    appearance = appearance == .dark ? .light : .dark
                }
                topIconButton(
                    icon: .lock,
                    label: copy.text("隐私密码", "Privacy PIN")
                ) { openPassword(allowsDecoyManagement: false) }
                topIconButton(
                    icon: .share,
                    label: copy.text("分享", "Share")
                ) {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                        showShare = true
                    }
                }
            }
        }
        .padding(.horizontal, AppBoxLayout.pagePadding)
        .frame(height: 44)
    }

    private func dismissSensitiveContent() {
        showSettings = false
        showShare = false
        showPassword = false
        store.activeWebApp = nil
        store.finishInstallRequest()
    }

    private var seriesTabs: some View {
        Group {
            if !store.catalogSeries.isEmpty {
                Picker(copy.text("应用分类", "App category"), selection: $selectedSeriesID) {
                    ForEach(store.catalogSeries) { series in
                        Text(copy.series(series))
                            .lineLimit(1)
                            .tag(series.id)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .tint(palette.accent)
            }
        }
    }

    private var selectedCatalogSeriesID: String? {
        if !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return nil
        }
        if store.catalogSeries.contains(where: { $0.id == selectedSeriesID }) {
            return selectedSeriesID
        }
        return store.catalogSeries.first?.id
    }

    private func selectDefaultSeriesIfNeeded() {
        let ids = store.catalogSeries.map(\.id)
        guard !ids.isEmpty else {
            selectedSeriesID = ""
            return
        }
        if !ids.contains(selectedSeriesID) {
            selectedSeriesID = ids[0]
        }
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
                title: group.title(for: language, fallback: copy),
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

    private func topIconButton(
        icon: AppBoxIcon,
        label: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            AppBoxGlyph(icon: icon)
                .frame(width: 19, height: 19)
                .foregroundStyle(palette.primaryText)
                .frame(width: 34, height: 34)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }

    private func noticeText(_ notice: AppBoxNotice) -> String {
        switch notice {
        case .installed(let id):
            let name = store.item(id: id)?.name(for: language) ?? ""
            return copy.text("\(name) 已安装", "\(name) installed")
        case .installFailed(let message):
            return copy.text("安装失败：\(message)", "Installation failed: \(message)")
        case .launched(let id):
            let name = store.item(id: id)?.name(for: language) ?? ""
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

    private func handleUnlock(_ result: AppBoxUnlockResult) {
        lockController.unlock(result)
        switch result {
        case .real:
            if let intent = pendingExternalIntent {
                pendingExternalIntent = nil
                lockController.confirmExternalAppCenterActivation()
                recordExternalState("unlock-real-resume")
                Task { await store.handleExternalIntent(intent, sharedModel: sharedModel) }
            }
        case .decoy:
            pendingExternalIntent = nil
            dismissSensitiveContent()
            recordExternalState("unlock-decoy-drop")
        case .failed:
            break
        }
    }

    private func openPassword(allowsDecoyManagement: Bool) {
        passwordAllowsDecoyManagement = allowsDecoyManagement
        showPassword = true
    }

    private func handleExternalURL(_ url: URL) {
        guard let intent = AppBoxDeepLinkParser.parse(url) else { return }
        let defaults = UserDefaults.standard
        defaults.set(url.absoluteString, forKey: "AppBox.lastHandledExternalURL")
        defaults.set(Date(), forKey: "AppBox.lastHandledExternalURLDate")
        defaults.set("\(intent.debugDescription)|protected=\(lockController.protectionEnabled)|space=\(lockController.currentSpace.debugDescription)", forKey: "AppBox.lastExternalIntentState")
        defaults.synchronize()

        if lockController.protectionEnabled && lockController.currentSpace != .real {
            pendingExternalIntent = intent
            dismissSensitiveContent()
            lockController.requireUnlock()
            recordExternalState("waiting-unlock|\(intent.debugDescription)")
            return
        }

        lockController.confirmExternalAppCenterActivation()
        recordExternalState("dispatch|\(intent.debugDescription)")

        Task {
            await store.handleExternalIntent(intent, sharedModel: sharedModel)
        }
    }

    private func consumeSharedDeepLink(_ url: URL?) {
        guard let url else { return }
        sharedModel.deepLink = nil
        _ = AppBoxIncomingURLRelay.consumePendingURL()
        handleExternalURL(url)
    }

    private func consumePendingExternalURL() {
        guard let url = AppBoxIncomingURLRelay.consumePendingURL() else { return }
        handleExternalURL(url)
    }

    private func recordExternalState(_ state: String) {
        let defaults = UserDefaults.standard
        defaults.set(state, forKey: "AppBox.lastExternalIntentState")
        defaults.set(Date(), forKey: "AppBox.lastExternalIntentStateDate")
        defaults.synchronize()
    }
}

private extension Optional where Wrapped == AppBoxSpaceSession {
    var debugDescription: String {
        switch self {
        case .real?: return "real"
        case .focus?: return "focus"
        case .decoy?: return "decoy"
        case nil: return "nil"
        }
    }
}

private extension AppBoxExternalIntent {
    var debugDescription: String {
        switch self {
        case .install(let url):
            return "install:\(url?.absoluteString ?? "picker")"
        case .openItem(let id, let launchAfterInstall):
            return "open:\(id):launch=\(launchAfterInstall)"
        case .native(let payload):
            return "native:appID=\(payload.appID ?? "nil"):platform=\(payload.platform ?? "nil")"
        }
    }
}
