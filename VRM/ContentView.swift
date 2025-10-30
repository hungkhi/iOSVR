import SwiftUI
import AVFoundation
import WebKit
import Photos

// moved to UIComponents.swift

// moved to UIComponents.swift

// ContentView - UPDATED FOR FULLSCREEN
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State var webViewRef: WKWebView? = nil
    @State private var chatText: String = ""
    var onModelReady: () -> Void = {}
    @State private var navigateToCharacters: Bool = false
    @State private var showPlaceholder: Bool = false
    @State private var placeholderTitle: String = ""
    @State private var showCostumeSheet: Bool = false
    @State private var showRoomSheet: Bool = false
    // Track currently selected character id for costume fetching
    @State private var currentCharacterId: String = "74432746-0bab-4972-a205-9169bece07f9"
    @State private var currentCharacterName: String = ""
    @State var currentRoomName: String = ""
    @State private var isBgmOn: Bool = false
    // Chat messages: text or voice
    @State var chatMessages: [ChatMessage] = []
    @FocusState private var chatFieldFocused: Bool
    // Characters for swipe navigation
    @State private var allCharacters: [CharacterItem] = []
    @State private var currentCharacterIndex: Int = 0
    // Parallax controller
    @State private var parallaxController: ParallaxController? = nil
    // Toast for save confirmation
    @State private var showSavedToast: Bool = false
    // ElevenLabs
    @StateObject private var convVM = ConversationViewModel()
    private let elevenLabsAgentId: String = "agent_9201k8qwpfsjew2v76qf995vq416"
    @State private var showChatList: Bool = true
    @State private var bootingAgent: Bool = false
    @State private var showSettingsSheet: Bool = false
    @State private var showMediaSheet: Bool = false
    var body: some View {
        NavigationStack {
            ZStack {
                VRMWebView(htmlFileName: "index", webView: $webViewRef, onModelReady: onModelReady)
                    .ignoresSafeArea()
                    .highPriorityGesture(
                    DragGesture(minimumDistance: 20, coordinateSpace: .local)
                        .onEnded { value in
                            let dx = value.translation.width
                            let dy = value.translation.height
                            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                            // Horizontal swipe -> change background
                            if abs(dx) > abs(dy), abs(dx) > 40 {
                                impactFeedback.impactOccurred()
                                if dx < 0 {
                                    webViewRef?.evaluateJavaScript("window.nextBackground&&window.nextBackground();")
                                } else {
                                    webViewRef?.evaluateJavaScript("window.prevBackground&&window.prevBackground();")
                                }
                        // Capture and persist current background and room name after transition
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                            captureAndSaveCurrentBackgroundAndRoom()
                                }
                            }
                            // Vertical swipe -> change character (random)
                            else if abs(dy) > 40 {
                                impactFeedback.impactOccurred()
                                changeCharacter(by: dy < 0 ? 1 : -1)
                            }
                        }
                )
                .onAppear {
                    let files = FileDiscovery.discoverFiles()
                    _ = files
                    // Ensure background music starts muted by default
                    webViewRef?.evaluateJavaScript("(function(){try{return window.setBgm&&window.setBgm(false);}catch(e){return false}})();") { _, _ in }
                    // Prefetch character thumbnails for faster grid loading
                    prefetchCharacterThumbnails()
                    // Fetch characters list for swipe up/down navigation
                    fetchCharactersList()
                    // Prefetch default character's costume thumbnails
                    prefetchCostumeThumbnails(for: currentCharacterId)
                    // Prefetch room thumbnails for faster room sheet loading
                    prefetchRoomThumbnails()
                    // Start parallax updates
                    if parallaxController == nil {
                        let controller = ParallaxController { dx, dy in
                            let js = "window.applyParallax&&window.applyParallax(\(Int(dx)),\(Int(dy)));"
                            webViewRef?.evaluateJavaScript(js)
                        }
                        parallaxController = controller
                        controller.start()
                    }
                    // Set local state to muted by default
                    DispatchQueue.main.async { self.isBgmOn = false }
                    // Seed title from persisted model name if available
                    if currentCharacterName.isEmpty {
                        let name = UserDefaults.standard.string(forKey: PersistKeys.modelName) ?? ""
                        if !name.isEmpty { currentCharacterName = name }
                    }
                    // Seed room name from persistence
                    if currentRoomName.isEmpty {
                        let rn = UserDefaults.standard.string(forKey: PersistKeys.roomName) ?? ""
                        if !rn.isEmpty { currentRoomName = rn }
                    }
                    // Apply persisted background if present and not already applied by injection
                    if let bg = UserDefaults.standard.string(forKey: PersistKeys.backgroundURL), !bg.isEmpty {
                        let escaped = bg.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                        let js = "(function(){try{if(!window.__bgApplied){document.body.style.backgroundImage=\"url('\(escaped)')\";window.__bgApplied=true;}}catch(e){}})();"
                        webViewRef?.evaluateJavaScript(js)
                    }
                    // Agent will be started manually via mic button
                }
                // Receive ElevenLabs agent text and append as pink bubbles
                .onReceive(convVM.agentText) { text in
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                        chatMessages.append(ChatMessage(kind: .text(text), isAgent: true))
                        while chatMessages.count > 5 { chatMessages.removeFirst() }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    switch newPhase {
                    case .active:
                        // Resume parallax
                        parallaxController?.start()
                    case .inactive, .background:
                        // Pause background music in the web view when app not active
                        webViewRef?.evaluateJavaScript("(function(){try{return window.setBgm&&window.setBgm(false);}catch(e){return false}})();")
                        parallaxController?.stop()
                    @unknown default:
                        webViewRef?.evaluateJavaScript("(function(){try{return window.setBgm&&window.setBgm(false);}catch(e){return false}})();")
                        parallaxController?.stop()
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
                                persistCharacter(id: item.id)
                                persistModel(url: url, name: item.name)
                                    currentCharacterName = item.name
                                } else {
                                // No direct URL; rely on model name mapping if provided elsewhere
                                persistCharacter(id: item.id)
                                currentCharacterName = item.name
                                }
                                // Do not auto-start agent; user controls via mic button
                                // Sync swipe index
                                if let idx = allCharacters.firstIndex(where: { $0.id == item.id }) {
                                    currentCharacterIndex = idx
                                }
                            }
                            .preferredColorScheme(.dark)
                        } label: { EmptyView() }
                        .hidden()

                        // Placeholder link removed with tab removal
                    }
                )
                .overlay(alignment: .topTrailing) {
                    ControlButtonsView(
                        onRoomTap: { showRoomSheet = true },
                        onDanceTap: { webViewRef?.evaluateJavaScript("window.triggerDance&&window.triggerDance();") },
                        onLoveTap: { showMediaSheet = true },
                        onCostumeTap: { showCostumeSheet = true },
                        onCameraTap: { captureAndSaveSnapshot() },
                        showChatList: showChatList,
                        hasMessages: !chatMessages.isEmpty,
                        onToggleChat: {
                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) { showChatList.toggle() }
                        }
                    )
                }
                .overlay(alignment: .top) {
                    SaveToastView(isVisible: showSavedToast)
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 8) {
                        ChatMessagesOverlay(
                            messages: chatMessages,
                            showChatList: showChatList,
                            onSwipeToHide: {
                                withAnimation(.easeInOut(duration: 0.25)) { showChatList = false }
                            },
                            calculateOpacity: calculateOpacity,
                            bottomInset: 0,
                            isInputFocused: chatFieldFocused
                        )
                        
                        if chatFieldFocused {
                            QuickMessageChips(onSendMessage: sendMessage)
                        }
                    }
                    .padding(.bottom, 8)
                }
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        HStack(spacing: 8) {
                            Button(action: {
                                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                impactFeedback.impactOccurred()
                                showSettingsSheet = true
                            }) { Image(systemName: "gearshape.fill") }
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
                    }
                    ToolbarItem(placement: .principal) {
                        VStack(spacing: 2) {
                            Text(displayedCharacterTitle())
                                .font(.system(size: 17, weight: .bold))
                                .foregroundStyle(.white)
                            if !currentRoomName.isEmpty {
                                Text(currentRoomName)
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.9))
                            }
                        }
                        .multilineTextAlignment(.center)
                    }
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            navigateToCharacters = true 
                        }) {
                            Image(systemName: "square.grid.2x2.fill")
                        }
                        .padding(6)
                    }

                    ToolbarItemGroup(placement: .bottomBar) {
                        HStack(spacing: 10) {
                            TextField("", text: $chatText, prompt: Text(chatPlaceholder()).foregroundStyle(.white))
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.sentences)
                                .disableAutocorrection(false)
                                .background(Color.clear)
                                .frame(maxWidth: .infinity)
                                .focused($chatFieldFocused)
                            
                            if chatFieldFocused || !chatText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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
                                .transition(.opacity.combined(with: .scale))
                            } else {
                                Button(action: {
                                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                                    impactFeedback.impactOccurred()
                                    if convVM.isConnected {
                                        bootingAgent = false
                                        // Append system message and trim to last 5
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            chatMessages.append(ChatMessage(kind: .text("Conversation stopped")))
                                            while chatMessages.count > 5 { chatMessages.removeFirst() }
                                        }
                                        Task { await convVM.endConversation() }
                                    } else {
                                        bootingAgent = true
                                        Task { await convVM.startConversationIfNeeded(agentId: elevenLabsAgentId) }
                                    }
                                }) {
                                    if bootingAgent {
                                        ProgressView()
                                            .progressViewStyle(.circular)
                                            .padding(.trailing, -6)
                                    } else if convVM.isConnected {
                                        Image(systemName: "stop.fill")
                                    } else {
                                        Image(systemName: "mic.fill")
                                    }
                                }
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 16)
                    }
                }
                .onChange(of: convVM.isConnected) { _, newVal in
                    if newVal { bootingAgent = false }
                }
                .sheet(isPresented: $showCostumeSheet) {
                    CostumeSheetView(characterId: currentCharacterId) { costume in
                        if let directURL = costume.model_url, !directURL.isEmpty {
                            let escaped = directURL
                                .replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
                            let js = "window.loadModelByURL(\"\(escaped)\", \"\(costume.costume_name)\");"
                            webViewRef?.evaluateJavaScript(js)
                            persistModel(url: directURL, name: costume.costume_name)
                        } else {
                            let modelName = costume.url + ".vrm"
                            let escaped = modelName
                                .replacingOccurrences(of: "\\", with: "\\\\")
                                .replacingOccurrences(of: "\"", with: "\\\"")
                            let js = "window.loadModelByName(\"\(escaped)\");"
                            webViewRef?.evaluateJavaScript(js)
                            persistModel(url: nil, name: modelName)
                        }
                    }
                    // Ensure the sheet refreshes when the current character changes (e.g., via swipe)
                    .id(currentCharacterId)
                    .preferredColorScheme(.dark)
                    .presentationDetents([.fraction(0.35), .large])
                    .presentationBackground(.ultraThinMaterial.opacity(0.2))
                }
                .sheet(isPresented: $showRoomSheet) {
                    RoomSheetView { room in
                        // Change background image in HTML
                        let escapedImage = room.image
                            .replacingOccurrences(of: "\\", with: "\\\\")
                            .replacingOccurrences(of: "\"", with: "\\\"")
                        let js = "document.body.style.backgroundImage = `url('\(escapedImage)')`;"
                        webViewRef?.evaluateJavaScript(js)
                        persistRoom(name: room.name, url: room.image)
                        currentRoomName = room.name
                    }
                    .preferredColorScheme(.dark)
                    .presentationDetents([.fraction(0.35), .large])
                    .presentationBackground(.ultraThinMaterial.opacity(0.2))
                }
                .sheet(isPresented: $showMediaSheet) {
                    MediaSheetView(characterId: currentCharacterId)
                        .preferredColorScheme(.dark)
                        .presentationDetents([.fraction(0.35), .large])
                        .presentationBackground(.ultraThinMaterial.opacity(0.2))
                }
                .sheet(isPresented: $showSettingsSheet) {
                    PlaceholderView(title: "Settings")
                        .preferredColorScheme(.dark)
                }
                if chatFieldFocused {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            chatFieldFocused = false
                        }
                }
            }
        }
    }
    
    private func sendMessage(_ message: String) {
        // Add message to chat list
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.1)) {
            chatMessages.append(ChatMessage(kind: .text(message)))
        }
        // Also send to ElevenLabs agent if connected
        Task { await convVM.sendText(message) }
        
        // Keep only last 5 messages
        if chatMessages.count > 5 {
            withAnimation(.easeInOut(duration: 0.2)) {
                while chatMessages.count > 5 { chatMessages.removeFirst() }
            }
        }
        
        // Auto-scroll to latest message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Scroll to end would be handled by ScrollViewReader if needed
        }
        
        // TODO: Send message to web view or API
        // webViewRef?.evaluateJavaScript("sendMessage('\(message)');")
    }
    
    private func chatPlaceholder() -> String {
        if bootingAgent { return "Setting up the conversation..." }
        if convVM.isConnected {
            let name: String
            if !currentCharacterName.isEmpty {
                name = currentCharacterName
            } else if let found = allCharacters.first(where: { $0.id == currentCharacterId })?.name {
                name = found
            } else { name = "Agent" }
            return "Talking to \(name)"
        }
        return "Ask Anything"
    }
    
    private func fetchCharactersList() {
        guard allCharacters.isEmpty else { return }
        var request = URLRequest(url: URL(string: "https://n8n8n.top/webhook/characters")!)
        request.httpMethod = "GET"
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([CharacterItem].self, from: data) {
                DispatchQueue.main.async {
                    self.allCharacters = items
                    if let idx = items.firstIndex(where: { $0.id == self.currentCharacterId }) {
                        self.currentCharacterIndex = idx
                    } else {
                        self.currentCharacterIndex = 0
                    }
                }
            }
        }.resume()
    }

    private func changeCharacter(by delta: Int) {
        guard !allCharacters.isEmpty else { return }
        let count = allCharacters.count
        var newIndex = (currentCharacterIndex + delta) % count
        if newIndex < 0 { newIndex += count }
        let item = allCharacters[newIndex]
        currentCharacterIndex = newIndex
        currentCharacterId = item.id
        currentCharacterName = item.name
        // Preload costumes for the new character
        prefetchCostumeThumbnails(for: item.id)
        // Load model by URL if available
        if let url = item.base_model_url, !url.isEmpty {
            let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let nameEscaped = item.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let js = "window.loadModelByURL(\"\(escaped)\", \"\(nameEscaped)\");"
            webViewRef?.evaluateJavaScript(js)
            // Persist selection for next launch
            persistCharacter(id: item.id)
            persistModel(url: url, name: item.name)
        }
        // Do not auto-start agent on character change; user controls via mic button
    }

    private func displayedCharacterTitle() -> String {
        if !currentCharacterName.isEmpty { return currentCharacterName }
        if let found = allCharacters.first(where: { $0.id == currentCharacterId }) { return found.name }
        return ""
    }

    // MARK: - Snapshot and save to Photos
    private func captureAndSaveSnapshot() {
        guard let webView = webViewRef else { return }
        let config = WKSnapshotConfiguration()
        config.rect = webView.bounds
        config.afterScreenUpdates = true
        webView.takeSnapshot(with: config) { image, error in
            guard let image = image else { return }
            if #available(iOS 14, *) {
                PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                    if status == .authorized || status == .limited {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }) { success, _ in
                            if success {
                                DispatchQueue.main.async {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showSavedToast = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            showSavedToast = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            } else {
                PHPhotoLibrary.requestAuthorization { status in
                    if status == .authorized {
                        PHPhotoLibrary.shared().performChanges({
                            PHAssetChangeRequest.creationRequestForAsset(from: image)
                        }) { success, _ in
                            if success {
                                DispatchQueue.main.async {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                        showSavedToast = true
                                    }
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                                        withAnimation(.easeOut(duration: 0.25)) {
                                            showSavedToast = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}

// moved to UIComponents.swift

// moved to UIComponents.swift

// No custom floating buttons; using default Toolbar items above

#Preview {
    ContentView()
}
