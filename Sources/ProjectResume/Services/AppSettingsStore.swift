import AppKit
import Carbon
import Combine
import Foundation
import SwiftUI

enum AppAccentTheme: String, CaseIterable, Identifiable, Codable {
    case rose
    case sky
    case emerald
    case amber
    case violet
    case graphite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rose: return "Rose"
        case .sky: return "Sky"
        case .emerald: return "Emerald"
        case .amber: return "Amber"
        case .violet: return "Violet"
        case .graphite: return "Graphite"
        }
    }

    var accentColor: Color {
        switch self {
        case .rose:
            return Color(red: 0.93, green: 0.38, blue: 0.46)
        case .sky:
            return Color(red: 0.28, green: 0.63, blue: 0.96)
        case .emerald:
            return Color(red: 0.19, green: 0.73, blue: 0.53)
        case .amber:
            return Color(red: 0.93, green: 0.66, blue: 0.21)
        case .violet:
            return Color(red: 0.57, green: 0.47, blue: 0.93)
        case .graphite:
            return Color(red: 0.49, green: 0.53, blue: 0.60)
        }
    }

    var darkModeAccentColor: Color {
        switch self {
        case .rose:
            return Color(red: 0.72, green: 0.22, blue: 0.30)
        case .sky:
            return Color(red: 0.20, green: 0.46, blue: 0.78)
        case .emerald:
            return Color(red: 0.13, green: 0.55, blue: 0.39)
        case .amber:
            return Color(red: 0.73, green: 0.47, blue: 0.14)
        case .violet:
            return Color(red: 0.43, green: 0.34, blue: 0.76)
        case .graphite:
            return Color(red: 0.35, green: 0.39, blue: 0.46)
        }
    }

    var darkModeCanvasColor: Color {
        switch self {
        case .rose:
            return Color(red: 0.11, green: 0.055, blue: 0.065)
        case .sky:
            return Color(red: 0.045, green: 0.075, blue: 0.11)
        case .emerald:
            return Color(red: 0.045, green: 0.085, blue: 0.07)
        case .amber:
            return Color(red: 0.10, green: 0.075, blue: 0.04)
        case .violet:
            return Color(red: 0.075, green: 0.06, blue: 0.115)
        case .graphite:
            return Color(red: 0.06, green: 0.065, blue: 0.075)
        }
    }

    var darkModeSurfaceColor: Color {
        switch self {
        case .rose:
            return Color(red: 0.14, green: 0.075, blue: 0.085)
        case .sky:
            return Color(red: 0.06, green: 0.095, blue: 0.135)
        case .emerald:
            return Color(red: 0.055, green: 0.105, blue: 0.085)
        case .amber:
            return Color(red: 0.125, green: 0.09, blue: 0.055)
        case .violet:
            return Color(red: 0.095, green: 0.075, blue: 0.145)
        case .graphite:
            return Color(red: 0.085, green: 0.09, blue: 0.105)
        }
    }

    func resolvedAccentColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkModeAccentColor : accentColor
    }

    func railTint(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return darkModeAccentColor.opacity(0.16)
        default:
            return accentColor.opacity(0.08)
        }
    }
}

struct ShortcutConfiguration: Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32

    static let `default` = ShortcutConfiguration(
        keyCode: UInt32(kVK_Space),
        carbonModifiers: UInt32(cmdKey | optionKey)
    )

    init(keyCode: UInt32, carbonModifiers: UInt32) {
        self.keyCode = keyCode
        self.carbonModifiers = carbonModifiers
    }

    init?(event: NSEvent) {
        let relevantFlags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let carbonModifiers = Self.carbonModifiers(from: relevantFlags)

        guard carbonModifiers != 0,
              Self.isSupported(carbonModifiers: carbonModifiers) else {
            return nil
        }

        self.init(keyCode: UInt32(event.keyCode), carbonModifiers: carbonModifiers)
    }

    var displayString: String {
        modifierSymbols + keyDisplayName
    }

    private var modifierSymbols: String {
        var parts: [String] = []

        if carbonModifiers & UInt32(controlKey) != 0 {
            parts.append("^")
        }

        if carbonModifiers & UInt32(optionKey) != 0 {
            parts.append("⌥")
        }

        if carbonModifiers & UInt32(shiftKey) != 0 {
            parts.append("⇧")
        }

        if carbonModifiers & UInt32(cmdKey) != 0 {
            parts.append("⌘")
        }

        return parts.joined()
    }

    private var keyDisplayName: String {
        switch keyCode {
        case UInt32(kVK_Space):
            return "Space"
        case UInt32(kVK_Return):
            return "Return"
        case UInt32(kVK_Escape):
            return "Escape"
        case 0:
            return "A"
        case 1:
            return "S"
        case 2:
            return "D"
        case 3:
            return "F"
        case 5:
            return "G"
        case 4:
            return "H"
        case 38:
            return "J"
        case 40:
            return "K"
        case 37:
            return "L"
        case 46:
            return "M"
        case 45:
            return "N"
        case 31:
            return "O"
        case 35:
            return "P"
        case 12:
            return "Q"
        case 15:
            return "R"
        case 17:
            return "T"
        case 32:
            return "U"
        case 9:
            return "V"
        case 13:
            return "W"
        case 7:
            return "X"
        case 16:
            return "Y"
        case 6:
            return "Z"
        case 18:
            return "1"
        case 19:
            return "2"
        case 20:
            return "3"
        case 21:
            return "4"
        case 23:
            return "5"
        case 22:
            return "6"
        case 26:
            return "7"
        case 28:
            return "8"
        case 25:
            return "9"
        case 29:
            return "0"
        default:
            return "Key \(keyCode)"
        }
    }

    private static func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        var modifiers: UInt32 = 0

        if flags.contains(.control) {
            modifiers |= UInt32(controlKey)
        }

        if flags.contains(.option) {
            modifiers |= UInt32(optionKey)
        }

        if flags.contains(.shift) {
            modifiers |= UInt32(shiftKey)
        }

        if flags.contains(.command) {
            modifiers |= UInt32(cmdKey)
        }

        return modifiers
    }

    private static func isSupported(carbonModifiers: UInt32) -> Bool {
        let hasCommand = carbonModifiers & UInt32(cmdKey) != 0
        let hasControl = carbonModifiers & UInt32(controlKey) != 0

        // Avoid option-only or shift-only shortcuts. They collide with normal typing
        // and are unreliable as app-wide/global shortcuts on macOS.
        return hasCommand || hasControl
    }
}

@MainActor
final class AppSettingsStore: ObservableObject {
    @Published var accentTheme: AppAccentTheme {
        didSet {
            UserDefaults.standard.set(accentTheme.rawValue, forKey: Keys.accentTheme)
        }
    }

    @Published var quickAccessShortcut: ShortcutConfiguration {
        didSet {
            UserDefaults.standard.set(Int(quickAccessShortcut.keyCode), forKey: Keys.quickAccessKeyCode)
            UserDefaults.standard.set(Int(quickAccessShortcut.carbonModifiers), forKey: Keys.quickAccessModifiers)
        }
    }

    @Published var closeQuickAccessAfterLaunch: Bool {
        didSet {
            UserDefaults.standard.set(closeQuickAccessAfterLaunch, forKey: Keys.closeQuickAccessAfterLaunch)
        }
    }

    @Published var showSessionCaptureAlert: Bool {
        didSet {
            UserDefaults.standard.set(showSessionCaptureAlert, forKey: Keys.showSessionCaptureAlert)
        }
    }

    @Published var automaticallyDeleteCapturedSessions: Bool {
        didSet {
            UserDefaults.standard.set(automaticallyDeleteCapturedSessions, forKey: Keys.automaticallyDeleteCapturedSessions)
        }
    }

    @Published var capturedSessionRetentionDays: Int {
        didSet {
            if capturedSessionRetentionDays < 1 {
                capturedSessionRetentionDays = 1
                return
            }
            UserDefaults.standard.set(capturedSessionRetentionDays, forKey: Keys.capturedSessionRetentionDays)
        }
    }

    @Published var betaUpdateDirectoryPath: String {
        didSet {
            UserDefaults.standard.set(betaUpdateDirectoryPath, forKey: Keys.betaUpdateDirectoryPath)
        }
    }

    var sessionRetentionDays: Int? {
        automaticallyDeleteCapturedSessions ? capturedSessionRetentionDays : nil
    }

    init() {
        let defaults = UserDefaults.standard

        if let storedTheme = defaults.string(forKey: Keys.accentTheme),
           let parsedTheme = AppAccentTheme(rawValue: storedTheme) {
            accentTheme = parsedTheme
        } else {
            accentTheme = .rose
        }

        let storedKeyCode = defaults.object(forKey: Keys.quickAccessKeyCode) as? Int
        let storedModifiers = defaults.object(forKey: Keys.quickAccessModifiers) as? Int

        if let storedKeyCode, let storedModifiers {
            quickAccessShortcut = ShortcutConfiguration(
                keyCode: UInt32(storedKeyCode),
                carbonModifiers: UInt32(storedModifiers)
            )
        } else {
            quickAccessShortcut = .default
        }

        if defaults.object(forKey: Keys.closeQuickAccessAfterLaunch) == nil {
            closeQuickAccessAfterLaunch = true
        } else {
            closeQuickAccessAfterLaunch = defaults.bool(forKey: Keys.closeQuickAccessAfterLaunch)
        }

        if defaults.object(forKey: Keys.showSessionCaptureAlert) == nil {
            showSessionCaptureAlert = true
        } else {
            showSessionCaptureAlert = defaults.bool(forKey: Keys.showSessionCaptureAlert)
        }

        if defaults.object(forKey: Keys.automaticallyDeleteCapturedSessions) == nil {
            automaticallyDeleteCapturedSessions = true
        } else {
            automaticallyDeleteCapturedSessions = defaults.bool(forKey: Keys.automaticallyDeleteCapturedSessions)
        }

        if let storedRetentionDays = defaults.object(forKey: Keys.capturedSessionRetentionDays) as? Int,
           storedRetentionDays > 0 {
            capturedSessionRetentionDays = storedRetentionDays
        } else {
            capturedSessionRetentionDays = 3
        }

        if let storedDirectoryPath = defaults.string(forKey: Keys.betaUpdateDirectoryPath),
           !storedDirectoryPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            betaUpdateDirectoryPath = storedDirectoryPath
        } else {
            betaUpdateDirectoryPath = Self.defaultBetaUpdateDirectoryPath()
        }
    }

    private static func defaultBetaUpdateDirectoryPath() -> String {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Documents/New project/dist", isDirectory: true)
            .path
    }
}

private enum Keys {
    static let accentTheme = "accentTheme"
    static let quickAccessKeyCode = "quickAccessKeyCode"
    static let quickAccessModifiers = "quickAccessModifiers"
    static let closeQuickAccessAfterLaunch = "closeQuickAccessAfterLaunch"
    static let showSessionCaptureAlert = "showSessionCaptureAlert"
    static let automaticallyDeleteCapturedSessions = "automaticallyDeleteCapturedSessions"
    static let capturedSessionRetentionDays = "capturedSessionRetentionDays"
    static let betaUpdateDirectoryPath = "betaUpdateDirectoryPath"
}
