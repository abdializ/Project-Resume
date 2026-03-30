import AppKit
import SwiftUI

struct ProjectBadgeView: View {
    @Environment(\.colorScheme) private var colorScheme

    let project: Project
    let accentColor: Color
    let size: CGFloat

    private var outerGradient: LinearGradient {
        LinearGradient(
            colors: [
                accentColor.opacity(colorScheme == .dark ? 0.18 : 0.10),
                accentColor.opacity(colorScheme == .dark ? 0.07 : 0.03)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var innerFill: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.white.opacity(0.94)
    }

    private var innerStroke: Color {
        colorScheme == .dark
            ? Color.white.opacity(0.10)
            : Color.black.opacity(0.05)
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                .fill(outerGradient)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.30, style: .continuous)
                        .stroke(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.05), lineWidth: 0.6)
                )

            RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                .fill(innerFill)
                .frame(width: size * 0.62, height: size * 0.62)
                .overlay(
                    RoundedRectangle(cornerRadius: size * 0.22, style: .continuous)
                        .stroke(innerStroke, lineWidth: 0.6)
                )
                .shadow(
                    color: Color.black.opacity(colorScheme == .dark ? 0.14 : 0.06),
                    radius: size * 0.10,
                    x: 0,
                    y: size * 0.04
                )
                .overlay {
                    Image(systemName: project.resolvedIconSymbol)
                        .font(.system(size: size * 0.30, weight: .semibold))
                        .foregroundStyle(
                            colorScheme == .dark
                                ? Color.white.opacity(0.92)
                                : accentColor.opacity(0.94)
                        )
                }
        }
        .frame(width: size, height: size)
    }
}
