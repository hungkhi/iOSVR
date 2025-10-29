import SwiftUI
import WebKit

// VRMWebView with proper file loading
struct VRMWebView: UIViewRepresentable {
    let htmlFileName: String
    @Binding var webView: WKWebView?
    var onModelReady: () -> Void = {}
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        let fileListJSON = FileDiscovery.generateFileListJSON()
        let script = """
        window.discoveredFiles = \(fileListJSON);
        console.log('🎯 Injected files:', window.discoveredFiles);
        """
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)
        
        // Inject persisted initial selections at document start
        let defaults = UserDefaults.standard
        let savedModelName = (defaults.string(forKey: PersistKeys.modelName) ?? "").replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let savedBackgroundURL = (defaults.string(forKey: PersistKeys.backgroundURL) ?? "").replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        var inject = ""
        if !savedModelName.isEmpty { inject += "window.nativeSelectedModelName=\"\(savedModelName)\";\n" }
        if !savedBackgroundURL.isEmpty { inject += "window.initialBackgroundUrl=\"\(savedBackgroundURL)\";\n" }
        if !inject.isEmpty {
            let persistedScript = WKUserScript(source: inject, injectionTime: .atDocumentStart, forMainFrameOnly: true)
            configuration.userContentController.addUserScript(persistedScript)
        }
        
        configuration.userContentController.add(context.coordinator, name: "logging")
        configuration.userContentController.add(context.coordinator, name: "loading")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webView.scrollView.bounces = false
        
        #if DEBUG
        if #available(iOS 16.4, *) { webView.isInspectable = true }
        #endif
        
        DispatchQueue.main.async { self.webView = webView }
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let htmlPath = Bundle.main.path(forResource: htmlFileName, ofType: "html") else { return }
        let htmlURL = URL(fileURLWithPath: htmlPath)
        let bundleURL = Bundle.main.bundleURL
        webView.loadFileURL(htmlURL, allowingReadAccessTo: bundleURL)
    }
    
    func makeCoordinator() -> Coordinator { Coordinator(onModelReady: onModelReady) }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let onModelReady: () -> Void
        init(onModelReady: @escaping () -> Void) { self.onModelReady = onModelReady }
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "loading", let text = message.body as? String, text == "initialReady" { onModelReady() }
        }
    }
}


