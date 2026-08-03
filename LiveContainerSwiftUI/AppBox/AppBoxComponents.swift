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
            accentColor = Color(red: 0.15, green: 0.42, blue: 0.90)
        case .mint:
            accentColor = Color(red: 0.06, green: 0.54, blue: 0.42)
        case .coral:
            accentColor = Color(red: 0.89, green: 0.31, blue: 0.35)
        }

        background = isDark
            ? Color(red: 0.055, green: 0.06, blue: 0.075)
            : Color(red: 0.965, green: 0.972, blue: 0.982)
        surface = isDark
            ? Color(red: 0.10, green: 0.11, blue: 0.14)
            : Color.white
        elevatedSurface = isDark
            ? Color(red: 0.14, green: 0.15, blue: 0.19)
            : Color.white
        mutedSurface = isDark
            ? Color.white.opacity(0.065)
            : Color(red: 0.94, green: 0.95, blue: 0.97)
        primaryText = isDark ? Color.white.opacity(0.94) : Color(red: 0.08, green: 0.09, blue: 0.12)
        secondaryText = isDark ? Color.white.opacity(0.58) : Color.black.opacity(0.48)
        accent = accentColor
        accentSoft = accentColor.opacity(isDark ? 0.20 : 0.10)
        divider = isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.065)
        border = isDark ? Color.white.opacity(0.09) : Color.black.opacity(0.055)
        destructive = Color(red: 0.90, green: 0.22, blue: 0.25)
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
        case .blue: return Color(red: 0.12, green: 0.47, blue: 0.94)
        case .indigo: return Color(red: 0.34, green: 0.31, blue: 0.82)
        case .mint: return Color(red: 0.08, green: 0.66, blue: 0.54)
        case .coral: return Color(red: 0.94, green: 0.36, blue: 0.31)
        case .gold: return Color(red: 0.78, green: 0.55, blue: 0.10)
        case .graphite: return Color(red: 0.18, green: 0.20, blue: 0.24)
        case .teal: return Color(red: 0.04, green: 0.56, blue: 0.66)
        case .rose: return Color(red: 0.82, green: 0.27, blue: 0.52)
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
                .frame(width: 40, height: 40)
                .foregroundColor(palette.primaryText)
                .appBoxGlassControl(palette, radius: 20, isEnabled: usesGlass)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

struct AppBoxGlyph: View {
    let icon: AppBoxIcon

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
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
        .font(.system(size: 15, weight: .regular))
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
    let isInstalling: Bool
    let action: () -> Void

    var body: some View {
        VStack(spacing: 6) {
            AppBoxIconView(item: item)
            Text(item.name(for: copy.language))
                .font(.system(size: 11.25, weight: .regular))
                .foregroundColor(palette.primaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
            Button(action: action) {
                Group {
                    if isInstalling {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .scaleEffect(0.72)
                    } else {
                        Text(isInstalled ? copy.text("启动", "Open") : copy.text("安装", "Install"))
                            .font(.system(size: 11.5, weight: .semibold))
                    }
                }
                .frame(width: 52, height: 28)
                .foregroundColor(palette.accent)
                .background(isInstalled ? palette.accentSoft : Color.clear)
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
            .buttonStyle(.plain)
            .disabled(isInstalling)
        }
        .frame(maxWidth: .infinity)
        .frame(minHeight: 98, alignment: .top)
        .accessibilityElement(children: .combine)
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
                    .font(.system(size: 11.25, weight: .regular))
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
                .font(.system(size: 14, weight: .medium))
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
                .font(.system(size: 17, weight: .semibold))
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
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(palette.primaryText)
            Spacer()
            if let detail {
                Text(detail)
                    .font(.system(size: 12, weight: .medium))
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
