import AppKit
import SwiftUI

struct MainWindowConfigurator: NSViewRepresentable {
    private static let minimumWindowSize = NSSize(width: 880, height: 460)
    private static let sidebarTrafficInset: CGFloat = 16
    private static let trafficVerticalOffset: CGFloat = -2
    final class Coordinator: NSObject, NSWindowDelegate {
        var didApplyInitialFrame = false
        var observedWindow: NSWindow?
        var isAdjustingWindow = false
        weak var previousDelegate: NSWindowDelegate?
        var sidebarCollapsed = false
        var sidebarWidth: CGFloat = 0
        var initialTrafficLightY: CGFloat?

        @MainActor
        func attach(to window: NSWindow) {
            guard observedWindow !== window else {
                return
            }

            removeObservers()
            observedWindow = window
            previousDelegate = window.delegate === self ? nil : window.delegate
            window.delegate = self

            let notificationCenter = NotificationCenter.default
            let windowNames: [Notification.Name] = [
                NSWindow.didResizeNotification,
                NSWindow.didChangeScreenNotification,
                NSWindow.didEndLiveResizeNotification
            ]

            for name in windowNames {
                notificationCenter.addObserver(
                    self,
                    selector: #selector(handleWindowConstraintNotification),
                    name: name,
                    object: window
                )
            }

            // Sidebar layout notification is posted with object: nil,
            // so we must observe with object: nil to receive it.
            notificationCenter.addObserver(
                self,
                selector: #selector(handleWindowConstraintNotification),
                name: .projectResumeSidebarChromeLayoutChanged,
                object: nil
            )
        }

        @MainActor
        @objc private func handleWindowConstraintNotification(_ notification: Notification) {
            guard let observedWindow else {
                return
            }

            switch notification.name {
            case .projectResumeSidebarChromeLayoutChanged:
                applySidebarChromeLayout(from: notification, in: observedWindow)
            case NSWindow.didResizeNotification:
                if observedWindow.inLiveResize {
                    return
                }
                constrainObservedWindowIfNeeded()
            default:
                constrainObservedWindowIfNeeded()
            }
        }

        @MainActor
        func constrainObservedWindowIfNeeded() {
            guard let observedWindow, !isAdjustingWindow else {
                return
            }

            isAdjustingWindow = true
            constrainWindowToVisibleFrame(observedWindow)
            layoutTrafficLights(in: observedWindow)
            isAdjustingWindow = false
        }

        @MainActor
        private func applySidebarChromeLayout(from notification: Notification, in window: NSWindow) {
            if let updatedWidth = notification.userInfo?["sidebarWidth"] as? CGFloat {
                sidebarWidth = updatedWidth
            } else if let updatedWidth = notification.userInfo?["sidebarWidth"] as? Double {
                sidebarWidth = updatedWidth
            }

            if let updatedCollapsed = notification.userInfo?["sidebarCollapsed"] as? Bool {
                sidebarCollapsed = updatedCollapsed
            }

            layoutTrafficLights(in: window)
        }

        @MainActor
        private func layoutTrafficLights(in window: NSWindow) {
            guard
                let closeButton = window.standardWindowButton(.closeButton),
                let minimizeButton = window.standardWindowButton(.miniaturizeButton),
                let zoomButton = window.standardWindowButton(.zoomButton)
            else {
                return
            }

            let buttons = [closeButton, minimizeButton, zoomButton]

            if sidebarCollapsed {
                for button in buttons {
                    button.isHidden = true
                    button.isEnabled = false
                    button.alphaValue = 0
                }
                return
            }

            for button in buttons {
                button.isHidden = false
                button.isEnabled = true
                button.alphaValue = 1
            }

            // Capture the default Y position on first call so it never drifts.
            if initialTrafficLightY == nil {
                initialTrafficLightY = closeButton.frame.origin.y
            }

            let leadingInset = MainWindowConfigurator.sidebarTrafficInset
            let buttonSize = closeButton.frame.size
            let yOrigin = (initialTrafficLightY ?? closeButton.frame.origin.y) + MainWindowConfigurator.trafficVerticalOffset
            let defaultSpacing: CGFloat = 6

            closeButton.setFrameOrigin(NSPoint(x: leadingInset, y: yOrigin))
            minimizeButton.setFrameOrigin(NSPoint(x: leadingInset + buttonSize.width + defaultSpacing, y: yOrigin))
            zoomButton.setFrameOrigin(NSPoint(x: leadingInset + (buttonSize.width + defaultSpacing) * 2, y: yOrigin))
        }

        @MainActor
        private func removeObservers() {
            NotificationCenter.default.removeObserver(self)
            if let observedWindow, observedWindow.delegate === self {
                observedWindow.delegate = previousDelegate
            }
            previousDelegate = nil
            observedWindow = nil
        }

        @MainActor
        func windowWillResize(_ sender: NSWindow, to frameSize: NSSize) -> NSSize {
            let visibleFrame = visibleFrame(for: sender)
            return NSSize(
                width: min(max(frameSize.width, sender.minSize.width), visibleFrame.width),
                height: min(max(frameSize.height, sender.minSize.height), visibleFrame.height)
            )
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView(frame: .zero)
        DispatchQueue.main.async {
            configureWindow(for: view, coordinator: context.coordinator)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            configureWindow(for: nsView, coordinator: context.coordinator)
        }
    }

    private func configureWindow(for view: NSView, coordinator: Coordinator) {
        guard let window = view.window else {
            DispatchQueue.main.async {
                configureWindow(for: view, coordinator: coordinator)
            }
            return
        }

        window.styleMask.insert(.titled)
        window.styleMask.insert(.closable)
        window.styleMask.insert(.miniaturizable)
        window.styleMask.insert(.resizable)
        window.styleMask.insert(.fullSizeContentView)
        window.collectionBehavior.insert(.fullScreenPrimary)
        window.collectionBehavior.insert(.managed)
        window.isOpaque = false
        window.backgroundColor = .clear
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.identifier = NSUserInterfaceItemIdentifier("ProjectResumeMainWindow")
        window.tabbingMode = .disallowed
        window.contentMinSize = Self.minimumWindowSize
        window.minSize = Self.minimumWindowSize
        window.standardWindowButton(.closeButton)?.isHidden = coordinator.sidebarCollapsed
        window.standardWindowButton(.closeButton)?.isEnabled = !coordinator.sidebarCollapsed
        window.standardWindowButton(.miniaturizeButton)?.isHidden = coordinator.sidebarCollapsed
        window.standardWindowButton(.miniaturizeButton)?.isEnabled = !coordinator.sidebarCollapsed
        window.standardWindowButton(.zoomButton)?.isHidden = coordinator.sidebarCollapsed
        window.standardWindowButton(.zoomButton)?.isEnabled = !coordinator.sidebarCollapsed
        coordinator.attach(to: window)
        coordinator.constrainObservedWindowIfNeeded()

        if !coordinator.didApplyInitialFrame {
            coordinator.didApplyInitialFrame = true
        }
    }
}

@MainActor
private func constrainWindowToVisibleFrame(_ window: NSWindow) {
    let visibleFrame = visibleFrame(for: window)
    guard !visibleFrame.isEmpty else {
        return
    }

    var frame = window.frame
    let targetWidth = min(max(frame.width, window.minSize.width), visibleFrame.width)
    let targetHeight = min(max(frame.height, window.minSize.height), visibleFrame.height)
    frame.size = NSSize(width: targetWidth, height: targetHeight)

    if frame.maxX > visibleFrame.maxX {
        frame.origin.x = visibleFrame.maxX - frame.width
    }

    if frame.minX < visibleFrame.minX {
        frame.origin.x = visibleFrame.minX
    }

    if frame.minY < visibleFrame.minY {
        frame.origin.y = visibleFrame.minY
    }

    if frame.maxY > visibleFrame.maxY {
        frame.origin.y = visibleFrame.maxY - frame.height
    }

    if frame != window.frame {
        window.setFrame(frame, display: true)
    }
}

@MainActor
private func visibleFrame(for window: NSWindow) -> CGRect {
    guard let screen = window.screen ?? NSScreen.main else {
        return .zero
    }

    return screen.visibleFrame.insetBy(dx: 10, dy: 10)
}
