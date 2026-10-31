import AppKit
import WebKit

let root = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let svgDirectory = root.appending(path: "svg", directoryHint: .isDirectory)
let outputDirectory = URL(fileURLWithPath: CommandLine.arguments[2], isDirectory: true)
try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)

@MainActor
final class Renderer: NSObject, WKNavigationDelegate {
    let webView = WKWebView(frame: NSRect(x: 0, y: 0, width: 1600, height: 900))
    var finished = false

    override init() {
        super.init()
        webView.navigationDelegate = self
    }

    func render(svg: URL, to destination: URL) throws {
        finished = false
        webView.loadFileURL(svg, allowingReadAccessTo: svg.deletingLastPathComponent())
        while !finished { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        var data: Data?
        var done = false
        let configuration = WKSnapshotConfiguration()
        configuration.rect = NSRect(x: 0, y: 0, width: 1600, height: 900)
        configuration.snapshotWidth = 1600
        webView.takeSnapshot(with: configuration) { image, _ in
            if let image, let tiff = image.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
                data = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
            }
            done = true
        }
        while !done { RunLoop.main.run(until: Date().addingTimeInterval(0.05)) }
        guard let data else { throw CocoaError(.fileWriteUnknown) }
        try data.write(to: destination)
    }

    nonisolated func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        MainActor.assumeIsolated { finished = true }
    }
}

MainActor.assumeIsolated {
    _ = NSApplication.shared
    let renderer = Renderer()
    let files = try! FileManager.default.contentsOfDirectory(at: svgDirectory, includingPropertiesForKeys: nil)
        .filter { $0.pathExtension == "svg" }.sorted { $0.lastPathComponent < $1.lastPathComponent }
    for file in files {
        let name = file.deletingPathExtension().lastPathComponent
        try! renderer.render(svg: file, to: outputDirectory.appending(path: "\(name).jpg"))
        print(name)
    }
}
