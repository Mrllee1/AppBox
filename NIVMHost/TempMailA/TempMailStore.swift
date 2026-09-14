import Foundation
import SwiftUI
import UIKit

@MainActor
final class TempMailStore: ObservableObject {
  @Published private(set) var phase: TempMailLoadPhase = .loading
  @Published private(set) var domains: [String] = []
  @Published private(set) var mailboxes: [TempMailbox] = []
  @Published private(set) var messages: [TempMailMessage] = []
  @Published private(set) var messageTotal = 0
  @Published private(set) var isRefreshing = false
  @Published private(set) var isCreating = false
  @Published private(set) var operationMessage: String?
  @Published var selectedMailboxID: Int?

  private let api: TempMailAPIClient
  private var didStart = false
  private var autoRefreshTask: Task<Void, Never>?
  private let selectedMailboxKey = "tempMail.selectedMailboxID"

  init(api: TempMailAPIClient? = nil) {
    self.api = api ?? TempMailAPIClient()
  }

  deinit {
    autoRefreshTask?.cancel()
  }

  var selectedMailbox: TempMailbox? {
    if let selectedMailboxID,
       let selected = mailboxes.first(where: { $0.id == selectedMailboxID }) {
      return selected
    }
    return mailboxes.first
  }

  var unreadCount: Int {
    messages.lazy.filter { !$0.isRead }.count
  }

  func start() async {
    guard !didStart else { return }
    didStart = true
    await initialize()
  }

  func retry() async {
    phase = .loading
    await initialize()
  }

  private func initialize() async {
    do {
      // Establish one guest session before issuing authenticated requests.
      // Keeping bootstrap serialized prevents duplicate guest creation and
      // refresh-token rotation races during a cold launch.
      domains = try await api.domains()
      mailboxes = try await api.mailboxes()
      guard !domains.isEmpty else {
        throw TempMailAPIError.server("邮箱域名暂时不可用，请稍后重试。")
      }

      restoreSelection()
      if mailboxes.isEmpty {
        let created = try await api.createMailbox(localPart: nil, domain: domains.randomElement() ?? domains[0])
        mailboxes = [created]
        selectMailbox(created)
      }
      try await loadMessages(showRefreshState: false)
      phase = .ready
      startAutoRefresh()
    } catch {
      phase = .failed(error.localizedDescription)
    }
  }

  func refresh() async {
    guard phase == .ready else { return }
    do {
      try await loadMessages(showRefreshState: true)
    } catch {
      showOperationMessage(error.localizedDescription)
    }
  }

  func refreshSilently() async {
    guard phase == .ready, !isRefreshing else { return }
    try? await loadMessages(showRefreshState: false)
  }

  func selectMailbox(_ mailbox: TempMailbox) {
    guard selectedMailboxID != mailbox.id else { return }
    selectedMailboxID = mailbox.id
    UserDefaults.standard.set(mailbox.id, forKey: selectedMailboxKey)
    messages = []
    messageTotal = 0
    Task {
      do {
        try await loadMessages(showRefreshState: true)
      } catch {
        showOperationMessage(error.localizedDescription)
      }
    }
  }

  func createMailbox(localPart: String?, domain: String) async -> Bool {
    guard !isCreating else { return false }
    isCreating = true
    defer { isCreating = false }
    do {
      let mailbox = try await api.createMailbox(localPart: localPart, domain: domain)
      mailboxes.insert(mailbox, at: 0)
      selectMailbox(mailbox)
      showOperationMessage("新邮箱已创建")
      return true
    } catch {
      showOperationMessage(error.localizedDescription)
      return false
    }
  }

  func replaceCurrentMailbox() async {
    guard let current = selectedMailbox, let domain = domains.randomElement() else { return }
    isCreating = true
    defer { isCreating = false }
    do {
      let replacement = try await api.createMailbox(localPart: nil, domain: domain)
      try await api.deleteMailbox(id: current.id)
      mailboxes.removeAll { $0.id == current.id }
      mailboxes.insert(replacement, at: 0)
      selectedMailboxID = replacement.id
      UserDefaults.standard.set(replacement.id, forKey: selectedMailboxKey)
      try await loadMessages(showRefreshState: false)
      showOperationMessage("邮箱地址已更换")
    } catch {
      showOperationMessage(error.localizedDescription)
    }
  }

  func deleteMailbox(_ mailbox: TempMailbox) async {
    do {
      try await api.deleteMailbox(id: mailbox.id)
      mailboxes.removeAll { $0.id == mailbox.id }
      if selectedMailboxID == mailbox.id {
        if let next = mailboxes.first {
          selectedMailboxID = next.id
          UserDefaults.standard.set(next.id, forKey: selectedMailboxKey)
          try await loadMessages(showRefreshState: false)
        } else {
          selectedMailboxID = nil
          messages = []
          messageTotal = 0
          UserDefaults.standard.removeObject(forKey: selectedMailboxKey)
        }
      }
      showOperationMessage("邮箱已删除")
    } catch {
      showOperationMessage(error.localizedDescription)
    }
  }

  func deleteMessage(_ message: TempMailMessage) async {
    do {
      try await api.deleteMessage(id: message.id)
      messages.removeAll { $0.id == message.id }
      messageTotal = max(0, messageTotal - 1)
      showOperationMessage("邮件已删除")
    } catch {
      showOperationMessage(error.localizedDescription)
    }
  }

  func markMessageRead(_ message: TempMailMessage) async {
    guard !message.isRead else { return }
    do {
      try await api.markMessageRead(id: message.id)
      if let index = messages.firstIndex(where: { $0.id == message.id }) {
        messages[index] = TempMailMessage(
          id: message.id,
          fromAddress: message.fromAddress,
          subject: message.subject,
          preview: message.preview,
          hasAttachments: message.hasAttachments,
          isRead: true,
          createdAt: message.createdAt
        )
      }
    } catch {
      showOperationMessage(error.localizedDescription)
    }
  }

  func loadMessageDetail(id: Int) async throws -> TempMailMessageDetail {
    let detail = try await api.message(id: id)
    if let index = messages.firstIndex(where: { $0.id == id }), !messages[index].isRead {
      let old = messages[index]
      messages[index] = TempMailMessage(
        id: old.id,
        fromAddress: old.fromAddress,
        subject: old.subject,
        preview: old.preview,
        hasAttachments: old.hasAttachments,
        isRead: true,
        createdAt: old.createdAt
      )
    }
    return detail
  }

  func exportAttachment(messageID: Int, attachment: TempMailAttachment) async throws -> URL {
    let downloaded = try await api.attachment(messageID: messageID, index: attachment.index)
    let directory = FileManager.default.temporaryDirectory
      .appendingPathComponent("TempMailAttachments", isDirectory: true)
      .appendingPathComponent(String(messageID), isDirectory: true)
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let fallback = "attachment-\(attachment.index + 1)"
    let originalName = downloaded.filename.trimmingCharacters(in: .whitespacesAndNewlines)
    let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
    let safeName = (originalName.isEmpty ? fallback : originalName)
      .components(separatedBy: invalid)
      .joined(separator: "-")
    let url = directory.appendingPathComponent(safeName, isDirectory: false)
    try downloaded.data.write(to: url, options: .atomic)
    return url
  }

  func copyAddress(_ mailbox: TempMailbox? = nil) {
    guard let address = (mailbox ?? selectedMailbox)?.address else { return }
    UIPasteboard.general.string = address
    UIImpactFeedbackGenerator(style: .light).impactOccurred()
    showOperationMessage("邮箱地址已复制")
  }

  func showOperationMessage(_ message: String) {
    operationMessage = message
    Task {
      try? await Task.sleep(for: .seconds(2))
      if operationMessage == message { operationMessage = nil }
    }
  }

  private func loadMessages(showRefreshState: Bool) async throws {
    guard let mailbox = selectedMailbox else {
      messages = []
      messageTotal = 0
      return
    }
    if showRefreshState { isRefreshing = true }
    defer { if showRefreshState { isRefreshing = false } }
    let result = try await api.messages(mailboxID: mailbox.id)
    messages = result.0
    messageTotal = result.1
  }

  private func restoreSelection() {
    let saved = UserDefaults.standard.integer(forKey: selectedMailboxKey)
    if saved > 0, mailboxes.contains(where: { $0.id == saved }) {
      selectedMailboxID = saved
    } else {
      selectedMailboxID = mailboxes.first?.id
    }
  }

  private func startAutoRefresh() {
    autoRefreshTask?.cancel()
    autoRefreshTask = Task { [weak self] in
      while !Task.isCancelled {
        try? await Task.sleep(for: .seconds(15))
        guard !Task.isCancelled else { return }
        await self?.refreshSilently()
      }
    }
  }
}
