import Foundation

struct GeneratedSessionProject {
    let draft: ProjectDraft
    let sourceSummary: String
}

struct SessionRefreshResult {
    let project: Project
    let sourceSummary: String
}

@MainActor
struct SessionProjectGenerator {
    private let sessionTracker: SessionTracker
    private let browserURLCaptureService: BrowserURLCaptureService

    init(
        sessionTracker: SessionTracker,
        browserURLCaptureService: BrowserURLCaptureService = BrowserURLCaptureService()
    ) {
        self.sessionTracker = sessionTracker
        self.browserURLCaptureService = browserURLCaptureService
    }

    func generateDraft(now: Date = .now) -> GeneratedSessionProject {
        let snapshot = captureSnapshot(now: now)
        let projectName = Self.defaultProjectName(now: now, apps: snapshot.focusedApps)
        let description = Self.descriptionText(appCount: snapshot.focusedApps.count, urlCount: snapshot.urls.count)
        let note = Self.noteText(now: now, apps: snapshot.focusedApps, urls: snapshot.urls)

        let draft = ProjectDraft(
            sourceProjectID: nil,
            createdAt: nil,
            name: projectName,
            projectDescription: description,
            folderPath: "",
            folderLaunchMode: .finder,
            apps: snapshot.appEntries,
            urls: snapshot.urls,
            terminalCommands: [],
            lastNote: note,
            sessionCapturedAt: now
        )

        let summary = "\(snapshot.focusedApps.count) apps, \(snapshot.urls.count) browser links"
        return GeneratedSessionProject(draft: draft, sourceSummary: summary)
    }

    func refresh(project: Project, now: Date = .now) -> SessionRefreshResult {
        let snapshot = captureSnapshot(now: now)

        var updatedProject = project
        updatedProject.apps = snapshot.appEntries
        updatedProject.urls = snapshot.urls
        updatedProject.sessionCapturedAt = now
        updatedProject.updatedAt = now

        let summary = "\(snapshot.focusedApps.count) apps, \(snapshot.urls.count) browser links"
        return SessionRefreshResult(project: updatedProject, sourceSummary: summary)
    }

    private func captureSnapshot(now: Date) -> SessionSnapshot {
        let trackedApps = sessionTracker.snapshot()
        let focusedApps = trackedApps
            .filter { $0.accumulatedFocusTime >= 60 || $0.isRunning }
        let appEntries = focusedApps.map { usage in
            usage.appPath.nilIfBlank ?? usage.displayName
        }
        let urls = browserURLCaptureService.captureBrowserURLs()

        return SessionSnapshot(
            focusedApps: focusedApps,
            appEntries: appEntries,
            urls: urls,
            capturedAt: now
        )
    }

    private static func defaultProjectName(now: Date, apps: [TrackedApplicationUsage]) -> String {
        if let topApp = apps.first?.displayName.nilIfBlank {
            return "\(topApp) Session \(now.formatted(date: .abbreviated, time: .omitted))"
        }

        return "Session \(now.formatted(date: .abbreviated, time: .omitted))"
    }

    private static func descriptionText(appCount: Int, urlCount: Int) -> String {
        if appCount == 0 && urlCount == 0 {
            return "Generated from the current macOS session."
        }

        return "Generated from the current macOS session with \(appCount) tracked apps and \(urlCount) captured links."
    }

    private static func noteText(now: Date, apps: [TrackedApplicationUsage], urls: [String]) -> String {
        let formatter = Date.FormatStyle(date: .abbreviated, time: .shortened)
        let topApps = apps
            .prefix(3)
            .map { usage in
                let minutes = max(1, Int(usage.accumulatedFocusTime / 60))
                return "\(usage.displayName) (\(minutes)m)"
            }
            .joined(separator: ", ")

        let appLine = topApps.isEmpty ? "No qualifying apps were tracked yet." : "Top apps: \(topApps)."
        let linkLine = urls.isEmpty ? "No browser links were captured from supported browsers." : "Captured \(urls.count) browser links."

        return "Session captured on \(now.formatted(formatter)). \(appLine) \(linkLine)"
    }
}

private struct SessionSnapshot {
    let focusedApps: [TrackedApplicationUsage]
    let appEntries: [String]
    let urls: [String]
    let capturedAt: Date
}
