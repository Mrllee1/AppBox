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
    @State private var isPINEnabled = AppBoxPINService().hasPIN

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            NavigationView {
                List {
                    Section {
                        settingsRow(.apps, copy.text("语言", "Language"), detail: language.displayName, target: .language)
                        settingsRow(
                            .edit,
                            copy.text("主题与外观", "Theme & Appearance"),
                            detail: "\(copy.appearance(appearance)) · \(copy.skin(skin))",
                            target: .theme
                        )
                        settingsRow(
                            .fileAdd,
                            copy.text("导入 IPA", "Import IPA"),
                            detail: copy.text("文件或链接", "File or link"),
                            target: .importer
                        )
                        settingsRow(
                            .shield,
                            copy.text("隐私密码", "Privacy PIN"),
                            detail: isPINEnabled
                                ? copy.text("已开启", "On")
                                : copy.text("未设置", "Not set"),
                            target: .password
                        )
                        settingsActionRow(
                            .share,
                            copy.text("分享\(AppBoxBrand.chineseName)", "Share \(AppBoxBrand.englishName)")
                        ) {
                            withAnimation(.easeOut(duration: 0.18)) { showShare = true }
                        }
                    } footer: {
                        Text(
                            copy.text(
                                "\(AppBoxBrand.chineseName)版本 1.0.0",
                                "\(AppBoxBrand.englishName) Version 1.0.0"
                            )
                        )
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)
                    }
                }
                .listStyle(.insetGrouped)
                .appBoxHideListBackground()
                .background(palette.background)
                .navigationTitle(copy.text("设置", "Settings"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button { dismiss() } label: {
                            Image(systemName: AppBoxIcon.close.rawValue)
                        }
                        .accessibilityLabel(copy.text("关闭", "Close"))
                    }
                }
                .tint(palette.accent)
            }
            .navigationViewStyle(StackNavigationViewStyle())

            if showShare {
                AppBoxShareView(language: language, skin: skin) {
                    withAnimation(.easeOut(duration: 0.18)) { showShare = false }
                }
                .zIndex(100)
            }
        }
        .preferredColorScheme(appearance.preferredColorScheme)
        .sheet(item: $destination, onDismiss: refreshPINStatus) { destination in
            switch destination {
            case .language:
                AppBoxLanguageView(language: $language, skin: skin)
            case .theme:
                AppBoxThemeView(appearance: $appearance, skin: $skin, language: language)
            case .password:
                AppBoxPasswordView(
                    language: language,
                    skin: skin,
                    mode: .manage,
                    onProtectionChange: { isPINEnabled = $0 }
                )
            case .importer:
                AppBoxContainerInstallerView(sourceURL: nil)
                    .appBoxImporterPresentation()
            }
        }
    }

    private func refreshPINStatus() {
        isPINEnabled = AppBoxPINService().hasPIN
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
                    .font(.body)
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)

                Spacer(minLength: 8)

                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundColor(palette.secondaryText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }

                AppBoxGlyph(icon: .arrowRight)
                    .frame(width: 15, height: 15)
                    .foregroundColor(palette.secondaryText.opacity(0.8))
            }
            .frame(minHeight: 44)
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
                    .font(.body)
                    .foregroundColor(palette.primaryText)
                Spacer()
                AppBoxGlyph(icon: .arrowRight)
                    .frame(width: 15, height: 15)
                    .foregroundColor(palette.secondaryText.opacity(0.8))
            }
            .frame(minHeight: 44)
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
        NavigationView {
            List {
                Section {
                    ForEach(AppBoxLanguage.allCases) { option in
                        Button {
                            language = option
                        } label: {
                            HStack {
                                Text(option.displayName)
                                    .font(.body)
                                    .foregroundColor(palette.primaryText)
                                Spacer()
                                if language == option {
                                    AppBoxGlyph(icon: .checkCircle)
                                        .frame(width: 19, height: 19)
                                        .foregroundColor(palette.accent)
                                }
                            }
                            .frame(minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .appBoxHideListBackground()
            .background(palette.background)
            .navigationTitle(copy.text("语言", "Language"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: AppBoxIcon.close.rawValue)
                    }
                    .accessibilityLabel(copy.text("关闭", "Close"))
                }
            }
            .tint(palette.accent)
        }
        .navigationViewStyle(StackNavigationViewStyle())
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
        NavigationView {
            List {
                Section(copy.text("外观", "Appearance")) {
                    Picker(copy.text("外观", "Appearance"), selection: $appearance) {
                        ForEach(AppBoxAppearance.allCases) { value in
                            Text(copy.appearance(value)).tag(value)
                        }
                    }
                    .pickerStyle(.segmented)
                    .labelsHidden()
                    .padding(.vertical, 4)
                }

                Section(copy.text("主题色", "Accent Color")) {
                    VStack(alignment: .leading, spacing: 8) {
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
                                            .font(.caption.weight(.medium))
                                            .foregroundColor(skin == value ? palette.primaryText : palette.secondaryText)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 10)
                                }
                                .buttonStyle(.plain)
                                .accessibilityAddTraits(skin == value ? .isSelected : [])
                            }
                        }
                        .frame(minHeight: 76)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .appBoxHideListBackground()
            .background(palette.background)
            .navigationTitle(copy.text("主题与外观", "Theme & Appearance"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button { dismiss() } label: {
                        Image(systemName: AppBoxIcon.close.rawValue)
                    }
                    .accessibilityLabel(copy.text("关闭", "Close"))
                }
            }
            .tint(palette.accent)
        }
        .navigationViewStyle(StackNavigationViewStyle())
        .preferredColorScheme(appearance.preferredColorScheme)
    }
}
