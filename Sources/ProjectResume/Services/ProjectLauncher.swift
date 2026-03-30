import AppKit
import Foundation

enum ProjectLaunchMode: String, CaseIterable, Identifiable {
    case everything
    case folderOnly
    case appsOnly
    case linksOnly
    case commandsOnly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .everything:
            return "Everything"
        case .folderOnly:
            return "Folder Only"
        case .appsOnly:
            return "Apps Only"
        case .linksOnly:
            return "Links Only"
        case .commandsOnly:
            return "Commands Only"
        }
    }

    var systemImage: String {
        switch self {
        case .everything:
            return "play.fill"
        case .folderOnly:
            return "folder"
        case .appsOnly:
            return "square.grid.2x2"
        case .linksOnly:
            return "link"
        case .commandsOnly:
            return "terminal"
        }
    }
}

struct LaunchResult {
    let warnings: [String]

    var hasWarnings: Bool {
        !warnings.isEmpty
    }
}

@MainActor
struct ProjectLauncher {
    private let workspace: NSWorkspace
    private let terminalRunner: TerminalCommandRunner

    init(
        workspace: NSWorkspace = .shared,
        terminalRunner: TerminalCommandRunner = TerminalCommandRunner()
    ) {
        self.workspace = workspace
        self.terminalRunner = terminalRunner
    }

    private static var vsCodeInstalledCache: Bool?

    var isVSCodeInstalled: Bool {
        if let cached = Self.vsCodeInstalledCache {
            return cached
        }
        
        let installed = resolveApplicationURL(from: "com.microsoft.VSCode") != nil
            || resolveApplicationURL(from: "Visual Studio Code") != nil
        
        Self.vsCodeInstalledCache = installed
        return installed
    }

    func displayName(for folderLaunchMode: FolderLaunchMode) -> String {
        switch folderLaunchMode.kind {
        case .finder:
            return "Finder"
        case .application:
            return ApplicationCatalog.displayName(for: folderLaunchMode.applicationEntry ?? "")
        }
    }

    func launch(_ project: Project, mode: ProjectLaunchMode = .everything) async -> LaunchResult {
        var warnings: [String] = []

        if mode == .everything || mode == .folderOnly {
            warnings.append(contentsOf: await openFolder(for: project))
        }

        if mode == .everything || mode == .appsOnly {
            warnings.append(contentsOf: await openApplications(project.apps))
        }

        if mode == .everything || mode == .linksOnly {
            warnings.append(contentsOf: openURLs(project.urls))
        }

        if mode == .everything || mode == .commandsOnly {
            warnings.append(contentsOf: runCommands(project.terminalCommands, workingDirectory: project.folderPath))
        }

        return LaunchResult(warnings: warnings)
    }

    private func openFolder(for project: Project) async -> [String] {
        guard let path = project.folderPath.nilIfBlank else {
            return []
        }

        let folderURL = URL(fileURLWithPath: path.expandedPath)
        guard FileManager.default.fileExists(atPath: folderURL.path) else {
            return ["Folder path does not exist: \(folderURL.path)"]
        }

        switch project.folderLaunchMode {
        case let mode where mode.kind == .finder:
            return workspace.open(folderURL) ? [] : ["Could not open folder in Finder: \(folderURL.path)"]
        case let mode:
            if let warning = openFolder(folderURL, with: mode.applicationEntry) {
                let finderWarning = workspace.open(folderURL) ? nil : "Could not open folder in Finder fallback: \(folderURL.path)"
                return [warning, finderWarning].compactMap { $0 }
            }
            return []
        }
    }

    private func openApplications(_ entries: [String]) async -> [String] {
        var warnings: [String] = []

        for entry in entries.normalizedEntries() {
            guard let applicationURL = resolveApplicationURL(from: entry) else {
                warnings.append("App could not be resolved: \(entry)")
                continue
            }

            if let warning = await openApplication(at: applicationURL) {
                warnings.append(warning)
            }
        }

        return warnings
    }

    private func openURLs(_ entries: [String]) -> [String] {
        entries.normalizedEntries().compactMap { entry in
            guard let url = normalizedURL(from: entry) else {
                return "Invalid URL: \(entry)"
            }

            return workspace.open(url) ? nil : "Could not open URL: \(entry)"
        }
    }

    private func runCommands(_ commands: [String], workingDirectory: String) -> [String] {
        commands.normalizedEntries().compactMap { command in
            terminalRunner.run(command: command, workingDirectory: workingDirectory)
        }
    }

    private func resolveApplicationURL(from entry: String) -> URL? {
        let trimmedEntry = entry.trimmed
        guard !trimmedEntry.isEmpty else {
            return nil
        }

        if trimmedEntry.hasPrefix("/") || trimmedEntry.hasPrefix("~") {
            let url = URL(fileURLWithPath: trimmedEntry.expandedPath)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }

        if trimmedEntry.contains("."),
           let bundleURL = workspace.urlForApplication(withBundleIdentifier: trimmedEntry) {
            return bundleURL
        }

        return resolveApplicationURLByName(trimmedEntry)
    }

    private func resolveApplicationURLByName(_ name: String) -> URL? {
        let candidateNames: [String]

        if name.hasSuffix(".app") {
            candidateNames = [name]
        } else {
            candidateNames = [name, "\(name).app"]
        }

        let searchRoots = [
            "/Applications",
            "/Applications/Utilities",
            "/System/Applications",
            "/System/Applications/Utilities",
            "~/Applications"
        ]

        for root in searchRoots {
            let rootURL = URL(fileURLWithPath: root.expandedPath, isDirectory: true)

            for candidateName in candidateNames {
                let candidateURL = rootURL.appendingPathComponent(candidateName, isDirectory: true)
                if FileManager.default.fileExists(atPath: candidateURL.path) {
                    return candidateURL
                }
            }
        }

        return nil
    }

    private func openApplication(at applicationURL: URL) async -> String? {
        await withCheckedContinuation { continuation in
            workspace.openApplication(at: applicationURL, configuration: .init()) { _, error in
                if let error {
                    continuation.resume(
                        returning: "Could not open \(applicationURL.lastPathComponent): \(error.localizedDescription)"
                    )
                } else {
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    private func openFolder(_ folderURL: URL, with applicationEntry: String?) -> String? {
        guard let applicationEntry,
              let applicationURL = resolveApplicationURL(from: applicationEntry) else {
            return "The selected app for opening folders is not available. Opened the folder in Finder instead."
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["-a", applicationURL.path, folderURL.path]
        process.standardError = outputPipe
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmed ?? "The open command returned a non-zero exit code."
                return "Could not open folder in \(applicationURL.deletingPathExtension().lastPathComponent): \(output)"
            }

            return nil
        } catch {
            return "Could not open folder in \(applicationURL.deletingPathExtension().lastPathComponent): \(error.localizedDescription)"
        }
    }

    private func normalizedURL(from entry: String) -> URL? {
        let trimmedEntry = entry.trimmed

        guard !trimmedEntry.isEmpty else {
            return nil
        }

        if let url = URL(string: trimmedEntry), url.scheme != nil {
            return url
        }

        return URL(string: "https://\(trimmedEntry)")
    }
}
