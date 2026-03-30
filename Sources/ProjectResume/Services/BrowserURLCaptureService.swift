import AppKit
import Foundation

struct BrowserURLCaptureService {
    private let workspace: NSWorkspace

    init(workspace: NSWorkspace = .shared) {
        self.workspace = workspace
    }

    func captureBrowserURLs() -> [String] {
        let browsers: [BrowserCaptureDefinition] = [
            .safariFamily("Safari"),
            .safariFamily("Safari Technology Preview"),
            .safariFamily("Orion"),
            .chromiumFamily("Google Chrome"),
            .chromiumFamily("Google Chrome Canary"),
            .chromiumFamily("Chromium"),
            .chromiumFamily("Arc"),
            .chromiumFamily("Brave Browser"),
            .chromiumFamily("Microsoft Edge"),
            .chromiumFamily("Opera"),
            .chromiumFamily("Opera GX"),
            .chromiumFamily("Vivaldi"),
            .chromiumFamily("Dia")
        ]

        let runningApplications = workspace.runningApplications

        return browsers
            .flatMap { captureURLs(for: $0, runningApplications: runningApplications) }
            .normalizedEntries()
            .uniquedPreservingOrder()
    }

    private func captureURLs(
        for browser: BrowserCaptureDefinition,
        runningApplications: [NSRunningApplication]
    ) -> [String] {
        guard isRunning(browser, in: runningApplications) else {
            return []
        }

        let inProcessResult = captureWithAppleScript(browser.script)
        if !inProcessResult.isEmpty {
            return inProcessResult
        }

        return captureWithOSAProcess(browser.script)
    }

    private func captureWithAppleScript(_ source: String) -> [String] {
        guard let script = NSAppleScript(source: source) else {
            return []
        }

        var errorInfo: NSDictionary?
        let result = script.executeAndReturnError(&errorInfo)

        guard errorInfo == nil else {
            return []
        }

        let output = result.stringValue ?? ""
        return normalizedLines(from: output)
    }

    private func captureWithOSAProcess(_ source: String) -> [String] {
        let process = Process()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", source]
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                return []
            }

            let output = String(
                data: outputPipe.fileHandleForReading.readDataToEndOfFile(),
                encoding: .utf8
            ) ?? ""

            return normalizedLines(from: output)
        } catch {
            return []
        }
    }

    private func normalizedLines(from output: String) -> [String] {
        output
            .components(separatedBy: CharacterSet.newlines)
            .map { $0.trimmed }
            .filter { !$0.isEmpty }
    }

    private func isRunning(
        _ browser: BrowserCaptureDefinition,
        in runningApplications: [NSRunningApplication]
    ) -> Bool {
        runningApplications.contains { app in
            if let bundleIdentifier = app.bundleIdentifier,
               browser.bundleIdentifiers.contains(bundleIdentifier) {
                return true
            }

            return app.localizedName == browser.appName
        }
    }
}

private struct BrowserCaptureDefinition {
    let appName: String
    let bundleIdentifiers: [String]
    let script: String

    static func safariFamily(_ appName: String) -> Self {
        .init(
            appName: appName,
            bundleIdentifiers: safariBundleIdentifiers(for: appName),
            script: """
            tell application "\(appName)"
                if not running then return ""
                set output to {}
                repeat with currentWindow in windows
                    repeat with currentTab in tabs of currentWindow
                        try
                            set end of output to URL of currentTab
                        end try
                    end repeat
                end repeat
                set oldDelimiters to AppleScript's text item delimiters
                set AppleScript's text item delimiters to linefeed
                set joinedOutput to output as text
                set AppleScript's text item delimiters to oldDelimiters
                return joinedOutput
            end tell
            """
        )
    }

    static func chromiumFamily(_ appName: String) -> Self {
        .init(
            appName: appName,
            bundleIdentifiers: chromiumBundleIdentifiers(for: appName),
            script: """
            tell application "\(appName)"
                if not running then return ""
                set output to {}
                repeat with currentWindow in windows
                    repeat with currentTab in tabs of currentWindow
                        try
                            set end of output to URL of currentTab
                        end try
                    end repeat
                end repeat
                set oldDelimiters to AppleScript's text item delimiters
                set AppleScript's text item delimiters to linefeed
                set joinedOutput to output as text
                set AppleScript's text item delimiters to oldDelimiters
                return joinedOutput
            end tell
            """
        )
    }

    private static func safariBundleIdentifiers(for appName: String) -> [String] {
        switch appName {
        case "Safari":
            return ["com.apple.Safari"]
        case "Safari Technology Preview":
            return ["com.apple.SafariTechnologyPreview"]
        case "Orion":
            return ["com.kagi.kagimacOS", "com.kagi.kagimacOS.setapp"]
        default:
            return []
        }
    }

    private static func chromiumBundleIdentifiers(for appName: String) -> [String] {
        switch appName {
        case "Google Chrome":
            return ["com.google.Chrome"]
        case "Google Chrome Canary":
            return ["com.google.Chrome.canary"]
        case "Chromium":
            return ["org.chromium.Chromium"]
        case "Arc":
            return ["company.thebrowser.Browser"]
        case "Brave Browser":
            return ["com.brave.Browser"]
        case "Microsoft Edge":
            return ["com.microsoft.edgemac"]
        case "Opera":
            return ["com.operasoftware.Opera"]
        case "Opera GX":
            return ["com.operasoftware.OperaGX"]
        case "Vivaldi":
            return ["com.vivaldi.Vivaldi"]
        case "Dia":
            return ["app.dia.Browser", "app.dia.desktop", "app.dia.mac"]
        default:
            return []
        }
    }
}
