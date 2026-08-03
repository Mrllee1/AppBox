import SwiftUI

struct AppBoxLaunchTransitionView: View {
    let state: AppBoxLaunchState
    let language: AppBoxLanguage
    let skin: AppBoxSkin

    @Environment(\.colorScheme) private var colorScheme

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }
    private var progress: Double { state.phase.progress }
    private var percentage: Int { Int((progress * 100).rounded()) }
    private let secureColor = Color(red: 0.08, green: 0.66, blue: 0.43)

    var body: some View {
        ZStack {
            backdrop

            VStack(spacing: 0) {
                AppBoxIconView(item: state.item, size: 64)
                    .shadow(color: state.item.iconStyle.backgroundColor.opacity(0.24), radius: 14, y: 6)
                    .padding(.bottom, 16)

                Text(copy.text("\(appName) 启动中…", "Opening \(appName)…"))
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .padding(.bottom, 20)

                progressBar
                    .padding(.bottom, 15)

                HStack(spacing: 9) {
                    AppBoxGlyph(icon: state.phase == .ready ? .shieldYes : .shield)
                        .frame(width: 18, height: 18)
                    Text(statusText)
                        .lineLimit(1)
                        .minimumScaleFactor(0.78)
                    Spacer(minLength: 8)
                    Text("\(percentage)%")
                        .monospacedDigit()
                }
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(secureColor)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 26)
            .frame(maxWidth: 310)
            .appBoxGlassControl(
                palette,
                radius: AppBoxLayout.cardRadius,
                isInteractive: false
            )
            .shadow(color: Color.black.opacity(colorScheme == .dark ? 0.34 : 0.15), radius: 24, y: 12)
            .padding(.horizontal, 24)
        }
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
        .accessibilityLabel(
            copy.text(
                "\(appName) 启动中，\(statusText)，\(percentage)%",
                "Opening \(appName), \(statusText), \(percentage)%"
            )
        )
    }

    private var backdrop: some View {
        Color.black
            .opacity(colorScheme == .dark ? 0.48 : 0.24)
            .ignoresSafeArea()
    }

    private var progressBar: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(palette.mutedSurface)
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .fill(palette.accent)
                    .frame(width: max(6, proxy.size.width * progress))
                    .shadow(color: palette.accent.opacity(0.30), radius: 5)
            }
        }
        .frame(height: 6)
        .animation(.easeInOut(duration: 0.32), value: state.phase)
    }

    private var appName: String {
        state.item.name(for: language)
    }

    private var statusText: String {
        switch state.phase {
        case .preparing:
            return copy.text("正在准备独立运行环境", "Preparing private environment")
        case .verifying:
            return copy.text("正在校验应用完整性", "Verifying app integrity")
        case .launching:
            return copy.text("正在启动安全环境", "Starting secure environment")
        case .ready:
            return copy.text("安全环境已就绪", "Secure environment ready")
        }
    }
}
