import SwiftUI

enum AppBoxPasswordMode: Equatable {
    case unlock
    case manage
}

private enum AppBoxPINStage {
    case verify
    case create
    case confirm
    case success
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
    @State private var feedback = ""

    private let service: AppBoxPINProviding

    init(
        language: AppBoxLanguage,
        skin: AppBoxSkin,
        mode: AppBoxPasswordMode,
        service: AppBoxPINProviding = AppBoxPINService()
    ) {
        self.language = language
        self.skin = skin
        self.mode = mode
        self.service = service
        _stage = State(initialValue: service.hasPIN ? .verify : .create)
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
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundColor(palette.primaryText)
                    .padding(.top, 22)
                Text(subtitle)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(feedback.isEmpty ? palette.secondaryText : palette.destructive)
                    .padding(.top, 8)

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
                                            .font(.system(size: 22, weight: .semibold))
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
                .padding(.top, 28)
                .contentShape(Rectangle())
                .onTapGesture { isInputFocused = true }

                if service.hasPIN && mode == .manage && stage == .verify {
                    Button(role: .destructive) {
                        removePIN()
                    } label: {
                        Text(copy.text("移除现有密码", "Remove current PIN"))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(palette.destructive)
                            .padding(.horizontal, 18)
                            .frame(height: 42)
                            .background(palette.destructive.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 24)
                }

                Spacer()
            }
        }
        .onAppear { isInputFocused = true }
    }

    private var title: String {
        switch stage {
        case .verify: return copy.text("验证密码", "Verify PIN")
        case .create: return copy.text("设置密码", "Set PIN")
        case .confirm: return copy.text("再次输入", "Confirm PIN")
        case .success: return copy.text("设置完成", "PIN Ready")
        }
    }

    private var subtitle: String {
        if !feedback.isEmpty { return feedback }
        switch stage {
        case .verify: return copy.text("请输入 4 位数字", "Enter your 4-digit PIN")
        case .create: return copy.text("请输入 4 位数字", "Enter a 4-digit PIN")
        case .confirm: return copy.text("请再次输入密码", "Enter the PIN again")
        case .success: return copy.text("密码已安全保存", "Your PIN is saved")
        }
    }

    private func handlePIN(_ value: String) {
        switch stage {
        case .verify:
            if service.verify(value) {
                feedback = ""
                if mode == .manage {
                    stage = .create
                    pin = ""
                } else {
                    stage = .success
                    dismissAfterSuccess()
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

    private func removePIN() {
        do {
            try service.remove()
            stage = .create
            pin = ""
            feedback = copy.text("密码已移除", "PIN removed")
        } catch {
            feedback = error.localizedDescription
        }
    }

    private func dismissAfterSuccess() {
        Task {
            try? await Task.sleep(nanoseconds: 650_000_000)
            dismiss()
        }
    }
}
