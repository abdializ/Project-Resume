import Foundation

final class LocalUpdateFeedServer: @unchecked Sendable {
    static let fixedPort: UInt16 = 8757
    static let appcastURL = URL(string: "http://127.0.0.1:8757/appcast.xml")!

    var onRequest: ((String) -> Void)?

    private var process: Process?
    private var outputPipe: Pipe?
    private var servedDirectoryURL: URL?
    private let logQueue = DispatchQueue(label: "ProjectResume.LocalUpdateFeedServer.logs")
    private let stateQueue = DispatchQueue(label: "ProjectResume.LocalUpdateFeedServer.state")
    private var recentLogLines: [String] = []

    func startIfNeeded(serving directoryURL: URL) throws -> URL {
        let standardizedDirectoryURL = directoryURL.standardizedFileURL

        if let process,
           process.isRunning,
           servedDirectoryURL == standardizedDirectoryURL {
            return Self.appcastURL
        }

        stop()
        killExistingProcessOnPort(Self.fixedPort)

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/python3")
        process.arguments = [
            "-u",
            "-m", "http.server",
            "\(Self.fixedPort)",
            "--bind", "127.0.0.1",
            "--directory", standardizedDirectoryURL.path
        ]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty,
                  let text = String(data: data, encoding: .utf8) else {
                return
            }

            self?.consume(logChunk: text)
        }

        process.terminationHandler = { [weak self] terminatedProcess in
            self?.emitLog("python server terminated (\(terminatedProcess.terminationStatus))")
        }

        try process.run()

        self.process = process
        outputPipe = pipe
        servedDirectoryURL = standardizedDirectoryURL

        Thread.sleep(forTimeInterval: 0.4)

        if !process.isRunning {
            throw NSError(
                domain: "LocalUpdateFeedServer",
                code: 2,
                userInfo: [
                    NSLocalizedDescriptionKey: "The local update feed server exited immediately.",
                    NSLocalizedFailureReasonErrorKey: recentLogsSummary()
                ]
            )
        }

        try waitUntilResponsive()
        return Self.appcastURL
    }

    func stop() {
        outputPipe?.fileHandleForReading.readabilityHandler = nil
        outputPipe = nil

        if let process, process.isRunning {
            process.terminate()
        }

        process = nil
        servedDirectoryURL = nil
    }

    private func killExistingProcessOnPort(_ port: UInt16) {
        let lsof = Process()
        lsof.executableURL = URL(fileURLWithPath: "/usr/sbin/lsof")
        lsof.arguments = ["-ti", ":\(port)"]

        let pipe = Pipe()
        lsof.standardOutput = pipe
        lsof.standardError = FileHandle.nullDevice

        do {
            try lsof.run()
            lsof.waitUntilExit()
        } catch {
            return
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let output = String(data: data, encoding: .utf8) else {
            return
        }

        let pids = output
            .split(whereSeparator: \.isNewline)
            .compactMap { Int32($0.trimmingCharacters(in: .whitespaces)) }

        for pid in pids {
            kill(pid, SIGTERM)
        }

        if !pids.isEmpty {
            Thread.sleep(forTimeInterval: 0.15)
        }
    }

    private func waitUntilResponsive(timeout: TimeInterval = 8) throws {
        let deadline = Date().addingTimeInterval(timeout)
        var lastError: Error?

        while Date() < deadline {
            if let process, !process.isRunning {
                throw NSError(
                    domain: "LocalUpdateFeedServer",
                    code: 3,
                    userInfo: [
                        NSLocalizedDescriptionKey: "The local update feed server stopped while starting.",
                        NSLocalizedFailureReasonErrorKey: recentLogsSummary()
                    ]
                )
            }

            do {
                var request = URLRequest(url: Self.appcastURL)
                request.httpMethod = "GET"
                request.timeoutInterval = 1.0

                let semaphore = DispatchSemaphore(value: 0)
                final class ResponseBox: @unchecked Sendable {
                    var error: Error?
                    var statusCode: Int?
                }

                let responseBox = ResponseBox()

                URLSession.shared.dataTask(with: request) { _, response, error in
                    responseBox.error = error
                    responseBox.statusCode = (response as? HTTPURLResponse)?.statusCode
                    semaphore.signal()
                }.resume()

                _ = semaphore.wait(timeout: .now() + 1)

                if let responseError = responseBox.error as NSError? {
                    // Server startup can briefly flap through transport errors while
                    // python binds the port. Keep retrying until the timeout.
                    lastError = responseError
                } else if responseBox.statusCode == 200 {
                    return
                } else if let statusCode = responseBox.statusCode {
                    lastError = NSError(
                        domain: "LocalUpdateFeedServer",
                        code: statusCode,
                        userInfo: [NSLocalizedDescriptionKey: "Local update feed returned HTTP \(statusCode)."]
                    )
                }
            }

            Thread.sleep(forTimeInterval: 0.1)
        }

        if let lastError = lastError as NSError? {
            throw NSError(
                domain: "LocalUpdateFeedServer",
                code: lastError.code,
                userInfo: [
                    NSLocalizedDescriptionKey: "Timed out waiting for the local update feed server.",
                    NSUnderlyingErrorKey: lastError,
                    NSLocalizedFailureReasonErrorKey: recentLogsSummary()
                ]
            )
        }

        throw NSError(
            domain: "LocalUpdateFeedServer",
            code: 1,
            userInfo: [
                NSLocalizedDescriptionKey: "Timed out waiting for the local update feed server.",
                NSLocalizedFailureReasonErrorKey: recentLogsSummary()
            ]
        )
    }

    private func consume(logChunk: String) {
        logQueue.async { [weak self] in
            logChunk
                .split(whereSeparator: \.isNewline)
                .map(String.init)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .forEach { line in
                    self?.appendLogLine(line)
                    self?.onRequest?(line)
                }
        }
    }

    private func emitLog(_ line: String) {
        logQueue.async { [weak self] in
            self?.appendLogLine(line)
            self?.onRequest?(line)
        }
    }

    private func appendLogLine(_ line: String) {
        stateQueue.sync {
            recentLogLines.append(line)
            if recentLogLines.count > 8 {
                recentLogLines.removeFirst(recentLogLines.count - 8)
            }
        }
    }

    private func recentLogsSummary() -> String {
        stateQueue.sync {
            recentLogLines.isEmpty ? "No server log output yet." : recentLogLines.joined(separator: " | ")
        }
    }
}
