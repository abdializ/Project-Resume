import AppKit
import Combine
import Foundation
import CoreGraphics

struct TrackedApplicationUsage: Identifiable, Hashable, Codable {
    let id: String
    let displayName: String
    let bundleIdentifier: String?
    let appPath: String
    var accumulatedFocusTime: TimeInterval
    var isRunning: Bool
}

private struct PersistedSession: Codable {
    let date: Date
    let apps: [TrackedApplicationUsage]
}

@MainActor
final class SessionTracker: NSObject, ObservableObject {
    @Published private(set) var trackedApplications: [TrackedApplicationUsage] = []
    @Published private(set) var sessionStartedAt = Date()

    private let workspace: NSWorkspace
    private let notificationCenter: NotificationCenter
    private let nowProvider: () -> Date

    private var trackedState: [String: AppTrackingState] = [:]
    private var activeApplicationID: String?

    private var trackingTimer: AnyCancellable?
    private var saveTimer: AnyCancellable?
    private var lastTick: Date?

    private let fileManager = FileManager.default
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(
        workspace: NSWorkspace = .shared,
        notificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        nowProvider: @escaping () -> Date = Date.init
    ) {
        self.workspace = workspace
        self.notificationCenter = notificationCenter
        self.nowProvider = nowProvider

        super.init()

        loadPersistedState()
        bootstrapRunningApplications()
        registerObservers()
        startTimers()
        refreshPublishedUsage()
    }

    deinit {
        notificationCenter.removeObserver(self)
    }

    func snapshot() -> [TrackedApplicationUsage] {
        refreshPublishedUsage()
        return trackedApplications
    }

    private func startTimers() {
        lastTick = nowProvider()

        // 1-second high precision tick for focus accumulation
        trackingTimer = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.tick()
            }

        // 30-second low frequency tick for saving state to disk
        saveTimer = Timer.publish(every: 30.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.persistState()
            }
    }

    private func tick() {
        let now = nowProvider()
        defer { lastTick = now }
        guard let last = lastTick else { return }

        let delta = now.timeIntervalSince(last)
        let idleTime = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: CGEventType(rawValue: ~0)!)

        // Only accumulate focus time if the user is not idle (> 5 minutes = 300 seconds)
        if idleTime < 300 {
            if let activeID = activeApplicationID, var state = trackedState[activeID] {
                state.accumulatedFocusTime += delta
                trackedState[activeID] = state
            }
        }

        refreshPublishedUsage()
    }

    private func bootstrapRunningApplications() {
        // Ensure we don't accidentally keep old entries marked as running if they aren't
        var runningBundlePaths = Set<String>()

        for app in workspace.runningApplications {
            guard shouldTrack(app) else { continue }

            let id = applicationID(for: app)
            runningBundlePaths.insert(id)

            if var state = trackedState[id] {
                state.isRunning = true
                state.displayName = app.localizedName ?? state.displayName
                trackedState[id] = state
            } else {
                trackedState[id] = AppTrackingState(
                    displayName: app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "Unknown App",
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.bundleURL?.path ?? "",
                    accumulatedFocusTime: 0,
                    isRunning: true
                )
            }
        }

        // Mark previously loaded ones as not running if they aren't actually running
        for (id, var state) in trackedState {
            if !runningBundlePaths.contains(id) {
                state.isRunning = false
                trackedState[id] = state
            }
        }

        if let frontmost = workspace.frontmostApplication,
           shouldTrack(frontmost) {
            activeApplicationID = applicationID(for: frontmost)
        }
    }

    private func registerObservers() {
        notificationCenter.addObserver(
            self,
            selector: #selector(handleActivationNotification(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(handleLaunchNotification(_:)),
            name: NSWorkspace.didLaunchApplicationNotification,
            object: nil
        )

        notificationCenter.addObserver(
            self,
            selector: #selector(handleTerminationNotification(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleSleepNotification(_:)),
            name: NSWorkspace.willSleepNotification,
            object: nil
        )
        
        notificationCenter.addObserver(
            self,
            selector: #selector(handleWakeNotification(_:)),
            name: NSWorkspace.didWakeNotification,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAppQuitNotification(_:)),
            name: NSApplication.willTerminateNotification,
            object: nil
        )
    }

    @objc private func handleAppQuitNotification(_ notification: Notification) {
        persistState()
    }

    @objc private func handleActivationNotification(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              shouldTrack(app) else {
            activeApplicationID = nil
            refreshPublishedUsage()
            return
        }

        upsertState(for: app)
        activeApplicationID = applicationID(for: app)
        refreshPublishedUsage()
    }

    @objc private func handleLaunchNotification(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication,
              shouldTrack(app) else {
            return
        }

        upsertState(for: app)
        refreshPublishedUsage()
    }

    @objc private func handleTerminationNotification(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }

        let id = applicationID(for: app)
        if activeApplicationID == id {
            activeApplicationID = nil
        }

        if var state = trackedState[id] {
            state.isRunning = false
            trackedState[id] = state
        }

        refreshPublishedUsage()
    }
    
    @objc private func handleSleepNotification(_ notification: Notification) {
        // Force a save right before sleep
        persistState()
    }
    
    @objc private func handleWakeNotification(_ notification: Notification) {
        // Reset the tick to avoid counting sleep duration as active time
        lastTick = nowProvider()
        
        // If system woke up on a new day, clear history to start fresh
        if !Calendar.current.isDateInToday(sessionStartedAt) {
            trackedState.removeAll()
            sessionStartedAt = nowProvider()
            bootstrapRunningApplications()
        }
    }

    private func upsertState(for app: NSRunningApplication) {
        let id = applicationID(for: app)
        var state = trackedState[id] ?? AppTrackingState(
            displayName: app.localizedName ?? app.bundleURL?.deletingPathExtension().lastPathComponent ?? "Unknown App",
            bundleIdentifier: app.bundleIdentifier,
            appPath: app.bundleURL?.path ?? "",
            accumulatedFocusTime: 0,
            isRunning: true
        )

        state.displayName = app.localizedName ?? state.displayName
        state.bundleIdentifier = app.bundleIdentifier ?? state.bundleIdentifier
        state.appPath = app.bundleURL?.path ?? state.appPath
        state.isRunning = true
        trackedState[id] = state
    }

    private func refreshPublishedUsage() {
        trackedApplications = trackedState.values
            .map { state in
                TrackedApplicationUsage(
                    id: state.id,
                    displayName: state.displayName,
                    bundleIdentifier: state.bundleIdentifier,
                    appPath: state.appPath,
                    accumulatedFocusTime: state.accumulatedFocusTime,
                    isRunning: state.isRunning
                )
            }
            .filter { $0.isRunning || $0.accumulatedFocusTime > 0 }
            .sorted { lhs, rhs in
                if lhs.accumulatedFocusTime == rhs.accumulatedFocusTime {
                    return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
                }

                return lhs.accumulatedFocusTime > rhs.accumulatedFocusTime
            }
    }

    private func shouldTrack(_ app: NSRunningApplication) -> Bool {
        guard app.activationPolicy == .regular else {
            return false
        }

        let bundleIdentifier = app.bundleIdentifier ?? ""
        if bundleIdentifier == Bundle.main.bundleIdentifier {
            return false
        }

        return app.bundleURL != nil
    }

    private func applicationID(for app: NSRunningApplication) -> String {
        if let bundleIdentifier = app.bundleIdentifier {
            return bundleIdentifier
        }

        return app.bundleURL?.path ?? UUID().uuidString
    }

    // MARK: - Persistence

    private func storageFileURL() -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let appDir = appSupport.appendingPathComponent("ProjectResume", isDirectory: true)
        return appDir.appendingPathComponent("session_history.json")
    }

    private func loadPersistedState() {
        let url = storageFileURL()
        guard fileManager.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url),
              let saved = try? decoder.decode(PersistedSession.self, from: data) else {
            return
        }

        // Only restore if the saved session is from today.
        // This ensures the tracker naturally resets at midnight.
        if Calendar.current.isDateInToday(saved.date) {
            sessionStartedAt = saved.date
            
            for app in saved.apps {
                trackedState[app.id] = AppTrackingState(
                    displayName: app.displayName,
                    bundleIdentifier: app.bundleIdentifier,
                    appPath: app.appPath,
                    accumulatedFocusTime: app.accumulatedFocusTime,
                    isRunning: false // Overwritten by bootstrapRunningApplications if it's actually running
                )
            }
        } else {
            // Delete old session history to save space / privacy
            try? fileManager.removeItem(at: url)
        }
    }

    private func persistState() {
        let url = storageFileURL()
        
        let appsToSave = trackedState.values.map { 
            TrackedApplicationUsage(
                id: $0.id, 
                displayName: $0.displayName, 
                bundleIdentifier: $0.bundleIdentifier, 
                appPath: $0.appPath, 
                accumulatedFocusTime: $0.accumulatedFocusTime, 
                isRunning: false
            ) 
        }
        
        let session = PersistedSession(date: sessionStartedAt, apps: appsToSave)
        
        if let data = try? encoder.encode(session) {
            try? fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true, attributes: nil)
            try? data.write(to: url, options: .atomic)
        }
    }
}

private struct AppTrackingState {
    let id: String
    var displayName: String
    var bundleIdentifier: String?
    var appPath: String
    var accumulatedFocusTime: TimeInterval
    var isRunning: Bool

    init(
        displayName: String,
        bundleIdentifier: String?,
        appPath: String,
        accumulatedFocusTime: TimeInterval,
        isRunning: Bool
    ) {
        self.id = bundleIdentifier ?? appPath
        self.displayName = displayName
        self.bundleIdentifier = bundleIdentifier
        self.appPath = appPath
        self.accumulatedFocusTime = accumulatedFocusTime
        self.isRunning = isRunning
    }
}
