import Foundation

public enum WidgetBridge {
    public static let appGroupIdentifier: String? = "group.app-practice.Project-Resume-Host"
    public static let accentThemeDefaultsKey = "accentTheme"

    public static func manualAppGroupContainerURL(fileManager: FileManager = .default) -> URL? {
        guard let appGroupIdentifier else {
            return nil
        }

        let homeDirectoryURL = fileManager.homeDirectoryForCurrentUser
        return homeDirectoryURL
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("Group Containers", isDirectory: true)
            .appendingPathComponent(appGroupIdentifier, isDirectory: true)
    }

    public static func currentAccentTheme(defaults: UserDefaults = .standard) -> AppAccentTheme {
        guard let storedTheme = defaults.string(forKey: accentThemeDefaultsKey),
              let parsedTheme = AppAccentTheme(rawValue: storedTheme) else {
            return .rose
        }

        return parsedTheme
    }

    public static func projectURL(for projectID: UUID) -> URL {
        var components = URLComponents()
        components.scheme = "projectresume"
        components.host = "open-project"
        components.queryItems = [
            URLQueryItem(name: "id", value: projectID.uuidString)
        ]

        guard let url = components.url else {
            preconditionFailure("Failed to construct project deep link for " + projectID.uuidString)
        }

        return url
    }

    public static func captureURL() -> URL {
        var components = URLComponents()
        components.scheme = "projectresume"
        components.host = "capture-session"

        guard let url = components.url else {
            preconditionFailure("Failed to construct capture deep link")
        }

        return url
    }
}
