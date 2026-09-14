import SwiftUI
import UIKit

struct TempMailRootView: View {
  @EnvironmentObject private var store: TempMailStore
  @AppStorage("tempMail.appearanceMode") private var appearanceModeRaw = TempMailAppearanceMode.system.rawValue
  @AppStorage("tempMail.animationsEnabled") private var animationsEnabled = true
  @State private var selectedTab: TempMailTab
  @State private var drawerPresented: Bool
  @State private var createPresented = false

  let onInternalUnlock: () -> Void

  init(onInternalUnlock: @escaping () -> Void) {
    self.onInternalUnlock = onInternalUnlock
    let arguments = ProcessInfo.processInfo.arguments
    let initialTab: TempMailTab
    if arguments.contains("--temp-mail-test-tab=inbox") {
      initialTab = .inbox
    } else if arguments.contains("--temp-mail-test-tab=manage") {
      initialTab = .manage
    } else {
      initialTab = .address
    }
    _selectedTab = State(initialValue: initialTab)
    _drawerPresented = State(initialValue: arguments.contains("--temp-mail-test-drawer"))
  }

  private var storedAppearanceMode: TempMailAppearanceMode {
    get { TempMailAppearanceMode(rawValue: appearanceModeRaw) ?? .system }
    nonmutating set { appearanceModeRaw = newValue.rawValue }
  }

  private var effectiveAppearanceMode: TempMailAppearanceMode {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--temp-mail-test-theme=light") { return .light }
    if arguments.contains("--temp-mail-test-theme=dark") { return .dark }
    return storedAppearanceMode
  }

  private var appearanceBinding: Binding<TempMailAppearanceMode> {
    Binding(
      get: { storedAppearanceMode },
      set: { storedAppearanceMode = $0 }
    )
  }

  var body: some View {
    ZStack {
      TempMailPalette.background.ignoresSafeArea()

      switch store.phase {
      case .loading:
        TempMailLaunchView(animationsEnabled: animationsEnabled)
      case let .failed(message):
        TempMailFailureView(message: message) {
          Task { await store.retry() }
        }
      case .ready:
        mainTabs
      }

      if drawerPresented {
        TempMailDrawer(
          isPresented: $drawerPresented,
          appearanceMode: appearanceBinding,
          animationsEnabled: $animationsEnabled,
          onCreateMailbox: { createPresented = true },
          onInternalUnlock: onInternalUnlock
        )
        .transition(.opacity)
        .zIndex(20)
      }
    }
    .tint(TempMailPalette.green)
    .preferredColorScheme(effectiveAppearanceMode.colorScheme)
    .background {
      TempMailAppearanceBridge(style: effectiveAppearanceMode.userInterfaceStyle)
        .frame(width: 0, height: 0)
    }
    .animation(animationsEnabled ? .easeInOut(duration: 0.25) : nil, value: drawerPresented)
    .onAppear {
      if let forcedTab = forcedTestTab {
        selectedTab = forcedTab
      }
    }
    .task { await store.start() }
    .sheet(isPresented: $createPresented) {
      TempMailCreateMailboxSheet(domains: store.domains)
        .environmentObject(store)
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }
    .overlay(alignment: .top) {
      if let message = store.operationMessage {
        TempMailToast(message: message)
          .padding(.top, 10)
          .transition(.move(edge: .top).combined(with: .opacity))
          .zIndex(40)
      }
    }
    .animation(animationsEnabled ? .spring(response: 0.28, dampingFraction: 0.86) : nil, value: store.operationMessage)
  }

  private var forcedTestTab: TempMailTab? {
    let arguments = ProcessInfo.processInfo.arguments
    if arguments.contains("--temp-mail-test-tab=address") { return .address }
    if arguments.contains("--temp-mail-test-tab=inbox") { return .inbox }
    if arguments.contains("--temp-mail-test-tab=manage") { return .manage }
    return nil
  }

  private var mainTabs: some View {
    // On iOS 26 the system TabView is rendered in the native Liquid Glass
    // layer. Keeping it system-owned also preserves correct safe-area,
    // accessibility and iPad behaviour without a visual fallback.
    TabView(selection: $selectedTab) {
      TempMailAddressView(
        drawerPresented: $drawerPresented,
        createPresented: $createPresented,
        animationsEnabled: animationsEnabled
      )
      .tabItem { Label("邮箱", systemImage: "envelope.fill") }
      .tag(TempMailTab.address)

      TempMailInboxView(
        drawerPresented: $drawerPresented,
        animationsEnabled: animationsEnabled
      )
      .tabItem { Label("收件箱", systemImage: "tray.full.fill") }
      .badge(store.unreadCount)
      .tag(TempMailTab.inbox)

      TempMailManagerView(
        drawerPresented: $drawerPresented,
        createPresented: $createPresented
      )
      .tabItem { Label("管理", systemImage: "rectangle.stack.fill") }
      .tag(TempMailTab.manage)
    }
  }
}

private struct TempMailLaunchView: View {
  let animationsEnabled: Bool
  @State private var floating = false

  var body: some View {
    VStack(spacing: 20) {
      TempMailLogoMark()
        .frame(width: 112, height: 112)
        .offset(y: floating ? -5 : 5)
        .animation(
          animationsEnabled
            ? .easeInOut(duration: 1.15).repeatForever(autoreverses: true)
            : nil,
          value: floating
        )
      Text("正在准备您的临时邮箱…")
        .font(.headline)
      ProgressView()
        .controlSize(.regular)
        .tint(TempMailPalette.green)
    }
    .onAppear { floating = true }
    .accessibilityElement(children: .combine)
    .accessibilityLabel("正在准备临时邮箱")
  }
}

private struct TempMailFailureView: View {
  let message: String
  let retry: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      Image(systemName: "wifi.exclamationmark")
        .font(.system(size: 45, weight: .medium))
        .foregroundStyle(TempMailPalette.secondaryText)
      Text("暂时无法加载")
        .font(.title3.weight(.semibold))
      Text(message)
        .font(.subheadline)
        .foregroundStyle(.secondary)
        .multilineTextAlignment(.center)
        .padding(.horizontal, 34)
      Button("重新连接", action: retry)
        .buttonStyle(TempMailPrimaryButtonStyle())
        .frame(maxWidth: 240)
    }
  }
}

private struct TempMailAddressView: View {
  @EnvironmentObject private var store: TempMailStore
  @Binding var drawerPresented: Bool
  @Binding var createPresented: Bool
  let animationsEnabled: Bool
  @State private var replaceConfirmation = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 20) {
          if let mailbox = store.selectedMailbox {
            TempMailEnvelopeCard(mailbox: mailbox, animationsEnabled: animationsEnabled)

            Button {
              replaceConfirmation = true
            } label: {
              HStack(spacing: 9) {
                if store.isCreating {
                  ProgressView().tint(TempMailPalette.secondaryText)
                } else {
                  Image(systemName: "arrow.triangle.2.circlepath")
                }
                Text(store.isCreating ? "正在更换…" : "更换邮箱地址")
              }
              .font(.subheadline.weight(.medium))
              .foregroundStyle(TempMailPalette.secondaryText)
              .padding(.horizontal, 20)
              .frame(minHeight: 44)
              .contentShape(Rectangle())
            }
            .buttonStyle(TempMailScaleButtonStyle())
            .disabled(store.isCreating)

          } else {
            TempMailNoMailboxCard { createPresented = true }
          }
        }
        .frame(maxWidth: 520)
        .padding(.horizontal, 24)
        .padding(.top, 50)
        .padding(.bottom, 36)
        .frame(maxWidth: .infinity)
      }
      .background(TempMailPalette.background)
      .toolbar {
        TempMailToolbarContent(
          title: "临时邮箱",
          drawerPresented: $drawerPresented,
          trailingAction: {
            Task { await store.refresh() }
          }
        )
      }
      .confirmationDialog(
        "更换邮箱地址？",
        isPresented: $replaceConfirmation,
        titleVisibility: .visible
      ) {
        Button("生成新地址") { Task { await store.replaceCurrentMailbox() } }
        Button("取消", role: .cancel) {}
      } message: {
        Text("当前地址及其邮件将被删除，此操作无法撤销。")
      }
    }
  }
}

private struct TempMailEnvelopeCard: View {
  @EnvironmentObject private var store: TempMailStore
  @Environment(\.accessibilityReduceMotion) private var reduceMotion
  let mailbox: TempMailbox
  let animationsEnabled: Bool
  @State private var flagRaised = false
  @State private var flagTask: Task<Void, Never>?

  var body: some View {
    ZStack {
      TempMailEnvelopeBackdrop()

      VStack(spacing: 0) {
        TempMailAnimatedFlagMark(isRaised: flagRaised)
          .frame(width: 110, height: 110)
          .animation(
            animationsEnabled && !reduceMotion
              ? .spring(response: 0.28, dampingFraction: 0.76)
              : nil,
            value: flagRaised
          )
          .padding(.top, 6)

        Spacer(minLength: 60)

        Text(mailbox.address)
          .font(.system(size: 21, weight: .semibold, design: .rounded))
          .lineLimit(1)
          .minimumScaleFactor(0.68)
          .multilineTextAlignment(.center)
          .textSelection(.enabled)
          .padding(.horizontal, 19)

        Text("您的临时电子邮件地址")
          .font(.subheadline)
          .foregroundStyle(TempMailPalette.secondaryText)
          .padding(.top, 7)

        Color.clear.frame(height: 18)

        Button(action: copyAddress) {
          Label("复制邮箱地址", systemImage: "doc.on.doc.fill")
            .font(.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 58)
            .background(TempMailPalette.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(TempMailScaleButtonStyle())
        .padding(.horizontal, 25)
        .padding(.bottom, 27)
      }
    }
    .frame(maxWidth: 328)
    .frame(height: 398)
    .onAppear(perform: raiseFlag)
    .onChange(of: mailbox.id) { _, _ in raiseFlag() }
    .onDisappear { flagTask?.cancel() }
  }

  private func copyAddress() {
    store.copyAddress()
    raiseFlag()
  }

  private func raiseFlag() {
    guard animationsEnabled && !reduceMotion else {
      flagTask?.cancel()
      flagRaised = true
      return
    }
    flagTask?.cancel()
    flagRaised = false
    flagTask = Task { @MainActor in
      try? await Task.sleep(for: .milliseconds(70))
      guard !Task.isCancelled else { return }
      flagRaised = true
    }
  }
}

private struct TempMailNoMailboxCard: View {
  let create: () -> Void

  var body: some View {
    VStack(spacing: 18) {
      TempMailLogoMark().frame(width: 104, height: 104)
      Text("创建您的第一个临时邮箱")
        .font(.title3.weight(.semibold))
      Text("无需注册，地址创建后即可接收邮件。")
        .font(.subheadline)
        .foregroundStyle(.secondary)
      Button("创建邮箱", action: create)
        .buttonStyle(TempMailPrimaryButtonStyle())
    }
    .padding(28)
    .frame(maxWidth: 380)
    .tempMailCard(radius: 26)
  }
}

private struct TempMailInboxView: View {
  @EnvironmentObject private var store: TempMailStore
  @Binding var drawerPresented: Bool
  let animationsEnabled: Bool
  @State private var messageToDelete: TempMailMessage?

  var body: some View {
    NavigationStack {
      VStack(spacing: 0) {
        TempMailMailboxPicker()
          .padding(.horizontal, 16)
          .padding(.top, 16)
          .padding(.bottom, 3)

        TempMailPullToRefreshScrollView(
          isRefreshing: store.isRefreshing,
          animationsEnabled: animationsEnabled,
          refresh: { await store.refresh() }
        ) {
          if store.messages.isEmpty {
            TempMailEmptyInboxView(animationsEnabled: animationsEnabled)
          } else {
            LazyVStack(spacing: 6) {
              ForEach(store.messages) { message in
                NavigationLink(value: message) {
                  TempMailMessageRow(message: message)
                }
                .buttonStyle(.plain)
                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                  if !message.isRead {
                    Button {
                      Task { await store.markMessageRead(message) }
                    } label: {
                      Label("已读", systemImage: "envelope.open")
                    }
                    .tint(TempMailPalette.green)
                  }
                }
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                  Button(role: .destructive) {
                    messageToDelete = message
                  } label: {
                    Label("删除", systemImage: "trash")
                  }
                }
              }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 16)
          }
        }
      }
      .background(TempMailPalette.background)
      .toolbar {
        TempMailToolbarContent(
          title: "收件箱",
          drawerPresented: $drawerPresented,
          trailingAction: { Task { await store.refresh() } }
        )
      }
      .navigationDestination(for: TempMailMessage.self) { message in
        TempMailDetailView(messageID: message.id)
      }
      .confirmationDialog(
        "删除这封邮件？",
        isPresented: Binding(
          get: { messageToDelete != nil },
          set: { if !$0 { messageToDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("删除", role: .destructive) {
          if let messageToDelete {
            Task { await store.deleteMessage(messageToDelete) }
          }
          messageToDelete = nil
        }
        Button("取消", role: .cancel) { messageToDelete = nil }
      } message: {
        Text("删除后无法恢复。")
      }
    }
  }
}

private struct TempMailMailboxPicker: View {
  @EnvironmentObject private var store: TempMailStore

  var body: some View {
    Menu {
      ForEach(store.mailboxes) { mailbox in
        Button {
          store.selectMailbox(mailbox)
        } label: {
          if mailbox.id == store.selectedMailbox?.id {
            Label(mailbox.address, systemImage: "checkmark")
          } else {
            Text(mailbox.address)
          }
        }
      }
    } label: {
      HStack(spacing: 10) {
        Image(systemName: "envelope.fill")
          .foregroundStyle(TempMailPalette.green)
        Text(store.selectedMailbox?.address ?? "选择邮箱")
          .font(.subheadline.weight(.medium))
          .foregroundStyle(.primary)
          .lineLimit(1)
        Spacer()
        if store.unreadCount > 0 {
          Text("\(store.unreadCount)")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .frame(height: 22)
            .background(TempMailPalette.green, in: Capsule())
        }
        Image(systemName: "chevron.down")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .padding(.horizontal, 15)
      .frame(height: 50)
      .tempMailCard(radius: 9)
    }
    .buttonStyle(.plain)
  }
}

private struct TempMailMessageRow: View {
  let message: TempMailMessage

  var body: some View {
    VStack(alignment: .leading, spacing: 0) {
      HStack(spacing: 7) {
        Circle()
          .fill(message.isRead ? Color.clear : TempMailPalette.green)
          .frame(width: 10, height: 10)
          .accessibilityHidden(true)
        Text(message.senderTitle)
          .font(.system(size: 16, weight: message.isRead ? .medium : .semibold))
          .lineLimit(1)
        Spacer(minLength: 8)
        Text(message.relativeDateLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tertiary)
      }

      Text(message.displaySubject)
        .font(.system(size: 15, weight: message.isRead ? .regular : .medium))
        .lineLimit(1)
        .padding(.top, 8)

      if !message.displayPreview.isEmpty || message.hasAttachments {
        HStack(alignment: .bottom, spacing: 8) {
          if !message.displayPreview.isEmpty {
            Text(message.displayPreview)
              .font(.system(size: 15))
              .foregroundStyle(TempMailPalette.secondaryText)
              .lineLimit(2)
              .frame(maxWidth: .infinity, alignment: .leading)
          } else {
            Spacer(minLength: 0)
          }
          if message.hasAttachments {
            Image(systemName: "paperclip")
              .font(.caption.weight(.semibold))
              .foregroundStyle(.secondary)
              .accessibilityLabel("包含附件")
          }
        }
        .padding(.top, 1)
      }
    }
    .padding(.horizontal, 18)
    .padding(.vertical, 10)
    .contentShape(Rectangle())
    .tempMailCard(radius: 17)
    .accessibilityElement(children: .combine)
  }
}

private struct TempMailEmptyInboxView: View {
  let animationsEnabled: Bool

  var body: some View {
    TempMailEmptyInboxArtwork(animationsEnabled: animationsEnabled)
      .frame(maxWidth: 390, maxHeight: 510)
      .padding(.horizontal, 12)
      .frame(maxWidth: .infinity, maxHeight: .infinity)
  }
}

private struct TempMailManagerView: View {
  @EnvironmentObject private var store: TempMailStore
  @Binding var drawerPresented: Bool
  @Binding var createPresented: Bool
  @State private var mailboxToDelete: TempMailbox?

  var body: some View {
    NavigationStack {
      ScrollView {
        LazyVStack(spacing: 10) {
          ForEach(store.mailboxes) { mailbox in
            TempMailManagerRow(
              mailbox: mailbox,
              isSelected: mailbox.id == store.selectedMailbox?.id,
              select: { store.selectMailbox(mailbox) },
              copy: { store.copyAddress(mailbox) },
              delete: { mailboxToDelete = mailbox }
            )
          }

          Button {
            createPresented = true
          } label: {
            Label("创建新邮箱", systemImage: "plus.circle.fill")
              .font(.headline)
              .foregroundStyle(.white)
              .frame(maxWidth: .infinity)
              .frame(height: 52)
              .background(TempMailPalette.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
          }
          .buttonStyle(TempMailScaleButtonStyle())
          .padding(.top, 8)
        }
        .frame(maxWidth: 620)
        .padding(16)
        .frame(maxWidth: .infinity)
      }
      .background(TempMailPalette.background)
      .toolbar {
        TempMailToolbarContent(
          title: "邮箱管理",
          drawerPresented: $drawerPresented,
          trailingSystemImage: "plus",
          trailingAction: { createPresented = true }
        )
      }
      .confirmationDialog(
        "删除这个邮箱？",
        isPresented: Binding(
          get: { mailboxToDelete != nil },
          set: { if !$0 { mailboxToDelete = nil } }
        ),
        titleVisibility: .visible
      ) {
        Button("删除", role: .destructive) {
          if let mailboxToDelete {
            Task { await store.deleteMailbox(mailboxToDelete) }
          }
          mailboxToDelete = nil
        }
        Button("取消", role: .cancel) { mailboxToDelete = nil }
      } message: {
        Text("邮箱地址和收到的邮件都将被永久删除。")
      }
    }
  }
}

private struct TempMailManagerRow: View {
  let mailbox: TempMailbox
  let isSelected: Bool
  let select: () -> Void
  let copy: () -> Void
  let delete: () -> Void

  var body: some View {
    HStack(spacing: 12) {
      Button(action: select) {
        ZStack {
          Circle()
            .fill(isSelected ? TempMailPalette.green : TempMailPalette.softGreen)
          Image(systemName: isSelected ? "checkmark" : "envelope")
            .font(.system(size: 15, weight: .bold))
            .foregroundStyle(isSelected ? .white : TempMailPalette.darkGreen)
        }
        .frame(width: 38, height: 38)
      }
      .buttonStyle(.plain)

      VStack(alignment: .leading, spacing: 4) {
        Text(mailbox.address)
          .font(.subheadline.weight(.semibold))
          .lineLimit(1)
        Text(isSelected ? "当前邮箱" : mailbox.domain)
          .font(.caption)
          .foregroundStyle(isSelected ? TempMailPalette.darkGreen : .secondary)
      }
      Spacer(minLength: 8)
      Button(action: copy) {
        Image(systemName: "doc.on.doc")
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
      Button(role: .destructive, action: delete) {
        Image(systemName: "trash")
          .foregroundStyle(TempMailPalette.danger)
          .frame(width: 36, height: 36)
      }
      .buttonStyle(.plain)
    }
    .padding(12)
    .tempMailCard(radius: 17)
  }
}

private struct TempMailCreateMailboxSheet: View {
  @EnvironmentObject private var store: TempMailStore
  @Environment(\.dismiss) private var dismiss
  let domains: [String]
  @State private var localPart = ""
  @State private var selectedDomain = ""

  var body: some View {
    NavigationStack {
      VStack(alignment: .leading, spacing: 22) {
        VStack(alignment: .leading, spacing: 9) {
          Text("邮箱名称")
            .font(.subheadline.weight(.semibold))
          HStack(spacing: 10) {
            TextField("留空则随机生成", text: $localPart)
              .textInputAutocapitalization(.never)
              .autocorrectionDisabled()
              .keyboardType(.asciiCapable)
              .onChange(of: localPart) { _, value in
                let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyz0123456789")
                let filtered = value.lowercased().filter { character in
                  character.unicodeScalars.count == 1 &&
                    character.unicodeScalars.first.map(allowed.contains) == true
                }
                if filtered != value { localPart = String(filtered.prefix(50)) }
              }
            Button {
              localPart = Self.randomLocalPart()
              UIImpactFeedbackGenerator(style: .light).impactOccurred()
            } label: {
              Image(systemName: "dice.fill")
                .foregroundStyle(TempMailPalette.green)
            }
          }
          .padding(.horizontal, 14)
          .frame(height: 52)
          .background(TempMailPalette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        VStack(alignment: .leading, spacing: 9) {
          Text("邮箱域名")
            .font(.subheadline.weight(.semibold))
          Picker("邮箱域名", selection: $selectedDomain) {
            ForEach(domains, id: \.self) { domain in
              Text("@\(domain)").tag(domain)
            }
          }
          .pickerStyle(.menu)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 14)
          .frame(height: 52)
          .background(TempMailPalette.background, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }

        Spacer()

        Button {
          Task {
            if await store.createMailbox(
              localPart: localPart.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : localPart,
              domain: selectedDomain
            ) {
              dismiss()
            }
          }
        } label: {
          HStack(spacing: 9) {
            if store.isCreating { ProgressView().tint(.white) }
            Text(store.isCreating ? "正在创建…" : "创建邮箱")
          }
          .font(.headline)
          .foregroundStyle(.white)
          .frame(maxWidth: .infinity)
          .frame(height: 54)
          .background(TempMailPalette.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(TempMailScaleButtonStyle())
        .disabled(selectedDomain.isEmpty || store.isCreating)
      }
      .padding(20)
      .background(TempMailPalette.surface)
      .navigationTitle("创建新邮箱")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .cancellationAction) {
          Button("取消") { dismiss() }
        }
      }
      .onAppear {
        if selectedDomain.isEmpty { selectedDomain = domains.first ?? "" }
      }
    }
  }

  private static func randomLocalPart() -> String {
    let chars = Array("abcdefghijklmnopqrstuvwxyz0123456789")
    return String((0..<10).compactMap { _ in chars.randomElement() })
  }
}

private struct TempMailDrawer: View {
  @Binding var isPresented: Bool
  @Binding var appearanceMode: TempMailAppearanceMode
  @Binding var animationsEnabled: Bool
  let onCreateMailbox: () -> Void
  let onInternalUnlock: () -> Void
  @State private var infoPage: TempMailInfoPage?
  @GestureState private var dragOffset: CGFloat = 0

#if APPBOX_INTERNAL_UNLOCK
  @State private var internalTapCount = 0
  @State private var internalTapDeadline = Date.distantPast
  @State private var isInternalPromptPresented = false
  @State private var internalCode = ""
  @State private var isInternalUnlocking = false
  @State private var internalUnlockError = ""
  @State private var isInternalErrorPresented = false
#endif

  var body: some View {
    GeometryReader { proxy in
      ZStack(alignment: .leading) {
        Color.black.opacity(0.28)
          .ignoresSafeArea()
          .onTapGesture { isPresented = false }

        VStack(spacing: 0) {
          HStack {
            TempMailLogoMark().frame(width: 54, height: 54)
            VStack(alignment: .leading, spacing: 3) {
              Text("临时邮箱")
                .font(.title3.weight(.bold))
              Text("快速、安全地接收邮件")
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
              isPresented = false
            } label: {
              Image(systemName: "xmark")
                .font(.system(size: 15, weight: .bold))
                .frame(width: 40, height: 40)
            }
            .buttonStyle(.plain)
          }
          .padding(.horizontal, 20)
          .padding(.top, max(18, proxy.safeAreaInsets.top))
          .padding(.bottom, 18)

          ScrollView {
            VStack(spacing: 2) {
              TempMailDrawerButton(title: "创建新邮箱", icon: "plus.circle.fill") {
                isPresented = false
                onCreateMailbox()
              }

              Divider().padding(.vertical, 8)

              TempMailAppearancePicker(selection: $appearanceMode)
              TempMailDrawerToggle(
                title: "界面动画",
                icon: "sparkles",
                isOn: $animationsEnabled
              )

              Divider().padding(.vertical, 8)

              TempMailDrawerButton(title: "使用帮助", icon: "questionmark.circle.fill") {
                infoPage = .help
              }
              TempMailDrawerButton(title: "隐私政策", icon: "hand.raised.fill") {
                infoPage = .privacy
              }
              TempMailDrawerButton(title: "用户协议", icon: "doc.text.fill") {
                infoPage = .terms
              }

              Divider().padding(.vertical, 8)

              HStack {
                Label("版本", systemImage: "info.circle.fill")
                Spacer()
                Text(versionLabel)
                  .foregroundStyle(.secondary)
              }
              .font(.subheadline)
              .padding(.horizontal, 18)
              .frame(height: 52)
              .contentShape(Rectangle())
#if APPBOX_INTERNAL_UNLOCK
              .onTapGesture(perform: registerInternalTap)
#endif
            }
            .padding(.horizontal, 12)
          }
        }
        .frame(width: min(proxy.size.width * 0.84, 390))
        .frame(maxHeight: .infinity)
        .background(.regularMaterial)
        .clipShape(
          UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 0,
            bottomTrailingRadius: 28,
            topTrailingRadius: 28,
            style: .continuous
          )
        )
        .shadow(color: .black.opacity(0.18), radius: 24, x: 10, y: 0)
        .offset(x: min(0, dragOffset))
        .gesture(
          DragGesture(minimumDistance: 10)
            .updating($dragOffset) { value, state, _ in
              if value.translation.width < 0 { state = value.translation.width }
            }
            .onEnded { value in
              if value.translation.width < -80 { isPresented = false }
            }
        )

#if APPBOX_INTERNAL_UNLOCK
        if isInternalUnlocking {
          Color.black.opacity(0.16).ignoresSafeArea()
          ProgressView("正在验证…")
            .padding(.horizontal, 24)
            .padding(.vertical, 18)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
#endif
      }
    }
    .sheet(item: $infoPage) { page in
      TempMailInfoSheet(page: page)
    }
#if APPBOX_INTERNAL_UNLOCK
    .alert("输入验证码", isPresented: $isInternalPromptPresented) {
      TextField("验证码", text: $internalCode)
        .textInputAutocapitalization(.characters)
        .autocorrectionDisabled()
      Button("取消", role: .cancel) { internalCode = "" }
      Button("验证", action: redeemInternalCode)
        .disabled(internalCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
    } message: {
      Text("请输入验证码以完成验证。")
    }
    .alert("验证失败", isPresented: $isInternalErrorPresented) {
      Button("确定", role: .cancel) {}
    } message: {
      Text(internalUnlockError)
    }
#endif
  }

  private var versionLabel: String {
    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "-"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "-"
    return "\(version) (\(build))"
  }

#if APPBOX_INTERNAL_UNLOCK
  private func registerInternalTap() {
    let now = Date()
    if now > internalTapDeadline { internalTapCount = 0 }
    internalTapCount += 1
    internalTapDeadline = now.addingTimeInterval(5)
    guard internalTapCount >= 7 else { return }
    internalTapCount = 0
    internalTapDeadline = .distantPast
    internalCode = ""
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    isInternalPromptPresented = true
  }

  private func redeemInternalCode() {
    let code = internalCode.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !code.isEmpty, !isInternalUnlocking else { return }
    internalCode = ""
    isInternalUnlocking = true
    Task {
      do {
        try await AppBoxInternalUnlockService().redeem(code: code)
        isInternalUnlocking = false
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        onInternalUnlock()
      } catch {
        isInternalUnlocking = false
        internalUnlockError = error.localizedDescription
        isInternalErrorPresented = true
        UINotificationFeedbackGenerator().notificationOccurred(.error)
      }
    }
  }
#endif
}

private struct TempMailDrawerButton: View {
  let title: String
  let icon: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .foregroundStyle(TempMailPalette.green)
          .frame(width: 24)
        Text(title).foregroundStyle(.primary)
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 18)
      .frame(height: 52)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
  }
}

private struct TempMailDrawerToggle: View {
  let title: String
  let icon: String
  @Binding var isOn: Bool

  var body: some View {
    Toggle(isOn: $isOn) {
      HStack(spacing: 14) {
        Image(systemName: icon)
          .foregroundStyle(TempMailPalette.green)
          .frame(width: 24)
        Text(title)
      }
    }
    .tint(TempMailPalette.green)
    .padding(.horizontal, 18)
    .frame(height: 52)
  }
}

private struct TempMailAppearancePicker: View {
  @Binding var selection: TempMailAppearanceMode
  @State private var isPickerPresented = false

  var body: some View {
    Button {
      isPickerPresented = true
    } label: {
      HStack(spacing: 14) {
        Image(systemName: selection.systemImage)
          .foregroundStyle(TempMailPalette.green)
          .frame(width: 24)
        VStack(alignment: .leading, spacing: 2) {
          Text("外观")
            .foregroundStyle(.primary)
          Text(selection.title)
            .font(.caption)
            .foregroundStyle(.secondary)
        }
        Spacer()
        Image(systemName: "chevron.right")
          .font(.caption2.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
      .padding(.horizontal, 18)
      .frame(height: 52)
      .frame(maxWidth: .infinity)
      .contentShape(Rectangle())
    }
    .buttonStyle(.plain)
    .confirmationDialog("选择外观", isPresented: $isPickerPresented, titleVisibility: .visible) {
      ForEach(TempMailAppearanceMode.allCases) { mode in
        Button(mode == selection ? "✓ \(mode.title)" : mode.title) {
          selection = mode
        }
      }
      Button("取消", role: .cancel) {}
    }
    .accessibilityLabel("外观，当前为\(selection.title)")
  }
}

private enum TempMailInfoPage: String, Identifiable {
  case help
  case privacy
  case terms

  var id: String { rawValue }

  var title: String {
    switch self {
    case .help: return "使用帮助"
    case .privacy: return "隐私政策"
    case .terms: return "用户协议"
    }
  }

  var bodyText: String {
    switch self {
    case .help:
      return "复制当前临时邮箱地址并在需要收信的网站使用。收到的邮件会自动出现在收件箱中，您也可以下拉刷新。创建新邮箱或删除旧邮箱，请前往“管理”页面。"
    case .privacy:
      return "我们仅处理提供临时邮箱服务所必需的数据。邮箱地址和邮件内容会保存在服务器中，用于在本设备展示；不会读取您的通讯录、照片、日历或位置信息。请勿使用临时邮箱接收敏感或长期保存的信息。"
    case .terms:
      return "临时邮箱仅供合法、正常的邮件接收场景使用。请勿用于欺诈、骚扰、规避平台规则或其他违法活动。邮箱及邮件可能按服务策略清理，请不要将其作为永久邮箱使用。"
    }
  }
}

private struct TempMailInfoSheet: View {
  @Environment(\.dismiss) private var dismiss
  let page: TempMailInfoPage

  var body: some View {
    NavigationStack {
      ScrollView {
        Text(page.bodyText)
          .font(.body)
          .lineSpacing(6)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(22)
      }
      .background(TempMailPalette.background)
      .navigationTitle(page.title)
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }
        }
      }
    }
  }
}

private struct TempMailToolbarContent: ToolbarContent {
  let title: String
  @Binding var drawerPresented: Bool
  var trailingSystemImage = "arrow.clockwise"
  let trailingAction: () -> Void

  var body: some ToolbarContent {
    ToolbarItem(placement: .topBarLeading) {
      Button {
        drawerPresented = true
      } label: {
        Image(systemName: "line.3.horizontal")
      }
      .accessibilityLabel("菜单")
    }
    ToolbarItem(placement: .principal) {
      Text(title).font(.headline.weight(.bold))
    }
    ToolbarItem(placement: .topBarTrailing) {
      Button(action: trailingAction) {
        Image(systemName: trailingSystemImage)
      }
      .accessibilityLabel(trailingSystemImage == "plus" ? "创建新邮箱" : "刷新")
    }
  }
}

private struct TempMailLogoMark: View {
  var body: some View {
    ZStack {
      Circle()
        .fill(TempMailPalette.softGreen)
      Circle()
        .stroke(TempMailPalette.green.opacity(0.18), lineWidth: 1)
        .padding(8)
      ZStack {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
          .fill(TempMailPalette.envelope)
          .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        Path { path in
          path.move(to: CGPoint(x: 3, y: 8))
          path.addLine(to: CGPoint(x: 24, y: 22))
          path.addLine(to: CGPoint(x: 45, y: 8))
        }
        .stroke(TempMailPalette.green, style: StrokeStyle(lineWidth: 3, lineCap: .round, lineJoin: .round))
      }
      .frame(width: 48, height: 36)
      Image(systemName: "sparkle")
        .font(.system(size: 15, weight: .bold))
        .foregroundStyle(TempMailPalette.green)
        .offset(x: 30, y: -30)
    }
  }
}

private struct TempMailAppearanceBridge: UIViewRepresentable {
  let style: UIUserInterfaceStyle

  func makeUIView(context: Context) -> TempMailAppearanceBridgeView {
    let view = TempMailAppearanceBridgeView()
    view.style = style
    return view
  }

  func updateUIView(_ view: TempMailAppearanceBridgeView, context: Context) {
    view.style = style
    view.applyStyle()
  }
}

private final class TempMailAppearanceBridgeView: UIView {
  var style: UIUserInterfaceStyle = .unspecified

  override func didMoveToWindow() {
    super.didMoveToWindow()
    applyStyle()
  }

  func applyStyle() {
    guard let window, window.overrideUserInterfaceStyle != style else { return }
    window.overrideUserInterfaceStyle = style
  }
}

private struct TempMailToast: View {
  let message: String

  var body: some View {
    Label(message, systemImage: "checkmark.circle.fill")
      .font(.subheadline.weight(.medium))
      .foregroundStyle(.primary)
      .padding(.horizontal, 16)
      .frame(height: 46)
      .background(.regularMaterial, in: Capsule())
      .shadow(color: .black.opacity(0.12), radius: 12, y: 5)
      .padding(.horizontal, 20)
  }
}

private struct TempMailPrimaryButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .font(.headline)
      .foregroundStyle(.white)
      .frame(maxWidth: .infinity)
      .frame(height: 52)
      .background(TempMailPalette.green, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
      .scaleEffect(configuration.isPressed ? 0.96 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
  }
}

private struct TempMailScaleButtonStyle: ButtonStyle {
  @Environment(\.accessibilityReduceMotion) private var reduceMotion

  func makeBody(configuration: Configuration) -> some View {
    configuration.label
      .scaleEffect(configuration.isPressed ? 0.97 : 1)
      .opacity(configuration.isPressed ? 0.88 : 1)
      .animation(reduceMotion ? nil : .easeOut(duration: 0.14), value: configuration.isPressed)
  }
}
