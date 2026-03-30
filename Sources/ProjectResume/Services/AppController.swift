import AppKit
import Combine
import Foundation

@MainActor
final class AppController: NSObject {
    private let hotKeyManager = GlobalHotKeyManager()
    private var quickAccessPanelController: QuickAccessPanelController?
    private var isConfigured = false
    private var cancellables: Set<AnyCancellable> = []
    private weak var store: ProjectStore?
    private var launcher: ProjectLauncher?

    override init() {
        super.init()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleToggleQuickAccessNotification),
            name: .projectResumeToggleQuickAccessRequested,
            object: nil
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleLaunchShortcutNotification(_:)),
            name: .projectResumeLaunchShortcutProjectRequested,
            object: nil
        )
    }

    func configureIfNeeded(
        store: ProjectStore,
        launcher: ProjectLauncher,
        settingsStore: AppSettingsStore,
        sessionTracker: SessionTracker
    ) {
        guard !isConfigured else {
            return
        }

        isConfigured = true
        self.store = store
        self.launcher = launcher
        quickAccessPanelController = QuickAccessPanelController(
            store: store,
            launcher: launcher,
            settingsStore: settingsStore,
            sessionTracker: sessionTracker
        )
        hotKeyManager.register(shortcut: settingsStore.quickAccessShortcut)
        settingsStore.$quickAccessShortcut
            .removeDuplicates()
            .sink { [weak self] shortcut in
                self?.hotKeyManager.register(shortcut: shortcut)
            }
            .store(in: &cancellables)

        Publishers.CombineLatest(
            settingsStore.$automaticallyDeleteCapturedSessions.removeDuplicates(),
            settingsStore.$capturedSessionRetentionDays.removeDuplicates()
        )
        .sink { [weak store, weak settingsStore] _, _ in
            guard let store, let settingsStore else {
                return
            }

            store.pruneExpiredCapturedProjects(retentionDays: settingsStore.sessionRetentionDays)
        }
        .store(in: &cancellables)

        store.pruneExpiredCapturedProjects(retentionDays: settingsStore.sessionRetentionDays)
    }

    func toggleQuickAccess() {
        quickAccessPanelController?.toggle()
    }

    func presentMainWindow() {
        NSApp.activate(ignoringOtherApps: true)
        if let mainWindow = NSApp.windows.first(where: { $0.identifier?.rawValue == "ProjectResumeMainWindow" }) {
            mainWindow.makeKeyAndOrderFront(nil)
        } else {
            NSApp.windows.first(where: { !($0 is NSPanel) })?.makeKeyAndOrderFront(nil)
        }
    }

    func showSettings() {
        presentMainWindow()
        NotificationCenter.default.post(name: .projectResumeShowSettingsRequested, object: nil)
    }

    func handleDeepLink(_ url: URL) {
        guard url.scheme?.lowercased() == "projectresume" else {
            return
        }

        let action = url.host?.lowercased() ?? url.pathComponents.dropFirst().first?.lowercased()
        if action == "capture-session" {
            presentMainWindow()
            NotificationCenter.default.post(name: .projectResumeCaptureSessionRequested, object: nil)
            return
        }

        guard action == "open-project",
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let projectIDValue = components.queryItems?.first(where: { $0.name == "id" })?.value,
              let projectID = UUID(uuidString: projectIDValue) else {
            return
        }

        presentMainWindow()
        NotificationCenter.default.post(
            name: .projectResumeOpenProjectRequested,
            object: nil,
            userInfo: ["projectID": projectID]
        )
    }

    @objc private func handleToggleQuickAccessNotification() {
        toggleQuickAccess()
    }

    @objc private func handleLaunchShortcutNotification(_ notification: Notification) {
        guard let slot = notification.userInfo?["slot"] as? Int,
              let store,
              let launcher,
              store.launchShortcutProjects.indices.contains(slot) else {
            return
        }

        let project = store.launchShortcutProjects[slot]
        Task {
            _ = await launcher.launch(project)
            store.recordLaunch(of: project)
        }
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }
}
