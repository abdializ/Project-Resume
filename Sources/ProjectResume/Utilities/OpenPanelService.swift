import AppKit
import UniformTypeIdentifiers

@MainActor
enum OpenPanelService {
    static func chooseFolder(initialPath: String?) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Folder"

        if let initialPath = initialPath?.nilIfBlank {
            panel.directoryURL = URL(fileURLWithPath: initialPath.expandedPath)
        }

        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    static func chooseApplication() -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose App"
        panel.allowedContentTypes = [.applicationBundle]

        return panel.runModal() == .OK ? panel.url?.path : nil
    }

    static func chooseUpdateFolder(initialPath: String?) -> String? {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.prompt = "Choose Update Folder"

        if let initialPath = initialPath?.nilIfBlank {
            panel.directoryURL = URL(fileURLWithPath: initialPath.expandedPath)
        }

        return panel.runModal() == .OK ? panel.url?.path : nil
    }
}
