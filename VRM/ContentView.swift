import SwiftUI
import AVFoundation
import WebKit
import Photos
import Auth

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
    @State private var currentAgentId: String = ""
    @StateObject private var authManager = AuthManager.shared
    var body: some View {
        NavigationStack {
            if authManager.session == nil && !authManager.isGuest {
                // Show sign-in page
                VStack(spacing: 24) {
                    Spacer()
                    Text("Welcome to VRM!")
                        .font(.largeTitle.bold())
                        .foregroundColor(.white)
                    Text("Please sign in to continue.")
                        .foregroundColor(.gray)
                        .padding(.bottom, 32)
                    if let errorMsg = authManager.errorMessage {
                        Text(errorMsg)
                            .foregroundColor(.red)
                    }
                    Button {
                        authManager.signInWithApple()
                    } label: {
                        HStack {
                            Image(systemName: "applelogo")
                            Text("Sign in with Apple")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.black.opacity(0.92))
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                    Button {
                        authManager.continueAsGuest()
                    } label: {
                        HStack {
                            Image(systemName: "person.fill.questionmark")
                            Text("Use as Guest")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .foregroundColor(.white)
                        .background(Color.gray.opacity(0.4))
                        .cornerRadius(12)
                    }
                    .disabled(authManager.isLoading)
                    Spacer()
                }
                .background(Color.black.ignoresSafeArea())
                .onAppear { onModelReady() }
            } else {
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
                        // Persist agent reply
                        persistConversationMessage(text: text, isAgent: true)
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
                                    
                                    applyCharacter(item)
                                    // Load model by URL if available
                                    if let url = item.base_model_url, !url.isEmpty {
                                        let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                                        let nameEscaped = item.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                                        let js = "window.loadModelByURL(\"\(escaped)\", \"\(nameEscaped)\");"
                                        webViewRef?.evaluateJavaScript(js)
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
                                            Task { await convVM.startConversationIfNeeded(agentId: currentAgentId.isEmpty ? elevenLabsAgentId : currentAgentId) }
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
                                upsertUserCharacterPreference(costumeName: costume.costume_name, costumeURL: directURL, roomName: nil, roomImage: nil)
                            } else {
                                let modelName = costume.url + ".vrm"
                                let escaped = modelName
                                    .replacingOccurrences(of: "\\", with: "\\\\")
                                    .replacingOccurrences(of: "\"", with: "\\\"")
                                let js = "window.loadModelByName(\"\(escaped)\");"
                                webViewRef?.evaluateJavaScript(js)
                                persistModel(url: nil, name: modelName)
                                upsertUserCharacterPreference(costumeName: modelName, costumeURL: nil, roomName: nil, roomImage: nil)
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
                            upsertUserCharacterPreference(costumeName: nil, costumeURL: nil, roomName: room.name, roomImage: room.image)
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
                        VStack {
                            if let user = authManager.user {
                                Text("Signed in as\n\(user.email ?? "Unknown")")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical)
                                Button("Log Out") {
                                    Task { await authManager.logout() }
                                }
                                .foregroundColor(.red)
                                .padding(.bottom, 24)
                            } else if authManager.isGuest {
                                Text("Using Guest Mode")
                                    .font(.headline)
                                    .multilineTextAlignment(.center)
                                    .padding(.vertical)
                                Button("Exit Guest Mode") {
                                    Task { await authManager.logout() }
                                }
                                .foregroundColor(.red)
                                .padding(.bottom, 24)
                            }
                            PlaceholderView(title: "Settings")
                                .preferredColorScheme(.dark)
                        }
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
        
        // Persist to Supabase conversation table
        persistConversationMessage(text: message, isAgent: false)
    }

    private func persistConversationMessage(text: String, isAgent: Bool) {
        guard !currentCharacterId.isEmpty else { return }
        let userIdString: String? = {
            if let anyId = AuthManager.shared.user?.id { return String(describing: anyId) }
            return nil
        }()
        let clientId = AuthManager.shared.isGuest ? (UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId()) : nil
        guard let url = URL(string: SUPABASE_URL + "/rest/v1/conversation") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        if let cid = clientId { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        var body: [String: Any] = [
            "character_id": currentCharacterId,
            "message": text,
            "is_agent": isAgent
        ]
        if let userId = userIdString { body["user_id"] = userId }
        if let clientId = clientId { body["client_id"] = clientId }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
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
        let query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "id,name,description,thumbnail_url,base_model_url,agent_elevenlabs_id"),
            URLQueryItem(name: "is_public", value: "is.true"),
            URLQueryItem(name: "order", value: "order.nullsfirst")
        ]
        guard let request = makeSupabaseRequest(path: "/rest/v1/characters", queryItems: query) else { return }
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

    // Add this helper to centralize the update logic
    private func applyCharacter(_ item: CharacterItem) {
        currentCharacterId = item.id
        currentCharacterName = item.name
        currentCharacterIndex = allCharacters.firstIndex(where: { $0.id == item.id }) ?? currentCharacterIndex
        // Update ElevenLabs agent id in state
        currentAgentId = item.agent_elevenlabs_id ?? ""
        // If conversation is already started, switch agent instantly
        if convVM.isConnected {
            Task {
                await convVM.endConversation()
                if !currentAgentId.isEmpty {
                    await convVM.startConversation(agentId: currentAgentId)
                }
            }
        }
        // Refresh costume thumbnails (will reload sheet if open)
        prefetchCostumeThumbnails(for: item.id)
        // Persist
        persistCharacter(id: item.id)
        persistModel(url: item.base_model_url, name: item.name)

        // Load latest conversation messages for this character
        loadLatestConversation()

        // Load and apply saved outfit and room for this user/guest
        loadUserCharacterPreference()
    }

    private func loadUserCharacterPreference() {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "current_costume_name,current_costume_model_url,current_room_name,current_room_image"),
            URLQueryItem(name: "character_id", value: "eq.\(currentCharacterId)")
        ]
        if let anyId = AuthManager.shared.user?.id {
            let uid = String(describing: anyId)
            query.append(URLQueryItem(name: "user_id", value: "eq.\(uid)"))
        } else if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId() {
            query.append(URLQueryItem(name: "client_id", value: "eq.\(cid)"))
        }
        guard var req = makeSupabaseRequest(path: "/rest/v1/user_character", queryItems: query) else { return }
        if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let row = arr.first else { return }
            let costumeURL = row["current_costume_model_url"] as? String
            let costumeName = row["current_costume_name"] as? String
            let roomName = row["current_room_name"] as? String
            let roomImage = row["current_room_image"] as? String
            DispatchQueue.main.async {
                if let image = roomImage, !image.isEmpty {
                    let escaped = image.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let js = "document.body.style.backgroundImage = `url('\(escaped)')`;"
                    webViewRef?.evaluateJavaScript(js)
                    if let rn = roomName { currentRoomName = rn }
                    persistRoom(name: roomName ?? "", url: image)
                }
                if let url = costumeURL, !url.isEmpty, let name = costumeName {
                    let escapedURL = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let escapedName = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let js = "window.loadModelByURL(\"\(escapedURL)\", \"\(escapedName)\");"
                    webViewRef?.evaluateJavaScript(js)
                    persistModel(url: url, name: name)
                } else if let name = costumeName, !name.isEmpty {
                    let escapedName = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let js = "window.loadModelByName(\"\(escapedName)\");"
                    webViewRef?.evaluateJavaScript(js)
                    persistModel(url: nil, name: name)
                }
            }
        }.resume()
    }

    private func upsertUserCharacterPreference(costumeName: String?, costumeURL: String?, roomName: String?, roomImage: String?) {
        guard !currentCharacterId.isEmpty else { return }
        let clientId = AuthManager.shared.isGuest ? (UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId()) : nil
        guard let url = URL(string: SUPABASE_URL + "/rest/v1/user_character") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("Bearer \(SUPABASE_ANON_KEY)", forHTTPHeaderField: "Authorization")
        req.setValue(SUPABASE_ANON_KEY, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        if let cid = clientId { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        var body: [String: Any] = [
            "character_id": currentCharacterId
        ]
        if let anyId = AuthManager.shared.user?.id { body["user_id"] = String(describing: anyId) }
        if let cid = clientId { body["client_id"] = cid }
        if let costumeName = costumeName { body["current_costume_name"] = costumeName }
        if let costumeURL = costumeURL { body["current_costume_model_url"] = costumeURL }
        if let roomName = roomName { body["current_room_name"] = roomName }
        if let roomImage = roomImage { body["current_room_image"] = roomImage }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }

    private struct ConversationRow: Decodable {
        let message: String
        let is_agent: Bool
        let created_at: String
    }

    private func loadLatestConversation(limit: Int = 5) {
        guard !currentCharacterId.isEmpty else { return }
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "message,is_agent,created_at"),
            URLQueryItem(name: "character_id", value: "eq.\(currentCharacterId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: String(limit))
        ]
        if let anyId = AuthManager.shared.user?.id {
            let uid = String(describing: anyId)
            query.append(URLQueryItem(name: "user_id", value: "eq.\(uid)"))
        } else if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId() {
            query.append(URLQueryItem(name: "client_id", value: "eq.\(cid)"))
        }
        guard var req = makeSupabaseRequest(path: "/rest/v1/conversation", queryItems: query) else { return }
        if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data, let rows = try? JSONDecoder().decode([ConversationRow].self, from: data) else { return }
            let mapped: [ChatMessage] = rows.reversed().map { row in
                ChatMessage(kind: .text(row.message), isAgent: row.is_agent)
            }
            DispatchQueue.main.async {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.9)) {
                    self.chatMessages = mapped
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
        applyCharacter(item)
        // Load model by URL if available
        if let url = item.base_model_url, !url.isEmpty {
            let escaped = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let nameEscaped = item.name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
            let js = "window.loadModelByURL(\"\(escaped)\", \"\(nameEscaped)\");"
            webViewRef?.evaluateJavaScript(js)
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
