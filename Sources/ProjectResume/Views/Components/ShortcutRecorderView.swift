import AppKit
import Carbon
import SwiftUI

struct ShortcutRecorderView: NSViewRepresentable {
    @Binding var shortcut: ShortcutConfiguration

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onShortcutChange = { newShortcut in
            shortcut = newShortcut
        }
        button.shortcut = shortcut
        return button
    }

    func updateNSView(_ nsView: ShortcutRecorderButton, context: Context) {
        nsView.shortcut = shortcut
    }
}

final class ShortcutRecorderButton: NSButton {
    var onShortcutChange: ((ShortcutConfiguration) -> Void)?
    var shortcut: ShortcutConfiguration = .default {
        didSet {
            if !isRecording {
                title = shortcut.displayString
            }
        }
    }

    private var isRecording = false {
        didSet {
            title = isRecording ? "Press Cmd/Control + key" : shortcut.displayString
        }
    }
    private var eventMonitor: Any?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
        isBordered = true
        focusRingType = .default
        font = .systemFont(ofSize: 13, weight: .medium)
        title = shortcut.displayString
        target = self
        action = #selector(startRecording)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    @objc private func startRecording() {
        isRecording = true
        installEventMonitorIfNeeded()
    }

    private func installEventMonitorIfNeeded() {
        removeEventMonitor()
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.isRecording else {
                return event
            }

            self.handleRecordingEvent(event)
            return nil
        }
    }

    private func removeEventMonitor() {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func handleRecordingEvent(_ event: NSEvent) {
        if event.keyCode == UInt16(kVK_Escape) {
            isRecording = false
            removeEventMonitor()
            return
        }

        guard let recordedShortcut = ShortcutConfiguration(event: event) else {
            NSSound.beep()
            return
        }

        shortcut = recordedShortcut
        onShortcutChange?(recordedShortcut)
        isRecording = false
        removeEventMonitor()
    }
}
