import AppKit

public final class ProjectResumeAppDelegate: NSObject, NSApplicationDelegate {
    public func applicationDidFinishLaunching(_ notification: Notification) {
        NSWindow.allowsAutomaticWindowTabbing = false
        NSApp.setActivationPolicy(.regular)
        applyAppIconIfAvailable()
        NSApp.activate(ignoringOtherApps: true)
    }

    @MainActor
    private func applyAppIconIfAvailable() {
        guard let iconURL = Bundle.module.url(forResource: "AppIcon", withExtension: "png"),
              let iconImage = NSImage(contentsOf: iconURL) else {
            return
        }

        NSApp.applicationIconImage = iconImage
    }
}
