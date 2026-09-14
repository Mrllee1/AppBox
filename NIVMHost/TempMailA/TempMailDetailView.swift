import SwiftUI
import UIKit
import WebKit

struct TempMailDetailView: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: TempMailStore

  let messageID: Int

  @State private var detail: TempMailMessageDetail?
  @State private var isLoading = true
  @State private var errorMessage: String?
  @State private var actionsPresented = false
  @State private var attachmentsPresented = false
  @State private var deleteRequestedFromActions = false
  @State private var deleteConfirmationPresented = false

  var body: some View {
    Group {
      if let detail {
        TempMailDetailContent(detail: detail)
      } else if isLoading {
        ProgressView("正在载入邮件…")
          .tint(TempMailPalette.green)
          .frame(maxWidth: .infinity, maxHeight: .infinity)
      } else {
        ContentUnavailableView {
          Label("无法打开邮件", systemImage: "exclamationmark.triangle")
        } description: {
          Text(errorMessage ?? "邮件内容暂时不可用。")
        } actions: {
          Button("重新加载") { Task { await load() } }
            .buttonStyle(.borderedProminent)
            .tint(TempMailPalette.green)
        }
      }
    }
    .background(TempMailPalette.background)
    .navigationTitle("邮件")
    .navigationBarTitleDisplayMode(.inline)
    .toolbar {
      if detail != nil {
        ToolbarItem(placement: .topBarTrailing) {
          Button {
            actionsPresented = true
          } label: {
            Image(systemName: "ellipsis.circle")
          }
          .accessibilityLabel("更多邮件操作")
        }
      }
    }
    .safeAreaInset(edge: .bottom, spacing: 0) {
      if let detail, !detail.attachments.isEmpty {
        TempMailAttachmentBar(count: detail.attachments.count) {
          attachmentsPresented = true
        }
      }
    }
    .sheet(isPresented: $actionsPresented, onDismiss: {
      if deleteRequestedFromActions {
        deleteRequestedFromActions = false
        deleteConfirmationPresented = true
      }
    }) {
      if let detail {
        TempMailMailActionsSheet(
          detail: detail,
          delete: {
            deleteRequestedFromActions = true
            actionsPresented = false
          }
        )
      }
    }
    .sheet(isPresented: $attachmentsPresented) {
      if let detail {
        TempMailAttachmentSheet(messageID: messageID, attachments: detail.attachments)
          .environmentObject(store)
      }
    }
    .confirmationDialog(
      "删除这封邮件？",
      isPresented: $deleteConfirmationPresented,
      titleVisibility: .visible
    ) {
      Button("删除", role: .destructive) {
        guard let detail else { return }
        actionsPresented = false
        Task {
          await store.deleteMessage(detail.summary)
          dismiss()
        }
      }
      Button("取消", role: .cancel) {}
    } message: {
      Text("删除后无法恢复。")
    }
    .task(id: messageID) { await load() }
  }

  @MainActor
  private func load() async {
    isLoading = true
    errorMessage = nil
    do {
      detail = try await store.loadMessageDetail(id: messageID)
    } catch {
      detail = nil
      errorMessage = error.localizedDescription
    }
    isLoading = false
  }
}

private struct TempMailDetailContent: View {
  @EnvironmentObject private var store: TempMailStore
  @Environment(\.colorScheme) private var colorScheme

  let detail: TempMailMessageDetail

  @State private var headerExpanded = false
  @State private var htmlHeight: CGFloat = 160

  var body: some View {
    ScrollView {
      VStack(alignment: .leading, spacing: 14) {
        Text(detail.displaySubject)
          .font(.title3.weight(.semibold))
          .lineLimit(2)
          .frame(maxWidth: .infinity, alignment: .leading)
          .padding(.horizontal, 23)

        VStack(spacing: 0) {
          messageHeader

          Divider()
            .padding(.horizontal, 12)

          messageBody
        }
        .tempMailCard(radius: 17)
        .padding(.horizontal, 7)
      }
      .padding(.top, 18)
      .padding(.bottom, 24)
    }
  }

  private var messageHeader: some View {
    VStack(spacing: 0) {
      HStack(alignment: .top, spacing: 12) {
        Text(detail.senderInitial)
          .font(.headline.weight(.semibold))
          .foregroundStyle(TempMailPalette.blue)
          .frame(width: 44, height: 44)
          .background(
            Color(red: 230 / 255, green: 239 / 255, blue: 1),
            in: RoundedRectangle(cornerRadius: 12, style: .continuous)
          )
          .accessibilityHidden(true)

        VStack(alignment: .leading, spacing: 5) {
          Text(detail.senderTitle)
            .font(.headline)
            .lineLimit(1)

          Button {
            withAnimation(.snappy(duration: 0.24)) {
              headerExpanded.toggle()
            }
          } label: {
            HStack(spacing: 5) {
              Text("发给我")
              Image(systemName: "chevron.down")
                .font(.caption2.weight(.semibold))
                .rotationEffect(.degrees(headerExpanded ? 180 : 0))
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .frame(minHeight: 24)
          }
          .buttonStyle(.plain)
          .accessibilityLabel(headerExpanded ? "收起邮件详情" : "展开邮件详情")
        }

        Spacer(minLength: 8)

        Text(detail.dateLabel)
          .font(.caption)
          .foregroundStyle(.secondary)
          .multilineTextAlignment(.trailing)
      }
      .padding(12)

      if headerExpanded {
        VStack(alignment: .leading, spacing: 9) {
          TempMailAddressLine(label: "发件人", value: detail.senderEmail)
          TempMailAddressLine(label: "收件人", value: recipientAddress)
          TempMailAddressLine(label: "时间", value: detail.fullDateLabel)
        }
        .padding(.horizontal, 12)
        .padding(.bottom, 12)
        .transition(.opacity.combined(with: .move(edge: .top)))
      }
    }
  }

  @ViewBuilder
  private var messageBody: some View {
    let html = detail.html.trimmingCharacters(in: .whitespacesAndNewlines)
    let text = detail.text.trimmingCharacters(in: .whitespacesAndNewlines)

    if !html.isEmpty {
      TempMailHTMLView(html: html, colorScheme: colorScheme, height: $htmlHeight)
        .frame(height: max(120, htmlHeight))
    } else if !text.isEmpty {
      Text(text)
        .font(.body)
        .lineSpacing(5)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(18)
    } else {
      ContentUnavailableView("这封邮件没有正文", systemImage: "doc.text")
        .frame(maxWidth: .infinity)
        .padding(.vertical, 48)
    }
  }

  private var recipientAddress: String {
    let value = detail.toAddress.trimmingCharacters(in: .whitespacesAndNewlines)
    return value.isEmpty ? (store.selectedMailbox?.address ?? "未知") : value
  }
}

private struct TempMailAddressLine: View {
  let label: String
  let value: String

  var body: some View {
    HStack(alignment: .top, spacing: 10) {
      Text(label)
        .foregroundStyle(.secondary)
        .frame(width: 48, alignment: .leading)
      Text(value.isEmpty ? "未知" : value)
        .foregroundStyle(.primary)
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
    }
    .font(.caption)
  }
}

private struct TempMailAttachmentBar: View {
  let count: Int
  let open: () -> Void

  var body: some View {
    Button(action: open) {
      HStack(spacing: 10) {
        Image(systemName: "paperclip")
          .foregroundStyle(TempMailPalette.green)
        Text("\(count) 个附件")
          .font(.subheadline.weight(.semibold))
        Spacer()
        Image(systemName: "chevron.up")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.secondary)
      }
      .foregroundStyle(.primary)
      .padding(.horizontal, 18)
      .frame(height: 52)
      .background(.ultraThinMaterial)
      .overlay(alignment: .top) { Divider() }
    }
    .buttonStyle(.plain)
    .accessibilityHint("查看和分享附件")
  }
}

private struct TempMailMailActionsSheet: View {
  @Environment(\.dismiss) private var dismiss

  let detail: TempMailMessageDetail
  let delete: () -> Void

  @State private var rawFileURL: URL?
  @State private var copied = false

  var body: some View {
    NavigationStack {
      ScrollView {
        VStack(spacing: 12) {
          HStack(spacing: 10) {
            TempMailActionTile(title: "回复", systemImage: "arrowshape.turn.up.left") {
              openComposer(kind: .reply)
            }
            TempMailActionTile(title: "转发", systemImage: "arrowshape.turn.up.right") {
              openComposer(kind: .forward)
            }
          }

          VStack(spacing: 0) {
            TempMailActionRow(title: "打印", systemImage: "printer") {
              printMessage()
            }

            Divider().padding(.leading, 52)

            if let rawFileURL {
              ShareLink(item: rawFileURL) {
                TempMailActionRowLabel(
                  title: "下载 EML",
                  systemImage: "arrow.down.doc",
                  showsChevron: false
                )
              }
              .buttonStyle(.plain)
            }

            if rawFileURL != nil {
              Divider().padding(.leading, 52)
            }

            NavigationLink {
              TempMailOriginalSourceView(raw: detail.raw)
            } label: {
              TempMailActionRowLabel(title: "显示原始邮件", systemImage: "chevron.left.forwardslash.chevron.right")
            }
            .buttonStyle(.plain)

            Divider().padding(.leading, 52)

            TempMailActionRow(
              title: copied ? "已复制" : "复制正文",
              systemImage: copied ? "checkmark" : "doc.on.doc"
            ) {
              UIPasteboard.general.string = detail.copyableContent
              UIImpactFeedbackGenerator(style: .light).impactOccurred()
              copied = true
            }

            Divider().padding(.leading, 52)

            TempMailActionRow(title: "删除邮件", systemImage: "trash", role: .destructive) {
              delete()
            }
          }
          .tempMailCard(radius: 17)
        }
        .padding(16)
      }
      .background(TempMailPalette.background)
      .navigationTitle("邮件操作")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .task { rawFileURL = makeRawFile() }
  }

  private enum ComposerKind {
    case reply
    case forward
  }

  private func openComposer(kind: ComposerKind) {
    var components = URLComponents()
    components.scheme = "mailto"
    components.path = kind == .reply ? detail.senderEmail : ""

    let subjectPrefix = kind == .reply ? "回复：" : "转发："
    var queryItems = [URLQueryItem(name: "subject", value: subjectPrefix + detail.displaySubject)]
    if kind == .forward {
      let excerpt = String(detail.copyableContent.prefix(2_000))
      queryItems.append(URLQueryItem(name: "body", value: "\n\n---------- 转发邮件 ----------\n\(excerpt)"))
    }
    components.queryItems = queryItems
    guard let url = components.url else { return }
    UIApplication.shared.open(url)
  }

  private func printMessage() {
    let markup: String
    if detail.html.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
      markup = "<html><body><h2>\(detail.displaySubject.htmlEscaped)</h2><pre>\(detail.text.htmlEscaped)</pre></body></html>"
    } else {
      markup = detail.html
    }
    let controller = UIPrintInteractionController.shared
    controller.printInfo = {
      let info = UIPrintInfo(dictionary: nil)
      info.jobName = detail.displaySubject
      info.outputType = .general
      return info
    }()
    controller.printFormatter = UIMarkupTextPrintFormatter(markupText: markup)
    controller.present(animated: true)
  }

  private func makeRawFile() -> URL? {
    let raw = detail.raw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !raw.isEmpty, let data = raw.data(using: .utf8) else { return nil }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent("TempMailRaw", isDirectory: true)
    try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let filename = detail.displaySubject.safeFilename(default: "message") + ".eml"
    let url = directory.appendingPathComponent(filename)
    do {
      try data.write(to: url, options: .atomic)
      return url
    } catch {
      return nil
    }
  }
}

private struct TempMailActionTile: View {
  let title: String
  let systemImage: String
  let action: () -> Void

  var body: some View {
    Button(action: action) {
      VStack(spacing: 8) {
        Image(systemName: systemImage)
          .font(.title3)
          .foregroundStyle(TempMailPalette.green)
        Text(title)
          .font(.subheadline.weight(.semibold))
          .foregroundStyle(.primary)
      }
      .frame(maxWidth: .infinity)
      .frame(height: 82)
      .tempMailCard(radius: 17)
    }
    .buttonStyle(.plain)
  }
}

private struct TempMailActionRow: View {
  let title: String
  let systemImage: String
  var role: ButtonRole?
  let action: () -> Void

  var body: some View {
    Button(role: role, action: action) {
      TempMailActionRowLabel(
        title: title,
        systemImage: systemImage,
        isDestructive: role == .destructive,
        showsChevron: false
      )
    }
    .buttonStyle(.plain)
  }
}

private struct TempMailActionRowLabel: View {
  let title: String
  let systemImage: String
  var isDestructive = false
  var showsChevron = true

  var body: some View {
    HStack(spacing: 14) {
      Image(systemName: systemImage)
        .font(.body.weight(.medium))
        .frame(width: 24)
      Text(title)
        .font(.body)
      Spacer()
      if showsChevron {
        Image(systemName: "chevron.right")
          .font(.caption.weight(.semibold))
          .foregroundStyle(.tertiary)
      }
    }
    .foregroundStyle(isDestructive ? TempMailPalette.danger : Color.primary)
    .padding(.horizontal, 14)
    .frame(minHeight: 52)
    .contentShape(Rectangle())
  }
}

private struct TempMailOriginalSourceView: View {
  let raw: String

  var body: some View {
    ScrollView([.horizontal, .vertical]) {
      Text(raw.isEmpty ? "没有可用的原始邮件数据。" : raw)
        .font(.system(.caption, design: .monospaced))
        .textSelection(.enabled)
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
    }
    .background(TempMailPalette.background)
    .navigationTitle("原始邮件")
    .navigationBarTitleDisplayMode(.inline)
  }
}

private struct TempMailAttachmentSheet: View {
  @Environment(\.dismiss) private var dismiss
  @EnvironmentObject private var store: TempMailStore

  let messageID: Int
  let attachments: [TempMailAttachment]

  @State private var downloadedURLs: [Int: URL] = [:]
  @State private var downloadingIndex: Int?
  @State private var errorMessage: String?

  var body: some View {
    NavigationStack {
      List(attachments) { attachment in
        HStack(spacing: 12) {
          Image(systemName: attachment.systemImage)
            .font(.title3)
            .foregroundStyle(TempMailPalette.green)
            .frame(width: 34, height: 34)

          VStack(alignment: .leading, spacing: 3) {
            Text(attachment.displayName)
              .font(.subheadline.weight(.medium))
              .lineLimit(1)
            Text("\(attachment.sizeLabel) · \(attachment.contentType)")
              .font(.caption)
              .foregroundStyle(.secondary)
              .lineLimit(1)
          }

          Spacer(minLength: 8)

          if downloadingIndex == attachment.index {
            ProgressView()
              .tint(TempMailPalette.green)
          } else if let url = downloadedURLs[attachment.index] {
            ShareLink(item: url) {
              Image(systemName: "square.and.arrow.up")
                .frame(width: 44, height: 44)
            }
            .accessibilityLabel("分享 \(attachment.displayName)")
          } else {
            Button {
              download(attachment)
            } label: {
              Image(systemName: "arrow.down.circle")
                .frame(width: 44, height: 44)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("下载 \(attachment.displayName)")
          }
        }
        .listRowBackground(TempMailPalette.surface)
      }
      .scrollContentBackground(.hidden)
      .background(TempMailPalette.background)
      .navigationTitle("附件")
      .navigationBarTitleDisplayMode(.inline)
      .toolbar {
        ToolbarItem(placement: .confirmationAction) {
          Button("完成") { dismiss() }
        }
      }
    }
    .presentationDetents([.medium, .large])
    .presentationDragIndicator(.visible)
    .alert("无法下载附件", isPresented: Binding(
      get: { errorMessage != nil },
      set: { if !$0 { errorMessage = nil } }
    )) {
      Button("好") { errorMessage = nil }
    } message: {
      Text(errorMessage ?? "请稍后重试。")
    }
  }

  private func download(_ attachment: TempMailAttachment) {
    guard downloadingIndex == nil else { return }
    downloadingIndex = attachment.index
    Task {
      do {
        let url = try await store.exportAttachment(messageID: messageID, attachment: attachment)
        downloadedURLs[attachment.index] = url
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } catch {
        errorMessage = error.localizedDescription
      }
      downloadingIndex = nil
    }
  }
}

private struct TempMailHTMLView: UIViewRepresentable {
  let html: String
  let colorScheme: ColorScheme
  @Binding var height: CGFloat

  func makeCoordinator() -> Coordinator {
    Coordinator(height: $height)
  }

  func makeUIView(context: Context) -> WKWebView {
    let configuration = WKWebViewConfiguration()
    configuration.websiteDataStore = .nonPersistent()
    configuration.defaultWebpagePreferences.allowsContentJavaScript = false

    let webView = WKWebView(frame: .zero, configuration: configuration)
    webView.isOpaque = false
    webView.backgroundColor = .clear
    webView.scrollView.backgroundColor = .clear
    webView.scrollView.isScrollEnabled = false
    webView.scrollView.bounces = false
    webView.navigationDelegate = context.coordinator
    context.coordinator.observe(webView)
    return webView
  }

  func updateUIView(_ webView: WKWebView, context: Context) {
    let document = Self.document(html: html, colorScheme: colorScheme)
    guard context.coordinator.loadedDocument != document else { return }
    context.coordinator.loadedDocument = document
    webView.loadHTMLString(document, baseURL: nil)
  }

  static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
    coordinator.stopObserving()
    webView.navigationDelegate = nil
  }

  final class Coordinator: NSObject, WKNavigationDelegate {
    var loadedDocument: String?
    private var contentSizeObservation: NSKeyValueObservation?
    private var height: Binding<CGFloat>

    init(height: Binding<CGFloat>) {
      self.height = height
    }

    func observe(_ webView: WKWebView) {
      contentSizeObservation = webView.scrollView.observe(\.contentSize, options: [.new]) { [weak self] _, change in
        guard let value = change.newValue?.height else { return }
        self?.updateHeight(value)
      }
    }

    func stopObserving() {
      contentSizeObservation?.invalidate()
      contentSizeObservation = nil
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
      updateHeight(webView.scrollView.contentSize.height)
    }

    func webView(
      _ webView: WKWebView,
      decidePolicyFor navigationAction: WKNavigationAction,
      decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
      guard let url = navigationAction.request.url else {
        decisionHandler(.allow)
        return
      }

      if navigationAction.navigationType == .linkActivated,
         let scheme = url.scheme?.lowercased(),
         ["http", "https", "mailto", "tel"].contains(scheme) {
        UIApplication.shared.open(url)
        decisionHandler(.cancel)
        return
      }

      let scheme = url.scheme?.lowercased() ?? ""
      decisionHandler(scheme == "about" || scheme == "data" ? .allow : .cancel)
    }

    private func updateHeight(_ newValue: CGFloat) {
      let measured = min(max(newValue, 120), 100_000)
      guard measured.isFinite, abs(height.wrappedValue - measured) > 1 else { return }
      DispatchQueue.main.async { [height] in
        height.wrappedValue = measured
      }
    }
  }

  private static func document(html: String, colorScheme: ColorScheme) -> String {
    let isDark = colorScheme == .dark
    let background = isDark ? "#3C3E40" : "#FFFFFF"
    let foreground = isDark ? "#FFFFFF" : "#111214"
    let secondary = isDark ? "#A6AEB2" : "#96979F"
    let style = """
    <meta name="viewport" content="width=device-width, initial-scale=1, viewport-fit=cover">
    <meta http-equiv="Content-Security-Policy" content="default-src 'none'; script-src 'none'; object-src 'none'; frame-src 'none'; connect-src 'none'; form-action 'none'; base-uri 'none'; img-src data: https: http:; style-src 'unsafe-inline'">
    <style>
      :root { color-scheme: \(isDark ? "dark" : "light"); }
      html, body { margin: 0; padding: 0; width: 100%; min-height: 1px; background: \(background); color: \(foreground); }
      body { box-sizing: border-box; padding: 18px; font: -apple-system-body; font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: 17px; line-height: 1.55; overflow-wrap: anywhere; }
      *, *::before, *::after { box-sizing: border-box; max-width: 100%; }
      img { max-width: 100% !important; height: auto !important; }
      a { color: #18CA88; text-decoration-thickness: from-font; }
      table { display: block; width: 100% !important; overflow-x: auto; border-collapse: collapse; }
      pre, code { white-space: pre-wrap; overflow-wrap: anywhere; font-family: ui-monospace, Menlo, monospace; }
      blockquote { margin-inline: 0; padding-left: 12px; border-left: 3px solid \(secondary); color: \(secondary); }
    </style>
    """

    if let headEnd = html.range(of: "</head>", options: .caseInsensitive) {
      var value = html
      value.insert(contentsOf: style, at: headEnd.lowerBound)
      return value
    }
    if let htmlStartEnd = html.range(of: #"<html[^>]*>"#, options: [.regularExpression, .caseInsensitive]) {
      var value = html
      value.insert(contentsOf: "<head>\(style)</head>", at: htmlStartEnd.upperBound)
      return value
    }
    return "<!doctype html><html><head>\(style)</head><body>\(html)</body></html>"
  }
}

private extension TempMailMessageDetail {
  var summary: TempMailMessage {
    TempMailMessage(
      id: id,
      fromAddress: fromAddress,
      subject: subject,
      preview: text,
      hasAttachments: !attachments.isEmpty,
      isRead: true,
      createdAt: createdAt
    )
  }
}

private extension String {
  var htmlEscaped: String {
    replacingOccurrences(of: "&", with: "&amp;")
      .replacingOccurrences(of: "<", with: "&lt;")
      .replacingOccurrences(of: ">", with: "&gt;")
      .replacingOccurrences(of: "\"", with: "&quot;")
      .replacingOccurrences(of: "'", with: "&#39;")
  }

  func safeFilename(default fallback: String) -> String {
    let invalid = CharacterSet(charactersIn: "/\\:?%*|\"<>\n\r\t")
    let cleaned = components(separatedBy: invalid).joined(separator: "-")
      .trimmingCharacters(in: .whitespacesAndNewlines)
    return String((cleaned.isEmpty ? fallback : cleaned).prefix(80))
  }
}
