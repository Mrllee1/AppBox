import SwiftUI
import UIKit
import WebKit

@MainActor
final class AppBoxWebViewModel: ObservableObject {
    @Published fileprivate(set) var title = ""
    @Published fileprivate(set) var currentURL: URL?
    @Published fileprivate(set) var isLoading = true
    @Published fileprivate(set) var progress = 0.0
    @Published fileprivate(set) var canGoBack = false
    @Published fileprivate(set) var canGoForward = false
    @Published fileprivate(set) var errorMessage: String?

    private weak var webView: WKWebView?

    fileprivate func attach(_ webView: WKWebView) {
        self.webView = webView
        refresh(from: webView)
    }

    fileprivate func refresh(from webView: WKWebView) {
        let snapshot = AppBoxWebViewSnapshot(
            title: webView.title ?? "",
            currentURL: webView.url,
            isLoading: webView.isLoading,
            progress: webView.estimatedProgress,
            canGoBack: webView.canGoBack,
            canGoForward: webView.canGoForward
        )
        DispatchQueue.main.async { [weak self] in
            self?.apply(snapshot)
        }
    }

    fileprivate func clearError() {
        guard errorMessage != nil else { return }
        DispatchQueue.main.async { [weak self] in
            self?.errorMessage = nil
        }
    }

    fileprivate func showError(_ error: Error) {
        let nsError = error as NSError
        guard nsError.code != NSURLErrorCancelled else { return }
        isLoading = false
        errorMessage = error.localizedDescription
    }

    func goBack() {
        guard let webView, webView.canGoBack else { return }
        webView.goBack()
    }

    func goForward() {
        guard let webView, webView.canGoForward else { return }
        webView.goForward()
    }

    func reload() {
        errorMessage = nil
        webView?.reload()
    }

    func stop() {
        webView?.stopLoading()
    }

    private func apply(_ snapshot: AppBoxWebViewSnapshot) {
        if title != snapshot.title { title = snapshot.title }
        if currentURL != snapshot.currentURL { currentURL = snapshot.currentURL }
        if isLoading != snapshot.isLoading { isLoading = snapshot.isLoading }
        if progress != snapshot.progress { progress = snapshot.progress }
        if canGoBack != snapshot.canGoBack { canGoBack = snapshot.canGoBack }
        if canGoForward != snapshot.canGoForward { canGoForward = snapshot.canGoForward }
    }
}

private struct AppBoxWebViewSnapshot {
    let title: String
    let currentURL: URL?
    let isLoading: Bool
    let progress: Double
    let canGoBack: Bool
    let canGoForward: Bool
}

struct AppBoxWebAppView: View {
    let item: AppBoxCatalogItem
    let language: AppBoxLanguage
    let skin: AppBoxSkin

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.openURL) private var openURL
    @StateObject private var model = AppBoxWebViewModel()

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AppBoxSheetHeader(
                    title: model.title.isEmpty ? item.name(for: language) : model.title,
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                ZStack {
                    if let entryURL = item.source.webEntryURL {
                        AppBoxWebView(
                            itemID: item.id,
                            initialURL: entryURL,
                            model: model
                        )
                        .background(palette.surface)
                    }

                    if let errorMessage = model.errorMessage {
                        webErrorView(errorMessage)
                    }
                }
                .overlay(alignment: .top) {
                    if model.isLoading {
                        ProgressView(value: max(model.progress, 0.04))
                            .progressViewStyle(.linear)
                            .tint(palette.accent)
                    }
                }

                webToolbar
            }

            GeometryReader { proxy in
                AppBoxSandboxFloatingControl(
                    language: language,
                    availableSize: proxy.size,
                    safeAreaInsets: proxy.safeAreaInsets,
                    returnToSandbox: { dismiss() }
                )
            }
        }
        .onDisappear { model.stop() }
    }

    private var webToolbar: some View {
        HStack(spacing: 4) {
            webToolbarButton(
                icon: .arrowRight,
                rotation: 180,
                label: copy.text("返回", "Back"),
                isEnabled: model.canGoBack,
                action: model.goBack
            )
            webToolbarButton(
                icon: .arrowRight,
                label: copy.text("前进", "Forward"),
                isEnabled: model.canGoForward,
                action: model.goForward
            )

            Spacer(minLength: 8)

            Text(model.currentURL?.host ?? item.source.webEntryURL?.host ?? "")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(palette.secondaryText)
                .lineLimit(1)
                .truncationMode(.middle)

            Spacer(minLength: 8)

            webToolbarButton(
                icon: .link,
                label: copy.text("在浏览器中打开", "Open in Browser")
            ) {
                guard let url = model.currentURL ?? item.source.webEntryURL else { return }
                openURL(url)
            }
        }
        .padding(.horizontal, 10)
        .frame(height: 52)
        .background(palette.elevatedSurface)
        .overlay(alignment: .top) {
            Rectangle().fill(palette.divider).frame(height: 1)
        }
    }

    private func webToolbarButton(
        icon: AppBoxIcon,
        rotation: Double = 0,
        label: String,
        isEnabled: Bool = true,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            AppBoxGlyph(icon: icon)
                .frame(width: 18, height: 18)
                .rotationEffect(.degrees(rotation))
                .foregroundColor(isEnabled ? palette.primaryText : palette.secondaryText.opacity(0.35))
                .frame(width: 40, height: 40)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .accessibilityLabel(label)
    }

    private func webErrorView(_ message: String) -> some View {
        VStack(spacing: 14) {
            AppBoxGlyph(icon: .cloud)
                .frame(width: 34, height: 34)
                .foregroundColor(palette.secondaryText)
            Text(copy.text("页面暂时无法打开", "Unable to Open Page"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(palette.primaryText)
            Text(message)
                .font(.system(size: 13, weight: .regular))
                .foregroundColor(palette.secondaryText)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .padding(.horizontal, 28)
            Button(copy.text("重新加载", "Reload"), action: model.reload)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(palette.accent)
                .frame(height: 40)
                .padding(.horizontal, 18)
                .background(palette.accentSoft)
                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.background)
    }
}

private struct AppBoxWebView: UIViewRepresentable {
    let itemID: String
    let initialURL: URL
    @ObservedObject var model: AppBoxWebViewModel

    func makeCoordinator() -> Coordinator {
        Coordinator(model: model)
    }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = AppBoxWebDataStore.shared.websiteDataStore(for: itemID)
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true
        configuration.applicationNameForUserAgent = "AppBox/1.0"

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true
        webView.allowsLinkPreview = true
        webView.scrollView.contentInsetAdjustmentBehavior = .automatic
        webView.isOpaque = false
        webView.backgroundColor = .clear
        webView.scrollView.backgroundColor = .clear
        context.coordinator.attach(to: webView)
        webView.load(URLRequest(url: initialURL, cachePolicy: .useProtocolCachePolicy))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        context.coordinator.updateModel(model)
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        private var model: AppBoxWebViewModel
        private var progressObservation: NSKeyValueObservation?

        init(model: AppBoxWebViewModel) {
            self.model = model
        }

        func updateModel(_ model: AppBoxWebViewModel) {
            self.model = model
        }

        func attach(to webView: WKWebView) {
            model.attach(webView)
            progressObservation = webView.observe(\.estimatedProgress, options: [.new]) { [weak self, weak webView] _, _ in
                guard let self, let webView else { return }
                Task { @MainActor in self.model.refresh(from: webView) }
            }
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation?) {
            model.clearError()
            model.refresh(from: webView)
        }

        func webView(_ webView: WKWebView, didCommit navigation: WKNavigation?) {
            model.refresh(from: webView)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation?) {
            model.refresh(from: webView)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation?, withError error: Error) {
            model.showError(error)
            model.refresh(from: webView)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation?, withError error: Error) {
            model.showError(error)
            model.refresh(from: webView)
        }

        func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
            model.showError(NSError(
                domain: "AppBoxWebRuntime",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "Web content process terminated"]
            ))
        }

        func webView(
            _ webView: WKWebView,
            decidePolicyFor navigationAction: WKNavigationAction,
            decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
        ) {
            guard let url = navigationAction.request.url else {
                decisionHandler(.cancel)
                return
            }

            let allowedSchemes = ["http", "https", "about", "data", "blob"]
            guard allowedSchemes.contains(url.scheme?.lowercased() ?? "") else {
                if UIApplication.shared.canOpenURL(url) {
                    UIApplication.shared.open(url)
                }
                decisionHandler(.cancel)
                return
            }

            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
                decisionHandler(.cancel)
            } else {
                decisionHandler(.allow)
            }
        }

        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            guard navigationAction.targetFrame == nil else { return nil }
            webView.load(navigationAction.request)
            return nil
        }
    }
}
