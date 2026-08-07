import SwiftUI

enum AppBoxSpaceSession: Equatable {
    case real
    case focus
    case decoy
}

@MainActor
final class AppBoxLockController: ObservableObject {
    @Published private(set) var isLocked: Bool
    @Published private(set) var currentSpace: AppBoxSpaceSession?

    private static let appCenterActivatedKey = "appbox.appCenterActivatedFromExternalIntent"

    private let pinService: AppBoxPINProviding
    private let forceLockedForDebug: Bool
    private let bypassPINForDebug: Bool
    private var unlockTarget: AppBoxSpaceSession

    init(pinService: AppBoxPINProviding = AppBoxPINService()) {
        self.pinService = pinService
        unlockTarget = Self.persistedDefaultSpace()
#if DEBUG
        forceLockedForDebug = ProcessInfo.processInfo.environment["APPBOX_DEBUG_FORCE_LOCKED"] == "1"
        bypassPINForDebug = Self.debugBypassPINRequested()
#else
        forceLockedForDebug = false
        bypassPINForDebug = false
#endif
        let shouldLock = !bypassPINForDebug && (forceLockedForDebug || pinService.hasPIN)
        isLocked = shouldLock
        currentSpace = shouldLock ? nil : Self.persistedDefaultSpace()
    }

    var protectionEnabled: Bool {
        !bypassPINForDebug && (forceLockedForDebug || pinService.hasPIN)
    }

    private var defaultSpace: AppBoxSpaceSession {
        Self.persistedDefaultSpace()
    }

    private static func persistedDefaultSpace() -> AppBoxSpaceSession {
        UserDefaults.standard.bool(forKey: appCenterActivatedKey) ? .real : .focus
    }

#if DEBUG
    private static func debugBypassPINRequested() -> Bool {
        let processInfo = ProcessInfo.processInfo
        if processInfo.environment["APPBOX_DEBUG_BYPASS_PIN"] == "1" {
            return true
        }
        return processInfo.arguments.contains { argument in
            argument == "--appbox-debug-bypass-pin" || argument.contains("debug_bypass_pin=1")
        }
    }
#endif

    func confirmExternalAppCenterActivation() {
        UserDefaults.standard.set(true, forKey: Self.appCenterActivatedKey)
        unlockTarget = .real
        currentSpace = .real
        isLocked = false
    }

    func handleScenePhase(_ phase: ScenePhase) {
        switch phase {
        case .active:
            break
        case .inactive, .background:
            lockIfNeeded()
        @unknown default:
            lockIfNeeded()
        }
    }

    func unlock(_ result: AppBoxUnlockResult) {
        switch result {
        case .real:
            currentSpace = unlockTarget
            isLocked = false
        case .decoy:
            currentSpace = .decoy
            isLocked = false
        case .failed:
            break
        }
    }

    func enterRealSpaceWithoutProtection() {
        guard !protectionEnabled else {
            lockIfNeeded()
            return
        }
        currentSpace = .real
        isLocked = false
    }

    func requireUnlock() {
        guard protectionEnabled else {
            enterRealSpaceWithoutProtection()
            return
        }
        unlockTarget = .real
        currentSpace = nil
        isLocked = true
    }

    func returnToDefaultSpace() {
        currentSpace = defaultSpace
        isLocked = false
    }

    func synchronizeProtectionState() {
        if protectionEnabled {
            if currentSpace == nil {
                unlockTarget = defaultSpace
                isLocked = true
            }
        } else {
            isLocked = false
            if currentSpace == nil {
                currentSpace = defaultSpace
            }
        }
    }

    private func lockIfNeeded() {
        guard protectionEnabled else {
            isLocked = false
            if currentSpace == nil {
                currentSpace = defaultSpace
            }
            return
        }
        unlockTarget = defaultSpace
        currentSpace = nil
        isLocked = true
    }
}

struct AppBoxLockScreen: View {
    let language: AppBoxLanguage
    let skin: AppBoxSkin
    let onUnlock: (AppBoxUnlockResult) -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool

    @State private var pin = ""
    @State private var revealPIN = false
    @State private var feedback = ""
    @State private var shakeOffset: CGFloat = 0

    private let service: AppBoxPINProviding

    init(
        language: AppBoxLanguage,
        skin: AppBoxSkin,
        service: AppBoxPINProviding = AppBoxPINService(),
        onUnlock: @escaping (AppBoxUnlockResult) -> Void
    ) {
        self.language = language
        self.skin = skin
        self.service = service
        self.onUnlock = onUnlock
    }

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            AppBoxPrivacyBackground(palette: palette)

            Text(copy.text("隐私空间", "Private Space"))
                .font(.headline.weight(.semibold))
                .foregroundColor(palette.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 58)
                .frame(maxHeight: .infinity, alignment: .top)
                .accessibilityAddTraits(.isHeader)

            VStack(spacing: 20) {
                AppBoxGlyph(icon: .shield)
                    .frame(width: 48, height: 48)
                    .foregroundColor(palette.accent)
                    .frame(width: 86, height: 86)
                    .appBoxGlassControl(palette, radius: 28, isInteractive: false)

                VStack(spacing: 8) {
                    Text(copy.text("请输入密码", "Enter PIN"))
                        .font(.title2.weight(.semibold))
                        .foregroundColor(palette.primaryText)
                    Text(feedback.isEmpty ? copy.text("4 位数字密码", "4-digit numeric PIN") : feedback)
                        .font(.subheadline.weight(.medium))
                        .foregroundColor(feedback.isEmpty ? palette.secondaryText : palette.destructive)
                }

                pinEntry
                    .offset(x: shakeOffset)
                    .padding(.top, 8)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            .padding(.horizontal, AppBoxLayout.pagePadding)
            .padding(.vertical, 72)
        }
        .onAppear { isInputFocused = true }
    }

    private var pinEntry: some View {
        ZStack {
            TextField("", text: $pin)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isInputFocused)
                .frame(width: 1, height: 1)
                .opacity(0.01)
                .onChange(of: pin) { value in
                    let filtered = String(value.filter(\.isNumber).prefix(4))
                    if filtered != value { pin = filtered }
                    if filtered.count == 4 { handlePIN(filtered) }
                }

            HStack(spacing: 10) {
                ForEach(0..<4, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(palette.elevatedSurface.opacity(0.92))
                        .frame(width: 56, height: 62)
                        .overlay {
                            if index < pin.count {
                                let character = pin[pin.index(pin.startIndex, offsetBy: index)]
                                Text(revealPIN ? String(character) : "•")
                                    .font(.title2.weight(.bold))
                                    .foregroundColor(palette.primaryText)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(index == pin.count ? palette.accent : palette.border.opacity(0.65), lineWidth: index == pin.count ? 1.8 : 1)
                        }
                }

                Button {
                    revealPIN.toggle()
                } label: {
                    AppBoxGlyph(icon: revealPIN ? .eye : .eyeOff)
                        .frame(width: 21, height: 21)
                        .foregroundColor(palette.secondaryText)
                        .frame(width: 52, height: 62)
                        .appBoxGlassControl(palette, radius: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copy.text("显示密码", "Show PIN"))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = true }
    }

    private func handlePIN(_ value: String) {
        let result = service.evaluate(value)
        switch result {
        case .real, .decoy:
            feedback = ""
            pin = ""
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                onUnlock(result)
            }
        case .failed:
            feedback = ""
            pin = ""
            withAnimation(reduceMotion ? nil : .easeOut(duration: 0.18)) {
                onUnlock(.decoy)
            }
        }
    }

    private func runFailureAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.055)) { shakeOffset = -9 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
            withAnimation(.linear(duration: 0.055)) { shakeOffset = 9 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.62)) { shakeOffset = 0 }
        }
    }
}
