import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

guard CommandLine.arguments.count >= 3 else {
    fputs("Usage: make_menu_icon_transparent.swift <input.png> <output.png> [threshold]\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let outputPath = CommandLine.arguments[2]
let threshold = CommandLine.arguments.count >= 4 ? UInt8(CommandLine.arguments[3]) ?? 245 : 245

guard let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: inputPath) as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
    fputs("Failed to load input image.\n", stderr)
    exit(1)
}

let width = image.width
let height = image.height
let bytesPerPixel = 4
let bitsPerComponent = 8
let bytesPerRow = width * bytesPerPixel
let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

guard let context = CGContext(
    data: nil,
    width: width,
    height: height,
    bitsPerComponent: bitsPerComponent,
    bytesPerRow: bytesPerRow,
    space: CGColorSpaceCreateDeviceRGB(),
    bitmapInfo: bitmapInfo
) else {
    fputs("Failed to create bitmap context.\n", stderr)
    exit(1)
}

let rect = CGRect(x: 0, y: 0, width: width, height: height)
context.draw(image, in: rect)

guard let data = context.data else {
    fputs("Failed to access bitmap data.\n", stderr)
    exit(1)
}

let pixelBuffer = data.bindMemory(to: UInt8.self, capacity: width * height * bytesPerPixel)

for pixelIndex in stride(from: 0, to: width * height * bytesPerPixel, by: bytesPerPixel) {
    let red = pixelBuffer[pixelIndex]
    let green = pixelBuffer[pixelIndex + 1]
    let blue = pixelBuffer[pixelIndex + 2]

    if red >= threshold, green >= threshold, blue >= threshold {
        pixelBuffer[pixelIndex + 3] = 0
    }
}

guard let outputImage = context.makeImage() else {
    fputs("Failed to render output image.\n", stderr)
    exit(1)
}

let outputURL = URL(fileURLWithPath: outputPath)
guard let destination = CGImageDestinationCreateWithURL(
    outputURL as CFURL,
    UTType.png.identifier as CFString,
    1,
    nil
) else {
    fputs("Failed to create output image destination.\n", stderr)
    exit(1)
}

CGImageDestinationAddImage(destination, outputImage, nil)

guard CGImageDestinationFinalize(destination) else {
    fputs("Failed to write output image.\n", stderr)
    exit(1)
}
