import Combine
import CoreLocation
import FamilyControls
import ManagedSettings
import SwiftUI
import UIKit

private enum QuietformTab: String, CaseIterable, Identifiable {
  case apps
  case places
  case schedule
  case settings

  var id: String { rawValue }
}

struct AppBoxPrivacySurfaceView: View {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var visibility = AppBoxVisibilityService()
  @StateObject private var automation = AppBoxFocusAutomationStore()
  @StateObject private var geofence = AppBoxGeofenceMonitor.shared
  @AppStorage("Quietform.prefersDarkMode") private var prefersDarkMode = false
  @AppStorage("Quietform.usesEnglish") private var usesEnglish = false

  @State private var selectedTab: QuietformTab
  @State private var activeAutomationID: String?
  @State private var isPickerPresented = false
  @State private var isPlaceEditorPresented = false
  @State private var isScheduleEditorPresented = false
  @State private var isSharePresented = false
  @State private var isWorking = false
  @State private var scheduleClock = Date()

  private let onInternalUnlock: () -> Void
  private let scheduleTimer = Timer.publish(every: 30, on: .main, in: .common).autoconnect()

#if APPBOX_INTERNAL_UNLOCK
  @State private var internalTapCount = 0
  @State private var internalTapDeadline = Date.distantPast
  @State private var isInternalPromptPresented = false
  @State private var internalCode = ""
  @State private var isInternalUnlocking = false
  @State private var internalUnlockError = ""
  @State private var isInternalErrorPresented = false
#endif

  init(onInternalUnlock: @escaping () -> Void = {}) {
    self.onInternalUnlock = onInternalUnlock
    _selectedTab = State(initialValue: Self.initialTab())
  }

  var body: some View {
    TabView(selection: $selectedTab) {
      surfacePage(.apps)
        .tag(QuietformTab.apps)
        .tabItem {
          Label(tabTitle(.apps), systemImage: tabSystemIcon(.apps))
        }

      surfacePage(.places)
        .tag(QuietformTab.places)
        .tabItem {
          Label(tabTitle(.places), systemImage: tabSystemIcon(.places))
        }

      surfacePage(.schedule)
        .tag(QuietformTab.schedule)
        .tabItem {
          Label(tabTitle(.schedule), systemImage: tabSystemIcon(.schedule))
        }

      surfacePage(.settings)
        .tag(QuietformTab.settings)
        .tabItem {
          Label(tabTitle(.settings), systemImage: tabSystemIcon(.settings))
        }
    }
    .tint(accent)
    .animation(.snappy(duration: 0.28), value: visibility.hasSelection)
    .animation(.snappy(duration: 0.28), value: visibility.isHidden)
    .sensoryFeedback(.success, trigger: visibility.isHidden)
    .environment(\.colorScheme, prefersDarkMode ? .dark : .light)
    .familyActivityPicker(isPresented: $isPickerPresented, selection: $visibility.selection)
    .sheet(isPresented: $isPlaceEditorPresented) {
      QuietformPlaceEditor(
        usesEnglish: usesEnglish,
        authorizationStatus: geofence.authorizationStatus,
        currentLocation: geofence.currentLocation,
        isRequestingLocation: geofence.isRequestingLocation,
        locationError: geofence.lastError,
        requestLocation: geofence.requestCurrentLocation,
        requestAlwaysAuthorization: requestLocationAccess,
        save: { name, trigger, coordinate, radius in
          automation.addPlaceRule(
            name: name,
            trigger: trigger,
            coordinate: coordinate,
            radiusMeters: radius
          )
          isPlaceEditorPresented = false
        }
      )
      .environment(\.colorScheme, prefersDarkMode ? .dark : .light)
    }
    .sheet(isPresented: $isScheduleEditorPresented) {
      QuietformScheduleEditor(usesEnglish: usesEnglish) { name, start, end in
        let calendar = Calendar.current
        let startParts = calendar.dateComponents([.hour, .minute], from: start)
        let endParts = calendar.dateComponents([.hour, .minute], from: end)
        automation.addScheduleRule(
          name: name,
          startHour: startParts.hour ?? 0,
          startMinute: startParts.minute ?? 0,
          endHour: endParts.hour ?? 0,
          endMinute: endParts.minute ?? 0
        )
        isScheduleEditorPresented = false
        enforceScheduleIfNeeded()
      }
      .environment(\.colorScheme, prefersDarkMode ? .dark : .light)
    }
    .sheet(isPresented: $isSharePresented) {
      QuietformShareSheet(items: [copy("Quietform，让重要的事更专注。", "Quietform, keep what matters in focus.")])
    }
    .onAppear {
      geofence.onRuleTriggered = handlePlaceRuleTriggered
      geofence.synchronize(rules: automation.placeRules)
      enforceScheduleIfNeeded()
    }
    .onChange(of: automation.placeRules) { rules in
      geofence.synchronize(rules: rules)
    }
    .onChange(of: geofence.authorizationStatus) { _ in
      geofence.synchronize(rules: automation.placeRules)
    }
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        visibility.refreshAuthorizationStatus()
        geofence.synchronize(rules: automation.placeRules)
        enforceScheduleIfNeeded()
      }
    }
    .onReceive(scheduleTimer) { date in
      scheduleClock = date
      enforceScheduleIfNeeded(at: date)
    }
#if APPBOX_INTERNAL_UNLOCK
    .alert(copy("输入验证码", "Enter verification code"), isPresented: $isInternalPromptPresented) {
      TextField(copy("请输入验证码", "Verification code"), text: $internalCode)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
      Button(copy("取消", "Cancel"), role: .cancel) {
        internalCode = ""
      }
      Button(copy("验证", "Verify")) {
        redeemInternalCode()
      }
      .disabled(internalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    } message: {
      Text(copy("请输入验证码完成验证。", "Enter the code to complete verification."))
    }
    .alert(copy("验证失败", "Verification failed"), isPresented: $isInternalErrorPresented) {
      Button(copy("知道了", "OK"), role: .cancel) {}
    } message: {
      Text(internalUnlockError)
    }
    .overlay {
      if isInternalUnlocking {
        ZStack {
          Color.black.opacity(0.18).ignoresSafeArea()
          ProgressView(copy("正在验证…", "Verifying…"))
            .font(.system(size: 14, weight: .semibold))
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
      }
    }
#endif
  }

  private func surfacePage(_ tab: QuietformTab) -> some View {
    ZStack {
      background

      VStack(spacing: 0) {
        pageHeader(for: tab)
        tabContent(for: tab)
      }
    }
  }

  private var background: some View {
    ZStack {
      Color(uiColor: .systemGroupedBackground)

      LinearGradient(
        colors: backgroundGradientColors,
        startPoint: .top,
        endPoint: .bottom
      )

      Circle()
        .fill(Color(red: 0.12, green: 0.58, blue: 1.00).opacity(0.18))
        .frame(width: 300, height: 300)
        .blur(radius: 72)
        .offset(x: 165, y: -250)

      Capsule()
        .fill(
          LinearGradient(
            colors: [accent.opacity(0.18), Color.cyan.opacity(0.13)],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .frame(width: 390, height: 150)
        .blur(radius: 54)
        .offset(x: -70, y: 430)
    }
    .ignoresSafeArea()
  }

  private func pageHeader(for tab: QuietformTab) -> some View {
    HStack(spacing: 12) {
      VStack(alignment: .leading, spacing: tab == .apps ? 4 : 0) {
        Text(tabTitle(tab))
          .font(.system(size: 26, weight: .bold, design: .rounded))
          .foregroundColor(.primary)
        if tab == .apps {
          Text(copy("把重要的留在眼前，把干扰轻轻收起", "Keep what matters close and distractions out of sight"))
            .font(.system(size: 12.5, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.82)
        }
      }

      Spacer(minLength: 8)
    }
    .padding(.horizontal, 20)
    .padding(.top, 14)
    .padding(.bottom, 8)
  }

  @ViewBuilder
  private func tabContent(for tab: QuietformTab) -> some View {
    ScrollView(showsIndicators: false) {
      VStack(spacing: 16) {
        switch tab {
        case .apps:
          appsPage
        case .places:
          placesPage
        case .schedule:
          schedulePage
        case .settings:
          settingsPage
        }
      }
      .padding(.horizontal, 20)
      .padding(.top, 8)
      .padding(.bottom, 28)
    }
    .scrollBounceBehavior(.basedOnSize)
  }

  private var appsPage: some View {
    VStack(spacing: 14) {
      protectionControlCard
      selectedItemsCard

      if let error = visibility.lastError, !error.isEmpty {
        Label(error, systemImage: "exclamationmark.circle.fill")
          .font(.system(size: 12.5, weight: .medium))
          .foregroundColor(.red)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 4)
      }
    }
  }

  private var placesPage: some View {
    VStack(spacing: 14) {
      if automation.placeRules.isEmpty {
        emptyState(
          asset: "QuietformIconPlaces",
          title: copy("尚未创建地点规则", "No place rules yet"),
          message: copy("到达或离开指定地点时，自动隐藏已选项目。", "Automatically hide selected items when arriving at or leaving a place."),
          actionTitle: locationActionTitle,
          action: locationPrimaryAction
        )
      } else {
        placeRulesCard
      }

      if !automation.placeRules.isEmpty && !geofence.isAlwaysAuthorized {
        permissionCard
      }
    }
  }

  private var schedulePage: some View {
    VStack(spacing: 14) {
      if automation.scheduleRules.isEmpty {
        emptyState(
          asset: "QuietformIconSchedule",
          title: copy("尚未创建日程", "No schedules yet"),
          message: copy("在每天的指定时段，自动隐藏已选项目。", "Automatically hide selected items during selected hours."),
          actionTitle: copy("新建日程", "New schedule"),
          action: { isScheduleEditorPresented = true }
        )
      } else {
        scheduleRulesCard
      }
    }
  }

  private var settingsPage: some View {
    VStack(spacing: 14) {
      VStack(spacing: 0) {
        settingsToggleRow(
          asset: "QuietformIconAppearance",
          title: copy("深色外观", "Dark appearance"),
          isOn: $prefersDarkMode
        )
        divider
        settingsToggleRow(
          asset: "QuietformIconLanguage",
          title: copy("English", "中文"),
          isOn: $usesEnglish
        )
        divider
        settingsButtonRow(
          asset: "QuietformIconShare",
          title: copy("分享 Quietform", "Share Quietform"),
          detail: ""
        ) {
          isSharePresented = true
        }
      }
      .quietformCard()

      VStack(spacing: 0) {
        settingsButtonRow(
          asset: "QuietformIconPrivacy",
          title: copy("隐私保护", "Privacy"),
          detail: copy("选择内容仅保存在本机", "Selections stay on this device"),
          action: nil
        )
        divider
        versionRow
      }
      .quietformCard()
    }
  }

  private var protectionControlCard: some View {
    HStack(spacing: 14) {
      QuietformAssetIcon(
        name: visibility.isHidden ? "QuietformIconFocus" : "QuietformIconPrivacy",
        size: 32
      )
      .frame(width: 36)

      VStack(alignment: .leading, spacing: 4) {
        Text(visibility.isHidden
          ? copy("隐藏保护已开启", "Hidden protection is on")
          : copy("隐藏保护未开启", "Hidden protection is off"))
          .font(.system(size: 17, weight: .bold))
          .foregroundColor(.primary)

        Text(protectionStatusDetail)
          .font(.system(size: 12.5, weight: .medium))
          .foregroundColor(.secondary)
          .lineLimit(2)
      }

      Spacer(minLength: 6)

      if isWorking {
        ProgressView()
          .controlSize(.regular)
          .frame(width: 51)
      } else {
        Toggle("", isOn: visibilityToggleBinding)
          .labelsHidden()
          .tint(accent)
          .disabled(isWorking)
          .accessibilityLabel(copy("隐藏保护", "Hidden protection"))
      }
    }
    .padding(18)
    .quietformCard()
  }

  @ViewBuilder
  private var selectedItemsCard: some View {
    if visibility.hasSelection {
      VStack(spacing: 0) {
        HStack(spacing: 9) {
          Text(visibility.isHidden ? copy("当前隐藏", "Currently hidden") : copy("已选择", "Selected"))
            .font(.system(size: 16, weight: .bold))

          Text(copy("\(selectedItemCount) 项", "\(selectedItemCount) items"))
            .font(.system(size: 11.5, weight: .bold, design: .rounded))
            .foregroundStyle(visibility.isHidden ? Color.green : accent)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background((visibility.isHidden ? Color.green : accent).opacity(0.11))
            .clipShape(Capsule())

          Spacer(minLength: 6)

          Button(action: chooseApps) {
            Label(copy("编辑", "Edit"), systemImage: "pencil")
              .font(.system(size: 12.5, weight: .semibold))
              .padding(.horizontal, 2)
          }
          .buttonStyle(.glass)
          .buttonBorderShape(.capsule)
          .tint(accent)
          .disabled(isWorking)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)

        Divider().padding(.leading, 16)

        ForEach(selectedApplicationTokens, id: \.self) { token in
          selectedTokenRow {
            Label(token)
          }
        }

        ForEach(selectedCategoryTokens, id: \.self) { token in
          selectedTokenRow {
            Label(token)
          }
        }

        ForEach(selectedWebDomainTokens, id: \.self) { token in
          selectedTokenRow {
            Label(token)
          }
        }
      }
      .quietformCard()
    } else {
      VStack(spacing: 14) {
        HStack(spacing: 13) {
          QuietformAssetIcon(name: "QuietformIconApps", size: 27)
            .frame(width: 46, height: 46)
            .background(accent.opacity(0.09))
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))

          VStack(alignment: .leading, spacing: 4) {
            Text(copy("尚未选择 App", "No apps selected"))
              .font(.system(size: 16, weight: .bold))
              .foregroundColor(.primary)
            Text(copy("选择后会在这里显示名称和图标", "Names and icons will appear here after selection"))
              .font(.system(size: 12.5, weight: .medium))
              .foregroundColor(.secondary)
          }

          Spacer(minLength: 0)
        }

        Button(action: chooseApps) {
          Label(copy("选择需要隐藏的 App", "Choose apps to hide"), systemImage: "plus")
            .font(.system(size: 15.5, weight: .bold))
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
        }
        .buttonStyle(.glassProminent)
        .buttonBorderShape(.roundedRectangle(radius: 16))
        .tint(accent)
        .disabled(isWorking)
      }
      .padding(16)
      .quietformCard()
    }
  }

  private var permissionCard: some View {
    Button(action: requestLocationAccess) {
      HStack(spacing: 12) {
        QuietformAssetIcon(name: "QuietformIconPlaces", size: 27)
          .frame(width: 32)
        VStack(alignment: .leading, spacing: 3) {
          Text(copy("定位权限", "Location access"))
            .font(.system(size: 14.5, weight: .semibold))
            .foregroundColor(.primary)
          Text(locationPermissionDetail)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.secondary)
      }
      .padding(14)
      .quietformCard()
    }
    .buttonStyle(.plain)
  }

  private var divider: some View {
    Divider().padding(.leading, 58)
  }

  @ViewBuilder
  private var versionRow: some View {
    let row = HStack(spacing: 12) {
      QuietformAssetIcon(name: "QuietformIconVersion", size: 21)
        .frame(width: 34, height: 34)
        .background(accent.opacity(0.10))
        .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
      Text(copy("版本", "Version"))
        .font(.system(size: 14.5, weight: .medium))
      Spacer()
      Text(versionLabel)
        .font(.system(size: 12.5, weight: .medium, design: .rounded))
        .foregroundColor(.secondary)
    }
    .padding(.horizontal, 12)
    .frame(height: 56)
    .contentShape(Rectangle())

#if APPBOX_INTERNAL_UNLOCK
    row.onTapGesture(perform: registerInternalTap)
#else
    row
#endif
  }

  private func emptyState(
    asset: String,
    title: String,
    message: String,
    actionTitle: String,
    action: @escaping () -> Void
  ) -> some View {
    VStack(spacing: 13) {
      HStack(spacing: 13) {
        QuietformAssetIcon(name: asset, size: 34)
          .frame(width: 40)

        VStack(alignment: .leading, spacing: 4) {
          Text(title)
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(.primary)
          Text(message)
            .font(.system(size: 12.5, weight: .medium))
            .foregroundColor(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)
      }

      Button(action: action) {
        Label(actionTitle, systemImage: "plus")
          .font(.system(size: 14.5, weight: .semibold))
          .foregroundColor(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 40)
      }
      .buttonStyle(.glassProminent)
      .buttonBorderShape(.roundedRectangle(radius: 14))
      .tint(accent)
      .frame(minHeight: 44)
      .contentShape(Rectangle())
    }
    .frame(maxWidth: .infinity)
    .padding(.horizontal, 18)
    .padding(.vertical, 16)
    .quietformCard()
  }

  private var placeRulesCard: some View {
    VStack(spacing: 0) {
      rulesHeader(
        title: copy("地点规则", "Place rules"),
        count: automation.placeRules.count,
        action: locationPrimaryAction
      )

      Divider().padding(.leading, 16)

      ForEach(Array(automation.placeRules.enumerated()), id: \.element.id) { index, rule in
        placeRuleRow(rule)
        if index < automation.placeRules.count - 1 {
          Divider().padding(.leading, 60)
        }
      }
    }
    .quietformCard()
  }

  private var scheduleRulesCard: some View {
    VStack(spacing: 0) {
      rulesHeader(
        title: copy("日程规则", "Schedules"),
        count: automation.scheduleRules.count,
        action: { isScheduleEditorPresented = true }
      )

      Divider().padding(.leading, 16)

      ForEach(Array(automation.scheduleRules.enumerated()), id: \.element.id) { index, rule in
        scheduleRuleRow(rule)
        if index < automation.scheduleRules.count - 1 {
          Divider().padding(.leading, 60)
        }
      }
    }
    .quietformCard()
  }

  private func rulesHeader(
    title: String,
    count: Int,
    action: @escaping () -> Void
  ) -> some View {
    HStack(spacing: 9) {
      Text(title)
        .font(.system(size: 16, weight: .bold))

      Text(copy("\(count) 项", "\(count) items"))
        .font(.system(size: 11.5, weight: .bold, design: .rounded))
        .foregroundStyle(accent)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(accent.opacity(0.11))
        .clipShape(Capsule())

      Spacer(minLength: 6)

      Button(action: action) {
        Label(copy("新增", "Add"), systemImage: "plus")
          .font(.system(size: 12.5, weight: .semibold))
          .padding(.horizontal, 2)
      }
      .buttonStyle(.glass)
      .buttonBorderShape(.capsule)
      .tint(accent)
    }
    .padding(.horizontal, 16)
    .padding(.vertical, 14)
  }

  private func placeRuleRow(_ rule: AppBoxPlaceRule) -> some View {
    let isMonitored = rule.isEnabled && geofence.monitoredRuleIDs.contains(rule.id)
    let status = !rule.isEnabled
      ? copy("已关闭", "Off")
      : isMonitored
        ? copy("监听中", "Monitoring")
        : copy("等待定位", "Waiting for location")
    let statusColor: Color = !rule.isEnabled ? .secondary : (isMonitored ? .green : .orange)
    let trigger = rule.trigger == .arrive
      ? copy("到达时", "On arrival")
      : copy("离开时", "On departure")

    return HStack(spacing: 11) {
      QuietformAssetIcon(name: "QuietformIconPlaces", size: 28)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 4) {
        Text(rule.name)
          .font(.system(size: 15.5, weight: .semibold))
          .lineLimit(1)

        HStack(spacing: 5) {
          Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6)
          Text("\(status) · \(trigger) · \(Int(rule.radiusMeters))m")
            .font(.system(size: 11.5, weight: .medium))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
        }
      }

      Spacer(minLength: 4)

      Menu {
        Button(role: .destructive) {
          automation.removePlaceRule(rule)
        } label: {
          Label(copy("删除", "Delete"), systemImage: "trash")
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 40)
      }

      Toggle("", isOn: Binding(
        get: { rule.isEnabled },
        set: { _ in automation.togglePlaceRule(rule) }
      ))
      .labelsHidden()
      .tint(accent)
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 70)
  }

  private func scheduleRuleRow(_ rule: AppBoxScheduleRule) -> some View {
    let isActive = rule.isEnabled && rule.contains(scheduleClock)
    let status = !rule.isEnabled
      ? copy("已关闭", "Off")
      : isActive
        ? copy("正在运行", "Active now")
        : copy("等待时段", "Waiting")
    let statusColor: Color = !rule.isEnabled ? .secondary : (isActive ? .green : accent)
    let time = String(format: "%02d:%02d–%02d:%02d", rule.startHour, rule.startMinute, rule.endHour, rule.endMinute)

    return HStack(spacing: 11) {
      QuietformAssetIcon(name: "QuietformIconSchedule", size: 28)
        .frame(width: 32)

      VStack(alignment: .leading, spacing: 4) {
        Text(rule.name)
          .font(.system(size: 15.5, weight: .semibold))
          .lineLimit(1)

        HStack(spacing: 5) {
          Circle()
            .fill(statusColor)
            .frame(width: 6, height: 6)
          Text("\(status) · \(time)")
            .font(.system(size: 11.5, weight: .medium, design: .rounded))
            .foregroundColor(.secondary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
        }
      }

      Spacer(minLength: 4)

      Menu {
        Button {
          activeAutomationID = rule.id
          Task { await visibility.hideSelection() }
        } label: {
          Label(copy("立即启用", "Run now"), systemImage: "play.fill")
        }
        .disabled(!visibility.hasSelection)

        Button(role: .destructive) {
          if activeAutomationID == rule.id {
            visibility.restoreAll()
            activeAutomationID = nil
          }
          automation.removeScheduleRule(rule)
        } label: {
          Label(copy("删除", "Delete"), systemImage: "trash")
        }
      } label: {
        Image(systemName: "ellipsis")
          .font(.system(size: 15, weight: .bold))
          .foregroundStyle(.secondary)
          .frame(width: 28, height: 40)
      }

      Toggle("", isOn: Binding(
        get: { rule.isEnabled },
        set: { _ in
          automation.toggleScheduleRule(rule)
          enforceScheduleIfNeeded()
        }
      ))
      .labelsHidden()
      .tint(accent)
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 70)
  }

  private func settingsToggleRow(
    asset: String,
    title: String,
    isOn: Binding<Bool>
  ) -> some View {
    HStack(spacing: 12) {
      settingsIcon(asset)
      Text(title).font(.system(size: 14.5, weight: .medium))
      Spacer()
      Toggle("", isOn: isOn).labelsHidden().tint(accent)
    }
    .padding(.horizontal, 12)
    .frame(height: 56)
  }

  @ViewBuilder
  private func settingsButtonRow(
    asset: String,
    title: String,
    detail: String,
    action: (() -> Void)?
  ) -> some View {
    if let action {
      Button(action: action) {
        settingsRowContent(asset: asset, title: title, detail: detail, showsChevron: true)
      }
      .buttonStyle(.plain)
    } else {
      settingsRowContent(asset: asset, title: title, detail: detail, showsChevron: false)
    }
  }

  private func settingsRowContent(
    asset: String,
    title: String,
    detail: String,
    showsChevron: Bool
  ) -> some View {
    HStack(spacing: 12) {
      settingsIcon(asset)
      Text(title)
        .font(.system(size: 14.5, weight: .medium))
        .foregroundColor(.primary)
      Spacer()
      if !detail.isEmpty {
        Text(detail)
          .font(.system(size: 11.5, weight: .medium))
          .foregroundColor(.secondary)
          .lineLimit(1)
          .minimumScaleFactor(0.7)
      }
      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.system(size: 12, weight: .bold))
          .foregroundColor(.secondary)
      }
    }
    .padding(.horizontal, 12)
    .frame(height: 56)
    .contentShape(Rectangle())
  }

  private func settingsIcon(_ asset: String) -> some View {
    QuietformAssetIcon(name: asset, size: 21)
      .frame(width: 34, height: 34)
      .background(accent.opacity(0.10))
      .clipShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
  }

  private func selectedTokenRow<Content: View>(@ViewBuilder label: () -> Content) -> some View {
    HStack(spacing: 12) {
      label()
        .font(.system(size: 15, weight: .semibold))
        .foregroundStyle(.primary)
        .lineLimit(1)

      Spacer(minLength: 8)

      Circle()
        .fill(visibility.isHidden ? Color.green : Color.secondary.opacity(0.30))
        .frame(width: 8, height: 8)
        .accessibilityHidden(true)
    }
    .padding(.horizontal, 16)
    .frame(minHeight: 58)
    .overlay(alignment: .bottom) {
      Divider().padding(.leading, 42)
    }
  }

  private var accent: Color { Color(red: 0.12, green: 0.48, blue: 0.96) }

  private var backgroundGradientColors: [Color] {
    if prefersDarkMode {
      return [
        Color(uiColor: .systemBackground).opacity(0.98),
        accent.opacity(0.12),
        Color(uiColor: .systemGroupedBackground).opacity(0.96),
      ]
    }
    return [
      Color(uiColor: .systemBackground).opacity(0.98),
      Color(red: 0.91, green: 0.96, blue: 1.00).opacity(0.72),
      Color(uiColor: .systemGroupedBackground).opacity(0.94),
    ]
  }

  private func copy(_ chinese: String, _ english: String) -> String {
    usesEnglish ? english : chinese
  }

  private func tabTitle(_ tab: QuietformTab) -> String {
    switch tab {
    case .apps: return copy("应用", "Apps")
    case .places: return copy("地点", "Places")
    case .schedule: return copy("日程", "Schedule")
    case .settings: return copy("设置", "Settings")
    }
  }

  private func tabSystemIcon(_ tab: QuietformTab) -> String {
    switch tab {
    case .apps: return "square.grid.2x2.fill"
    case .places: return "location.fill"
    case .schedule: return "calendar"
    case .settings: return "gearshape.fill"
    }
  }

  private var versionLabel: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    return "\(version) (\(build))"
  }

  private var selectedItemCount: Int {
    visibility.selectedApplicationCount + visibility.selectedCategoryCount + visibility.selectedWebDomainCount
  }

  private var selectedApplicationTokens: [ManagedSettings.ApplicationToken] {
    Array(visibility.selection.applicationTokens)
  }

  private var selectedCategoryTokens: [ManagedSettings.ActivityCategoryToken] {
    Array(visibility.selection.categoryTokens)
  }

  private var selectedWebDomainTokens: [ManagedSettings.WebDomainToken] {
    Array(visibility.selection.webDomainTokens)
  }

  private var protectionStatusDetail: String {
    if isWorking {
      return copy("正在更新隐藏状态…", "Updating hidden status…")
    }
    if visibility.isHidden {
      return copy("\(selectedItemCount) 个项目正在隐藏", "\(selectedItemCount) items are hidden")
    }
    if visibility.hasSelection {
      return copy("已选择 \(selectedItemCount) 个项目", "\(selectedItemCount) items selected")
    }
    return visibility.isAuthorized
      ? copy("选择需要隐藏的 App", "Choose apps to hide")
      : copy("首次选择时需要系统授权", "System access is requested on first selection")
  }

  private var locationActionTitle: String {
    geofence.isAlwaysAuthorized ? copy("新建地点", "New place") : copy("允许定位", "Allow location")
  }

  private var locationPermissionDetail: String {
    switch geofence.authorizationStatus {
    case .authorizedAlways:
      return copy("后台地点触发已可用", "Background triggers are available")
    case .authorizedWhenInUse:
      return copy("需要升级为“始终允许”", "Upgrade access to Always")
    case .notDetermined:
      return copy("允许后可创建地点规则", "Allow access to create place rules")
    case .denied, .restricted:
      return copy("前往系统设置调整", "Open system settings")
    @unknown default:
      return copy("定位状态不可用", "Location status unavailable")
    }
  }

  private func locationPrimaryAction() {
    if geofence.isAlwaysAuthorized {
      isPlaceEditorPresented = true
    } else {
      requestLocationAccess()
    }
  }

  private func requestLocationAccess() {
    if geofence.canRequestAuthorization {
      geofence.requestAlwaysAuthorization()
      return
    }
    guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
    UIApplication.shared.open(url)
  }

  private func chooseApps() {
    Task {
      if await visibility.requestAuthorizationIfNeeded() {
        isPickerPresented = true
      }
    }
  }

  private var visibilityToggleBinding: Binding<Bool> {
    Binding(
      get: { visibility.isHidden },
      set: { setVisibility($0) }
    )
  }

  private func setVisibility(_ shouldHide: Bool) {
    if !shouldHide {
      visibility.restoreAll()
      activeAutomationID = nil
      return
    }

    guard visibility.hasSelection else {
      chooseApps()
      return
    }

    isWorking = true
    Task {
      await visibility.hideSelection()
      isWorking = false
    }
  }

  private func handlePlaceRuleTriggered(_ rule: AppBoxPlaceRule) {
    guard visibility.hasSelection,
          automation.placeRules.contains(where: { $0.id == rule.id && $0.isEnabled }) else { return }
    activeAutomationID = rule.id
    automation.markPlaceRuleTriggered(rule)
    Task { await visibility.hideSelection() }
  }

  private func enforceScheduleIfNeeded(at date: Date = Date()) {
    guard let activeRule = automation.activeSchedule(at: date) else {
      if let activeAutomationID,
         automation.scheduleRules.contains(where: { $0.id == activeAutomationID }) {
        visibility.restoreAll()
        self.activeAutomationID = nil
      }
      return
    }

    guard visibility.hasSelection else { return }
    guard activeAutomationID != activeRule.id || !visibility.isHidden else { return }
    activeAutomationID = activeRule.id
    Task { await visibility.hideSelection() }
  }

  private static func initialTab(arguments: [String] = ProcessInfo.processInfo.arguments) -> QuietformTab {
    guard let argument = arguments.first(where: { $0.hasPrefix("--appbox-a-tab=") }),
          let value = argument.split(separator: "=", maxSplits: 1).last,
          let tab = QuietformTab(rawValue: String(value)) else {
      return .apps
    }
    return tab
  }

#if APPBOX_INTERNAL_UNLOCK
  private func registerInternalTap() {
    let now = Date()
    if now > internalTapDeadline { internalTapCount = 0 }
    internalTapCount += 1
    internalTapDeadline = now.addingTimeInterval(5)
    guard internalTapCount >= 7 else { return }

    internalTapCount = 0
    internalTapDeadline = .distantPast
    internalCode = ""
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    isInternalPromptPresented = true
  }

  private func redeemInternalCode() {
    let code = internalCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !code.isEmpty, !isInternalUnlocking else { return }
    internalCode = ""
    isInternalUnlocking = true
    Task {
      do {
        try await AppBoxInternalUnlockService().redeem(code: code)
        isInternalUnlocking = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onInternalUnlock()
      } catch {
        isInternalUnlocking = false
        internalUnlockError = error.localizedDescription
        isInternalErrorPresented = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
      }
    }
  }
#endif
}

private struct QuietformPlaceEditor: View {
  @Environment(\.dismiss) private var dismiss
  let usesEnglish: Bool
  let authorizationStatus: CLAuthorizationStatus
  let currentLocation: CLLocation?
  let isRequestingLocation: Bool
  let locationError: String?
  let requestLocation: () -> Void
  let requestAlwaysAuthorization: () -> Void
  let save: (String, AppBoxPlaceRule.Trigger, CLLocationCoordinate2D, Double) -> Void

  @State private var name = ""
  @State private var trigger: AppBoxPlaceRule.Trigger = .leave
  @State private var radius = 200.0

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text(copy("地点", "Place"))) {
          TextField(copy("例如：公司、学校、家", "Work, school, home"), text: $name)
          HStack {
            VStack(alignment: .leading, spacing: 3) {
              Text(currentLocation == nil ? copy("尚未获取位置", "Location not ready") : copy("当前位置已获取", "Current location ready"))
              if let currentLocation {
                Text(String(format: "%.5f, %.5f", currentLocation.coordinate.latitude, currentLocation.coordinate.longitude))
                  .font(.caption)
                  .foregroundColor(.secondary)
              }
            }
            Spacer()
            if isRequestingLocation { ProgressView() }
          }
          Button(copy("获取当前位置", "Use current location"), action: requestLocation)
          if authorizationStatus != .authorizedAlways {
            Button(copy("允许始终定位", "Allow Always access"), action: requestAlwaysAuthorization)
          }
          if let locationError, !locationError.isEmpty {
            Text(locationError).font(.caption).foregroundColor(.red)
          }
        }

        Section(header: Text(copy("触发方式", "Trigger"))) {
          Picker("", selection: $trigger) {
            Text(copy("离开时", "When leaving")).tag(AppBoxPlaceRule.Trigger.leave)
            Text(copy("到达时", "When arriving")).tag(AppBoxPlaceRule.Trigger.arrive)
          }
          .pickerStyle(.segmented)
          HStack {
            Text(copy("半径", "Radius"))
            Slider(value: $radius, in: 100...1_000, step: 50)
            Text("\(Int(radius))m")
              .font(.system(size: 12, weight: .semibold, design: .rounded))
              .frame(width: 50)
          }
        }

        Section {
          Button(copy("保存地点", "Save place")) {
            guard let coordinate = currentLocation?.coordinate else { return }
            save(name, trigger, coordinate, radius)
          }
          .disabled(currentLocation == nil)
        } footer: {
          Text(copy("后台自动触发需要定位权限为“始终允许”。", "Background triggers require Always location access."))
        }
      }
      .navigationTitle(copy("新建地点", "New place"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(copy("取消", "Cancel")) { dismiss() }
        }
      }
    }
  }

  private func copy(_ chinese: String, _ english: String) -> String {
    usesEnglish ? english : chinese
  }
}

private struct QuietformScheduleEditor: View {
  @Environment(\.dismiss) private var dismiss
  let usesEnglish: Bool
  let save: (String, Date, Date) -> Void

  @State private var name = ""
  @State private var start = Date()
  @State private var end = Calendar.current.date(byAdding: .hour, value: 1, to: Date()) ?? Date()

  var body: some View {
    NavigationView {
      Form {
        Section(header: Text(copy("日程", "Schedule"))) {
          TextField(copy("例如：工作时间", "Work hours"), text: $name)
          DatePicker(copy("开始", "Start"), selection: $start, displayedComponents: .hourAndMinute)
          DatePicker(copy("结束", "End"), selection: $end, displayedComponents: .hourAndMinute)
        }
        Section {
          Button(copy("保存日程", "Save schedule")) { save(name, start, end) }
        } footer: {
          Text(copy("日程每天重复，并在 Quietform 运行期间自动检查。", "Schedules repeat daily and are checked while Quietform is running."))
        }
      }
      .navigationTitle(copy("新建日程", "New schedule"))
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button(copy("取消", "Cancel")) { dismiss() }
        }
      }
    }
  }

  private func copy(_ chinese: String, _ english: String) -> String {
    usesEnglish ? english : chinese
  }
}

private struct QuietformShareSheet: UIViewControllerRepresentable {
  let items: [Any]

  func makeUIViewController(context: Context) -> UIActivityViewController {
    UIActivityViewController(activityItems: items, applicationActivities: nil)
  }

  func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

private struct QuietformAssetIcon: View {
  let name: String
  let size: CGFloat

  var body: some View {
    Image(name)
      .renderingMode(.original)
      .resizable()
      .scaledToFit()
      .frame(width: size, height: size)
      .accessibilityHidden(true)
  }
}

private struct QuietformGlassCardModifier: ViewModifier {
  let cornerRadius: CGFloat

  func body(content: Content) -> some View {
    content
      .glassEffect(
        .regular,
        in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
      )
      .shadow(color: Color.black.opacity(0.045), radius: 16, y: 8)
  }
}

private extension View {
  func quietformCard() -> some View {
    modifier(QuietformGlassCardModifier(cornerRadius: 23))
  }
}
