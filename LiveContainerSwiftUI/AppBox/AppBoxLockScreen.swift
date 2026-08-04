import LocalAuthentication
import SwiftUI

@MainActor
final class AppBoxLockController: ObservableObject {
    @Published private(set) var isLocked: Bool

    private let pinService: AppBoxPINProviding
    private let forceLockedForDebug: Bool
    private var hasPendingUnlock = false

    init(pinService: AppBoxPINProviding = AppBoxPINService()) {
        self.pinService = pinService
#if DEBUG
        forceLockedForDebug = ProcessInfo.processInfo.environment["APPBOX_DEBUG_FORCE_LOCKED"] == "1"
#else
        forceLockedForDebug = false
#endif
        isLocked = forceLockedForDebug || pinService.hasPIN
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            if hasPendingUnlock {
                hasPendingUnlock = false
                isLocked = false
            }
        case .inactive:
            isLocked = protectionEnabled
        case .background:
            hasPendingUnlock = false
            isLocked = protectionEnabled
        @unknown default:
            hasPendingUnlock = false
            isLocked = protectionEnabled
        }
    }

    func requestUnlock(while phase: ScenePhase) {
        switch phase {
        case .active:
            hasPendingUnlock = false
            isLocked = false
        case .inactive:
            hasPendingUnlock = true
        case .background:
            hasPendingUnlock = false
        @unknown default:
            hasPendingUnlock = false
        }
    }

    func synchronizeProtectionState() {
        if !protectionEnabled {
            hasPendingUnlock = false
            isLocked = false
        }
    }

    private var protectionEnabled: Bool {
        forceLockedForDebug || pinService.hasPIN
    }
}

struct AppBoxLockScreen: View {
    let language: AppBoxLanguage
    let skin: AppBoxSkin
    let onUnlock: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @State private var biometryKind: AppBoxBiometryKind = .unavailable
    @State private var isAuthenticating = false
    @State private var showPassword = false
    @State private var feedback = ""

    private let biometricService: AppBoxBiometricAuthenticating

    init(
        language: AppBoxLanguage,
        skin: AppBoxSkin,
        biometricService: AppBoxBiometricAuthenticating = AppBoxBiometricService(),
        onUnlock: @escaping () -> Void
    ) {
        self.language = language
        self.skin = skin
        self.biometricService = biometricService
        self.onUnlock = onUnlock
    }

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()
            palette.accentSoft.opacity(colorScheme == .dark ? 0.26 : 0.48).ignoresSafeArea()

            VStack(spacing: 0) {
                Text(copy.text("隐私空间", "Private Space"))
                    .font(.headline)
                    .foregroundColor(palette.primaryText)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .accessibilityAddTraits(.isHeader)

                Spacer()
                    .frame(height: 112)

                Button(action: authenticate) {
                    VStack(spacing: 22) {
                        ZStack {
                            AppBoxGlyph(icon: biometricIcon)
                                .frame(width: 42, height: 42)
                                .foregroundColor(palette.accent)
                        }
                        .overlay {
                            if isAuthenticating {
                                ProgressView()
                                    .tint(palette.accent)
                                    .scaleEffect(1.1)
                            }
                        }

                        Text(biometricPrompt)
                            .font(.body.weight(.medium))
                            .foregroundColor(palette.primaryText)
                            .multilineTextAlignment(.center)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isAuthenticating || biometryKind == .unavailable)
                .accessibilityLabel(biometricPrompt)

                if !feedback.isEmpty {
                    Text(feedback)
                        .font(.footnote)
                        .foregroundColor(palette.destructive)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 36)
                        .padding(.top, 14)
                }

                Button {
                    feedback = ""
                    showPassword = true
                } label: {
                    Text(copy.text("密码解锁", "Unlock with PIN"))
                        .font(.body)
                        .foregroundColor(palette.secondaryText)
                        .padding(.horizontal, 20)
                        .frame(minHeight: 48)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, feedback.isEmpty ? 28 : 14)

                Spacer()
            }
            .padding(.horizontal, AppBoxLayout.pagePadding)
        }
        .onAppear {
            biometryKind = biometricService.biometryKind
        }
        .fullScreenCover(isPresented: $showPassword) {
            AppBoxPasswordView(
                language: language,
                skin: skin,
                mode: .unlock,
                onSuccess: onUnlock
            )
        }
    }

    private var biometricIcon: AppBoxIcon {
        switch biometryKind {
        case .faceID: return .faceID
        case .touchID: return .touchID
        case .opticID: return .opticID
        case .unavailable: return .shield
        }
    }

    private var biometricPrompt: String {
        switch biometryKind {
        case .faceID:
            return copy.text("点击进行 Face ID 解锁", "Tap to unlock with Face ID")
        case .touchID:
            return copy.text("点击进行 Touch ID 解锁", "Tap to unlock with Touch ID")
        case .opticID:
            return copy.text("点击进行 Optic ID 解锁", "Tap to unlock with Optic ID")
        case .unavailable:
            return copy.text("生物识别不可用", "Biometric unlock unavailable")
        }
    }

    private func authenticate() {
        guard !isAuthenticating, biometryKind != .unavailable else { return }
        isAuthenticating = true
        feedback = ""

        Task {
            do {
                try await biometricService.authenticate(
                    reason: copy.text("解锁天涯盒子隐私空间", "Unlock Tianya Box Private Space")
                )
                isAuthenticating = false
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                    onUnlock()
                }
            } catch {
                isAuthenticating = false
                handleAuthenticationError(error)
            }
        }
    }

    private func handleAuthenticationError(_ error: Error) {
        guard let authenticationError = error as? LAError else {
            feedback = copy.text("无法使用生物识别，请使用密码解锁", "Biometric unlock failed. Use your PIN")
            return
        }

        switch authenticationError.code {
        case .userCancel, .appCancel, .systemCancel:
            feedback = ""
        case .biometryLockout:
            feedback = copy.text("生物识别已锁定，请使用密码解锁", "Biometrics are locked. Use your PIN")
        default:
            feedback = copy.text("未能识别，请重试或使用密码", "Not recognized. Try again or use your PIN")
        }
    }
}
