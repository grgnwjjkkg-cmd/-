import SwiftUI
import WebKit

@main
struct KemetApp: App {
    var body: some Scene {
        WindowGroup {
            GameView()
                .ignoresSafeArea()
                .statusBarHidden()
                .persistentSystemOverlays(.hidden)
        }
    }
}

/// ゲーム本体（Game フォルダの three.js）を WebView で動かす
struct GameView: UIViewRepresentable {
    func makeCoordinator() -> SaveBridge { SaveBridge() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.setURLSchemeHandler(BundleSchemeHandler(), forURLScheme: BundleSchemeHandler.scheme)
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        // セーブデータ：ゲームから受け取って端末に保存し、起動時に戻す
        config.userContentController.add(context.coordinator, name: "save")
        if let saved = SaveBridge.load() {
            let js = "try { if (!localStorage.getItem('kemet-save-v1')) localStorage.setItem('kemet-save-v1', \(saved)); } catch (e) {}"
            config.userContentController.addUserScript(WKUserScript(source: js, injectionTime: .atDocumentStart, forMainFrameOnly: true))
        }

        let web = WKWebView(frame: .zero, configuration: config)
        web.isOpaque = false
        web.backgroundColor = .black
        web.scrollView.isScrollEnabled = false
        web.scrollView.bounces = false
        web.scrollView.contentInsetAdjustmentBehavior = .never
        #if DEBUG
        if #available(iOS 16.4, *) { web.isInspectable = true }
        #endif
        web.load(URLRequest(url: URL(string: "\(BundleSchemeHandler.scheme)://app/index.html")!))
        return web
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}
}

/// ゲームからのセーブを受け取って保存する
final class SaveBridge: NSObject, WKScriptMessageHandler {
    private static var url: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent("kemet-save.json")
    }

    /// JavaScript にそのまま埋め込める文字列（JSON文字列をさらに文字列として）
    static func load() -> String? {
        guard let data = try? Data(contentsOf: url), let text = String(data: data, encoding: .utf8),
              let quoted = try? JSONEncoder().encode(text) else { return nil }
        return String(data: quoted, encoding: .utf8)
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let text = message.body as? String else { return }
        try? FileManager.default.createDirectory(at: Self.url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? text.data(using: .utf8)?.write(to: Self.url, options: .atomic)
    }
}

/// kemet://app/... を、アプリに同梱した Game フォルダのファイルとして返す
final class BundleSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "kemet"
    private let root = Bundle.main.resourceURL!.appendingPathComponent("Game")

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else { return }
        let path = url.path.removingPercentEncoding ?? url.path
        let file = root.appendingPathComponent(path.isEmpty || path == "/" ? "index.html" : String(path.dropFirst()))
        guard file.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path),
              let data = try? Data(contentsOf: file) else {
            let response = HTTPURLResponse(url: url, statusCode: 404, httpVersion: "HTTP/1.1", headerFields: nil)!
            urlSchemeTask.didReceive(response)
            urlSchemeTask.didFinish()
            return
        }
        let headers = [
            "Content-Type": Self.mime(file.pathExtension),
            "Content-Length": "\(data.count)",
            "Access-Control-Allow-Origin": "*",
        ]
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: headers)!
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    static func mime(_ ext: String) -> String {
        switch ext.lowercased() {
        case "html": "text/html; charset=utf-8"
        case "js", "mjs": "text/javascript; charset=utf-8"
        case "css": "text/css; charset=utf-8"
        case "json": "application/json"
        case "glb": "model/gltf-binary"
        case "gltf": "model/gltf+json"
        case "png": "image/png"
        case "jpg", "jpeg": "image/jpeg"
        case "webp": "image/webp"
        case "mp3": "audio/mpeg"
        case "m4a": "audio/mp4"
        default: "application/octet-stream"
        }
    }
}
