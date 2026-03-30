import AppKit
import SwiftUI

struct ProjectNotesEditor: NSViewRepresentable {
    @Binding var text: String
    var placeholder: String

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = true

        let textView = MarkdownTextView()
        textView.delegate = context.coordinator
        textView.isRichText = false
        textView.importsGraphics = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.isAutomaticDashSubstitutionEnabled = false
        textView.isAutomaticTextReplacementEnabled = false
        textView.allowsUndo = true
        textView.backgroundColor = .clear
        textView.drawsBackground = false
        textView.textContainerInset = NSSize(width: 0, height: 8)
        textView.autoresizingMask = [.width]
        textView.frame = NSRect(origin: .zero, size: scrollView.contentView.bounds.size)
        textView.textContainer?.widthTracksTextView = true
        textView.textContainer?.heightTracksTextView = false
        textView.textContainer?.containerSize = NSSize(
            width: scrollView.contentSize.width,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.textContainer?.lineFragmentPadding = 0
        textView.minSize = NSSize(width: 0, height: 0)
        textView.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.placeholder = placeholder
        textView.onTextChange = { updatedText in
            if context.coordinator.isApplyingUpdate { return }
            if text != updatedText {
                DispatchQueue.main.async {
                    self.text = updatedText
                }
            }
        }

        scrollView.documentView = textView
        context.coordinator.textView = textView
        context.coordinator.apply(text: text)
        return scrollView
    }

    func updateNSView(_ nsView: NSScrollView, context: Context) {
        context.coordinator.textView?.placeholder = placeholder
        context.coordinator.apply(text: text)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    @MainActor
    final class Coordinator: NSObject, NSTextViewDelegate {
        fileprivate weak var textView: MarkdownTextView?
        var isApplyingUpdate = false

        func apply(text: String) {
            guard let textView else { return }
            guard textView.string != text || !textView.hasStyledText else { return }

            let selectedRange = textView.selectedRange()
            isApplyingUpdate = true
            textView.applyStyledText(text)
            textView.setSelectedRange(NSRange(location: min(selectedRange.location, textView.string.count), length: 0))
            isApplyingUpdate = false
        }

        func textDidChange(_ notification: Notification) {
            guard let textView else { return }
            textView.refreshStylingPreservingSelection()
            textView.onTextChange?(textView.string)
        }
    }
}

private final class MarkdownTextView: NSTextView {
    var onTextChange: ((String) -> Void)?
    var placeholder: String = "" {
        didSet { needsDisplay = true }
    }
    var hasStyledText = false

    override var string: String {
        didSet { needsDisplay = true }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        textContainer?.containerSize = NSSize(
            width: max(0, newSize.width),
            height: CGFloat.greatestFiniteMagnitude
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        guard string.isEmpty, !placeholder.isEmpty else { return }

        let inset = textContainerInset
        let attributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.placeholderTextColor
        ]
        let placeholderRect = NSRect(
            x: inset.width + 2,
            y: inset.height + 1,
            width: bounds.width - (inset.width * 2),
            height: bounds.height - (inset.height * 2)
        )
        placeholder.draw(in: placeholderRect, withAttributes: attributes)
    }

    override func insertNewline(_ sender: Any?) {
        let selected = selectedRange()
        guard selected.length == 0 else {
            super.insertNewline(sender)
            return
        }

        let nsString = string as NSString
        let lineRange = nsString.lineRange(for: NSRange(location: selected.location, length: 0))
        let line = nsString.substring(with: lineRange)
        let trimmedLine = line.trimmingCharacters(in: .newlines)
        let prefix = Self.continuationPrefix(for: trimmedLine)

        if let prefix {
            if Self.isOnlyPrefix(trimmedLine, prefix: prefix) {
                if lineRange.location + prefix.count <= nsString.length {
                    textStorage?.replaceCharacters(in: NSRange(location: lineRange.location, length: min(prefix.count, lineRange.length)), with: "")
                    setSelectedRange(NSRange(location: lineRange.location, length: 0))
                    didChangeText()
                    return
                }
            }

            insertText("\n\(prefix)", replacementRange: selected)
            return
        }

        super.insertNewline(sender)
    }

    func applyStyledText(_ text: String) {
        let attributed = Self.styledAttributedString(for: text)
        textStorage?.setAttributedString(attributed)
        hasStyledText = true
        needsDisplay = true
    }

    func refreshStylingPreservingSelection() {
        let selection = selectedRange()
        hasStyledText = false
        applyStyledText(string)
        setSelectedRange(selection)
    }

    private static func continuationPrefix(for line: String) -> String? {
        let patterns = ["- [ ] ", "- [x] ", "- ", "* ", "• "]
        for pattern in patterns where line.hasPrefix(pattern) {
            return pattern
        }

        let scanner = Scanner(string: line)
        var integer: Int = 0
        if scanner.scanInt(&integer), scanner.scanString(". ") != nil {
            return "\(integer + 1). "
        }

        return nil
    }

    private static func isOnlyPrefix(_ line: String, prefix: String) -> Bool {
        let remainder = line.dropFirst(prefix.count).trimmingCharacters(in: .whitespaces)
        return remainder.isEmpty
    }

    private static func styledAttributedString(for text: String) -> NSAttributedString {
        let output = NSMutableAttributedString(string: text)
        let fullRange = NSRange(location: 0, length: output.length)
        let paragraphStyle = NSMutableParagraphStyle()
        paragraphStyle.lineSpacing = 6
        paragraphStyle.paragraphSpacing = 10

        output.addAttributes([
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: paragraphStyle
        ], range: fullRange)

        let nsText = text as NSString
        var searchLocation = 0
        var inCodeBlock = false

        while searchLocation < nsText.length {
            let lineRange = nsText.lineRange(for: NSRange(location: searchLocation, length: 0))
            let line = nsText.substring(with: lineRange).trimmingCharacters(in: .newlines)

            if line.hasPrefix("```") {
                inCodeBlock.toggle()
                output.addAttributes(codeBlockAttributes(paragraphStyle: paragraphStyle), range: lineRange)
            } else if inCodeBlock {
                output.addAttributes(codeAttributes(paragraphStyle: paragraphStyle), range: lineRange)
            } else if line.hasPrefix("# ") {
                output.addAttributes(headingAttributes(size: 28, paragraphStyle: paragraphStyle), range: lineRange)
            } else if line.hasPrefix("## ") {
                output.addAttributes(headingAttributes(size: 22, paragraphStyle: paragraphStyle), range: lineRange)
            } else if line.hasPrefix("### ") {
                output.addAttributes(headingAttributes(size: 18, paragraphStyle: paragraphStyle), range: lineRange)
            } else if line.hasPrefix("> ") {
                output.addAttributes(quoteAttributes(paragraphStyle: paragraphStyle), range: lineRange)
            } else if line.hasPrefix("- [ ] ") || line.hasPrefix("- [x] ") || line.hasPrefix("- ") || line.hasPrefix("* ") || line.hasPrefix("• ") {
                output.addAttributes(listAttributes(paragraphStyle: paragraphStyle), range: lineRange)
            } else if numberedListPrefixRange(in: line) != nil {
                output.addAttributes(listAttributes(paragraphStyle: paragraphStyle), range: lineRange)
            }

            searchLocation = NSMaxRange(lineRange)
        }

        return output
    }

    private static func numberedListPrefixRange(in line: String) -> Range<String.Index>? {
        let scanner = Scanner(string: line)
        var integer: Int = 0
        if scanner.scanInt(&integer), scanner.scanString(". ") != nil {
            return line.startIndex..<line.index(line.startIndex, offsetBy: scanner.currentIndex.utf16Offset(in: line))
        }
        return nil
    }

    private static func headingAttributes(size: CGFloat, paragraphStyle: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        let style = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        style.paragraphSpacing = 12
        return [
            .font: NSFont.systemFont(ofSize: size, weight: .semibold),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style
        ]
    }

    private static func listAttributes(paragraphStyle: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        let style = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        style.headIndent = 18
        style.firstLineHeadIndent = 0
        return [
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .paragraphStyle: style
        ]
    }

    private static func quoteAttributes(paragraphStyle: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        let style = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        style.headIndent = 18
        style.firstLineHeadIndent = 12
        return [
            .font: NSFont.systemFont(ofSize: 16, weight: .regular),
            .foregroundColor: NSColor.secondaryLabelColor,
            .paragraphStyle: style
        ]
    }

    private static func codeAttributes(paragraphStyle: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        let style = paragraphStyle.mutableCopy() as! NSMutableParagraphStyle
        style.headIndent = 14
        style.firstLineHeadIndent = 14
        return [
            .font: NSFont.monospacedSystemFont(ofSize: 14, weight: .regular),
            .foregroundColor: NSColor.textColor,
            .backgroundColor: NSColor.textBackgroundColor.withAlphaComponent(0.5),
            .paragraphStyle: style
        ]
    }

    private static func codeBlockAttributes(paragraphStyle: NSParagraphStyle) -> [NSAttributedString.Key: Any] {
        codeAttributes(paragraphStyle: paragraphStyle)
    }
}
