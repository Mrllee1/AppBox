import Foundation

struct AppBoxIPAInstallRequest: Equatable {
    let id: String
    let sourceURL: URL
    let expectedBundleIdentifier: String?
}

@MainActor
protocol AppBoxIPAInstalling: AnyObject {
    func install(
        _ request: AppBoxIPAInstallRequest,
        progress: @escaping @MainActor (AppBoxInstallState) -> Void
    ) async throws -> LCAppModel

    func cancel(requestID: String)
}

enum AppBoxIPAInstallError: LocalizedError {
    case invalidResponse
    case unreadableSource
    case invalidArchive
    case missingApplication
    case unreadableApplication
    case bundleIdentifierMismatch
    case alreadyInstalled
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "The download server returned an invalid response."
        case .unreadableSource:
            return "The selected file could not be read."
        case .invalidArchive:
            return "The downloaded file is not a valid IPA."
        case .missingApplication:
            return "No application was found in the IPA."
        case .unreadableApplication:
            return "The application information could not be read."
        case .bundleIdentifierMismatch:
            return "The downloaded app does not match this catalog item."
        case .alreadyInstalled:
            return "The application is already installed."
        case .signingFailed(let message):
            return message
        }
    }
}

@MainActor
final class AppBoxIPAInstallService: AppBoxIPAInstalling {
    private var downloads: [String: AppBoxIPADownloadOperation] = [:]

    func install(
        _ request: AppBoxIPAInstallRequest,
        progress: @escaping @MainActor (AppBoxInstallState) -> Void
    ) async throws -> LCAppModel {
        let fileManager = FileManager.default
        let workingDirectory = fileManager.temporaryDirectory
            .appendingPathComponent("AppBoxCatalogInstall", isDirectory: true)
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let archiveURL = workingDirectory.appendingPathComponent("download.ipa")
        let extractionDirectory = workingDirectory.appendingPathComponent("Extracted", isDirectory: true)

        try fileManager.createDirectory(at: extractionDirectory, withIntermediateDirectories: true)
        defer { try? fileManager.removeItem(at: workingDirectory) }

        progress(.downloading(progress: 0))
        if request.sourceURL.isFileURL {
            try await stageLocalArchive(from: request.sourceURL, to: archiveURL)
            progress(.downloading(progress: 1))
        } else {
            let download = AppBoxIPADownloadOperation { value in
                progress(.downloading(progress: value))
            }
            downloads[request.id] = download
            defer { downloads[request.id] = nil }
            try await download.start(from: request.sourceURL, to: archiveURL)
        }
        try Task.checkCancellation()

        progress(.processing)
        let extractionProgress = Progress.discreteProgress(totalUnitCount: 100)
        guard await extractArchive(archiveURL, to: extractionDirectory, progress: extractionProgress) == 0 else {
            throw AppBoxIPAInstallError.invalidArchive
        }
        try Task.checkCancellation()

        let payloadURL = extractionDirectory.appendingPathComponent("Payload", isDirectory: true)
        let payloadItems = try fileManager.contentsOfDirectory(
            at: payloadURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        )
        guard let applicationURL = payloadItems.first(where: { $0.pathExtension.lowercased() == "app" }) else {
            throw AppBoxIPAInstallError.missingApplication
        }
        guard let importedInfo = LCAppInfo(bundlePath: applicationURL.path),
              let importedBundleIdentifier = importedInfo.bundleIdentifier() else {
            throw AppBoxIPAInstallError.unreadableApplication
        }
        if let expectedBundleIdentifier = request.expectedBundleIdentifier,
           importedBundleIdentifier != expectedBundleIdentifier {
            throw AppBoxIPAInstallError.bundleIdentifierMismatch
        }

        let relativeBundlePath = "\(importedBundleIdentifier.sanitizeNonACSII()).app"
        let outputURL = LCPath.bundlePath.appendingPathComponent(relativeBundlePath, isDirectory: true)
        guard !fileManager.fileExists(atPath: outputURL.path) else {
            throw AppBoxIPAInstallError.alreadyInstalled
        }

        try fileManager.moveItem(at: applicationURL, to: outputURL)
        var shouldRemoveOutput = true
        defer {
            if shouldRemoveOutput {
                try? fileManager.removeItem(at: outputURL)
            }
        }

        guard let finalInfo = LCAppInfo(bundlePath: outputURL.path) else {
            throw AppBoxIPAInstallError.unreadableApplication
        }
        finalInfo.relativeBundlePath = relativeBundlePath
        finalInfo.spoofSDKVersion = true

        let signingResult = await sign(finalInfo)
        if let message = signingResult.message, !signingResult.succeeded {
            throw AppBoxIPAInstallError.signingFailed(message)
        }
        try Task.checkCancellation()

        finalInfo.installationDate = .now
        if let schemes = finalInfo.urlSchemes() as? [Any], !schemes.isEmpty {
            UserDefaults.lcShared().mutableArrayValue(forKey: "LCGuestURLSchemes")
                .addObjects(from: schemes)
        }

        shouldRemoveOutput = false
        return LCAppModel(appInfo: finalInfo)
    }

    func cancel(requestID: String) {
        downloads[requestID]?.cancel()
        downloads[requestID] = nil
    }

    private nonisolated func stageLocalArchive(from sourceURL: URL, to destinationURL: URL) async throws {
        let didAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if didAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        guard FileManager.default.isReadableFile(atPath: sourceURL.path) else {
            throw AppBoxIPAInstallError.unreadableSource
        }

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        } catch {
            throw AppBoxIPAInstallError.unreadableSource
        }
    }

    private nonisolated func extractArchive(
        _ archiveURL: URL,
        to destinationURL: URL,
        progress: Progress
    ) async -> Int32 {
        extract(archiveURL.path, destinationURL.path, progress)
    }

    private func sign(_ appInfo: LCAppInfo) async -> (succeeded: Bool, message: String?) {
        await withCheckedContinuation { continuation in
            appInfo.patchExecAndSignIfNeed(
                completionHandler: { succeeded, message in
                    continuation.resume(returning: (succeeded, message))
                },
                progressHandler: { _ in },
                forceSign: false
            )
        }
    }
}

private final class AppBoxIPADownloadOperation: NSObject, URLSessionDownloadDelegate {
    private let progressHandler: @MainActor (Double) -> Void
    private var continuation: CheckedContinuation<Void, Error>?
    private var destinationURL: URL?
    private var session: URLSession?
    private var task: URLSessionDownloadTask?

    init(progressHandler: @escaping @MainActor (Double) -> Void) {
        self.progressHandler = progressHandler
    }

    func start(from sourceURL: URL, to destinationURL: URL) async throws {
        self.destinationURL = destinationURL

        try await withTaskCancellationHandler {
            try await withCheckedThrowingContinuation { continuation in
                self.continuation = continuation
                let configuration = URLSessionConfiguration.ephemeral
                configuration.timeoutIntervalForRequest = 60
                configuration.timeoutIntervalForResource = 30 * 60
                let session = URLSession(configuration: configuration, delegate: self, delegateQueue: .main)
                self.session = session
                let task = session.downloadTask(with: sourceURL)
                self.task = task
                task.resume()
            }
        } onCancel: {
            Task { @MainActor in self.cancel() }
        }
    }

    @MainActor
    func cancel() {
        task?.cancel()
        finish(.failure(CancellationError()))
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didWriteData bytesWritten: Int64,
        totalBytesWritten: Int64,
        totalBytesExpectedToWrite: Int64
    ) {
        guard totalBytesExpectedToWrite > 0 else { return }
        let value = min(max(Double(totalBytesWritten) / Double(totalBytesExpectedToWrite), 0), 1)
        Task { @MainActor in progressHandler(value) }
    }

    func urlSession(
        _ session: URLSession,
        downloadTask: URLSessionDownloadTask,
        didFinishDownloadingTo location: URL
    ) {
        guard let response = downloadTask.response as? HTTPURLResponse,
              (200...299).contains(response.statusCode),
              let destinationURL else {
            finish(.failure(AppBoxIPAInstallError.invalidResponse))
            return
        }

        do {
            try FileManager.default.moveItem(at: location, to: destinationURL)
            finish(.success(()))
        } catch {
            finish(.failure(error))
        }
    }

    func urlSession(
        _ session: URLSession,
        task: URLSessionTask,
        didCompleteWithError error: Error?
    ) {
        if let error {
            finish(.failure(error))
        }
    }

    private func finish(_ result: Result<Void, Error>) {
        guard let continuation else { return }
        self.continuation = nil
        task = nil
        session?.finishTasksAndInvalidate()
        session = nil
        continuation.resume(with: result)
    }
}
