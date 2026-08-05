import SwiftUI
import UniformTypeIdentifiers
import UIKit

enum AppBoxImportFailure: Equatable {
    case invalidLink
    case unsupportedFile
    case unreadableFile
    case invalidArchive
    case alreadyInstalled
    case catalogMismatch
    case signingFailed
    case network
    case launchFailed
    case unknown
}

enum AppBoxImportViewState: Equatable {
    case idle
    case downloading(progress: Double)
    case processing
    case cancelling
    case success(appName: String)
    case failure(AppBoxImportFailure)

    var isBusy: Bool {
        switch self {
        case .downloading, .processing, .cancelling:
            return true
        case .idle, .success, .failure:
            return false
        }
    }
}

@MainActor
final class AppBoxImportViewModel: ObservableObject {
    @Published var linkText = ""
    @Published private(set) var state: AppBoxImportViewState = .idle
    @Published private(set) var installedApp: LCAppModel?
    @Published private(set) var launchingBundleIdentifier: String?

    private let installer: any AppBoxIPAInstalling
    private var operationTask: Task<Void, Never>?
    private var activeRequestID: String?
    private var isCancellationRequested = false

    init(installer: (any AppBoxIPAInstalling)? = nil) {
        self.installer = installer ?? AppBoxIPAInstallService()
    }

    func importLink(onInstalled: @escaping (LCAppModel) -> Void) {
        let value = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              url.host != nil else {
            state = .failure(.invalidLink)
            return
        }

        start(url, onInstalled: onInstalled)
    }

    func importFile(_ url: URL, onInstalled: @escaping (LCAppModel) -> Void) {
        guard ["ipa", "tipa"].contains(url.pathExtension.lowercased()) else {
            state = .failure(.unsupportedFile)
            return
        }

        start(url, onInstalled: onInstalled)
    }

    func importSource(_ url: URL, onInstalled: @escaping (LCAppModel) -> Void) {
        if url.isFileURL {
            importFile(url, onInstalled: onInstalled)
        } else {
            linkText = url.absoluteString
            importLink(onInstalled: onInstalled)
        }
    }

    func pasteLink() {
        guard let value = UIPasteboard.general.string else { return }
        linkText = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if case .failure(.invalidLink) = state {
            state = .idle
        }
    }

    func reset() {
        guard !state.isBusy else { return }
        installedApp = nil
        state = .idle
    }

    func cancel() {
        guard let requestID = activeRequestID, !isCancellationRequested else { return }
        isCancellationRequested = true
        state = .cancelling
        installer.cancel(requestID: requestID)
        operationTask?.cancel()
    }

    func launch(_ app: LCAppModel) {
        guard launchingBundleIdentifier == nil, !state.isBusy else { return }
        launchingBundleIdentifier = app.bundleIdentifier

        Task { [weak self] in
            do {
                try await app.runApp()
                self?.launchingBundleIdentifier = nil
            } catch {
                self?.launchingBundleIdentifier = nil
                self?.state = .failure(.launchFailed)
            }
        }
    }

    private func start(_ sourceURL: URL, onInstalled: @escaping (LCAppModel) -> Void) {
        guard activeRequestID == nil else { return }

        let requestID = UUID().uuidString
        activeRequestID = requestID
        isCancellationRequested = false
        installedApp = nil
        state = sourceURL.isFileURL ? .processing : .downloading(progress: 0)

        operationTask = Task { [weak self] in
            guard let self else { return }
            do {
                let app = try await installer.install(
                    AppBoxIPAInstallRequest(
                        id: requestID,
                        sourceURL: sourceURL,
                        expectedBundleIdentifier: nil
                    )
                ) { [weak self] installState in
                    guard let self,
                          self.activeRequestID == requestID,
                          !self.isCancellationRequested else { return }
                    self.apply(installState, isLocalFile: sourceURL.isFileURL)
                }

                try Task.checkCancellation()
                guard activeRequestID == requestID, !isCancellationRequested else {
                    throw CancellationError()
                }

                onInstalled(app)
                installedApp = app
                state = .success(appName: app.displayName)
                finish(requestID: requestID)
            } catch is CancellationError {
                guard activeRequestID == requestID else { return }
                state = .idle
                finish(requestID: requestID)
            } catch {
                guard activeRequestID == requestID else { return }
                state = .failure(map(error))
                finish(requestID: requestID)
            }
        }
    }

    private func apply(_ installState: AppBoxInstallState, isLocalFile: Bool) {
        switch installState {
        case .downloading(let progress):
            state = isLocalFile ? .processing : .downloading(progress: progress)
        case .processing:
            state = .processing
        case .completed:
            break
        case .failed:
            state = .failure(.unknown)
        }
    }

    private func finish(requestID: String) {
        guard activeRequestID == requestID else { return }
        activeRequestID = nil
        isCancellationRequested = false
        operationTask = nil
    }

    private func map(_ error: Error) -> AppBoxImportFailure {
        guard let installError = error as? AppBoxIPAInstallError else {
            return error is URLError ? .network : .unknown
        }

        switch installError {
        case .invalidResponse:
            return .network
        case .unreadableSource:
            return .unreadableFile
        case .invalidArchive, .missingApplication, .unreadableApplication:
            return .invalidArchive
        case .bundleIdentifierMismatch:
            return .catalogMismatch
        case .alreadyInstalled:
            return .alreadyInstalled
        case .signingFailed:
            return .signingFailed
        }
    }
}

struct AppBoxContainerInstallerView: View {
    let sourceURL: URL?

    @EnvironmentObject private var sharedModel: SharedModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("appbox.language") private var language: AppBoxLanguage = .simplifiedChinese
    @AppStorage("appbox.skin") private var skin: AppBoxSkin = .sky

    @StateObject private var model = AppBoxImportViewModel()
    @State private var isChoosingFile = false
    @State private var didStartInitialSource = false

    private var copy: AppBoxCopy { AppBoxCopy(language: language) }
    private var palette: AppBoxPalette { AppBoxPalette(skin: skin, colorScheme: colorScheme) }

    var body: some View {
        ZStack {
            palette.background.ignoresSafeArea()

            VStack(spacing: 0) {
                AppBoxSheetHeader(
                    title: copy.text("导入 IPA", "Import IPA"),
                    closeLabel: copy.text("关闭", "Close"),
                    palette: palette,
                    dismiss: { dismiss() }
                )

                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: AppBoxLayout.sectionSpacing) {
                        content

                        if !sharedModel.apps.isEmpty {
                            importedApps
                        }
                    }
                    .padding(.horizontal, AppBoxLayout.pagePadding)
                    .padding(.top, 12)
                    .padding(.bottom, 32)
                }
            }
        }
        .tint(palette.accent)
        .betterFileImporter(
            isPresented: $isChoosingFile,
            types: [.ipa, .tipa],
            multiple: false,
            callback: { urls in
                isChoosingFile = false
                guard let url = urls.first else { return }
                model.importFile(url, onInstalled: addInstalledApp)
            },
            onDismiss: { isChoosingFile = false }
        )
        .onAppear {
            guard !didStartInitialSource, let sourceURL else { return }
            didStartInitialSource = true
            model.importSource(sourceURL, onInstalled: addInstalledApp)
        }
        .onDisappear { model.cancel() }
        .animation(reduceMotion ? nil : .easeOut(duration: 0.20), value: model.state)
    }

    @ViewBuilder
    private var content: some View {
        switch model.state {
        case .idle:
            sourceControls
        case .downloading(let progress):
            statusCard(
                icon: .cloud,
                title: copy.text("正在下载", "Downloading"),
                detail: "\(Int((progress * 100).rounded()))%",
                progress: progress,
                showsActivity: false,
                actionTitle: copy.text("取消", "Cancel"),
                action: model.cancel
            )
        case .processing:
            statusCard(
                icon: .shield,
                title: copy.text("正在验证并安装", "Verifying and installing"),
                detail: copy.text("正在处理应用文件", "Processing app package"),
                progress: nil,
                showsActivity: true,
                actionTitle: copy.text("取消", "Cancel"),
                action: model.cancel
            )
        case .cancelling:
            statusCard(
                icon: .stop,
                title: copy.text("正在取消", "Cancelling"),
                detail: copy.text("正在结束当前任务", "Finishing the current task"),
                progress: nil,
                showsActivity: true,
                actionTitle: nil,
                action: nil
            )
        case .success(let appName):
            resultCard(
                icon: .checkCircle,
                color: Color(uiColor: .systemGreen),
                title: copy.text("导入完成", "Import complete"),
                detail: copy.text("\(appName) 已添加到已导入应用", "\(appName) was added to Imported Apps"),
                primaryTitle: copy.text("启动", "Open"),
                primaryAction: {
                    guard let app = model.installedApp else { return }
                    model.launch(app)
                },
                secondaryTitle: copy.text("继续导入", "Import another"),
                secondaryAction: model.reset
            )
        case .failure(let failure):
            resultCard(
                icon: .warning,
                color: palette.destructive,
                title: copy.text("无法导入", "Import failed"),
                detail: failureMessage(failure),
                primaryTitle: copy.text("重新选择", "Try again"),
                primaryAction: model.reset,
                secondaryTitle: nil,
                secondaryAction: nil
            )
        }
    }

    private var sourceControls: some View {
        VStack(alignment: .leading, spacing: AppBoxLayout.sectionSpacing) {
            VStack(alignment: .leading, spacing: 12) {
                AppBoxSectionHeading(title: copy.text("本地文件", "Local file"), palette: palette)

                Button { isChoosingFile = true } label: {
                    HStack(spacing: 14) {
                        sourceIcon(.folder)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(copy.text("选择 IPA 文件", "Choose IPA file"))
                                .font(.body.weight(.semibold))
                                .foregroundColor(palette.primaryText)
                            Text("IPA · TIPA")
                                .font(.caption)
                                .foregroundColor(palette.secondaryText)
                        }
                        Spacer(minLength: 8)
                        AppBoxGlyph(icon: .arrowRight)
                            .frame(width: 14, height: 14)
                            .foregroundColor(palette.secondaryText)
                    }
                    .padding(.horizontal, 16)
                    .frame(minHeight: 72)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .appBoxSurface(palette)
            }

            VStack(alignment: .leading, spacing: 12) {
                AppBoxSectionHeading(title: copy.text("下载链接", "Download link"), palette: palette)

                VStack(spacing: 12) {
                    HStack(spacing: 10) {
                        AppBoxGlyph(icon: .link)
                            .frame(width: 18, height: 18)
                            .foregroundColor(palette.secondaryText)

                        TextField("https://example.com/app.ipa", text: $model.linkText)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .keyboardType(.URL)
                            .submitLabel(.go)
                            .onSubmit { model.importLink(onInstalled: addInstalledApp) }

                        if !model.linkText.isEmpty {
                            Button { model.linkText = "" } label: {
                                AppBoxGlyph(icon: .closeCircle)
                                    .frame(width: 18, height: 18)
                                    .foregroundColor(palette.secondaryText)
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel(copy.text("清空", "Clear"))
                        }

                        Button(action: model.pasteLink) {
                            AppBoxGlyph(icon: .clipboard)
                                .frame(width: 19, height: 19)
                                .foregroundColor(palette.accent)
                                .frame(width: 36, height: 36)
                                .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(copy.text("粘贴", "Paste"))
                    }
                    .padding(.leading, 14)
                    .padding(.trailing, 6)
                    .frame(height: AppBoxLayout.controlHeight)
                    .background(palette.mutedSurface)
                    .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))

                    Button { model.importLink(onInstalled: addInstalledApp) } label: {
                        Text(copy.text("从链接导入", "Import from link"))
                            .font(.body.weight(.semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity, minHeight: AppBoxLayout.controlHeight)
                            .background(model.linkText.isEmpty ? palette.secondaryText : palette.accent)
                            .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(model.linkText.isEmpty)
                }
                .padding(14)
                .appBoxSurface(palette)
            }
        }
    }

    private var importedApps: some View {
        VStack(alignment: .leading, spacing: 12) {
            AppBoxSectionHeading(
                title: copy.text("已导入应用", "Imported Apps"),
                detail: "\(sharedModel.apps.count)",
                palette: palette
            )

            VStack(spacing: 0) {
                ForEach(Array(sharedModel.apps.enumerated()), id: \.element.bundleIdentifier) { index, app in
                    importedAppRow(app)
                    if index < sharedModel.apps.count - 1 {
                        Rectangle()
                            .fill(palette.divider)
                            .frame(height: 1)
                            .padding(.leading, 70)
                    }
                }
            }
            .appBoxSurface(palette)
        }
    }

    private func importedAppRow(_ app: LCAppModel) -> some View {
        HStack(spacing: 12) {
            IconImageView(icon: app.appInfo.iconIsDarkIcon(colorScheme == .dark) ?? UIImage())
                .frame(width: 46, height: 46)

            VStack(alignment: .leading, spacing: 3) {
                Text(app.displayName)
                    .font(.body.weight(.semibold))
                    .foregroundColor(palette.primaryText)
                    .lineLimit(1)
                Text(app.version)
                    .font(.caption)
                    .foregroundColor(palette.secondaryText)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            Button { model.launch(app) } label: {
                if model.launchingBundleIdentifier == app.bundleIdentifier {
                    ProgressView()
                        .tint(palette.accent)
                        .frame(width: 56, height: 34)
                } else {
                    Text(copy.text("启动", "Open"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(palette.accent)
                        .frame(minWidth: 56, minHeight: 34)
                        .background(palette.accentSoft)
                        .clipShape(Capsule())
                }
            }
            .buttonStyle(.plain)
            .disabled(model.launchingBundleIdentifier != nil || model.state.isBusy)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 70)
    }

    private func sourceIcon(_ icon: AppBoxIcon) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous)
                .fill(palette.accentSoft)
            AppBoxGlyph(icon: icon)
                .frame(width: 21, height: 21)
                .foregroundColor(palette.accent)
        }
        .frame(width: 42, height: 42)
    }

    private func statusCard(
        icon: AppBoxIcon,
        title: String,
        detail: String,
        progress: Double?,
        showsActivity: Bool,
        actionTitle: String?,
        action: (() -> Void)?
    ) -> some View {
        VStack(spacing: 18) {
            sourceIcon(icon)

            VStack(spacing: 5) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(palette.primaryText)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(palette.secondaryText)
            }

            if let progress {
                ProgressView(value: min(max(progress, 0), 1))
                    .progressViewStyle(.linear)
                    .tint(palette.accent)
            } else if showsActivity {
                ProgressView()
                    .tint(palette.accent)
            }

            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .font(.body.weight(.medium))
                    .foregroundColor(palette.destructive)
                    .frame(minWidth: 96, minHeight: AppBoxLayout.controlHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .appBoxSurface(palette)
    }

    private func resultCard(
        icon: AppBoxIcon,
        color: Color,
        title: String,
        detail: String,
        primaryTitle: String,
        primaryAction: @escaping () -> Void,
        secondaryTitle: String?,
        secondaryAction: (() -> Void)?
    ) -> some View {
        VStack(spacing: 18) {
            ZStack {
                Circle().fill(color.opacity(0.12))
                AppBoxGlyph(icon: icon)
                    .frame(width: 28, height: 28)
                    .foregroundColor(color)
            }
            .frame(width: 56, height: 56)

            VStack(spacing: 6) {
                Text(title)
                    .font(.title3.weight(.semibold))
                    .foregroundColor(palette.primaryText)
                Text(detail)
                    .font(.subheadline)
                    .foregroundColor(palette.secondaryText)
                    .multilineTextAlignment(.center)
            }

            Button(action: primaryAction) {
                Text(primaryTitle)
                    .font(.body.weight(.semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity, minHeight: AppBoxLayout.controlHeight)
                    .background(palette.accent)
                    .clipShape(RoundedRectangle(cornerRadius: AppBoxLayout.cardRadius, style: .continuous))
            }
            .buttonStyle(.plain)

            if let secondaryTitle, let secondaryAction {
                Button(secondaryTitle, action: secondaryAction)
                    .font(.body.weight(.medium))
                    .foregroundColor(palette.accent)
                    .frame(minHeight: AppBoxLayout.controlHeight)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .appBoxSurface(palette)
    }

    private func failureMessage(_ failure: AppBoxImportFailure) -> String {
        switch failure {
        case .invalidLink:
            return copy.text("请输入有效的 HTTP 或 HTTPS 下载链接", "Enter a valid HTTP or HTTPS download link")
        case .unsupportedFile:
            return copy.text("请选择 IPA 或 TIPA 文件", "Choose an IPA or TIPA file")
        case .unreadableFile:
            return copy.text("无法读取所选文件，请重新选择", "The selected file could not be read")
        case .invalidArchive:
            return copy.text("文件不是有效的 IPA，或应用信息不完整", "The file is not a valid IPA or its app information is incomplete")
        case .alreadyInstalled:
            return copy.text("该应用已经导入", "This app is already imported")
        case .catalogMismatch:
            return copy.text("应用与下载项目不匹配", "The app does not match the download item")
        case .signingFailed:
            return copy.text("应用处理失败，请检查签名环境后重试", "App processing failed. Check the signing environment and try again")
        case .network:
            return copy.text("下载失败，请检查链接或网络后重试", "Download failed. Check the link or network and try again")
        case .launchFailed:
            return copy.text("应用暂时无法启动，请稍后重试", "The app could not be opened. Try again later")
        case .unknown:
            return copy.text("无法完成导入，请确认文件有效后重试", "The import could not be completed. Check the file and try again")
        }
    }

    private func addInstalledApp(_ app: LCAppModel) {
        guard !sharedModel.apps.contains(where: { $0.bundleIdentifier == app.bundleIdentifier }) else { return }
        sharedModel.apps.append(app)
    }
}
