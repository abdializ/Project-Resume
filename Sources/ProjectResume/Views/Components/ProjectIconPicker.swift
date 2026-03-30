import SwiftUI

struct ProjectIconChoice: Identifiable, Hashable {
    let symbol: String?
    let label: String

    var id: String {
        symbol ?? "automatic"
    }
}

struct ProjectIconPicker: View {
    @Environment(\.colorScheme) private var colorScheme

    @Binding var selectedSymbol: String?
    let accentColor: Color

    private let iconChoices: [ProjectIconChoice] = [
        .init(symbol: nil, label: "Automatic"),
        .init(symbol: "briefcase", label: "Work"),
        .init(symbol: "folder", label: "Folder"),
        .init(symbol: "square.grid.2x2", label: "Apps"),
        .init(symbol: "globe", label: "Web"),
        .init(symbol: "terminal", label: "Terminal"),
        .init(symbol: "doc.text", label: "Docs"),
        .init(symbol: "paintpalette", label: "Design"),
        .init(symbol: "chart.bar", label: "Analytics"),
        .init(symbol: "graduationcap", label: "Study"),
        .init(symbol: "shippingbox", label: "Ops"),
        .init(symbol: "sparkles", label: "Ideas")
    ]

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
            ForEach(iconChoices) { choice in
                Button {
                    selectedSymbol = choice.symbol
                } label: {
                    ZStack {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(backgroundFill(for: choice))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(borderColor(for: choice), lineWidth: selectedSymbol == choice.symbol ? 1.2 : 0.8)
                            )

                        if let symbol = choice.symbol {
                            Image(systemName: symbol)
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundStyle(foregroundColor(for: choice))
                        } else {
                            Image(systemName: "wand.and.stars")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(foregroundColor(for: choice))
                        }
                    }
                    .frame(height: 50)
                }
                .buttonStyle(.plain)
                .help(choice.label)
            }
        }
    }

    private func backgroundFill(for choice: ProjectIconChoice) -> Color {
        if selectedSymbol == choice.symbol {
            return accentColor.opacity(colorScheme == .dark ? 0.18 : 0.13)
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.06)
            : Color.black.opacity(0.035)
    }

    private func borderColor(for choice: ProjectIconChoice) -> Color {
        if selectedSymbol == choice.symbol {
            return accentColor.opacity(colorScheme == .dark ? 0.70 : 0.44)
        }

        return Color.primary.opacity(colorScheme == .dark ? 0.07 : 0.05)
    }

    private func foregroundColor(for choice: ProjectIconChoice) -> Color {
        if selectedSymbol == choice.symbol {
            return colorScheme == .dark ? .white : accentColor
        }

        return colorScheme == .dark
            ? Color.white.opacity(0.82)
            : Color.black.opacity(0.78)
    }
}
