import AppKit
import Foundation

guard CommandLine.arguments.count == 7 else {
    fputs("usage: reframe_icon <input.png> <output.png> <canvas> <scale> <offsetX> <offsetY>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])
let canvasSize = CGFloat(Double(CommandLine.arguments[3]) ?? 1024)
let scale = CGFloat(Double(CommandLine.arguments[4]) ?? 1.0)
let offsetX = CGFloat(Double(CommandLine.arguments[5]) ?? 0.0)
let offsetY = CGFloat(Double(CommandLine.arguments[6]) ?? 0.0)

guard let sourceImage = NSImage(contentsOf: inputURL) else {
    fputs("failed to load image at \(inputURL.path)\n", stderr)
    exit(1)
}

let outputImage = NSImage(size: NSSize(width: canvasSize, height: canvasSize))
outputImage.lockFocus()

NSColor.clear.setFill()
NSRect(origin: .zero, size: outputImage.size).fill()

let baseRect = NSRect(origin: .zero, size: outputImage.size)
let scaledWidth = baseRect.width * scale
let scaledHeight = baseRect.height * scale
let drawRect = NSRect(
    x: (baseRect.width - scaledWidth) / 2 + offsetX,
    y: (baseRect.height - scaledHeight) / 2 + offsetY,
    width: scaledWidth,
    height: scaledHeight
)

sourceImage.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)
outputImage.unlockFocus()

guard let tiffData = outputImage.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiffData),
      let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("failed to encode output image\n", stderr)
    exit(1)
}

try pngData.write(to: outputURL)
