import Carbon
import Foundation

final class GlobalHotKeyManager {
    private var hotKeyRefs: [UInt32: EventHotKeyRef] = [:]
    private var eventHandlerRef: EventHandlerRef?

    func register(shortcut: ShortcutConfiguration) {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        if eventHandlerRef == nil {
            let selfPointer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
            InstallEventHandler(
                GetApplicationEventTarget(),
                { _, event, _ in
                    guard let event else {
                        return noErr
                    }

                    var hotKeyID = EventHotKeyID()
                    let status = GetEventParameter(
                        event,
                        EventParamName(kEventParamDirectObject),
                        EventParamType(typeEventHotKeyID),
                        nil,
                        MemoryLayout<EventHotKeyID>.size,
                        nil,
                        &hotKeyID
                    )

                    if status == noErr {
                        switch hotKeyID.id {
                        case 1:
                            NotificationCenter.default.post(name: .projectResumeToggleQuickAccessRequested, object: nil)
                        case 2...5:
                            NotificationCenter.default.post(
                                name: .projectResumeLaunchShortcutProjectRequested,
                                object: nil,
                                userInfo: ["slot": Int(hotKeyID.id - 2)]
                            )
                        default:
                            break
                        }
                    }

                    return noErr
                },
                1,
                &eventType,
                selfPointer,
                &eventHandlerRef
            )
        }

        unregisterAllHotKeys()

        registerHotKey(shortcut, id: 1)

        let fixedProjectShortcuts: [(ShortcutConfiguration, UInt32)] = [
            (ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_1), carbonModifiers: UInt32(controlKey | optionKey)), 2),
            (ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_2), carbonModifiers: UInt32(controlKey | optionKey)), 3),
            (ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_3), carbonModifiers: UInt32(controlKey | optionKey)), 4),
            (ShortcutConfiguration(keyCode: UInt32(kVK_ANSI_4), carbonModifiers: UInt32(controlKey | optionKey)), 5)
        ]

        for (shortcut, id) in fixedProjectShortcuts {
            registerHotKey(shortcut, id: id)
        }
    }

    deinit {
        unregisterAllHotKeys()

        if let eventHandlerRef {
            RemoveEventHandler(eventHandlerRef)
        }
    }

    private func fourCharCode(from string: String) -> OSType {
        string.utf8.reduce(0) { partialResult, character in
            (partialResult << 8) + OSType(character)
        }
    }

    private func registerHotKey(_ shortcut: ShortcutConfiguration, id: UInt32) {
        var hotKeyRef: EventHotKeyRef?
        let hotKeyID = EventHotKeyID(signature: fourCharCode(from: "PRJK"), id: id)
        RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )

        if let hotKeyRef {
            hotKeyRefs[id] = hotKeyRef
        }
    }

    private func unregisterAllHotKeys() {
        for hotKeyRef in hotKeyRefs.values {
            UnregisterEventHotKey(hotKeyRef)
        }
        hotKeyRefs.removeAll()
    }
}

extension Notification.Name {
    static let projectResumeToggleQuickAccessRequested = Notification.Name("projectResumeToggleQuickAccessRequested")
    static let projectResumeLaunchShortcutProjectRequested = Notification.Name("projectResumeLaunchShortcutProjectRequested")
}
