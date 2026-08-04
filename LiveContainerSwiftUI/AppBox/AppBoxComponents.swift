import SwiftUI

struct AppBoxPalette {
    let background: Color
    let surface: Color
    let elevatedSurface: Color
    let mutedSurface: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let accentSoft: Color
    let divider: Color
    let border: Color
    let destructive: Color

    init(skin: AppBoxSkin, colorScheme: ColorScheme) {
        let isDark = colorScheme == .dark
        let accentColor: Color

        switch skin {
        case .sky:
            accentColor = Color(uiColor: .systemBlue)
        case .mint:
            accentColor = Color(uiColor: .systemMint)
        case .coral:
            accentColor = Color(uiColor: .systemPink)
        }

        background = Color(uiColor: .systemGroupedBackground)
        surface = Color(uiColor: .secondarySystemGroupedBackground)
        elevatedSurface = Color(uiColor: .systemBackground)
        mutedSurface = Color(uiColor: .systemGray5)
        primaryText = Color(uiColor: .label)
        secondaryText = Color(uiColor: .secondaryLabel)
        accent = accentColor
        accentSoft = accentColor.opacity(isDark ? 0.22 : 0.12)
        divider = Color(uiColor: .separator)
        border = Color(uiColor: .separator).opacity(isDark ? 0.70 : 0.45)
        destructive = Color(uiColor: .systemRed)
    }
}

enum AppBoxLayout {
    static let pagePadding: CGFloat = 16
    static let sectionSpacing: CGFloat = 24
    static let cardRadius: CGFloat = 8
    static let controlHeight: CGFloat = 44
}

extension AppBoxAppearance {
    var preferredColorScheme: ColorScheme? {
        switch self {
        case .system: return nil
        case .light: return .light
        case .dark: return .dark
        }
    }
}

extension AppBoxIconStyle {
    var backgroundColor: Color {
        switch self {
        case .blue: return Color(uiColor: .systemBlue)
        case .indigo: return Color(uiColor: .systemIndigo)
        case .mint: return Color(uiColor: .systemMint)
        case .coral: return Color(uiColor: .systemRed)
        case .gold: return Color(uiColor: .systemOrange)
        case .graphite: return Color(uiColor: .systemGray)
        case .teal: return Color(uiColor: .systemTeal)
        case .rose: return Color(uiColor: .systemPink)
        }
    }
}

struct AppBoxIconButton: View {
    let icon: AppBoxIcon
    let accessibilityLabel: String
    let palette: AppBoxPalette
    var usesGlass = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppBoxGlyph(icon: icon)
                .frame(width: 18, height: 18)
                .frame(width: AppBoxLayout.controlHeight, height: AppBoxLayout.controlHeight)
                .foregroundColor(palette.primaryText)
                .appBoxGlassControl(palette, radius: AppBoxLayout.controlHeight / 2, isEnabled: usesGlass)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AppBoxGlyph: View {
    let icon: AppBoxIcon

    var body: some View {
        Image(systemName: icon.rawValue)
            .symbolRenderingMode(.monochrome)
            .resizable()
            .scaledToFit()
            .accessibilityHidden(true)
    }
}

struct AppBoxIconView: View {
    let item: AppBoxCatalogItem
    var size: CGFloat = 48

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(item.iconStyle.backgroundColor)
            AppBoxGlyph(icon: item.icon)
                .frame(width: size * 0.42, height: size * 0.42)
                .foregroundColor(.white)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

struct AppBoxSearchBar: View {
    @Binding var text: String
    let placeholder: String
    let palette: AppBoxPalette

    var body: some View {
        HStack(spacing: 10) {
            AppBoxGlyph(icon: .search)
                .frame(width: 19, height: 19)
                .foregroundColor(palette.secondaryText)
            TextField(placeholder, text: $text)
                .textInputAutocapitalization(.never)
                .disableAutocorrection(true)
                .foregroundColor(palette.primaryText)
            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    AppBoxGlyph(icon: .closeCircle)
                        .frame(width: 18, height: 18)
                        .foregroundColor(palette.secondaryText)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Clear")
            }
        }
        .font(.body)
        .padding(.horizontal, 15)
        .frame(height: 44)
        .appBoxGlassControl(palette, radius: 14)
    }
}

struct AppBoxAppCell: View {
    let item: AppBoxCatalogItem
    let copy: AppBoxCopy
    let palette: AppBoxPalette
    let isInstalled: Bool
    let installState: AppBoxInstallState?
    let action: () -> Void

    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    var body: some View {
        VStack(spacing: 6) {
            Button(action: action) {
                AppBoxInstallIcon(item: item, state: installState, palette: palette)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isActionDisabled)
            Text(item.name(for: copy.language))
                .font(.caption2)
                .foregroundColor(palette.primaryText)
                .lineLimit(dynamicTypeSize.isAccessibilitySize ? 2 : 1)
                .minimumScaleFactor(0.75)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
            Button(action: action) {
                Text(actionTitle)
                    .font(.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .frame(minWidth: 56, minHeight: 32)
                .foregroundColor(actionColor)
                .background(actionBackground)
                .clipShape(Capsule())
                .frame(minHeight: AppBoxLayout.controlHeight)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(isActionDisabled)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: dynamicTypeSize.isAccessibilitySize ? 124 : 110, alignment: .top)
        .accessibilityElement(children: .combine)
        .accessibilityValue(accessibilityValue)
    }

    private var actionTitle: String {
        switch installState {
        case .downloading:
            return copy.text("取消", "Cancel")
        case .processing:
            return copy.text("安装中", "Installing")
        case .completed:
            return copy.text("完成", "Done")
        case .failed:
            return copy.text("重试", "Retry")
        case nil:
            return isInstalled ? copy.text("启动", "Open") : copy.text("安装", "Install")
        }
    }

    private var isActionDisabled: Bool {
        switch installState {
        case .processing, .completed:
            return true
        case .downloading, .failed, nil:
            return false
        }
    }

    private var actionColor: Color {
        if case .failed = installState { return palette.destructive }
        return palette.accent
    }

    private var actionBackground: Color {
        if case .failed = installState { return palette.destructive.opacity(0.12) }
        if isInstalled || installState != nil { return palette.accentSoft }
        return palette.mutedSurface
    }

    private var accessibilityValue: String {
        switch installState {
        case .downloading(let progress):
            return copy.text("下载进度 \(Int((progress * 100).rounded()))%", "Download \(Int((progress * 100).rounded())) percent")
        case .processing:
            return copy.text("正在安装", "Installing")
        case .completed:
            return copy.text("安装完成", "Installed")
        case .failed(let message):
            return copy.text("安装失败：\(message)", "Installation failed: \(message)")
        case nil:
            return isInstalled ? copy.text("已安装", "Installed") : copy.text("未安装", "Not installed")
        }
    }
}

private struct AppBoxInstallIcon: View {
    let item: AppBoxCatalogItem
    let state: AppBoxInstallState?
    let palette: AppBoxPalette

    var body: some View {
        ZStack {
            AppBoxIconView(item: item)
                .opacity(state?.isActive == true ? 0.58 : 1)

            switch state {
            case .downloading(let progress):
                progressControl(progress: progress)
            case .processing:
                processingControl
            case .completed:
                statusControl(icon: .check, color: Color(uiColor: .systemGreen))
                    .transition(.scale(scale: 0.72).combined(with: .opacity))
            case .failed:
                statusControl(icon: .warning, color: palette.destructive)
            case nil:
                EmptyView()
            }
        }
        .frame(width: 52, height: 52)
        .animation(.easeOut(duration: 0.20), value: state)
    }

    private func progressControl(progress: Double) -> some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.52))
            Circle()
                .stroke(Color.white.opacity(0.36), lineWidth: 2.5)
                .padding(3)
            Circle()
                .trim(from: 0, to: min(max(progress, 0.015), 1))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 2.5, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .padding(3)
            AppBoxGlyph(icon: .stop)
                .frame(width: 8, height: 8)
                .foregroundColor(.white)
        }
        .frame(width: 31, height: 31)
    }

    private var processingControl: some View {
        ZStack {
            Circle()
                .fill(Color.black.opacity(0.52))
            ProgressView()
                .progressViewStyle(.circular)
                .tint(.white)
                .scaleEffect(0.72)
        }
        .frame(width: 31, height: 31)
    }

    private func statusControl(icon: AppBoxIcon, color: Color) -> some View {
        ZStack {
            Circle().fill(color)
            AppBoxGlyph(icon: icon)
                .frame(width: 13, height: 13)
                .foregroundColor(.white)
        }
        .frame(width: 30, height: 30)
    }
}

struct AppBoxInstalledTile: View {
    let item: AppBoxCatalogItem
    let copy: AppBoxCopy
    let palette: AppBoxPalette
    let canRemove: Bool
    let open: () -> Void
    let remove: () -> Void

    var body: some View {
        Button(action: open) {
            VStack(spacing: 6) {
                AppBoxIconView(item: item, size: 46)
                Text(item.name(for: copy.language))
                    .font(.caption2)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundColor(palette.primaryText)
            }
            .frame(width: 62)
        }
        .buttonStyle(.plain)
        .contextMenu {
            if canRemove {
                Button(role: .destructive, action: remove) {
                    AppBoxGlyph(icon: .trash)
                    Text(copy.text("卸载", "Uninstall"))
                }
            }
        }
    }
}

struct AppBoxNoticeView: View {
    let text: String
    let palette: AppBoxPalette

    var body: some View {
        HStack(spacing: 8) {
            AppBoxGlyph(icon: .checkCircle)
                .frame(width: 18, height: 18)
                .foregroundColor(palette.accent)
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundColor(palette.primaryText)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(palette.elevatedSurface)
        .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous)
                .stroke(palette.border, lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.10), radius: 12, y: 5)
    }
}

struct AppBoxSheetHeader: View {
    let title: String
    let closeLabel: String
    let palette: AppBoxPalette
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            AppBoxIconButton(
                icon: .close,
                accessibilityLabel: closeLabel,
                palette: palette,
                usesGlass: true,
                action: dismiss
            )
            Spacer()
            Text(title)
                .font(.headline)
                .foregroundColor(palette.primaryText)
            Spacer()
            Color.clear.frame(width: AppBoxLayout.controlHeight, height: AppBoxLayout.controlHeight)
        }
        .padding(.horizontal, AppBoxLayout.pagePadding - 2)
        .frame(height: 56)
    }
}

struct AppBoxSectionHeading: View {
    let title: String
    var detail: String? = nil
    let palette: AppBoxPalette

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(palette.primaryText)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.caption.weight(.medium))
                    .foregroundColor(palette.secondaryText)
            }
        }
    }
}

private struct AppBoxSurfaceModifier: ViewModifier {
    let palette: AppBoxPalette
    let addsShadow: Bool

    func body(content: Content) -> some View {
        content
            .background(palette.surface)
            .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous)
                    .stroke(palette.border, lineWidth: 1)
            }
            .shadow(
                color: addsShadow ? Color.black.opacity(0.045) : Color.clear,
                radius: 8,
                y: 3
            )
    }
}

private struct AppBoxGlassControlModifier: ViewModifier {
    let palette: AppBoxPalette
    let radius: CGFloat
    let isInteractive: Bool
    let isEnabled: Bool
    let tint: Color?

    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    @ViewBuilder
    func body(content: Content) -> some View {
        if !isEnabled {
            content
        } else if #available(iOS 26.0, *) {
            if let tint {
                content.glassEffect(
                    isInteractive ? .regular.tint(tint).interactive() : .regular.tint(tint),
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
            } else {
                content.glassEffect(
                    isInteractive ? .regular.interactive() : .regular,
                    in: RoundedRectangle(cornerRadius: radius, style: .continuous)
                )
            }
        } else {
            content
                .background(reduceTransparency ? (tint ?? palette.surface) : Color.clear)
                .background(reduceTransparency ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.ultraThinMaterial))
                .background(tint?.opacity(0.82) ?? Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .stroke(palette.border, lineWidth: 1)
                }
        }
    }
}

extension View {
    func appBoxSurface(_ palette: AppBoxPalette, addsShadow: Bool = false) -> some View {
        modifier(AppBoxSurfaceModifier(palette: palette, addsShadow: addsShadow))
    }

    func appBoxGlassControl(
        _ palette: AppBoxPalette,
        radius: CGFloat,
        isInteractive: Bool = true,
        isEnabled: Bool = true,
        tint: Color? = nil
    ) -> some View {
        modifier(
            AppBoxGlassControlModifier(
                palette: palette,
                radius: radius,
                isInteractive: isInteractive,
                isEnabled: isEnabled,
                tint: tint
            )
        )
    }

    @ViewBuilder
    func appBoxHideListBackground() -> some View {
        if #available(iOS 16.0, *) {
            scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}
