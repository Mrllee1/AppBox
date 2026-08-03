import SwiftUI

private enum AppBoxSettingsDestination: String, Identifiable {
    case language
    case theme
    case password
    case importer

    var id: String { rawValue }
}

struct AppBoxSettingsView: View {
    @Binding var language: AppBoxLanguage
    @Binding var appearance: AppBoxAppearance
    @Binding var skin: AppBoxSkin

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var destination: AppBoxSettingsDestination?
    @State private var showShare = false

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AppBoxSheetHeader(
                    title: copy.text("设置", "Settings"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 28) {
                        settingsGroup(
                            title: copy.text("偏好设置", "Preferences"),
                            rows: [
                                (.apps, copy.text("语言", "Language"), language.displayName, .language),
                                (
                                    .edit,
                                    copy.text("主题与外观", "Theme & Appearance"),
                                    "\(copy.appearance(appearance)) · \(copy.skin(skin))",
                                    .theme
                                )
                            ]
                        )

                        settingsGroup(
                            title: copy.text("应用管理", "App Management"),
                            rows: [
                                (.fileAdd, copy.text("导入 IPA", "Import IPA"), copy.text("文件或链接", "File or link"), .importer),
                                (.shield, copy.text("隐私密码", "Privacy PIN"), copy.text("4 位数字", "4-digit PIN"), .password)
                            ]
                        )

                        VStack(alignment: .leading, spacing: 10) {
                            Text(copy.text("更多", "More").uppercased())
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(palette.secondaryText)
                            settingsActionRow(.share, copy.text("分享 AppBox", "Share AppBox")) {
                                withAnimation(.easeOut(duration: 0.18)) { showShare = true }
                            }
                        }

                        Text(copy.text("AppBox 版本 1.0.0", "AppBox Version 1.0.0"))
                            .font(.system(size: 12, weight: .regular))
                            .foregroundColor(palette.secondaryText)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 8)
                    }
                    .padding(.horizontal, AppBoxLayout.pagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 36)
                }
            }

            if showShare {
                AppBoxShareView(language: language, skin: skin) {
                    withAnimation(.easeOut(duration: 0.18)) { showShare = false }
                }
                .zIndex(100)
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
        .sheet(item: $destination) { destination in
            switch destination {
            case .language:
                AppBoxLanguageView(language: $language, skin: skin)
            case .theme:
                AppBoxThemeView(appearance: $appearance, skin: $skin, language: language)
            case .password:
                AppBoxPasswordView(language: language, skin: skin, mode: .manage)
            case .importer:
                AppBoxContainerInstallerView(sourceURL: nil)
            }
        }
    }

    private func settingsGroup(
        title: String,
        rows: [(AppBoxIcon, String, String?, AppBoxSettingsDestination)]
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(palette.secondaryText)

            VStack(spacing: 0) {
                ForEach(Array(rows.enumerated()), id: \.element.3) { index, row in
                    settingsRow(row.0, row.1, detail: row.2, target: row.3)
                    if index < rows.count - 1 {
                        Rectangle()
                            .fill(palette.divider)
                            .frame(height: 1)
                            .padding(.leading, 40)
                    }
                }
            }
        }
    }

    private func settingsRow(
        _ icon: AppBoxIcon,
        _ title: String,
        detail: String?,
        target: AppBoxSettingsDestination
    ) -> some View {
        Button { destination = target } label: {
            HStack(spacing: 12) {
                AppBoxGlyph(icon: icon)
                    .frame(width: 18, height: 18)
                    .foregroundColor(palette.accent)
                    .frame(width: 28, height: 28)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let detail {
                    Text(detail)
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                AppBoxGlyph(icon: .arrowRight)
                    .frame(width: 15, height: 15)
                    .foregroundColor(palette.secondaryText.opacity(0.8))
            }
            .padding(.horizontal, 2)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func settingsActionRow(
        _ icon: AppBoxIcon,
        _ title: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                AppBoxGlyph(icon: icon)
                    .frame(width: 18, height: 18)
                    .foregroundColor(palette.accent)
                    .frame(width: 28, height: 28)
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(palette.primaryText)
                Spacer()
                AppBoxGlyph(icon: .arrowRight)
                    .frame(width: 15, height: 15)
                    .foregroundColor(palette.secondaryText.opacity(0.8))
            }
            .padding(.horizontal, 2)
            .frame(height: 54)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

struct AppBoxLanguageView: View {
    @Binding var language: AppBoxLanguage
    let skin: AppBoxSkin

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AppBoxSheetHeader(
                    title: copy.text("语言", "Language"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                VStack(spacing: 0) {
                    ForEach(Array(AppBoxLanguage.allCases.enumerated()), id: \.element.id) { index, option in
                        Button {
                            language = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .font(.system(size: 15, weight: .medium))
                                    .foregroundColor(palette.primaryText)
                                Spacer()
                                if language == option {
                                    AppBoxGlyph(icon: .checkCircle)
                                        .frame(width: 19, height: 19)
                                        .foregroundColor(palette.accent)
                                }
                            }
                            .padding(.horizontal, 16)
                            .frame(height: 56)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if index < AppBoxLanguage.allCases.count - 1 {
                            Rectangle()
                                .fill(palette.divider)
                                .frame(height: 1)
                                .padding(.leading, 16)
                        }
                    }
                }
                .padding(.horizontal, AppBoxLayout.pagePadding)
                .padding(.top, 12)

                Spacer()
            }
        }
    }
}

struct AppBoxThemeView: View {
    @Binding var appearance: AppBoxAppearance
    @Binding var skin: AppBoxSkin
    let language: AppBoxLanguage

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AppBoxSheetHeader(
                    title: copy.text("主题与外观", "Theme & Appearance"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 24) {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(copy.text("外观", "Appearance").uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(palette.secondaryText)

                            HStack(spacing: 4) {
                                ForEach(AppBoxAppearance.allCases) { value in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) { appearance = value }
                                    } label: {
                                        Text(copy.appearance(value))
                                            .font(.system(size: 14, weight: appearance == value ? .semibold : .medium))
                                            .foregroundColor(appearance == value ? palette.accent : palette.secondaryText)
                                            .frame(maxWidth: .infinity)
                                            .frame(height: 36)
                                            .background(appearance == value ? palette.accentSoft : Color.clear)
                                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(appearance == value ? .isSelected : [])
                                }
                            }
                            .padding(4)
                            .appBoxGlassControl(palette, radius: 12, isInteractive: false)
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text(copy.text("主题色", "Accent Color").uppercased())
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(palette.secondaryText)

                            HStack(spacing: 8) {
                                ForEach(AppBoxSkin.allCases) { value in
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.18)) { skin = value }
                                    } label: {
                                        VStack(spacing: 10) {
                                            ZStack {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .fill(AppBoxPalette(skin: value, colorScheme: .light).accent)
                                                    .frame(width: 44, height: 44)
                                                if skin == value {
                                                    AppBoxGlyph(icon: .check)
                                                        .frame(width: 17, height: 17)
                                                        .foregroundColor(.white)
                                                }
                                            }
                                            .overlay {
                                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                                    .stroke(
                                                        skin == value ? palette.primaryText.opacity(0.18) : Color.clear,
                                                        lineWidth: 2
                                                    )
                                                    .padding(-4)
                                            }
                                            Text(copy.skin(value))
                                                .font(.system(size: 12, weight: .medium))
                                                .foregroundColor(skin == value ? palette.primaryText : palette.secondaryText)
                                        }
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityAddTraits(skin == value ? .isSelected : [])
                                }
                            }
                        }
                    }
                    .padding(.horizontal, AppBoxLayout.pagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
    }
}
