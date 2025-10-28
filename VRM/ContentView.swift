import SwiftUI
import WebKit

// Simple auto-discovery
struct FileDiscovery {
    static func discoverFiles() -> (vrmFiles: [String], fbxFiles: [String]) {
        print("🔍 Starting file discovery...")
        
        var vrmFiles: [String] = []
        var fbxFiles: [String] = []
        
        // Find all VRM files
        if let vrmURLs = Bundle.main.urls(forResourcesWithExtension: "vrm", subdirectory: nil) {
            vrmFiles = vrmURLs.map { $0.lastPathComponent }
            print("📁 Found \(vrmFiles.count) VRM files: \(vrmFiles.prefix(5))")
        }
        
        // Find all FBX files
        if let fbxURLs = Bundle.main.urls(forResourcesWithExtension: "fbx", subdirectory: nil) {
            fbxFiles = fbxURLs.map { $0.lastPathComponent }
            print("🎬 Found \(fbxFiles.count) FBX files: \(fbxFiles.prefix(5))")
        }
        
        return (vrmFiles, fbxFiles)
    }
    
    static func generateFileListJSON() -> String {
        let files = discoverFiles()
        
        let jsonObject: [String: Any] = [
            "vrmFiles": files.vrmFiles,
            "fbxFiles": files.fbxFiles
        ]
        
        if let jsonData = try? JSONSerialization.data(withJSONObject: jsonObject, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            return jsonString
        }
        
        return "{\"vrmFiles\":[],\"fbxFiles\":[]}"
    }
}

// VRMWebView with proper file loading
struct VRMWebView: UIViewRepresentable {
    let htmlFileName: String
    @Binding var webView: WKWebView?
    
    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.mediaTypesRequiringUserActionForPlayback = []
        
        // IMPORTANT: Set preferences to allow file access
        let preferences = WKWebpagePreferences()
        preferences.allowsContentJavaScript = true
        configuration.defaultWebpagePreferences = preferences
        
        // Add user script to inject file list
        let fileListJSON = FileDiscovery.generateFileListJSON()
        
        let script = """
        window.discoveredFiles = \(fileListJSON);
        console.log('🎯 Injected files:', window.discoveredFiles);
        """
        
        let userScript = WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
        configuration.userContentController.addUserScript(userScript)
        
        // Add message handler for debugging
        configuration.userContentController.add(context.coordinator, name: "logging")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Enable web inspector
        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif
        
        // Expose the created webView to SwiftUI via binding so toolbar buttons can call JS
        DispatchQueue.main.async {
            self.webView = webView
        }
        return webView
    }
    
    func updateUIView(_ webView: WKWebView, context: Context) {
        guard let htmlPath = Bundle.main.path(forResource: htmlFileName, ofType: "html") else {
            print("❌ HTML file not found: \(htmlFileName).html")
            return
        }
        
        let htmlURL = URL(fileURLWithPath: htmlPath)
        let bundleURL = Bundle.main.bundleURL
        
        print("📄 HTML path: \(htmlPath)")
        print("📦 Bundle URL: \(bundleURL)")
        
        // CRITICAL: Allow access to entire bundle, not just HTML directory
        // This ensures VRM/FBX files can be loaded
        webView.loadFileURL(htmlURL, allowingReadAccessTo: bundleURL)
        
        print("✅ LoadFileURL called with bundle access")
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator()
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            print("✅ WebView finished loading")
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("❌ WebView provisional navigation failed: \(error.localizedDescription)")
        }
        
        // Handle console.log messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logging" {
                print("🌐 JS: \(message.body)")
            }
        }
    }
}

// ContentView - UPDATED FOR FULLSCREEN
struct ContentView: View {
    @State private var webViewRef: WKWebView? = nil
    @State private var chatText: String = ""
    var body: some View {
        NavigationStack {
            VRMWebView(htmlFileName: "index", webView: $webViewRef)
                .ignoresSafeArea() // This ignores ALL safe areas including home indicator
                .onAppear {
                    print("=== 🚀 App Started ===")
                    let files = FileDiscovery.discoverFiles()
                    print("=== 📊 Summary ===")
                    print("VRM: \(files.vrmFiles.count) files")
                    print("FBX: \(files.fbxFiles.count) files")
                    print("==================")
                    
                    // Print bundle info
                    if let bundlePath = Bundle.main.resourcePath {
                        print("📦 Bundle resource path: \(bundlePath)")
                    }
                }
                .toolbar {
                    // Top navigation bar: Random Model
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            webViewRef?.evaluateJavaScript("window.loadRandomFiles();")
                        } label: {
                            Label("Random Model", systemImage: "die.face.5")
                        }
                    }

                    // Bottom bar: Change Animation + wide chat input
                    ToolbarItem(placement: .bottomBar) {
                        HStack(spacing: 12) {
                            Button {
                                webViewRef?.evaluateJavaScript("window.loadNextAnimation();")
                            } label: {
                                Label("Change Animation", systemImage: "figure.dance")
                            }

                            TextField("Chat...", text: $chatText)
                                .textFieldStyle(.roundedBorder)
                                .disableAutocorrection(true)
                                .autocapitalization(.none)
                                .frame(maxWidth: .infinity)
                        }
                    }
                }
        }
    }
}

#Preview {
    ContentView()
}
