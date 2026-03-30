import AppKit
import Foundation
import UniformTypeIdentifiers

struct DiscoveredApplication: Identifiable, Hashable {
    let path: String
    let title: String
    let bundleIdentifier: String?
    let isRunning: Bool

    var id: String { path }
}

enum ApplicationCatalog {
    private static let allowedApplicationRoots = [
        "/Applications",
        "/Applications/Utilities",
        "/System/Applications",
        "/System/Applications/Utilities",
        "~/Applications"
    ].map(\.expandedPath)

    private static let preferredIDEPatterns = [
        "cursor",
        "code",
        "codium",
        "windsurf",
        "zed",
        "xcode",
        "fleet",
        "nova",
        "sublime",
        "textmate",
        "intellij",
        "webstorm",
        "pycharm",
        "rubymine",
        "clion",
        "goland",
        "android studio",
        "eclipse",
        "antigravity"
    ]

    nonisolated(unsafe) private static var cachedInstalledApplications: [DiscoveredApplication]?

    static func discoverInstalledApplications() -> [DiscoveredApplication] {
        if let cached = cachedInstalledApplications {
            return cached
        }
        
        let fileManager = FileManager.default

        var appsByPath: [String: DiscoveredApplication] = [:]
        let runningApps = NSWorkspace.shared.runningApplications

        for app in runningApps {
            guard let url = app.bundleURL,
                  isUserFacingApplication(url) else {
                continue
            }

            let path = url.path
            appsByPath[path] = DiscoveredApplication(
                path: path,
                title: url.deletingPathExtension().lastPathComponent,
                bundleIdentifier: app.bundleIdentifier,
                isRunning: !app.isTerminated
            )
        }

        for root in allowedApplicationRoots where fileManager.fileExists(atPath: root) {
            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: root, isDirectory: true),
                includingPropertiesForKeys: [.isApplicationKey, .isDirectoryKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let fileURL as URL in enumerator {
                guard isUserFacingApplication(fileURL) else {
                    continue
                }

                let path = fileURL.path
                if appsByPath[path] != nil {
                    continue
                }

                let runningApp = runningApps.first { $0.bundleURL?.path == path }
                appsByPath[path] = DiscoveredApplication(
                    path: path,
                    title: fileURL.deletingPathExtension().lastPathComponent,
                    bundleIdentifier: runningApp?.bundleIdentifier,
                    isRunning: runningApp?.isTerminated == false
                )
            }
        }

        let result = appsByPath.values.sorted { lhs, rhs in
            if lhs.isRunning != rhs.isRunning {
                return lhs.isRunning && !rhs.isRunning
            }

            return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }
        
        cachedInstalledApplications = result
        return result
    }

    static func discoverIDEApplications() -> [DiscoveredApplication] {
        discoverInstalledApplications().filter { app in
            let haystack = "\(app.title) \(app.bundleIdentifier ?? "")".lowercased()
            return preferredIDEPatterns.contains { haystack.contains($0) }
        }
    }

    static func resolveApplicationURL(from entry: String?) -> URL? {
        guard let entry else {
            return nil
        }

        let trimmed = entry.trimmed
        guard !trimmed.isEmpty else {
            return nil
        }

        if trimmed.hasPrefix("/") || trimmed.hasPrefix("~") {
            let fileURL = URL(fileURLWithPath: trimmed.expandedPath)
            return isUserFacingApplication(fileURL) ? fileURL : nil
        }

        if trimmed.contains("."),
           let bundleURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: trimmed) {
            return bundleURL
        }

        return discoverInstalledApplications()
            .first { app in
                app.title.compare(trimmed.replacingOccurrences(of: ".app", with: ""), options: .caseInsensitive) == .orderedSame
            }
            .map { URL(fileURLWithPath: $0.path) }
    }

    static func displayName(for entry: String) -> String {
        let trimmed = entry.trimmed

        if let appURL = resolveApplicationURL(from: trimmed) {
            return appURL.deletingPathExtension().lastPathComponent
        }

        guard !trimmed.isEmpty else {
            return "Application"
        }

        return trimmed.replacingOccurrences(of: ".app", with: "")
    }

    static func icon(for entry: String?, size: CGFloat) -> NSImage {
        if let appURL = resolveApplicationURL(from: entry) {
            let icon = NSWorkspace.shared.icon(forFile: appURL.path)
            icon.size = NSSize(width: size * 2, height: size * 2)
            return icon
        }

        let fallbackIcon: NSImage
        if let applicationType = UTType(filenameExtension: "app") {
            fallbackIcon = NSWorkspace.shared.icon(for: applicationType)
        } else {
            fallbackIcon = NSImage(size: NSSize(width: size * 2, height: size * 2))
        }
        fallbackIcon.size = NSSize(width: size * 2, height: size * 2)
        return fallbackIcon
    }

    private static func isUserFacingApplication(_ url: URL) -> Bool {
        let standardizedPath = url.standardizedFileURL.path

        guard standardizedPath.hasSuffix(".app"),
              !standardizedPath.contains("/Contents/"),
              !standardizedPath.contains("/Frameworks/"),
              !standardizedPath.contains("/PrivateFrameworks/"),
              !standardizedPath.contains("/Library/CoreServices/"),
              allowedApplicationRoots.contains(where: { root in
                  standardizedPath == root || standardizedPath.hasPrefix(root + "/")
              }) else {
            return false
        }

        return true
    }
}
