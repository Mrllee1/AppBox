import SwiftUI

enum AppBoxPasswordMode: Equatable {
    case unlock
    case manage
}

private enum AppBoxPINStage: Equatable {
    case overview
    case verifyPrimary
    case create
    case confirm
    case success
}

private enum AppBoxPINIntent: Equatable {
    case unlock
    case createPrimary
    case changePrimary
    case removePrimary
    case createDecoy
    case changeDecoy
    case removeDecoy
}

struct AppBoxPasswordView: View {
    let language: AppBoxLanguage
    let skin: AppBoxSkin
    let mode: AppBoxPasswordMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @FocusState private var isInputFocused: Bool

    @State private var pin = ""
    @State private var firstPIN = ""
    @State private var revealPIN = false
    @State private var stage: AppBoxPINStage
    @State private var intent: AppBoxPINIntent
    @State private var feedback = ""
    @State private var shakeOffset: CGFloat = 0
    @State private var hasPrimary: Bool
    @State private var hasDecoy: Bool
    @State private var confirmation: AppBoxPINIntent?

    private let service: AppBoxPINProviding
    private let onUnlock: ((AppBoxUnlockResult) -> Void)?
    private let onSuccess: (() -> Void)?
    private let onProtectionChange: ((Bool) -> Void)?

    init(
        language: AppBoxLanguage,
        skin: AppBoxSkin,
        mode: AppBoxPasswordMode,
        service: AppBoxPINProviding = AppBoxPINService(),
        onUnlock: ((AppBoxUnlockResult) -> Void)? = nil,
        onSuccess: (() -> Void)? = nil,
        onProtectionChange: ((Bool) -> Void)? = nil
    ) {
        self.language = language
        self.skin = skin
        self.mode = mode
        self.service = service
        self.onUnlock = onUnlock
        self.onSuccess = onSuccess
        self.onProtectionChange = onProtectionChange

        let primaryEnabled = service.hasPIN
        _hasPrimary = State(initialValue: primaryEnabled)
        _hasDecoy = State(initialValue: service.hasDecoyPIN)

        if mode == .unlock {
            _intent = State(initialValue: .unlock)
            _stage = State(initialValue: primaryEnabled ? .verifyPrimary : .success)
        } else if primaryEnabled {
            _intent = State(initialValue: .changePrimary)
            _stage = State(initialValue: .overview)
        } else {
            _intent = State(initialValue: .createPrimary)
            _stage = State(initialValue: .create)
        }
    }

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            AppBoxPrivacyBackground(palette: palette)

            VStack(spacing: 0) {
                AppBoxSheetHeader(
                    title: copy.text("隐私密码", "Privacy PIN"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 22) {
                        header

                        if stage == .overview {
                            managementActions
                        } else if isPINEntryStage {
                            pinEntry
                                .offset(x: shakeOffset)
                        }
                    }
                    .frame(maxWidth: 440)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, AppBoxLayout.pagePadding)
                    .padding(.top, 40)
                    .padding(.bottom, 40)
                }
            }
        }
        .onAppear { updateInputFocus() }
        .onChange(of: stage) { _ in updateInputFocus() }
        .confirmationDialog(
            confirmationTitle,
            isPresented: Binding(
                get: { confirmation != nil },
                set: { if !$0 { confirmation = nil } }
            ),
            titleVisibility: .visible
        ) {
            if let confirmation {
                Button(confirmationConfirmTitle(confirmation), role: .destructive) {
                    begin(confirmation)
                }
            }
            Button(copy.text("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(confirmationMessage)
        }
    }

    private var header: some View {
        VStack(spacing: 16) {
            AppBoxGlyph(icon: stage == .success ? .shieldYes : .shield)
                .frame(width: 46, height: 46)
                .foregroundColor(palette.accent)
                .frame(width: 86, height: 86)
                .appBoxGlassControl(palette, radius: 28, isInteractive: false)

            VStack(spacing: 8) {
                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(palette.primaryText)
                    .multilineTextAlignment(.center)
                Text(subtitle)
                    .font(.subheadline.weight(.medium))
                    .foregroundColor(feedback.isEmpty ? palette.secondaryText : palette.destructive)
                    .multilineTextAlignment(.center)
            }
        }
    }

    private var isPINEntryStage: Bool {
        stage == .verifyPrimary || stage == .create || stage == .confirm
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
                        .frame(width: 54, height: 60)
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
                        .frame(width: 52, height: 60)
                        .appBoxGlassControl(palette, radius: 16)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copy.text("显示密码", "Show PIN"))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = true }
    }

    private var managementActions: some View {
        VStack(spacing: 14) {
            AppBoxPasswordStatusCard(
                icon: .lock,
                title: copy.text("主密码", "Main PIN"),
                subtitle: hasPrimary
                    ? copy.text("用于进入真实空间", "Opens the private space")
                    : copy.text("尚未设置", "Not set"),
                isEnabled: hasPrimary,
                palette: palette
            )

            primaryActions

            AppBoxPasswordStatusCard(
                icon: .shield,
                title: copy.text("伪装密码", "Decoy PIN"),
                subtitle: hasDecoy
                    ? copy.text("输入后进入专注空间", "Opens the clean focus space")
                    : copy.text("可选，用于隐私伪装", "Optional privacy decoy"),
                isEnabled: hasDecoy,
                palette: palette
            )
            .padding(.top, 8)

            decoyActions
        }
    }

    @ViewBuilder
    private var primaryActions: some View {
        if hasPrimary {
            AppBoxPasswordActionButton(
                title: copy.text("修改主密码", "Change Main PIN"),
                icon: .edit,
                style: .primary,
                palette: palette
            ) {
                begin(.changePrimary)
            }

            AppBoxPasswordActionButton(
                title: copy.text("移除主密码", "Remove Main PIN"),
                icon: .trash,
                style: .destructive,
                palette: palette
            ) {
                confirmation = .removePrimary
            }
        } else {
            AppBoxPasswordActionButton(
                title: copy.text("设置主密码", "Set Main PIN"),
                icon: .lock,
                style: .primary,
                palette: palette
            ) {
                begin(.createPrimary)
            }
        }
    }

    @ViewBuilder
    private var decoyActions: some View {
        if hasPrimary {
            AppBoxPasswordActionButton(
                title: hasDecoy ? copy.text("修改伪装密码", "Change Decoy PIN") : copy.text("设置伪装密码", "Set Decoy PIN"),
                icon: .shield,
                style: .secondary,
                palette: palette
            ) {
                begin(hasDecoy ? .changeDecoy : .createDecoy)
            }

            if hasDecoy {
                AppBoxPasswordActionButton(
                    title: copy.text("关闭伪装空间", "Turn Off Decoy Space"),
                    icon: .trash,
                    style: .destructive,
                    palette: palette
                ) {
                    confirmation = .removeDecoy
                }
            }
        } else {
            Text(copy.text("先设置主密码后，再开启伪装空间。", "Set a main PIN before enabling Decoy Space."))
                .font(.footnote.weight(.medium))
                .foregroundColor(palette.secondaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
        }
    }

    private var title: String {
        switch stage {
        case .overview:
            return copy.text("密码保护", "PIN Protection")
        case .verifyPrimary:
            return copy.text("验证主密码", "Verify Main PIN")
        case .create:
            switch intent {
            case .createPrimary: return copy.text("设置主密码", "Set Main PIN")
            case .changePrimary: return copy.text("设置新主密码", "Set New Main PIN")
            case .createDecoy: return copy.text("设置伪装密码", "Set Decoy PIN")
            case .changeDecoy: return copy.text("设置新伪装密码", "Set New Decoy PIN")
            default: return copy.text("输入密码", "Enter PIN")
            }
        case .confirm:
            return copy.text("再次输入", "Confirm PIN")
        case .success:
            switch intent {
            case .unlock: return copy.text("验证成功", "Verified")
            case .createPrimary: return copy.text("主密码已设置", "Main PIN Set")
            case .changePrimary: return copy.text("主密码已修改", "Main PIN Changed")
            case .removePrimary: return copy.text("主密码已移除", "Main PIN Removed")
            case .createDecoy: return copy.text("伪装密码已设置", "Decoy PIN Set")
            case .changeDecoy: return copy.text("伪装密码已修改", "Decoy PIN Changed")
            case .removeDecoy: return copy.text("伪装空间已关闭", "Decoy Space Off")
            }
        }
    }

    private var subtitle: String {
        if !feedback.isEmpty { return feedback }
        switch stage {
        case .overview:
            return copy.text("主密码进入真实空间，伪装密码进入专注空间。", "Main PIN opens private space. Decoy PIN opens focus space.")
        case .verifyPrimary:
            return copy.text("请输入当前 4 位主密码", "Enter your current 4-digit main PIN")
        case .create:
            return copy.text("请输入 4 位数字", "Enter a 4-digit PIN")
        case .confirm:
            return copy.text("请再次输入密码", "Enter the PIN again")
        case .success:
            if intent == .removePrimary {
                return copy.text("伪装密码也已同步移除", "The decoy PIN was removed too")
            }
            return copy.text("设置已保存", "Settings saved")
        }
    }

    private var confirmationTitle: String {
        switch confirmation {
        case .removePrimary:
            return copy.text("移除主密码？", "Remove Main PIN?")
        case .removeDecoy:
            return copy.text("关闭伪装空间？", "Turn Off Decoy Space?")
        default:
            return ""
        }
    }

    private var confirmationMessage: String {
        switch confirmation {
        case .removePrimary:
            return copy.text("移除后，进入应用将不再需要密码，伪装密码也会被清除。", "The app will no longer require a PIN and the decoy PIN will be cleared.")
        case .removeDecoy:
            return copy.text("关闭后，伪装密码将失效。", "The decoy PIN will stop working.")
        default:
            return ""
        }
    }

    private func confirmationConfirmTitle(_ intent: AppBoxPINIntent) -> String {
        switch intent {
        case .removePrimary:
            return copy.text("移除主密码", "Remove Main PIN")
        case .removeDecoy:
            return copy.text("关闭伪装空间", "Turn Off")
        default:
            return copy.text("确认", "Confirm")
        }
    }

    private func handlePIN(_ value: String) {
        switch stage {
        case .overview:
            break
        case .verifyPrimary:
            guard service.verify(value) else {
                fail(copy.text("主密码错误，请重试", "Incorrect main PIN"))
                return
            }
            feedback = ""
            pin = ""
            switch intent {
            case .changePrimary, .createDecoy, .changeDecoy:
                stage = .create
            case .removePrimary:
                removePrimary()
            case .removeDecoy:
                removeDecoy()
            case .unlock:
                completeUnlock(.real)
            case .createPrimary:
                stage = .create
            }
        case .create:
            firstPIN = value
            feedback = ""
            pin = ""
            stage = .confirm
        case .confirm:
            guard value == firstPIN else {
                firstPIN = ""
                pin = ""
                stage = .create
                fail(copy.text("两次密码不一致", "PINs do not match"))
                return
            }
            saveConfirmedPIN(value)
        case .success:
            break
        }
    }

    private func saveConfirmedPIN(_ value: String) {
        do {
            switch intent {
            case .createPrimary, .changePrimary:
                if service.verifyDecoy(value) {
                    fail(copy.text("主密码不能与伪装密码相同", "Main PIN cannot match the decoy PIN"))
                    firstPIN = ""
                    pin = ""
                    stage = .create
                    return
                }
                try service.save(value)
            case .createDecoy, .changeDecoy:
                guard !service.verify(value) else {
                    fail(copy.text("伪装密码不能与主密码相同", "Decoy PIN cannot match the main PIN"))
                    firstPIN = ""
                    pin = ""
                    stage = .create
                    return
                }
                try service.saveDecoy(value)
            default:
                break
            }

            refreshStatus()
            onProtectionChange?(service.hasPIN)
            feedback = ""
            pin = ""
            stage = .success
            dismissAfterSuccess()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func begin(_ newIntent: AppBoxPINIntent) {
        intent = newIntent
        feedback = ""
        firstPIN = ""
        pin = ""
        revealPIN = false
        confirmation = nil

        switch newIntent {
        case .createPrimary:
            stage = .create
        case .changePrimary, .createDecoy, .changeDecoy, .removePrimary, .removeDecoy:
            stage = service.hasPIN ? .verifyPrimary : .create
        case .unlock:
            stage = .verifyPrimary
        }
    }

    private func removePrimary() {
        do {
            try service.remove()
            refreshStatus()
            onProtectionChange?(false)
            feedback = ""
            pin = ""
            stage = .success
            dismissAfterSuccess()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func removeDecoy() {
        do {
            try service.removeDecoy()
            refreshStatus()
            onProtectionChange?(service.hasPIN)
            feedback = ""
            pin = ""
            stage = .success
            dismissAfterSuccess()
        } catch {
            fail(error.localizedDescription)
        }
    }

    private func completeUnlock(_ result: AppBoxUnlockResult) {
        onUnlock?(result)
        onSuccess?()
        dismiss()
    }

    private func fail(_ message: String) {
        feedback = message
        pin = ""
        runFailureAnimation()
    }

    private func refreshStatus() {
        hasPrimary = service.hasPIN
        hasDecoy = service.hasDecoyPIN
    }

    private func updateInputFocus() {
        isInputFocused = isPINEntryStage
    }

    private func dismissAfterSuccess() {
        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            if mode == .manage {
                if service.hasPIN {
                    stage = .overview
                } else {
                    dismiss()
                }
            } else {
                dismiss()
            }
        }
    }

    private func runFailureAnimation() {
        guard !reduceMotion else { return }
        withAnimation(.linear(duration: 0.055)) { shakeOffset = -8 }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.055) {
            withAnimation(.linear(duration: 0.055)) { shakeOffset = 8 }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.11) {
            withAnimation(.spring(response: 0.20, dampingFraction: 0.62)) { shakeOffset = 0 }
        }
    }
}

private struct AppBoxPasswordStatusCard: View {
    let icon: AppBoxIcon
    let title: String
    let subtitle: String
    let isEnabled: Bool
    let palette: AppBoxPalette

    var body: some View {
        HStack(spacing: 14) {
            AppBoxGlyph(icon: icon)
                .frame(width: 22, height: 22)
                .foregroundColor(isEnabled ? palette.accent : palette.secondaryText)
                .frame(width: 46, height: 46)
                .background((isEnabled ? palette.accentSoft : palette.mutedSurface).opacity(0.88))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(palette.primaryText)
                Text(subtitle)
                    .font(.footnote.weight(.medium))
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(2)
            }

            Spacer()

            Circle()
                .fill(isEnabled ? Color(uiColor: .systemGreen) : palette.secondaryText.opacity(0.28))
                .frame(width: 9, height: 9)
        }
        .padding(16)
        .appBoxSurface(palette, addsShadow: false)
    }
}

private enum AppBoxPasswordActionStyle {
    case primary
    case secondary
    case destructive
}

private struct AppBoxPasswordActionButton: View {
    let title: String
    let icon: AppBoxIcon
    let style: AppBoxPasswordActionStyle
    let palette: AppBoxPalette
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                AppBoxGlyph(icon: icon)
                    .frame(width: 18, height: 18)
                Text(title)
                    .font(.body.weight(.semibold))
                Spacer()
                AppBoxGlyph(icon: .arrowRight)
                    .frame(width: 14, height: 14)
                    .opacity(0.72)
            }
            .foregroundColor(foreground)
            .padding(.horizontal, 16)
            .frame(height: 50)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private var foreground: Color {
        switch style {
        case .primary:
            return .white
        case .secondary:
            return palette.accent
        case .destructive:
            return palette.destructive
        }
    }

    private var background: Color {
        switch style {
        case .primary:
            return palette.accent
        case .secondary:
            return palette.accentSoft
        case .destructive:
            return palette.destructive.opacity(0.11)
        }
    }
}
