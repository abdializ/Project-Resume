import Combine
import Foundation
import Sparkle

@MainActor
final class SparkleUpdateService: ObservableObject {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var statusMessage = "Updates are managed by Sparkle."
    @Published private(set) var lastServerEvent = "No local update feed requests yet."

    private let updaterController: SPUStandardUpdaterController
    private let serverQueue = DispatchQueue(label: "ProjectResume.SparkleUpdateService.server")
    private var canCheckCancellable: AnyCancellable?
    private var hasStartedUpdater = false
    private var configuredFeedDirectoryPath: String?
    private var isPreparingFeed = false
    private var pendingInteractiveCheck = false
    private let updaterDelegate = SparkleFeedDelegate()
    private let localFeedServer = LocalUpdateFeedServer()

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: false,
            updaterDelegate: updaterDelegate,
            userDriverDelegate: nil
        )

        updaterDelegate.report = { [weak self] message in
            Task { @MainActor in
                self?.statusMessage = message
            }
        }

        canCheckCancellable = updaterController.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: \.canCheckForUpdates, on: self)

        localFeedServer.onRequest = { [weak self] event in
            Task { @MainActor in
                self?.lastServerEvent = event
            }
        }
    }

    var isRunningBetaBuild: Bool {
        (Bundle.main.bundleIdentifier ?? "").contains("beta")
    }

    var currentVersionDescription: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "0"
        return "v\(version) (\(build))"
    }

    func configure(feedDirectoryPath: String) {
        guard isRunningBetaBuild else {
            statusMessage = "Sparkle updates are available in the beta app only."
            return
        }

        configuredFeedDirectoryPath = feedDirectoryPath
        prepareFeedIfNeeded(triggerCheckAfterPreparation: false)
    }

    func checkForUpdates() {
        guard isRunningBetaBuild else {
            statusMessage = "Sparkle checks are only available in the beta app."
            return
        }

        pendingInteractiveCheck = true
        prepareFeedIfNeeded(triggerCheckAfterPreparation: true)
    }

    func checkForUpdates(feedDirectoryPath: String) {
        configuredFeedDirectoryPath = feedDirectoryPath
        checkForUpdates()
    }

    func testFeedConnection() {
        guard isRunningBetaBuild else {
            statusMessage = "Feed tests are only available in the beta app."
            return
        }

        guard let configuredFeedDirectoryPath else {
            statusMessage = "Choose an update folder first."
            return
        }

        statusMessage = "Testing update feed..."
        prepareFeedIfNeeded(triggerCheckAfterPreparation: false)

        Task {
            do {
                _ = try await startFeedServer(directoryPath: configuredFeedDirectoryPath)
                let appcastURL = LocalUpdateFeedServer.appcastURL
                let (appcastData, appcastResponse) = try await URLSession.shared.data(from: appcastURL)
                let appcastStatus = (appcastResponse as? HTTPURLResponse)?.statusCode ?? -1

                guard appcastStatus == 200 else {
                    statusMessage = "Feed test failed on appcast. HTTP \(appcastStatus)"
                    return
                }

                let zipURL = appcastURL.deletingLastPathComponent().appendingPathComponent("Project-Resume-Beta.zip")
                var request = URLRequest(url: zipURL)
                request.httpMethod = "HEAD"

                let (_, zipResponse) = try await URLSession.shared.data(for: request)
                let zipStatus = (zipResponse as? HTTPURLResponse)?.statusCode ?? -1

                let preview = String(data: appcastData.prefix(120), encoding: .utf8)?
                    .replacingOccurrences(of: "\n", with: " ")
                    .trimmingCharacters(in: .whitespacesAndNewlines) ?? "No preview"

                statusMessage = "Feed test succeeded. appcast=HTTP \(appcastStatus), zip=HTTP \(zipStatus). Preview: \(preview)"
            } catch {
                let nsError = error as NSError
                statusMessage = "Feed test failed. \(describe(error: nsError))"
            }
        }
    }

    private func prepareFeedIfNeeded(triggerCheckAfterPreparation: Bool) {
        guard let configuredFeedDirectoryPath else {
            statusMessage = "Choose an update folder first."
            return
        }

        if isPreparingFeed {
            if triggerCheckAfterPreparation {
                pendingInteractiveCheck = true
                statusMessage = "Preparing updater..."
            }
            return
        }

        isPreparingFeed = true
        if triggerCheckAfterPreparation {
            statusMessage = "Preparing updater..."
        }

        Task {
            do {
                let appcastURL = try await startFeedServer(directoryPath: configuredFeedDirectoryPath)
                updaterDelegate.feedURLString = appcastURL.absoluteString

                if !hasStartedUpdater {
                    updaterController.startUpdater()
                    hasStartedUpdater = true
                }

                isPreparingFeed = false

                if pendingInteractiveCheck {
                    pendingInteractiveCheck = false
                    statusMessage = "Checking for updates..."
                    updaterController.checkForUpdates(nil)
                } else {
                    statusMessage = "Sparkle is ready. Feed: \(appcastURL.absoluteString)"
                }
            } catch {
                isPreparingFeed = false
                pendingInteractiveCheck = false
                statusMessage = "Could not start the local update feed server: \(error.localizedDescription)"
            }
        }
    }

    private func startFeedServer(directoryPath: String) async throws -> URL {
        let feedDirectoryURL = URL(fileURLWithPath: directoryPath.expandedPath, isDirectory: true)
        return try await withCheckedThrowingContinuation { continuation in
            serverQueue.async { [localFeedServer] in
                do {
                    let appcastURL = try localFeedServer.startIfNeeded(serving: feedDirectoryURL)
                    continuation.resume(returning: appcastURL)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func describe(error: NSError) -> String {
        [
            "domain=\(error.domain)",
            "code=\(error.code)",
            error.localizedDescription,
            error.localizedFailureReason,
            error.localizedRecoverySuggestion,
            (error.userInfo[NSUnderlyingErrorKey] as? NSError).map {
                "underlying(domain=\($0.domain), code=\($0.code), description=\($0.localizedDescription))"
            }
        ]
        .compactMap { $0?.nilIfBlank }
        .joined(separator: " | ")
    }
}

private final class SparkleFeedDelegate: NSObject, SPUUpdaterDelegate {
    var feedURLString: String?
    var report: ((String) -> Void)?

    func feedURLString(for updater: SPUUpdater) -> String? {
        feedURLString
    }

    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        report?("Sparkle loaded the appcast successfully.")
    }

    func updater(_ updater: SPUUpdater, didFindValidUpdate item: SUAppcastItem) {
        let version = item.displayVersionString
        let build = item.versionString
        report?("Update found: \(version) (\(build)).")
    }

    func updaterDidNotFindUpdate(_ updater: SPUUpdater, error: Error) {
        let nsError = error as NSError
        report?("No update found. \(describe(error: nsError))")
    }

    func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        let nsError = error as NSError
        report?("Sparkle failed downloading \(item.displayVersionString). \(describe(error: nsError))")
    }

    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        let nsError = error as NSError
        report?("Sparkle aborted. \(describe(error: nsError))")
    }

    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: (any Error)?) {
        if let error {
            let nsError = error as NSError
            report?("Update cycle finished with error. \(describe(error: nsError))")
        }
    }

    private func describe(error: NSError) -> String {
        let parts = [
            "domain=\(error.domain)",
            "code=\(error.code)",
            error.localizedDescription,
            error.localizedFailureReason,
            error.localizedRecoverySuggestion,
            (error.userInfo[NSUnderlyingErrorKey] as? NSError).map {
                "underlying(domain=\($0.domain), code=\($0.code), description=\($0.localizedDescription))"
            }
        ]
            .compactMap { $0?.nilIfBlank }

        return parts.joined(separator: " | ")
    }
}
