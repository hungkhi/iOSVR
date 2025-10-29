import SwiftUI
import WebKit

// MARK: - Character API Models
struct CharacterItem: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let description: String?
    let thumbnail_url: String?
    let base_model_url: String?
}

// Costume from API
struct CostumeItem: Identifiable, Decodable, Hashable {
    let id: String
    let character_id: String
    let costume_name: String
    let url: String
    let thumbnail: String?
    let model_url: String?
}

// Room from API
struct RoomItem: Identifiable, Decodable, Hashable {
    let id: String
    let name: String
    let thumbnail: String?
    let image: String
    let created_at: String
    let `public`: Bool
}

// Simple auto-discovery
struct FileDiscovery {
    static func discoverFiles() -> (vrmFiles: [String], fbxFiles: [String]) {
        
        
        var vrmFiles: [String] = []
        var fbxFiles: [String] = []
        
        // Find all VRM files
        if let vrmURLs = Bundle.main.urls(forResourcesWithExtension: "vrm", subdirectory: nil) {
            vrmFiles = vrmURLs.map { $0.lastPathComponent }
            
        }
        
        // Find all FBX files
        if let fbxURLs = Bundle.main.urls(forResourcesWithExtension: "fbx", subdirectory: nil) {
            fbxFiles = fbxURLs.map { $0.lastPathComponent }
            
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
    var onModelReady: () -> Void = {}
    
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
        configuration.userContentController.add(context.coordinator, name: "loading")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        if #available(iOS 11.0, *) {
            webView.scrollView.contentInsetAdjustmentBehavior = .never
        }
        webView.scrollView.bounces = false
        
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
            
            return
        }
        
        let htmlURL = URL(fileURLWithPath: htmlPath)
        let bundleURL = Bundle.main.bundleURL
        
        
        
        // CRITICAL: Allow access to entire bundle, not just HTML directory
        // This ensures VRM/FBX files can be loaded
        webView.loadFileURL(htmlURL, allowingReadAccessTo: bundleURL)
        
        
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(onModelReady: onModelReady)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        private let onModelReady: () -> Void
        init(onModelReady: @escaping () -> Void) {
            self.onModelReady = onModelReady
        }
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            
        }
        
        // Handle console.log messages from JavaScript
        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            if message.name == "logging" {
                
            } else if message.name == "loading" {
                if let text = message.body as? String, text == "modelLoaded" {
                    
                    onModelReady()
                }
            }
        }
    }
}

// MARK: - Costume Bottom Sheet
private struct CostumeSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var items: [CostumeItem] = []
    var characterId: String = "74432746-0bab-4972-a205-9169bece07f9"
    let onSelect: (CostumeItem) -> Void

    private let grid = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Text("Failed to load")
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.footnote)
                        Button("Retry") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                } else if items.isEmpty {
                    VStack(spacing: 10) {
                        Text("No costumes")
                            .foregroundStyle(.white.opacity(0.8))
                        Button("Reload") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(items) { item in
                                Button {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                                .aspectRatio(1, contentMode: .fit)
                                            if let t = item.thumbnail, let u = URL(string: t) {
                                                AsyncImage(url: u) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image.resizable().scaledToFill()
                                                    case .empty:
                                                        ProgressView().tint(.white)
                                                    case .failure(_):
                                                        Color.white.opacity(0.06)
                                                    @unknown default:
                                                        Color.white.opacity(0.06)
                                                    }
                                                }
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                .aspectRatio(1, contentMode: .fit)
                                            }
                                        }
                                        Text(item.costume_name)
                                            .font(.footnote)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .background(Color.clear.ignoresSafeArea())
                }
            }
            .background(.ultraThinMaterial.opacity(0.6))
            .navigationTitle("Change Costume")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { 
                    Button("Done") { 
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        dismiss() 
                    } 
                }
            }
        }
        .onAppear { if items.isEmpty { load() } }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        items.removeAll()
        let effectiveId = characterId.isEmpty ? "74432746-0bab-4972-a205-9169bece07f9" : characterId
        let urlString = "https://n8n8n.top/webhook/costumes?character_id=\(effectiveId)"
        guard let url = URL(string: urlString) else { isLoading = false; return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let data = data else { errorMessage = "No data"; return }
                do {
                    let decoded = try JSONDecoder().decode([CostumeItem].self, from: data)
                    items = decoded
                } catch {
                    errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// MARK: - Room Bottom Sheet
private struct RoomSheetView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    @State private var items: [RoomItem] = []
    let onSelect: (RoomItem) -> Void

    private let grid = [
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top),
        GridItem(.flexible(), spacing: 14, alignment: .top)
    ]

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView().tint(.white)
                } else if let errorMessage {
                    VStack(spacing: 10) {
                        Text("Failed to load")
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .foregroundStyle(.white.opacity(0.7))
                            .font(.footnote)
                        Button("Retry") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                } else if items.isEmpty {
                    VStack(spacing: 10) {
                        Text("No rooms")
                            .foregroundStyle(.white.opacity(0.8))
                        Button("Reload") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                } else {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 14) {
                            ForEach(items) { item in
                                Button {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    VStack(spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                                .fill(Color.white.opacity(0.06))
                                                .aspectRatio(1, contentMode: .fit)
                                            if let t = item.thumbnail, let u = URL(string: t) {
                                                AsyncImage(url: u) { phase in
                                                    switch phase {
                                                    case .success(let image):
                                                        image.resizable().scaledToFill()
                                                    case .empty:
                                                        ProgressView().tint(.white)
                                                    case .failure(_):
                                                        Color.white.opacity(0.06)
                                                    @unknown default:
                                                        Color.white.opacity(0.06)
                                                    }
                                                }
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                                .aspectRatio(1, contentMode: .fit)
                                            }
                                        }
                                        Text(item.name)
                                            .font(.footnote)
                                            .foregroundStyle(.white)
                                            .lineLimit(1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 12)
                        .padding(.bottom, 24)
                    }
                    .background(Color.clear.ignoresSafeArea())
                }
            }
            .background(.ultraThinMaterial.opacity(0.6))
            .navigationTitle("Change Room")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) { 
                    Button("Done") { 
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        dismiss() 
                    } 
                }
            }
        }
        .onAppear { if items.isEmpty { load() } }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        items.removeAll()
        let urlString = "https://n8n8n.top/webhook/rooms"
        guard let url = URL(string: urlString) else { isLoading = false; return }
        URLSession.shared.dataTask(with: url) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let data = data else { errorMessage = "No data"; return }
                do {
                    let decoded = try JSONDecoder().decode([RoomItem].self, from: data)
                    items = decoded
                } catch {
                    errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// ContentView - UPDATED FOR FULLSCREEN
struct ContentView: View {
    @State private var webViewRef: WKWebView? = nil
    @State private var chatText: String = ""
    @State private var selectedTab: String = "Play"
    var onModelReady: () -> Void = {}
    @State private var navigateToCharacters: Bool = false
    @State private var showPlaceholder: Bool = false
    @State private var placeholderTitle: String = ""
    @State private var showCostumeSheet: Bool = false
    @State private var showRoomSheet: Bool = false
    // Track currently selected character id for costume fetching
    @State private var currentCharacterId: String = "74432746-0bab-4972-a205-9169bece07f9"
    @State private var isBgmOn: Bool = true
    @State private var chatMessages: [String] = []
    var body: some View {
        NavigationStack {
            VRMWebView(htmlFileName: "index", webView: $webViewRef, onModelReady: onModelReady)
                .ignoresSafeArea()
                .onAppear {
                    let files = FileDiscovery.discoverFiles()
                    _ = files
                    webViewRef?.evaluateJavaScript("(function(){try{return window.setBgm&&window.setBgm(true);}catch(e){return false}})();") { _, _ in }
                    // Prefetch character thumbnails for faster grid loading
                    prefetchCharacterThumbnails()
                    // Prefetch default character's costume thumbnails
                    prefetchCostumeThumbnails(for: currentCharacterId)
                    // Prefetch room thumbnails for faster room sheet loading
                    prefetchRoomThumbnails()
                    // Sync initial BGM state
                    webViewRef?.evaluateJavaScript("(function(){try{return window.isBgmPlaying&&window.isBgmPlaying();}catch(e){return false}})();") { result, _ in
                        if let playing = result as? Bool {
                            DispatchQueue.main.async { self.isBgmOn = playing }
                        }
                    }
                }
                .background(
                    ZStack {
                        // Hidden navigation link target for CharactersView
                        NavigationLink(isActive: $navigateToCharacters) {
                            CharactersView { item in
                                
                                currentCharacterId = item.id
                                // Preload costumes for the selected character for faster sheet load
                                prefetchCostumeThumbnails(for: item.id)
                                if let url = item.base_model_url, !url.isEmpty {
                                    let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                                    let nameEscaped = item.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                                    let js = "window.loadModelByURL(\"\(escaped)\", \"\(nameEscaped)\");"
                                    webViewRef?.evaluateJavaScript(js)
                                } else {
                                    
                                }
                            }
                            .preferredColorScheme(.dark)
                        } label: { EmptyView() }
                        .hidden()

                        // Hidden navigation link for placeholder pages
                        NavigationLink(isActive: $showPlaceholder) {
                            PlaceholderView(title: placeholderTitle)
                                .preferredColorScheme(.dark)
                        } label: { EmptyView() }
                        .hidden()
                    }
                )
                .overlay(alignment: .topTrailing) {
                    VStack(spacing: 6) {
                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showRoomSheet = true
                        }) {
                            Image(systemName: "photo.on.rectangle")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .clipShape(Circle())

                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            webViewRef?.evaluateJavaScript("window.triggerDance&&window.triggerDance();") 
                        }) {
                            Image(systemName: "figure.dance")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .clipShape(Circle())

                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            webViewRef?.evaluateJavaScript("window.triggerLove&&window.triggerLove();") 
                        }) {
                            Image(systemName: "heart")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .clipShape(Circle())

                        // Change Clothes button (opens costume sheet)
                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showCostumeSheet = true 
                        }) {
                            Image(systemName: "tshirt")
                                .font(.system(size: 14, weight: .semibold))
                                .frame(width: 32, height: 32)
                                .contentShape(Circle())
                        }
                        .buttonStyle(.glass)
                        .buttonBorderShape(.circle)
                        .clipShape(Circle())
                    }
                    .padding(.trailing, 8)
                    .padding(.top, 6)
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 8) {
                        // Live chat messages list - vertical, bottom aligned, fades when older
                        if !chatMessages.isEmpty {
                            ScrollViewReader { proxy in
                                ScrollView(.vertical, showsIndicators: false) {
                                    LazyVStack(alignment: .leading, spacing: 6) {
                                        ForEach(chatMessages.indices, id: \.self) { index in
                                            Text(chatMessages[index])
                                                .font(.system(size: 13, weight: .medium))
                                                .foregroundStyle(.white)
                                                .shadow(color: .black.opacity(0.3), radius: 1, x: 0, y: 1)
                                                .opacity(calculateOpacity(for: index))
                                                .id(index)
                                        }
                                    }
                                    // Ensure the stack is at least the chat area height and pinned to bottom when few messages
                                    .frame(minHeight: 200, alignment: .bottomLeading)
                                    .padding(.horizontal, 28)
                                    .padding(.bottom, 2)
                                }
                                .frame(height: 200)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .onAppear {
                                    if let last = chatMessages.indices.last {
                                        proxy.scrollTo(last, anchor: .bottom)
                                    }
                                }
                                .onChange(of: chatMessages.count) { _, _ in
                                    if let last = chatMessages.indices.last {
                                        withAnimation(.easeOut(duration: 0.2)) {
                                            proxy.scrollTo(last, anchor: .bottom)
                                        }
                                    }
                                }
                            }
                        }
                        
                        // Preset quick message chips
                        HStack(spacing: 8) {
                            Button(action: { 
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                sendMessage("Dance for me")
                            }) {
                                Text("Dance for me")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(action: { 
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                sendMessage("Kiss me")
                            }) {
                                Text("Kiss me")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)

                            Button(action: { 
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                sendMessage("Clothe off")
                            }) {
                                Text("Clothe off")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(.ultraThinMaterial)
                                    .clipShape(Capsule())
                                    .overlay(
                                        Capsule()
                                            .stroke(Color.white.opacity(0.15), lineWidth: 1)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 28)
                    }
                    .padding(.bottom, 14)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            webViewRef?.evaluateJavaScript("(function(){try{return window.toggleBgm&&window.toggleBgm();}catch(e){return false}})();") { result, _ in
                                if let playing = result as? Bool {
                                    
                                    DispatchQueue.main.async { self.isBgmOn = playing }
                                }
                            }
                        }) { Image(systemName: isBgmOn ? "speaker.wave.2.fill" : "speaker.slash.fill") }
                    }
                    ToolbarItem(placement: .principal) {
                        Picker("Mode", selection: $selectedTab) {
                            Text("Play").tag("Play")
                            Text("Chat").tag("Chat")
                            Text("Gallery").tag("Gallery")
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 300)
                        .onChange(of: selectedTab) { oldValue, newValue in
                            switch newValue {
                            case "Play":
                                showPlaceholder = false
                            case "Chat":
                                placeholderTitle = "Chat"
                                showPlaceholder = true
                            case "Gallery":
                                placeholderTitle = "Gallery"
                                showPlaceholder = true
                            default:
                                break
                            }
                        }
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            navigateToCharacters = true 
                        }) {
                            Image(systemName: "square.grid.2x2.fill")
                        }
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack(spacing: 10) {
                            TextField("Ask Anything", text: $chatText)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.sentences)
                                .disableAutocorrection(false)
                                .background(Color.clear)
                                .frame(maxWidth: .infinity)
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                let trimmed = chatText.trimmingCharacters(in: .whitespacesAndNewlines)
                                guard !trimmed.isEmpty else { return }
                                sendMessage(trimmed)
                                chatText = ""
                            }) {
                                Image(systemName: "paperplane.fill")
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                    }
                }
                .sheet(isPresented: $showCostumeSheet) {
                    CostumeSheetView(characterId: currentCharacterId) { costume in
                        if let directURL = costume.model_url, !directURL.isEmpty {
                            let escaped = directURL
                                .replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
                            let js = "window.loadModelByURL(\"\(escaped)\", \"\(costume.costume_name)\");"
                            webViewRef?.evaluateJavaScript(js)
                        } else {
                            let modelName = costume.url + ".vrm"
                            let escaped = modelName
                                .replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
                            let js = "window.loadModelByName(\"\(escaped)\");"
                            webViewRef?.evaluateJavaScript(js)
                        }
                    }
                    .preferredColorScheme(.dark)
                    .presentationDetents([.fraction(0.35), .large])
                    .presentationBackground(.ultraThinMaterial.opacity(0.6))
                }
                .sheet(isPresented: $showRoomSheet) {
                    RoomSheetView { room in
                        // Change background image in HTML
                        let escapedImage = room.image
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "\"", with: "\\\"")
                        let js = "document.body.style.backgroundImage = `url('\(escapedImage)')`;"
                        webViewRef?.evaluateJavaScript(js)
                    }
                    .preferredColorScheme(.dark)
                    .presentationDetents([.fraction(0.35), .large])
                    .presentationBackground(.ultraThinMaterial.opacity(0.6))
                }
        }
    }
    
    private func sendMessage(_ message: String) {
        // Add message to chat list
        chatMessages.append(message)
        
        // Keep only last 10 messages to prevent memory issues
        if chatMessages.count > 10 {
            chatMessages.removeFirst()
        }
        
        // Auto-scroll to latest message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Scroll to end would be handled by ScrollViewReader if needed
        }
        
        // TODO: Send message to web view or API
        // webViewRef?.evaluateJavaScript("sendMessage('\(message)');")
    }

    private func calculateOpacity(for index: Int) -> Double {
        let total = chatMessages.count
        // Start fading older messages; most recent ~4 stay strong
        let fadeWindow = 6
        let start = max(0, total - fadeWindow)
        if index >= start { return 1.0 }
        // Older than the fade window: progressively reduce opacity down to 0.15
        let distance = Double(start - index)
        let maxDistance: Double = 6.0
        let alpha = max(0.15, 1.0 - distance / maxDistance)
        return alpha
    }
}

// MARK: - Networking
// CharactersView: fetches from API and displays image + name cards
private struct CharactersView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var characters: [CharacterItem] = []
    @State private var isLoading: Bool = false
    @State private var errorMessage: String? = nil
    let onSelect: (CharacterItem) -> Void

    // Two-column layout of rounded long image cards (top-aligned to avoid stagger overlap)
    private let grid = [
        GridItem(.flexible(), spacing: 16, alignment: .top),
        GridItem(.flexible(), spacing: 16, alignment: .top)
    ]

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Group {
                if isLoading {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 16, pinnedViews: []) {
                            ForEach(0..<8, id: \.self) { _ in
                                SkeletonCharacterCardView()
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                } else if let errorMessage {
                    VStack(spacing: 12) {
                        Text("Failed to load characters")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text(errorMessage)
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                        Button("Retry") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                    .padding()
                } else if characters.isEmpty {
                    VStack(spacing: 12) {
                        Text("No characters available")
                            .foregroundStyle(.white.opacity(0.8))
                        Button("Reload") { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            load() 
                        }
                    }
                    .padding()
                } else {
                    ScrollView {
                        LazyVGrid(columns: grid, spacing: 16, pinnedViews: []) {
                            ForEach(characters) { item in
                                Button {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    onSelect(item)
                                    dismiss()
                                } label: {
                                    CharacterCardView(item: item)
                                        .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
        }
        .navigationTitle("Characters")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Reload") { 
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    load() 
                }
            }
        }
        .onAppear { if characters.isEmpty { load() } }
    }

    private func load() {
        guard !isLoading else { return }
        isLoading = true
        errorMessage = nil
        characters.removeAll()
        var request = URLRequest(url: URL(string: "https://n8n8n.top/webhook/characters")!)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, response, error in
            DispatchQueue.main.async {
                isLoading = false
                if let error = error { errorMessage = error.localizedDescription; return }
                guard let data = data else { errorMessage = "No data"; return }
                
                do {
                    var cleaned = data
                    if var str = String(data: data, encoding: .utf8) {
                        str = str.trimmingCharacters(in: .whitespacesAndNewlines)
                        if let range = str.range(of: "]", options: .backwards) {
                            let sliced = String(str[str.startIndex..<range.upperBound])
                            if let slicedData = sliced.data(using: .utf8) { cleaned = slicedData }
                        }
                    }
                    let items = try JSONDecoder().decode([CharacterItem].self, from: cleaned)
                    characters = items
                    
                } catch {
                    errorMessage = "Decoding error: \(error.localizedDescription)"
                }
            }
        }.resume()
    }
}

// MARK: - Thumbnail Prefetcher
private enum ImagePrefetcher {
    static func prefetch(urls: [URL]) {
        let session = URLSession.shared
        for url in urls { session.dataTask(with: url) { _, _, _ in }.resume() }
    }
}

private extension ContentView {
    func prefetchCharacterThumbnails() {
        guard let url = URL(string: "https://n8n8n.top/webhook/characters") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([CharacterItem].self, from: data) {
                let urls = items.compactMap { $0.thumbnail_url }.compactMap { URL(string: $0) }
                ImagePrefetcher.prefetch(urls: urls)
                
            }
        }.resume()
    }

    func prefetchCostumeThumbnails(for characterId: String) {
        let effectiveId = characterId.isEmpty ? "74432746-0bab-4972-a205-9169bece07f9" : characterId
        guard let url = URL(string: "https://n8n8n.top/webhook/costumes?character_id=\(effectiveId)") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([CostumeItem].self, from: data) {
                let urls = items.compactMap { $0.thumbnail }.compactMap { URL(string: $0) }
                ImagePrefetcher.prefetch(urls: urls)
                
            }
        }.resume()
    }
    
    func prefetchRoomThumbnails() {
        guard let url = URL(string: "https://n8n8n.top/webhook/rooms") else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([RoomItem].self, from: data) {
                let urls = items.compactMap { $0.thumbnail }.compactMap { URL(string: $0) }
                ImagePrefetcher.prefetch(urls: urls)
            }
        }.resume()
    }
}

// MARK: - Placeholder Page
private struct PlaceholderView: View {
    let title: String
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            Text("Function is under development")
                .foregroundStyle(.white)
                .font(.headline)
        }
        .navigationTitle(title)
    }
}

// MARK: - Skeleton Loading Views
private struct SkeletonCharacterCardView: View {
    private let cornerRadius: CGFloat = 20
    private let horizontalPadding: CGFloat = 16
    private let interItemSpacing: CGFloat = 16
    private let contentPadding: CGFloat = 16
    @State private var animate: Bool = false

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let targetWidth = max(0, (screenWidth - horizontalPadding * 2 - interItemSpacing) / 2.0)

        ZStack(alignment: .bottomLeading) {
            // Base card background
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color.white.opacity(0.06))

            // Subtle bottom gradient to mimic content overlay area
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.35)],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(maxWidth: .infinity)
            .frame(height: 180)
            .frame(maxHeight: .infinity, alignment: .bottom)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))

            // Title and description bars
            VStack(alignment: .leading, spacing: 10) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.14))
                    .frame(height: 18)
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.white.opacity(0.10))
                    .frame(width: targetWidth * 0.6, height: 12)
            }
            .padding(.horizontal, contentPadding + 20)
            .padding(.bottom, contentPadding + 10)

            // Shimmer overlay across the whole card
            shimmer
                .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
                .allowsHitTesting(false)
        }
        .frame(width: targetWidth, height: targetWidth * 1.3)
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .onAppear {
            withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                animate = true
            }
        }
    }

    private var shimmer: some View {
        GeometryReader { geo in
            let width = geo.size.width
            LinearGradient(
                gradient: Gradient(stops: [
                    .init(color: Color.white.opacity(0.0), location: 0.0),
                    .init(color: Color.white.opacity(0.18), location: 0.5),
                    .init(color: Color.white.opacity(0.0), location: 1.0)
                ]),
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(width: width * 0.6)
            .offset(x: animate ? width : -width)
            .blendMode(.plusLighter)
        }
        .opacity(0.55)
    }
}

// No custom floating buttons; using default Toolbar items above

#Preview {
    ContentView()
}
