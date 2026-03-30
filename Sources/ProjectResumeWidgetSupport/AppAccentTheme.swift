import Foundation
import SwiftUI

public enum AppAccentTheme: String, CaseIterable, Identifiable, Codable {
    case rose
    case sky
    case emerald
    case amber
    case violet
    case graphite

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .rose: return "Rose"
        case .sky: return "Sky"
        case .emerald: return "Emerald"
        case .amber: return "Amber"
        case .violet: return "Violet"
        case .graphite: return "Graphite"
        }
    }

    public var accentColor: Color {
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

    public var darkModeAccentColor: Color {
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

    public var darkModeCanvasColor: Color {
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

    public var darkModeSurfaceColor: Color {
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

    public func resolvedAccentColor(for colorScheme: ColorScheme) -> Color {
        colorScheme == .dark ? darkModeAccentColor : accentColor
    }

    public func railTint(for colorScheme: ColorScheme) -> Color {
        switch colorScheme {
        case .dark:
            return darkModeAccentColor.opacity(0.16)
        default:
            return accentColor.opacity(0.08)
        }
    }
}
