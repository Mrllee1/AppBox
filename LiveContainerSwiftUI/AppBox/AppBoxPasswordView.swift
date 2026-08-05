import SwiftUI

enum AppBoxPasswordMode: Equatable {
    case unlock
    case manage
}

private enum AppBoxPINStage {
    case overview
    case verify
    case create
    case confirm
    case success
}

private enum AppBoxPINIntent {
    case unlock
    case create
    case change
    case remove
}

struct AppBoxPasswordView: View {
    let language: AppBoxLanguage
    let skin: AppBoxSkin
    let mode: AppBoxPasswordMode

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @FocusState private var isInputFocused: Bool

    @State private var pin = ""
    @State private var firstPIN = ""
    @State private var revealPIN = false
    @State private var stage: AppBoxPINStage
    @State private var intent: AppBoxPINIntent
    @State private var feedback = ""
    @State private var showRemoveConfirmation = false

    private let service: AppBoxPINProviding
    private let onSuccess: (() -> Void)?
    private let onProtectionChange: ((Bool) -> Void)?

    init(
        language: AppBoxLanguage,
        skin: AppBoxSkin,
        mode: AppBoxPasswordMode,
        service: AppBoxPINProviding = AppBoxPINService(),
        onSuccess: (() -> Void)? = nil,
        onProtectionChange: ((Bool) -> Void)? = nil
    ) {
        self.language = language
        self.skin = skin
        self.mode = mode
        self.service = service
        self.onSuccess = onSuccess
        self.onProtectionChange = onProtectionChange

        if mode == .unlock {
            _intent = State(initialValue: .unlock)
            _stage = State(initialValue: service.hasPIN ? .verify : .create)
        } else if service.hasPIN {
            _intent = State(initialValue: .change)
            _stage = State(initialValue: .overview)
        } else {
            _intent = State(initialValue: .create)
            _stage = State(initialValue: .create)
        }
    }

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AppBoxSheetHeader(
                    title: copy.text("隐私空间", "Private Space"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                Spacer().frame(height: 54)

                AppBoxGlyph(icon: stage == .success ? .shieldYes : .shield)
                    .frame(width: 48, height: 48)
                    .foregroundColor(palette.accent)

                Text(title)
                    .font(.title2.weight(.semibold))
                    .foregroundColor(palette.primaryText)
                    .padding(.top, 22)
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(feedback.isEmpty ? palette.secondaryText : palette.destructive)
                    .padding(.top, 8)

                if stage == .overview {
                    managementActions
                        .padding(.top, 32)
                } else if isPINEntryStage {
                    pinEntry
                        .padding(.top, 28)
                }

                Spacer()
            }
        }
        .onAppear { updateInputFocus() }
        .onChange(of: stage) { _ in updateInputFocus() }
        .confirmationDialog(
            copy.text("移除隐私密码？", "Remove privacy PIN?"),
            isPresented: $showRemoveConfirmation,
            titleVisibility: .visible
        ) {
            Button(copy.text("移除密码", "Remove PIN"), role: .destructive) {
                begin(.remove)
            }
            Button(copy.text("取消", "Cancel"), role: .cancel) {}
        } message: {
            Text(copy.text("移除后，进入应用将不再需要解锁。", "The app will no longer require unlocking."))
        }
    }

    private var isPINEntryStage: Bool {
        stage == .verify || stage == .create || stage == .confirm
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
                    RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous)
                        .fill(palette.surface)
                        .overlay {
                            if index < pin.count {
                                let character = pin[pin.index(pin.startIndex, offsetBy: index)]
                                Text(revealPIN ? String(character) : "•")
                                    .font(.title2.weight(.semibold))
                                    .foregroundColor(palette.primaryText)
                            }
                        }
                        .overlay {
                            RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous)
                                .stroke(index == pin.count ? palette.accent : palette.border, lineWidth: index == pin.count ? 1.5 : 1)
                        }
                        .frame(width: 54, height: 60)
                }
                Button {
                    revealPIN.toggle()
                } label: {
                    AppBoxGlyph(icon: revealPIN ? .eye : .eyeOff)
                        .frame(width: 21, height: 21)
                        .foregroundColor(palette.secondaryText)
                        .frame(width: 44, height: 60)
                        .appBoxGlassControl(palette, radius: AppBoxLayout.cardRadius)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(copy.text("显示密码", "Show PIN"))
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isInputFocused = true }
    }

    private var managementActions: some View {
        VStack(spacing: 12) {
            Button {
                begin(.change)
            } label: {
                Label {
                    Text(copy.text("修改密码", "Change PIN"))
                        .font(.body.weight(.semibold))
                } icon: {
                    AppBoxGlyph(icon: .edit)
                        .frame(width: 18, height: 18)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                showRemoveConfirmation = true
            } label: {
                Label {
                    Text(copy.text("移除密码", "Remove PIN"))
                        .font(.body.weight(.semibold))
                } icon: {
                    AppBoxGlyph(icon: .trash)
                        .frame(width: 18, height: 18)
                }
                .foregroundColor(palette.destructive)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(palette.destructive.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: 320)
        .padding(.horizontal, AppBoxLayout.pagePadding)
    }

    private var title: String {
        switch stage {
        case .overview: return copy.text("密码保护已开启", "PIN Protection On")
        case .verify: return copy.text("验证密码", "Verify PIN")
        case .create:
            return intent == .change
                ? copy.text("设置新密码", "Set New PIN")
                : copy.text("设置密码", "Set PIN")
        case .confirm: return copy.text("再次输入", "Confirm PIN")
        case .success:
            switch intent {
            case .unlock: return copy.text("验证成功", "Verified")
            case .create: return copy.text("密码已设置", "PIN Set")
            case .change: return copy.text("密码已修改", "PIN Changed")
            case .remove: return copy.text("密码已移除", "PIN Removed")
            }
        }
    }

    private var subtitle: String {
        if !feedback.isEmpty { return feedback }
        switch stage {
        case .overview: return copy.text("你可以修改或移除当前密码", "Change or remove your current PIN")
        case .verify:
            return copy.text("请输入当前 4 位密码", "Enter your current 4-digit PIN")
        case .create:
            return intent == .change
                ? copy.text("请输入新的 4 位密码", "Enter a new 4-digit PIN")
                : copy.text("请输入 4 位数字", "Enter a 4-digit PIN")
        case .confirm: return copy.text("请再次输入密码", "Enter the PIN again")
        case .success:
            return intent == .remove
                ? copy.text("进入应用将不再需要解锁", "Unlocking is no longer required")
                : copy.text("密码已安全保存", "Your PIN is saved")
        }
    }

    private func handlePIN(_ value: String) {
        switch stage {
        case .overview:
            break
        case .verify:
            if service.verify(value) {
                feedback = ""
                switch intent {
                case .unlock:
                    stage = .success
                    dismissAfterSuccess()
                case .change:
                    stage = .create
                    pin = ""
                case .remove:
                    removePIN()
                case .create:
                    stage = .create
                    pin = ""
                }
            } else {
                feedback = copy.text("密码错误，请重试", "Incorrect PIN")
                pin = ""
            }
        case .create:
            firstPIN = value
            feedback = ""
            stage = .confirm
            pin = ""
        case .confirm:
            guard value == firstPIN else {
                feedback = copy.text("两次密码不一致", "PINs do not match")
                firstPIN = ""
                pin = ""
                stage = .create
                return
            }
            do {
                try service.save(value)
                onProtectionChange?(true)
                feedback = ""
                stage = .success
                dismissAfterSuccess()
            } catch {
                feedback = error.localizedDescription
                pin = ""
            }
        case .success:
            break
        }
    }

    private func begin(_ newIntent: AppBoxPINIntent) {
        intent = newIntent
        feedback = ""
        firstPIN = ""
        pin = ""
        revealPIN = false
        stage = .verify
    }

    private func removePIN() {
        do {
            try service.remove()
            onProtectionChange?(false)
            stage = .success
            pin = ""
            feedback = ""
            dismissAfterSuccess()
        } catch {
            feedback = error.localizedDescription
            pin = ""
        }
    }

    private func updateInputFocus() {
        isInputFocused = isPINEntryStage
    }

    private func dismissAfterSuccess() {
        onSuccess?()
        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            dismiss()
        }
    }
}
