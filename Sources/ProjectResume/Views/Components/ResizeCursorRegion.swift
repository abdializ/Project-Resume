import AppKit
import SwiftUI

struct ResizeCursorRegion: NSViewRepresentable {
    func makeNSView(context: Context) -> ResizeCursorNSView {
        ResizeCursorNSView()
    }

    func updateNSView(_ nsView: ResizeCursorNSView, context: Context) {}
}

final class ResizeCursorNSView: NSView {
    override func resetCursorRects() {
        discardCursorRects()
        addCursorRect(bounds, cursor: .resizeLeftRight)
    }
}
