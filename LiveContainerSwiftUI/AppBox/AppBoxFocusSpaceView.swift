import CoreLocation
import FamilyControls
import SwiftUI
import UIKit

enum AppBoxFocusTab: String, CaseIterable, Identifiable {
    case apps
    case places
    case schedule
    case settings

    var id: String { rawValue }
}

struct AppBoxFocusSpaceView: View {
    @Binding var language: AppBoxLanguage
    @Binding var appearance: AppBoxAppearance
    @Binding var skin: AppBoxSkin

    let isDecoy: Bool
    let isPrivacyEnabled: Bool
    let canManagePassword: Bool
    let openPassword: () -> Void
    let openShare: () -> Void

    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @StateObject private var visibility = AppBoxVisibilityService()
    @StateObject private var automation = AppBoxFocusAutomationStore()
    @StateObject private var geofenceMonitor = AppBoxGeofenceMonitor.shared
    @State private var selectedTab: AppBoxFocusTab = .apps
    @State private var activeAutomationID: String?
    @State private var isActivityPickerPresented = false
    @State private var isPlaceEditorPresented = false
    @State private var isScheduleEditorPresented = false
    @State private var didApplyDebugInitialTab = false
    @State private var scheduleClock = Date()

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    private let scheduleTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack(alignment: .bottom) {
            AppBoxFocusBackground(palette: palette)

            VStack(spacing: 0) {
                header
                tabContent
            }

            AppBoxFloatingTabBar(
                selectedTab: $selectedTab,
                language: language,
                palette: palette
            )
            .padding(.horizontal, 20)
            .padding(.bottom, 10)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.84), value: selectedTab)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: visibility.isHidden)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.22), value: activeAutomationID)
        .onAppear {
            geofenceMonitor.onRuleTriggered = handlePlaceRuleTriggered
            geofenceMonitor.synchronize(rules: automation.placeRules)
            applyDebugInitialTabIfNeeded()
            enforceScheduleIfNeeded()
        }
        .onChange(of: automation.placeRules) { rules in
            geofenceMonitor.synchronize(rules: rules)
        }
        .onChange(of: geofenceMonitor.authorizationStatus) { _ in
            geofenceMonitor.synchronize(rules: automation.placeRules)
        }
        .onReceive(scheduleTimer) { date in
            scheduleClock = date
            enforceScheduleIfNeeded(at: date)
        }
        .familyActivityPicker(isPresented: $isActivityPickerPresented, selection: $visibility.selection)
        .sheet(isPresented: $isPlaceEditorPresented) {
            AppBoxPlaceEditorSheet(
                language: language,
                palette: palette,
                authorizationStatus: geofenceMonitor.authorizationStatus,
                currentLocation: geofenceMonitor.currentLocation,
                isRequestingLocation: geofenceMonitor.isRequestingLocation,
                locationError: geofenceMonitor.lastError,
                requestLocationAction: {
                    geofenceMonitor.requestCurrentLocation()
                },
                requestAlwaysAuthorizationAction: requestLocationAccess,
                addAction: { name, trigger, coordinate, radiusMeters in
                    automation.addPlaceRule(
                        name: name,
                        trigger: trigger,
                        coordinate: coordinate,
                        radiusMeters: radiusMeters
                    )
                    isPlaceEditorPresented = false
                }
            )
        }
        .sheet(isPresented: $isScheduleEditorPresented) {
            AppBoxScheduleEditorSheet(
                language: language,
                palette: palette,
                addAction: { name, startHour, startMinute, endHour, endMinute in
                    automation.addScheduleRule(
                        name: name,
                        startHour: startHour,
                        startMinute: startMinute,
                        endHour: endHour,
                        endMinute: endMinute
                    )
                    isScheduleEditorPresented = false
                    enforceScheduleIfNeeded()
                }
            )
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            Text(tabTitle(selectedTab))
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.82)

            Spacer(minLength: 10)

            if selectedTab != .apps {
                Button(action: headerAction) {
                    AppBoxGlyph(icon: headerIcon)
                        .frame(width: 20, height: 20)
                        .foregroundColor(headerIcon == .share ? palette.primaryText : palette.accent)
                        .frame(width: 42, height: 42)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(headerActionTitle)
            }
        }
        .padding(.horizontal, AppBoxLayout.pagePadding)
        .padding(.top, 18)
        .padding(.bottom, 10)
    }

    private var headerIcon: AppBoxIcon {
        switch selectedTab {
        case .apps, .places, .schedule:
            return .plus
        case .settings:
            return .share
        }
    }

    private var headerActionTitle: String {
        switch selectedTab {
        case .apps:
            return copy.text("选择应用", "Choose Apps")
        case .places:
            return copy.text("新增地点", "Add Place")
        case .schedule:
            return copy.text("新增日程", "Add Schedule")
        case .settings:
            return copy.text("分享", "Share")
        }
    }

    private func headerAction() {
        switch selectedTab {
        case .apps:
            chooseSystemApps()
        case .places:
            isPlaceEditorPresented = true
        case .schedule:
            isScheduleEditorPresented = true
        case .settings:
            openShare()
        }
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .apps:
            scrollPage { appsPage }
        case .places:
            scrollPage { placesPage }
        case .schedule:
            scrollPage { schedulePage }
        case .settings:
            scrollPage { settingsPage }
        }
    }

    private func scrollPage<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 18) {
                content()
            }
            .padding(.horizontal, AppBoxLayout.pagePadding)
            .padding(.top, 8)
            .padding(.bottom, 104)
        }
    }

    private var appsPage: some View {
        VStack(spacing: 14) {
            AppBoxSelectedAppsPanel(
                selection: visibility.selection,
                selectedApplicationCount: visibility.selectedApplicationCount,
                selectedCategoryCount: visibility.selectedCategoryCount,
                selectedWebDomainCount: visibility.selectedWebDomainCount,
                isAuthorized: visibility.isAuthorized,
                isHidden: visibility.isHidden,
                errorMessage: visibility.lastError,
                language: language,
                palette: palette,
                chooseAction: chooseSystemApps,
                primaryAction: toggleVisibility,
                clearSelectionAction: {
                    visibility.clearSelection()
                    activeAutomationID = nil
                }
            )
        }
    }

    private var placesPage: some View {
        VStack(spacing: 14) {
            if automation.placeRules.isEmpty {
                AppBoxAutomationEmptyState(
                    icon: .locationArrow,
                    title: copy.text("根据地点自动隐藏选定应用。", "Hide selected apps by location."),
                    message: copy.text("先选择应用，再用当前位置创建地点规则。后台触发需要始终允许定位。", "Choose apps first, then create a place rule from your current location. Background triggers require Always location access."),
                    primaryTitle: locationPrimaryTitle,
                    primaryIcon: locationPrimaryIcon,
                    secondaryTitle: geofenceMonitor.isAlwaysAuthorized ? nil : copy.text("新建地点", "New Place"),
                    secondaryIcon: geofenceMonitor.isAlwaysAuthorized ? nil : .plus,
                    palette: palette,
                    primaryAction: {
                        if geofenceMonitor.isAlwaysAuthorized {
                            isPlaceEditorPresented = true
                        } else {
                            requestLocationAccess()
                        }
                    },
                    secondaryAction: { isPlaceEditorPresented = true }
                )
            } else {
                ForEach(automation.placeRules) { rule in
                    AppBoxPlaceRuleCard(
                        rule: rule,
                        isMonitoring: geofenceMonitor.monitoredRuleIDs.contains(rule.id),
                        canMonitor: geofenceMonitor.isAlwaysAuthorized,
                        language: language,
                        palette: palette,
                        toggleAction: { automation.togglePlaceRule(rule) },
                        removeAction: { automation.removePlaceRule(rule) }
                    )
                }

                AppBoxInlineActionRow(
                    icon: .arrowUpRight,
                    title: copy.text("定位权限", "Location Permission"),
                    detail: locationPermissionDetail,
                    palette: palette,
                    action: requestLocationAccess
                )
            }
        }
    }

    private var schedulePage: some View {
        VStack(spacing: 14) {
            if automation.scheduleRules.isEmpty {
                AppBoxAutomationEmptyState(
                    icon: .calendarClock,
                    title: copy.text("在一天中特定时间停用或启用应用。", "Disable or restore apps at specific times."),
                    message: copy.text("日程会在应用运行时自动检查；手动启用时立即生效。", "Schedules are checked while the app is running and can be applied manually."),
                    primaryTitle: copy.text("新建日程", "New Schedule"),
                    primaryIcon: .plus,
                    secondaryTitle: nil,
                    secondaryIcon: nil,
                    palette: palette,
                    primaryAction: { isScheduleEditorPresented = true },
                    secondaryAction: nil
                )
            } else {
                ForEach(automation.scheduleRules) { rule in
                    AppBoxScheduleRuleCard(
                        rule: rule,
                        isActive: activeAutomationID == rule.id || rule.contains(scheduleClock),
                        language: language,
                        palette: palette,
                        toggleAction: {
                            automation.toggleScheduleRule(rule)
                            enforceScheduleIfNeeded()
                        },
                        runAction: {
                            activeAutomationID = rule.id
                            Task { await hideVisibility() }
                        },
                        removeAction: {
                            if activeAutomationID == rule.id {
                                restoreVisibility()
                            }
                            automation.removeScheduleRule(rule)
                        }
                    )
                }
            }
        }
    }

    private var settingsPage: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                profileRow(
                    icon: .lock,
                    title: copy.text("隐私密码", "Privacy PIN"),
                    detail: passwordDetail,
                    isEnabled: canManagePassword,
                    action: canManagePassword ? openPassword : nil
                )
                profileDivider
                profileRow(
                    icon: .modeDark,
                    title: copy.text("外观", "Appearance"),
                    detail: copy.appearance(appearance)
                ) {
                    cycleAppearance()
                }
                profileDivider
                profileRow(
                    icon: .paintpalette,
                    title: copy.text("主题", "Theme"),
                    detail: copy.skin(skin)
                ) {
                    cycleSkin()
                }
                profileDivider
                profileRow(
                    icon: .translate,
                    title: copy.text("语言", "Language"),
                    detail: language.displayName
                ) {
                    language = language == .simplifiedChinese ? .english : .simplifiedChinese
                }
                profileDivider
                profileRow(
                    icon: .share,
                    title: copy.text("分享", "Share"),
                    detail: AppBoxBrand.name(for: language),
                    action: openShare
                )
            }
            .appBoxLiquidCard(palette, radius: 22)

            VStack(spacing: 0) {
                profileRow(
                    icon: .shield,
                    title: copy.text("空间状态", "Space Status"),
                    detail: isDecoy ? copy.text("正常", "Normal") : copy.text("默认入口", "Default")
                )
                profileDivider
                profileRow(
                    icon: .info,
                    title: copy.text("版本", "Version"),
                    detail: "1.0.0"
                )
            }
            .appBoxLiquidCard(palette, radius: 22)
        }
    }

    private var passwordDetail: String {
        if isDecoy { return copy.text("已保护", "Protected") }
        return isPrivacyEnabled ? copy.text("已开启", "On") : copy.text("未设置", "Not set")
    }

    private var profileDivider: some View {
        Rectangle()
            .fill(palette.divider.opacity(0.24))
            .frame(height: 1)
            .padding(.leading, 58)
    }

    private func profileRow(
        icon: AppBoxIcon,
        title: String,
        detail: String,
        isEnabled: Bool = true,
        action: (() -> Void)? = nil
    ) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 12) {
                AppBoxGlyph(icon: icon)
                    .frame(width: 16, height: 16)
                    .foregroundColor(isEnabled ? palette.accent : palette.secondaryText)
                    .frame(width: 32, height: 32)
                    .background((isEnabled ? palette.accentSoft : palette.mutedSurface).opacity(0.82))
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))

                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(isEnabled ? palette.primaryText : palette.secondaryText)

                Spacer()

                Text(detail)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)

                if action != nil {
                    AppBoxGlyph(icon: .arrowRight)
                        .frame(width: 13, height: 13)
                        .foregroundColor(palette.secondaryText.opacity(0.8))
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(action == nil)
    }

    private func tabTitle(_ tab: AppBoxFocusTab) -> String {
        switch tab {
        case .apps:
            return copy.text("应用", "Apps")
        case .places:
            return copy.text("地点", "Places")
        case .schedule:
            return copy.text("日程", "Schedule")
        case .settings:
            return copy.text("设置", "Settings")
        }
    }

    private func chooseSystemApps() {
        Task {
            if await visibility.requestAuthorizationIfNeeded() {
                isActivityPickerPresented = true
            }
        }
    }

    private func hideVisibility() async {
        await visibility.hideSelection()
    }

    private func restoreVisibility() {
        visibility.restoreAll()
        activeAutomationID = nil
    }

    private func toggleVisibility() {
        if visibility.isHidden {
            restoreVisibility()
        } else {
            Task { await hideVisibility() }
        }
    }

    private func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }

    private func requestLocationAccess() {
        if geofenceMonitor.canRequestAuthorization {
            geofenceMonitor.requestAlwaysAuthorization()
            return
        }
        openAppSettings()
    }

    private var locationPrimaryTitle: String {
        switch geofenceMonitor.authorizationStatus {
        case .authorizedAlways:
            return copy.text("新建地点", "New Place")
        case .notDetermined, .authorizedWhenInUse:
            return copy.text("允许定位", "Allow Location")
        case .denied, .restricted:
            return copy.text("系统设置", "System Settings")
        @unknown default:
            return copy.text("系统设置", "System Settings")
        }
    }

    private var locationPrimaryIcon: AppBoxIcon {
        geofenceMonitor.authorizationStatus == .authorizedAlways ? .plus : .arrowUpRight
    }

    private var locationPermissionDetail: String {
        switch geofenceMonitor.authorizationStatus {
        case .authorizedAlways:
            return copy.text("后台地点触发已可用", "Background location triggers enabled")
        case .authorizedWhenInUse:
            return copy.text("需要升级为始终允许", "Upgrade to Always access")
        case .notDetermined:
            return copy.text("允许后可创建后台地点规则", "Allow access to create background place rules")
        case .denied, .restricted:
            return copy.text("前往系统设置调整", "Open app settings")
        @unknown default:
            return copy.text("前往系统设置调整", "Open app settings")
        }
    }

    private func handlePlaceRuleTriggered(_ rule: AppBoxPlaceRule) {
        guard visibility.hasSelection else { return }
        guard automation.placeRules.contains(where: { $0.id == rule.id && $0.isEnabled }) else { return }
        activeAutomationID = rule.id
        automation.markPlaceRuleTriggered(rule)
        Task { await hideVisibility() }
    }

    private func enforceScheduleIfNeeded(at date: Date = Date()) {
        guard let activeRule = automation.activeSchedule(at: date) else {
            if let activeAutomationID,
               automation.scheduleRules.contains(where: { $0.id == activeAutomationID }) {
                restoreVisibility()
            }
            return
        }

        guard visibility.hasSelection else { return }
        guard activeAutomationID != activeRule.id || !visibility.isHidden else { return }
        activeAutomationID = activeRule.id
        Task { await hideVisibility() }
    }

    private func cycleAppearance() {
        switch appearance {
        case .system: appearance = .light
        case .light: appearance = .dark
        case .dark: appearance = .system
        }
    }

    private func cycleSkin() {
        switch skin {
        case .sky: skin = .mint
        case .mint: skin = .coral
        case .coral: skin = .sky
        }
    }

    private func applyDebugInitialTabIfNeeded() {
#if DEBUG
        guard !didApplyDebugInitialTab else { return }
        didApplyDebugInitialTab = true
        guard let rawValue = ProcessInfo.processInfo.environment["APPBOX_DEBUG_FOCUS_TAB"],
              let tab = AppBoxFocusTab(rawValue: rawValue) else { return }
        selectedTab = tab
#endif
    }
}

struct AppBoxFocusBackground: View {
    let palette: AppBoxPalette

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: colorScheme == .dark
                    ? [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .secondarySystemBackground),
                        palette.accentSoft.opacity(0.18)
                    ]
                    : [
                        Color(uiColor: .systemBackground),
                        Color(uiColor: .systemGroupedBackground),
                        palette.accentSoft.opacity(0.24)
                    ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            palette.background
                .opacity(colorScheme == .dark ? 0.34 : 0.20)
                .ignoresSafeArea()
        }
    }
}

struct AppBoxPrivacyBackground: View {
    let palette: AppBoxPalette

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        LinearGradient(
            colors: colorScheme == .dark
                ? [
                    Color(red: 0.04, green: 0.07, blue: 0.12),
                    Color(red: 0.07, green: 0.12, blue: 0.20),
                    palette.accent.opacity(0.22)
                ]
                : [
                    Color(red: 0.80, green: 0.90, blue: 1.00),
                    Color(red: 0.90, green: 0.97, blue: 0.99),
                    Color(uiColor: .systemBackground)
                ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .ignoresSafeArea()
    }
}

private struct AppBoxFloatingTabBar: View {
    @Binding var selectedTab: AppBoxFocusTab
    let language: AppBoxLanguage
    let palette: AppBoxPalette

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppBoxFocusTab.allCases) { tab in
                Button {
                    withAnimation(reduceMotion ? nil : .spring(response: 0.36, dampingFraction: 0.86)) {
                        selectedTab = tab
                    }
                } label: {
                    ZStack {
                        if selectedTab == tab {
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .fill(Color.clear)
                                .appBoxTabSelectionLens(palette, radius: 24)
                                .matchedGeometryEffect(id: "tabSelection", in: selectionNamespace)
                        }

                        VStack(spacing: 3) {
                            AppBoxGlyph(icon: icon(tab))
                                .frame(width: 22, height: 22)
                            Text(title(tab))
                                .font(.system(size: 10, weight: .semibold))
                                .lineLimit(1)
                                .minimumScaleFactor(0.82)
                        }
                        .foregroundColor(selectedTab == tab ? palette.accent : palette.secondaryText)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .contentShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selectedTab == tab ? .isSelected : [])
            }
        }
        .padding(4)
        .frame(maxWidth: 500)
        .frame(height: 64)
        .appBoxTabBarGlass(palette, radius: 32)
    }

    private func title(_ tab: AppBoxFocusTab) -> String {
        switch tab {
        case .apps: return copy.text("应用", "Apps")
        case .places: return copy.text("地点", "Places")
        case .schedule: return copy.text("日程", "Schedule")
        case .settings: return copy.text("设置", "Settings")
        }
    }

    private func icon(_ tab: AppBoxFocusTab) -> AppBoxIcon {
        switch tab {
        case .apps: return .apps
        case .places: return .mapPin
        case .schedule: return .calendarClock
        case .settings: return .gear
        }
    }
}

private struct AppBoxSelectedAppsPanel: View {
    let selection: FamilyActivitySelection
    let selectedApplicationCount: Int
    let selectedCategoryCount: Int
    let selectedWebDomainCount: Int
    let isAuthorized: Bool
    let isHidden: Bool
    let errorMessage: String?
    let language: AppBoxLanguage
    let palette: AppBoxPalette
    let chooseAction: () -> Void
    let primaryAction: () -> Void
    let clearSelectionAction: () -> Void

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var hasSelection: Bool { selectedApplicationCount > 0 || selectedCategoryCount > 0 || selectedWebDomainCount > 0 }
    private let columns = Array(repeating: GridItem(.flexible(minimum: 0, maximum: 72), spacing: 6), count: 5)

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(copy.text("已选应用", "Selected Apps"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    Text(statusText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(isHidden ? Color(uiColor: .systemGreen) : palette.secondaryText)
                }

                Spacer()
            }

            selectedContent

            VStack(spacing: 10) {
                if hasSelection {
                    if isHidden {
                        AppBoxHoldProgressButton(
                            title: copy.text("长按显示", "Hold to Show"),
                            icon: .eye,
                            tint: Color(uiColor: .systemGreen),
                            action: primaryAction
                        )
                    } else {
                        Button(action: primaryAction) {
                            HStack(spacing: 8) {
                                AppBoxGlyph(icon: .eyeOff)
                                    .frame(width: 17, height: 17)
                                Text(copy.text("隐藏", "Hide"))
                            }
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(palette.accent)
                            .clipShape(Capsule())
                            .shadow(color: palette.accent.opacity(0.11), radius: 18, y: 8)
                        }
                        .buttonStyle(.plain)
                    }

                    HStack(spacing: 10) {
                        Button(action: chooseAction) {
                            Text(copy.text("重新选择", "Choose Again"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(palette.accent)
                                .frame(maxWidth: .infinity)
                                .frame(height: 40)
                                .background(palette.accentSoft.opacity(0.82))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)

                        Button(action: clearSelectionAction) {
                            Text(copy.text("清空", "Clear"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(palette.secondaryText)
                                .frame(width: 76)
                                .frame(height: 40)
                                .background(palette.mutedSurface.opacity(0.46))
                                .clipShape(Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                } else {
                    Button(action: chooseAction) {
                            Text(copy.text("选择应用", "Choose Apps"))
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 46)
                            .background(palette.accent)
                            .clipShape(Capsule())
                            .shadow(color: palette.accent.opacity(0.11), radius: 18, y: 8)
                    }
                    .buttonStyle(.plain)
                }
            }

            if let errorMessage, !errorMessage.isEmpty {
                HStack(spacing: 8) {
                    AppBoxGlyph(icon: .warning)
                        .frame(width: 14, height: 14)
                    Text(errorMessage)
                        .font(.caption.weight(.medium))
                        .lineLimit(2)
                }
                .foregroundColor(palette.destructive)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(palette.destructive.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
        .padding(14)
        .appBoxLiquidCard(palette, radius: 22)
    }

    @ViewBuilder
    private var selectedContent: some View {
        if hasSelection {
            if isHidden {
                AppBoxHiddenSelectionView(countText: countText, language: language, palette: palette)
            } else if #available(iOS 15.2, *) {
                LazyVGrid(columns: columns, spacing: 8) {
                    ForEach(Array(selection.applicationTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(AppBoxActivityIconOnlyLabelStyle())
                    }
                    ForEach(Array(selection.categoryTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(AppBoxActivityIconOnlyLabelStyle())
                    }
                    ForEach(Array(selection.webDomainTokens), id: \.self) { token in
                        Label(token)
                            .labelStyle(AppBoxActivityIconOnlyLabelStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 0)
            } else {
                AppBoxSelectedAppsFallback(countText: countText, palette: palette)
            }
        } else {
            HStack(spacing: 12) {
                AppBoxGlyph(icon: .apps)
                    .frame(width: 20, height: 20)
                    .foregroundColor(palette.accent)
                    .frame(width: 40, height: 40)
                    .background(palette.accentSoft.opacity(0.70))
                    .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(copy.text("未选择应用", "No apps selected"))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    Text(copy.text("选择需要隐藏的 App。", "Choose apps to hide."))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 8)
        }
    }

    private var statusText: String {
        if isHidden {
            return copy.text("当前已隐藏", "Hidden now")
        }
        if hasSelection {
            return copy.text("\(countText)，显示中", "\(countText), visible")
        }
        return copy.text("未选择", "No selection")
    }

    private var countText: String {
        var parts: [String] = []
        if selectedApplicationCount > 0 {
            parts.append(copy.text("\(selectedApplicationCount) 个 App", "\(selectedApplicationCount) apps"))
        }
        if selectedCategoryCount > 0 {
            parts.append(copy.text("\(selectedCategoryCount) 个分类", "\(selectedCategoryCount) categories"))
        }
        if selectedWebDomainCount > 0 {
            parts.append(copy.text("\(selectedWebDomainCount) 个网站", "\(selectedWebDomainCount) sites"))
        }
        return parts.joined(separator: " / ")
    }
}

private struct AppBoxActivityIconOnlyLabelStyle: LabelStyle {
    func makeBody(configuration: Configuration) -> some View {
        ZStack {
            configuration.icon
                .scaleEffect(1.55)
                .frame(width: 54, height: 54)
        }
            .frame(width: 60, height: 60)
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .compositingGroup()
            .shadow(color: Color.black.opacity(0.036), radius: 10, y: 4)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
    }
}

private struct AppBoxHoldProgressButton: View {
    let title: String
    let icon: AppBoxIcon
    let tint: Color
    let action: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var progress: CGFloat = 0
    @State private var isHolding = false
    @State private var didComplete = false
    @State private var completionWorkItem: DispatchWorkItem?

    private let holdDuration: TimeInterval = 1.15

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(tint.opacity(0.56))

            GeometryReader { proxy in
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, proxy.size.width * progress))
            }

            HStack(spacing: 8) {
                AppBoxGlyph(icon: icon)
                    .frame(width: 17, height: 17)
                Text(title)
            }
            .font(.system(size: 15, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 46)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 46)
        .clipShape(Capsule())
        .contentShape(Capsule())
        .shadow(color: tint.opacity(0.10), radius: 18, y: 8)
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in beginHoldIfNeeded() }
                .onEnded { _ in cancelHoldIfNeeded() }
        )
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityHint("按住直到进度条填满")
        .accessibilityAddTraits(.isButton)
        .onDisappear { resetHold(immediate: true) }
    }

    private func beginHoldIfNeeded() {
        guard !isHolding, !didComplete else { return }
        isHolding = true

        withAnimation(reduceMotion ? nil : .linear(duration: holdDuration)) {
            progress = 1
        }

        let workItem = DispatchWorkItem {
            guard isHolding, !didComplete else { return }
            didComplete = true
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                resetHold(immediate: true)
            }
        }
        completionWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + holdDuration, execute: workItem)
    }

    private func cancelHoldIfNeeded() {
        guard !didComplete else { return }
        resetHold(immediate: false)
    }

    private func resetHold(immediate: Bool) {
        completionWorkItem?.cancel()
        completionWorkItem = nil
        isHolding = false
        didComplete = false

        if immediate || reduceMotion {
            progress = 0
        } else {
            withAnimation(.easeOut(duration: 0.18)) {
                progress = 0
            }
        }
    }
}

private struct AppBoxHiddenSelectionView: View {
    let countText: String
    let language: AppBoxLanguage
    let palette: AppBoxPalette

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }

    var body: some View {
        HStack(spacing: 12) {
            AppBoxGlyph(icon: .eyeOff)
                .frame(width: 20, height: 20)
                .foregroundColor(Color(uiColor: .systemGreen))
                .frame(width: 40, height: 40)
                .background(Color(uiColor: .systemGreen).opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(copy.text("已隐藏", "Hidden"))
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(palette.primaryText)
                Text(countText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 2)
        .padding(.vertical, 8)
    }
}

private struct AppBoxSelectedAppsFallback: View {
    let countText: String
    let palette: AppBoxPalette

    var body: some View {
        HStack(spacing: 12) {
            AppBoxGlyph(icon: .apps)
                .frame(width: 20, height: 20)
                .foregroundColor(palette.accent)
                .frame(width: 42, height: 42)
                .background(palette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            Text(countText)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(palette.primaryText)
            Spacer()
        }
        .padding(12)
        .appBoxLiquidCard(palette, radius: 18, addsShadow: false)
    }
}

private struct AppBoxAutomationEmptyState: View {
    let icon: AppBoxIcon
    let title: String
    let message: String
    let primaryTitle: String
    let primaryIcon: AppBoxIcon
    let secondaryTitle: String?
    let secondaryIcon: AppBoxIcon?
    let palette: AppBoxPalette
    let primaryAction: () -> Void
    let secondaryAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 18) {
            Spacer(minLength: 76)

            AppBoxGlyph(icon: icon)
                .frame(width: 42, height: 42)
                .foregroundColor(palette.accent)

            Text(title)
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 8)

            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(palette.primaryText)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 18)

            Button(action: primaryAction) {
                AppBoxAutomationActionLabel(title: primaryTitle, icon: primaryIcon)
            }
            .buttonStyle(.plain)

            if let secondaryTitle, let secondaryIcon, let secondaryAction {
                Button(action: secondaryAction) {
                    AppBoxAutomationActionLabel(title: secondaryTitle, icon: secondaryIcon, isSecondary: true)
                }
                .buttonStyle(.plain)
            }

            Spacer(minLength: 140)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct AppBoxAutomationActionLabel: View {
    let title: String
    let icon: AppBoxIcon
    var isSecondary = false

    var body: some View {
        HStack(spacing: 8) {
            AppBoxGlyph(icon: icon)
                .frame(width: 16, height: 16)
            Text(title)
        }
        .font(.system(size: 15, weight: .semibold))
        .foregroundColor(.white)
        .padding(.horizontal, 20)
        .frame(height: 44)
        .background(isSecondary ? Color(uiColor: .systemGray) : Color(uiColor: .systemIndigo))
        .clipShape(Capsule())
        .shadow(color: Color(uiColor: .systemIndigo).opacity(isSecondary ? 0 : 0.18), radius: 10, y: 5)
    }
}

private struct AppBoxInlineActionRow: View {
    let icon: AppBoxIcon
    let title: String
    let detail: String
    let palette: AppBoxPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppBoxGlyph(icon: icon)
                    .frame(width: 16, height: 16)
                    .foregroundColor(palette.accent)
                    .frame(width: 34, height: 34)
                    .background(palette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    Text(detail)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }
                Spacer()
                AppBoxGlyph(icon: .arrowRight)
                    .frame(width: 13, height: 13)
                    .foregroundColor(palette.secondaryText.opacity(0.7))
            }
            .padding(12)
            .appBoxLiquidCard(palette, radius: 18)
        }
        .buttonStyle(.plain)
    }
}

private struct AppBoxPlaceRuleCard: View {
    let rule: AppBoxPlaceRule
    let isMonitoring: Bool
    let canMonitor: Bool
    let language: AppBoxLanguage
    let palette: AppBoxPalette
    let toggleAction: () -> Void
    let removeAction: () -> Void

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AppBoxGlyph(icon: .mapPin)
                    .frame(width: 19, height: 19)
                    .foregroundColor(palette.accent)
                    .frame(width: 42, height: 42)
                    .background(palette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    Text(triggerText)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }

                Spacer()

                Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in toggleAction() }))
                    .labelsHidden()
                    .tint(palette.accent)
            }

            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    AppBoxRuleBadge(
                        text: monitorText,
                        color: monitorColor,
                        palette: palette
                    )
                    AppBoxRuleBadge(
                        text: copy.text("半径 \(Int(rule.radiusMeters.rounded()))m", "\(Int(rule.radiusMeters.rounded()))m radius"),
                        color: palette.accent,
                        palette: palette
                    )
                }

                Text(locationText)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.82)

                if let lastTriggeredAt = rule.lastTriggeredAt {
                    Text(copy.text("最近触发 \(lastTriggeredAt.formatted(date: .omitted, time: .shortened))", "Last triggered \(lastTriggeredAt.formatted(date: .omitted, time: .shortened))"))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }
            }

            Button(role: .destructive, action: removeAction) {
                Text(copy.text("删除地点", "Delete Place"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(palette.destructive)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .frame(height: 30)
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .appBoxLiquidCard(palette, radius: 20)
    }

    private var triggerText: String {
        switch rule.trigger {
        case .leave:
            return copy.text("离开时停用选定应用", "Disable apps when leaving")
        case .arrive:
            return copy.text("到达时停用选定应用", "Disable apps when arriving")
        }
    }

    private var locationText: String {
        guard let coordinate = rule.coordinate else {
            return copy.text("未设置位置", "Location not set")
        }
        return String(format: "%.5f, %.5f", coordinate.latitude, coordinate.longitude)
    }

    private var monitorText: String {
        if !rule.isEnabled {
            return copy.text("已关闭", "Off")
        }
        if !rule.hasLocation {
            return copy.text("无位置", "No location")
        }
        if isMonitoring {
            return copy.text("监听中", "Monitoring")
        }
        if canMonitor {
            return copy.text("等待注册", "Pending")
        }
        return copy.text("需定位权限", "Needs location")
    }

    private var monitorColor: Color {
        if isMonitoring {
            return Color(uiColor: .systemGreen)
        }
        if !rule.isEnabled {
            return palette.secondaryText
        }
        return Color(uiColor: .systemOrange)
    }
}

private struct AppBoxRuleBadge: View {
    let text: String
    let color: Color
    let palette: AppBoxPalette

    var body: some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(color)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(color.opacity(0.12))
            .clipShape(Capsule())
    }
}

private struct AppBoxScheduleRuleCard: View {
    let rule: AppBoxScheduleRule
    let isActive: Bool
    let language: AppBoxLanguage
    let palette: AppBoxPalette
    let toggleAction: () -> Void
    let runAction: () -> Void
    let removeAction: () -> Void

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                AppBoxGlyph(icon: .calendarClock)
                    .frame(width: 19, height: 19)
                    .foregroundColor(palette.accent)
                    .frame(width: 42, height: 42)
                    .background(palette.accentSoft)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

                VStack(alignment: .leading, spacing: 4) {
                    Text(rule.name)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                    Text(timeRange)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                }

                Spacer()

                Toggle("", isOn: Binding(get: { rule.isEnabled }, set: { _ in toggleAction() }))
                    .labelsHidden()
                    .tint(palette.accent)
            }

            HStack(spacing: 10) {
                Text(isActive ? copy.text("当前时段", "Active now") : copy.text("未触发", "Idle"))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isActive ? Color(uiColor: .systemGreen) : palette.secondaryText)
                    .padding(.horizontal, 10)
                    .frame(height: 26)
                    .background((isActive ? Color(uiColor: .systemGreen).opacity(0.12) : palette.mutedSurface.opacity(0.75)))
                    .clipShape(Capsule())

                Spacer()

                Button(action: runAction) {
                    Text(copy.text("立即启用", "Run Now"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(palette.accent)
                        .frame(height: 30)
                }
                .buttonStyle(.plain)

                Button(role: .destructive, action: removeAction) {
                    Text(copy.text("删除", "Delete"))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(palette.destructive)
                        .frame(height: 30)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .appBoxLiquidCard(palette, radius: 20)
    }

    private var timeRange: String {
        "\(format(rule.startHour, rule.startMinute)) - \(format(rule.endHour, rule.endMinute))"
    }

    private func format(_ hour: Int, _ minute: Int) -> String {
        String(format: "%02d:%02d", hour, minute)
    }
}

private struct AppBoxPlaceEditorSheet: View {
    let language: AppBoxLanguage
    let palette: AppBoxPalette
    let authorizationStatus: CLAuthorizationStatus
    let currentLocation: CLLocation?
    let isRequestingLocation: Bool
    let locationError: String?
    let requestLocationAction: () -> Void
    let requestAlwaysAuthorizationAction: () -> Void
    let addAction: (String, AppBoxPlaceRule.Trigger, CLLocationCoordinate2D, Double) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var trigger: AppBoxPlaceRule.Trigger = .leave
    @State private var radiusMeters = 200.0

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }

    var body: some View {
        ZStack {
            AppBoxFocusBackground(palette: palette)

            VStack(spacing: 18) {
                AppBoxSheetHeader(
                    title: copy.text("新建地点", "New Place"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.text("地点名称", "Place Name"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(palette.primaryText)

                    TextField(copy.text("例如：公司、学校、家", "Work, school, home"), text: $name)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .appBoxGlassControl(palette, radius: 14)

                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 12) {
                            AppBoxGlyph(icon: .locationArrow)
                                .frame(width: 17, height: 17)
                                .foregroundColor(palette.accent)
                                .frame(width: 36, height: 36)
                                .background(palette.accentSoft)
                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                            VStack(alignment: .leading, spacing: 3) {
                                Text(locationTitle)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(palette.primaryText)
                                Text(locationDetail)
                                    .font(.system(size: 12, weight: .medium))
                                    .foregroundColor(palette.secondaryText)
                                    .lineLimit(2)
                            }

                            Spacer()
                        }

                        HStack(spacing: 10) {
                            Button(action: requestLocationAction) {
                                Text(isRequestingLocation ? copy.text("定位中", "Locating") : copy.text("获取当前位置", "Use Current Location"))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 36)
                                    .background(palette.accent)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                            .disabled(isRequestingLocation)

                            if authorizationStatus != .authorizedAlways {
                                Button(action: requestAlwaysAuthorizationAction) {
                                    Text(copy.text("始终允许", "Always"))
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(palette.accent)
                                        .frame(width: 82)
                                        .frame(height: 36)
                                        .background(palette.accentSoft.opacity(0.82))
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        if let locationError, !locationError.isEmpty {
                            Text(locationError)
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(palette.destructive)
                        }
                    }
                    .padding(12)
                    .appBoxGlassControl(palette, radius: 16, isInteractive: false)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(copy.text("触发半径", "Radius"))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(palette.primaryText)
                            Spacer()
                            Text("\(Int(radiusMeters.rounded()))m")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(palette.secondaryText)
                        }
                        Slider(value: $radiusMeters, in: 100...1000, step: 50)
                            .tint(palette.accent)
                    }

                    Text(copy.text("触发方式", "Trigger"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(palette.primaryText)
                        .padding(.top, 4)

                    Picker("", selection: $trigger) {
                        Text(copy.text("离开时", "When Leaving")).tag(AppBoxPlaceRule.Trigger.leave)
                        Text(copy.text("到达时", "When Arriving")).tag(AppBoxPlaceRule.Trigger.arrive)
                    }
                    .pickerStyle(.segmented)

                    Text(copy.text("保存后会注册系统地点围栏。后台自动触发需要定位权限为“始终允许”。", "Saving registers a system geofence. Background triggers require Always location access."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .appBoxLiquidCard(palette, radius: 20)

                Button {
                    guard let coordinate = currentLocation?.coordinate else { return }
                    addAction(name, trigger, coordinate, radiusMeters)
                } label: {
                    Text(copy.text("保存地点", "Save Place"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(currentLocation == nil ? palette.secondaryText.opacity(0.40) : palette.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .disabled(currentLocation == nil)
                .padding(.horizontal, AppBoxLayout.pagePadding)

                Spacer()
            }
            .padding(.top, 12)
        }
    }

    private var locationTitle: String {
        if currentLocation != nil {
            return copy.text("已获取当前位置", "Current location ready")
        }
        if isRequestingLocation {
            return copy.text("正在定位", "Locating")
        }
        return copy.text("选择当前位置", "Choose current location")
    }

    private var locationDetail: String {
        if let currentLocation {
            let coordinate = currentLocation.coordinate
            return String(
                format: copy.text("精度 %.0fm • %.5f, %.5f", "%.0fm accuracy • %.5f, %.5f"),
                max(0, currentLocation.horizontalAccuracy),
                coordinate.latitude,
                coordinate.longitude
            )
        }

        switch authorizationStatus {
        case .authorizedAlways:
            return copy.text("点击获取当前位置。", "Tap to fetch your current location.")
        case .authorizedWhenInUse:
            return copy.text("可创建地点；后台触发仍需始终允许。", "You can create a place; background triggers still need Always access.")
        case .notDetermined:
            return copy.text("点击后会请求定位权限。", "Tap to request location permission.")
        case .denied, .restricted:
            return copy.text("定位权限被拒绝，请前往系统设置开启。", "Location permission is denied. Enable it in Settings.")
        @unknown default:
            return copy.text("定位状态不可用。", "Location status unavailable.")
        }
    }
}

private struct AppBoxScheduleEditorSheet: View {
    let language: AppBoxLanguage
    let palette: AppBoxPalette
    let addAction: (String, Int, Int, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var startDate = Date()
    @State private var endDate = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }

    var body: some View {
        ZStack {
            AppBoxFocusBackground(palette: palette)

            VStack(spacing: 18) {
                AppBoxSheetHeader(
                    title: copy.text("新建日程", "New Schedule"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                VStack(alignment: .leading, spacing: 12) {
                    Text(copy.text("日程名称", "Schedule Name"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(palette.primaryText)

                    TextField(copy.text("例如：工作时间", "Work hours"), text: $name)
                        .textInputAutocapitalization(.never)
                        .disableAutocorrection(true)
                        .font(.system(size: 15, weight: .medium))
                        .padding(.horizontal, 12)
                        .frame(height: 46)
                        .appBoxGlassControl(palette, radius: 14)

                    HStack(spacing: 12) {
                        timePicker(title: copy.text("开始", "Start"), date: $startDate)
                        timePicker(title: copy.text("结束", "End"), date: $endDate)
                    }

                    Text(copy.text("保存后日程默认启用；当应用运行且到达该时段时会自动隐藏选定应用。", "Saved schedules are enabled by default and apply while the app is running."))
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(palette.secondaryText)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(16)
                .appBoxLiquidCard(palette, radius: 20)

                Button {
                    let start = Calendar.current.dateComponents([.hour, .minute], from: startDate)
                    let end = Calendar.current.dateComponents([.hour, .minute], from: endDate)
                    addAction(
                        name,
                        start.hour ?? 0,
                        start.minute ?? 0,
                        end.hour ?? 0,
                        end.minute ?? 0
                    )
                } label: {
                    Text(copy.text("保存日程", "Save Schedule"))
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(palette.accent)
                        .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .padding(.horizontal, AppBoxLayout.pagePadding)

                Spacer()
            }
            .padding(.top, 12)
        }
    }

    private func timePicker(title: String, date: Binding<Date>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(palette.secondaryText)
            DatePicker("", selection: date, displayedComponents: .hourAndMinute)
                .labelsHidden()
                .datePickerStyle(.compact)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .appBoxGlassControl(palette, radius: 14)
    }
}
