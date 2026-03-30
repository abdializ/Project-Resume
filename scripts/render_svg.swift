import AppKit
import Foundation
import WebKit

final class Renderer: NSObject, WKNavigationDelegate {
    private let svgURL: URL
    private let outputURL: URL
    private let size: CGSize
    private var webView: WKWebView?

    init(svgURL: URL, outputURL: URL, size: CGSize) {
        self.svgURL = svgURL
        self.outputURL = outputURL
        self.size = size
    }

    func start() throws {
        let svgMarkup = try String(contentsOf: svgURL, encoding: .utf8)
        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(origin: .zero, size: size), configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        webView.navigationDelegate = self
        self.webView = webView

        let html = """
        <!doctype html>
        <html>
        <head>
          <meta charset="utf-8">
          <style>
            html, body {
              margin: 0;
              width: \(Int(size.width))px;
              height: \(Int(size.height))px;
              background: transparent;
              overflow: hidden;
            }
            body {
              display: flex;
              align-items: center;
              justify-content: center;
            }
            svg {
              width: \(Int(size.width))px;
              height: \(Int(size.height))px;
              display: block;
            }
          </style>
        </head>
        <body>
          \(svgMarkup)
        </body>
        </html>
        """

        webView.loadHTMLString(html, baseURL: svgURL.deletingLastPathComponent())
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        let configuration = WKSnapshotConfiguration()
        configuration.rect = CGRect(origin: .zero, size: size)
        configuration.afterScreenUpdates = true

        webView.takeSnapshot(with: configuration) { image, error in
            if let error {
                fputs("snapshot failed: \(error.localizedDescription)\n", stderr)
                NSApp.terminate(nil)
                return
            }

            guard let image,
                  let tiffData = image.tiffRepresentation,
                  let bitmap = NSBitmapImageRep(data: tiffData),
                  let pngData = bitmap.representation(using: .png, properties: [:]) else {
                fputs("failed to encode png\n", stderr)
                NSApp.terminate(nil)
                return
            }

            do {
                try pngData.write(to: self.outputURL)
                NSApp.terminate(nil)
            } catch {
                fputs("failed to write png: \(error.localizedDescription)\n", stderr)
                NSApp.terminate(nil)
            }
        }
    }
}

guard CommandLine.arguments.count == 3 else {
    fputs("usage: render_svg <input.svg> <output.png>\n", stderr)
    exit(2)
}

let inputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let outputURL = URL(fileURLWithPath: CommandLine.arguments[2])

let app = NSApplication.shared
app.setActivationPolicy(.prohibited)

let renderer = Renderer(
    svgURL: inputURL,
    outputURL: outputURL,
    size: CGSize(width: 1024, height: 1024)
)

try renderer.start()
app.run()
