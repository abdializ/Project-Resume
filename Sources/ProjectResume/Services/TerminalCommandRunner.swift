import Foundation

struct TerminalCommandRunner {
    func run(command: String, workingDirectory: String?) -> String? {
        let trimmedCommand = command.trimmed
        guard !trimmedCommand.isEmpty else {
            return nil
        }

        let process = Process()
        let outputPipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", appleScript(for: trimmedCommand, workingDirectory: workingDirectory)]
        process.standardError = outputPipe
        process.standardOutput = outputPipe

        do {
            try process.run()
            process.waitUntilExit()

            guard process.terminationStatus == 0 else {
                let output = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8)?
                    .trimmed ?? "Terminal automation returned a non-zero exit code."
                return "Could not run terminal command '\(trimmedCommand)': \(output)"
            }

            return nil
        } catch {
            return "Could not run terminal command '\(trimmedCommand)': \(error.localizedDescription)"
        }
    }

    private func appleScript(for command: String, workingDirectory: String?) -> String {
        let fullCommand: String

        if let workingDirectory = workingDirectory?.nilIfBlank {
            fullCommand = "cd \(shellQuoted(workingDirectory.expandedPath)) && \(command)"
        } else {
            fullCommand = command
        }

        return """
        tell application "Terminal"
            activate
            do script "\(escapedForAppleScript(fullCommand))"
        end tell
        """
    }

    private func shellQuoted(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    private func escapedForAppleScript(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }
}
