import AppKit
import SwiftUI

@MainActor
final class QuickAccessPanelController {
    private let panel: NSPanel

    init(
        store: ProjectStore,
        launcher: ProjectLauncher,
        settingsStore: AppSettingsStore,
        sessionTracker: SessionTracker
    ) {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 560, height: 620),
            styleMask: [.titled, .fullSizeContentView, .utilityWindow],
            backing: .buffered,
            defer: false
        )
        panel.title = "Quick Access"
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.hidesOnDeactivate = true
        panel.isMovableByWindowBackground = true
        panel.standardWindowButton(.miniaturizeButton)?.isHidden = true
        panel.standardWindowButton(.zoomButton)?.isHidden = true

        panel.contentView = NSHostingView(
            rootView: QuickAccessPanelView(
                store: store,
                launcher: launcher,
                settingsStore: settingsStore,
                sessionTracker: sessionTracker
            ) { [weak panel] in
                panel?.orderOut(nil)
            }
        )

        self.panel = panel
    }

    func toggle() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            show()
        }
    }

    private func show() {
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }
}
