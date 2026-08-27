import FamilyControls
import SwiftUI

struct AppBoxPrivacySurfaceView: View {
  @Environment(\.scenePhase) private var scenePhase
  @StateObject private var visibility = AppBoxVisibilityService()
  @State private var isPickerPresented = false
  @State private var isWorking = false

  var body: some View {
    ZStack {
      LinearGradient(
        colors: [
          Color(red: 0.94, green: 0.97, blue: 1.00),
          Color(red: 0.98, green: 0.99, blue: 1.00),
          Color(red: 0.93, green: 0.96, blue: 1.00),
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
      )
      .ignoresSafeArea()

      ScrollView(showsIndicators: false) {
        VStack(alignment: .leading, spacing: 18) {
          header
          statusCard
          selectionCard
          privacyTip
        }
        .padding(.horizontal, 20)
        .padding(.top, 18)
        .padding(.bottom, 36)
      }
    }
    .familyActivityPicker(
      isPresented: $isPickerPresented,
      selection: $visibility.selection
    )
    .onChange(of: scenePhase) { phase in
      if phase == .active {
        visibility.refreshAuthorizationStatus()
      }
    }
  }

  private var header: some View {
    HStack(spacing: 14) {
      VStack(alignment: .leading, spacing: 5) {
        Text("Quietform")
          .font(.system(size: 27, weight: .bold, design: .rounded))
          .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.20))

        Text("把重要的留在眼前，把干扰轻轻收起")
          .font(.system(size: 13.5, weight: .medium))
          .foregroundColor(Color(red: 0.34, green: 0.40, blue: 0.50))
      }

      Spacer()

      Image("QuietformMark")
        .resizable()
        .scaledToFill()
        .frame(width: 52, height: 52)
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
          RoundedRectangle(cornerRadius: 17, style: .continuous)
            .stroke(Color.white.opacity(0.78), lineWidth: 1)
        }
        .shadow(color: Color(red: 0.16, green: 0.16, blue: 0.32).opacity(0.24), radius: 13, y: 7)
    }
  }

  private var statusCard: some View {
    VStack(alignment: .leading, spacing: 16) {
      HStack(alignment: .top, spacing: 13) {
        Image(systemName: visibility.isHidden ? "eye.slash.fill" : "shield.checkered")
          .font(.system(size: 21, weight: .semibold))
          .foregroundColor(visibility.isHidden ? .white : Color(red: 0.18, green: 0.44, blue: 0.94))
          .frame(width: 44, height: 44)
          .background(visibility.isHidden ? Color(red: 0.18, green: 0.67, blue: 0.43) : Color.blue.opacity(0.10))
          .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

        VStack(alignment: .leading, spacing: 5) {
          Text(visibility.isHidden ? "隐藏保护已开启" : "隐藏保护未开启")
            .font(.system(size: 17, weight: .bold))
            .foregroundColor(Color(red: 0.08, green: 0.12, blue: 0.20))

          Text(statusDescription)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(Color(red: 0.36, green: 0.42, blue: 0.52))
            .fixedSize(horizontal: false, vertical: true)
        }

        Spacer(minLength: 0)
      }

      HStack(spacing: 10) {
        metric(value: "\(visibility.selectedApplicationCount)", label: "App")
        metric(value: "\(visibility.selectedCategoryCount)", label: "分类")
        metric(value: visibility.isAuthorized ? "已授权" : "待授权", label: "权限")
      }
    }
    .padding(18)
    .background(Color.white.opacity(0.88))
    .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
    .overlay {
      RoundedRectangle(cornerRadius: 24, style: .continuous)
        .stroke(Color.white.opacity(0.90), lineWidth: 1)
    }
    .shadow(color: Color(red: 0.12, green: 0.20, blue: 0.34).opacity(0.10), radius: 20, y: 10)
  }

  private var selectionCard: some View {
    VStack(spacing: 13) {
      Button(action: chooseApps) {
        actionLabel(
          title: visibility.hasSelection ? "重新选择 App" : "选择需要隐藏的 App",
          icon: "square.grid.2x2.fill",
          foreground: Color(red: 0.14, green: 0.39, blue: 0.92),
          background: Color.blue.opacity(0.09)
        )
      }
      .buttonStyle(.plain)

      Button(action: toggleVisibility) {
        HStack(spacing: 10) {
          if isWorking {
            ProgressView()
              .tint(.white)
          } else {
            Image(systemName: visibility.isHidden ? "eye.fill" : "eye.slash.fill")
          }
          Text(visibility.isHidden ? "恢复全部 App" : "隐藏所选 App")
            .font(.system(size: 16, weight: .bold))
        }
        .foregroundColor(.white)
        .frame(maxWidth: .infinity)
        .frame(height: 54)
        .background(
          LinearGradient(
            colors: visibility.isHidden
              ? [Color(red: 0.40, green: 0.46, blue: 0.58), Color(red: 0.27, green: 0.32, blue: 0.43)]
              : [Color(red: 0.20, green: 0.49, blue: 0.98), Color(red: 0.35, green: 0.36, blue: 0.91)],
            startPoint: .leading,
            endPoint: .trailing
          )
        )
        .clipShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
      }
      .buttonStyle(.plain)
      .disabled(isWorking || (!visibility.isHidden && !visibility.hasSelection))
      .opacity((!visibility.isHidden && !visibility.hasSelection) ? 0.48 : 1)

      if visibility.hasSelection {
        Button("清空选择") {
          visibility.clearSelection()
        }
        .font(.system(size: 13, weight: .semibold))
        .foregroundColor(Color(red: 0.39, green: 0.45, blue: 0.56))
        .disabled(isWorking)
      }

      if let error = visibility.lastError, !error.isEmpty {
        HStack(alignment: .top, spacing: 8) {
          Image(systemName: "exclamationmark.circle.fill")
          Text(error)
            .fixedSize(horizontal: false, vertical: true)
        }
        .font(.system(size: 12.5, weight: .medium))
        .foregroundColor(Color(red: 0.82, green: 0.24, blue: 0.23))
        .frame(maxWidth: .infinity, alignment: .leading)
      }
    }
    .padding(16)
    .background(Color.white.opacity(0.86))
    .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    .shadow(color: Color.black.opacity(0.06), radius: 16, y: 8)
  }

  private var privacyTip: some View {
    HStack(alignment: .top, spacing: 11) {
      Image(systemName: "lock.shield.fill")
        .foregroundColor(Color(red: 0.20, green: 0.49, blue: 0.98))
      Text("App 选择由 iOS 系统页面完成。Quietform 只保存匿名选择令牌，无法读取你选择的应用名称或使用内容。")
        .font(.system(size: 12.5, weight: .medium))
        .foregroundColor(Color(red: 0.38, green: 0.44, blue: 0.54))
        .fixedSize(horizontal: false, vertical: true)
    }
    .padding(.horizontal, 4)
  }

  private var statusDescription: String {
    if visibility.isHidden {
      return "所选项目已由屏幕使用时间保护，可随时在这里恢复。"
    }
    if visibility.hasSelection {
      return "所选项目已保存，点击下方按钮即可隐藏。"
    }
    return "先授权屏幕使用时间，再从系统列表选择 App。"
  }

  private func metric(value: String, label: String) -> some View {
    VStack(alignment: .leading, spacing: 3) {
      Text(value)
        .font(.system(size: value.count > 4 ? 13 : 18, weight: .bold, design: .rounded))
        .foregroundColor(Color(red: 0.10, green: 0.15, blue: 0.24))
        .lineLimit(1)
        .minimumScaleFactor(0.72)
      Text(label)
        .font(.system(size: 11.5, weight: .semibold))
        .foregroundColor(Color(red: 0.43, green: 0.49, blue: 0.58))
    }
    .frame(maxWidth: .infinity, alignment: .leading)
    .padding(.horizontal, 12)
    .padding(.vertical, 10)
    .background(Color(red: 0.95, green: 0.97, blue: 1.00))
    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
  }

  private func actionLabel(
    title: String,
    icon: String,
    foreground: Color,
    background: Color
  ) -> some View {
    HStack(spacing: 12) {
      Image(systemName: icon)
        .font(.system(size: 18, weight: .semibold))
        .frame(width: 30)
      Text(title)
        .font(.system(size: 15, weight: .semibold))
      Spacer()
      Image(systemName: "chevron.right")
        .font(.system(size: 13, weight: .bold))
        .opacity(0.64)
    }
    .foregroundColor(foreground)
    .padding(.horizontal, 15)
    .frame(height: 52)
    .background(background)
    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
  }

  private func chooseApps() {
    Task {
      if await visibility.requestAuthorizationIfNeeded() {
        isPickerPresented = true
      }
    }
  }

  private func toggleVisibility() {
    if visibility.isHidden {
      visibility.restoreAll()
      return
    }

    isWorking = true
    Task {
      await visibility.hideSelection()
      isWorking = false
    }
  }
}
