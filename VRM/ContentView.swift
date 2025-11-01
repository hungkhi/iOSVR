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
    @State private var currentRoomId: String? = nil
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
    // Synchronize model loading with background changes
    @State private var isModelLoading: Bool = false
    @State private var pendingBackgroundImage: String? = nil
    @State private var pendingRoomNameQueued: String? = nil
    // Rooms ordering for background swipe
    @State private var allRooms: [RoomItem] = []
    @State private var navigateToChatHistory: Bool = false
    // Full-screen chat history mode state
    @State private var showChatHistoryFullScreen: Bool = false
    @State private var historyRows: [HistoryRow] = []
    @State private var historyIsFetching: Bool = false
    private let historyBatchSize: Int = 15
    @State private var historyOldestCursor: String? = nil
    @State private var historyShowTimeFor: Set<String> = []
    @State private var historyReachedEnd: Bool = false
    // Avatar loading/selection state
    @State private var loadedAvatarIds: Set<String> = []
    @State private var pendingAvatarSelection: Int? = nil
    @State private var lastCharacterIndex: Int = 0
    @State private var lastSelectionDirection: Int = 0 // +1 down, -1 up
    // Keyboard handling
    @State private var keyboardHeight: CGFloat = 0
    // Age gate
    @AppStorage("ageVerified18") private var ageVerified18: Bool = false
    @State private var showAgeConfirm: Bool = false
    @State private var showAgeBlocked: Bool = false
    @State private var showTermsSheet: Bool = false
    @State private var showPrivacySheet: Bool = false
    // Post-conversation feedback (managed by view model)
    @StateObject private var feedbackVM = FeedbackViewModel()
    // Settings toggles
    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("settings.autoPlayMusic") private var autoPlayMusic: Bool = false
    @AppStorage("settings.autoEnterTalking") private var autoEnterTalking: Bool = false
    // Display name prompt
    @State private var showNamePrompt: Bool = false
    @State private var pendingDisplayName: String = ""
    // Notification navigation
    @State private var pendingCharacterIdFromNotification: String? = nil
    var body: some View {
        NavigationStack {
            if authManager.session == nil && !authManager.isGuest {
                OnboardingView(onModelReady: onModelReady)
                .alert("Sorry, you must be 18+ to use this app.", isPresented: $showAgeBlocked) {
                    Button("OK", role: .cancel) { }
                }
            } else {
                ZStack {
                    VRMWebView(htmlFileName: "index", webView: $webViewRef, onModelReady: onModelReady)
                        .ignoresSafeArea()
                        .highPriorityGesture(
                        DragGesture(minimumDistance: 20, coordinateSpace: .local)
                            .onEnded { value in
                                let dx = value.translation.width
                                let dy = value.translation.height
                                triggerHaptic(.light)
                                // Horizontal swipe -> change background
                                if abs(dx) > abs(dy), abs(dx) > 40 {
                                    advanceRoom(by: dx < 0 ? 1 : -1)
                                }
                                // Vertical swipe -> change character (random)
                                else if abs(dy) > 40 {
                                    triggerHaptic(.light)
                                    changeCharacter(by: dy < 0 ? 1 : -1)
                                }
                            }
                    )
                    .onAppear {
                        let files = FileDiscovery.discoverFiles()
                        _ = files
                        // Seed currentCharacterId from persistence so initial selection matches saved character
                        if let persistedId = UserDefaults.standard.string(forKey: PersistKeys.characterId), !persistedId.isEmpty {
                            currentCharacterId = persistedId
                        }
                        // Respect auto-play setting at launch
                        if autoPlayMusic {
                            BackgroundMusicManager.shared.play()
                            DispatchQueue.main.async { self.isBgmOn = true }
                        } else {
                            BackgroundMusicManager.shared.pause()
                            DispatchQueue.main.async { self.isBgmOn = false }
                        }
                        // Prefetch character thumbnails for faster grid loading
                        prefetchCharacterThumbnails()
                        // Fetch characters list for swipe up/down navigation
                        fetchCharactersList()
                        // Prefetch default character's costume thumbnails
                        prefetchCostumeThumbnails(for: currentCharacterId)
                        // Prefetch room thumbnails and pull ordered list for swipe sequencing
                        prefetchRoomThumbnails()
                        fetchRoomsOrder()
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
                        // Do not seed title from model name; title should reflect character name only
                        // Seed room name from persistence
                        if currentRoomName.isEmpty {
                            let rn = UserDefaults.standard.string(forKey: PersistKeys.roomName) ?? ""
                            if !rn.isEmpty { currentRoomName = rn }
                        }
                        // Apply or re-apply persisted background to avoid white flashes
                        ensureBackgroundApplied()
                        // Auto-start conversation if enabled
                        if autoEnterTalking && !convVM.isConnected {
                            bootingAgent = true
                            Task { await convVM.startConversationIfNeeded(agentId: currentAgentId.isEmpty ? elevenLabsAgentId : currentAgentId) }
                        }
                        // Agent will be started manually via mic button otherwise
                        if chatMessages.isEmpty { loadLatestConversation() }
                    }
                    // Show name prompt if needed when user becomes available
                    .onChange(of: authManager.user) { _, newUser in
                        guard newUser != nil else { return }
                        if authManager.needsDisplayNamePrompt() {
                            let fallback = (newUser?.email ?? "").split(separator: "@").first.map(String.init) ?? ""
                            pendingDisplayName = fallback
                            showNamePrompt = true
                        }
                    }
                    // Receive ElevenLabs agent text and append as pink bubbles
                    .onReceive(convVM.agentText) { text in
                        // Ensure background music stays off whenever agent speaks
                        muteBgmIfNeeded()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            chatMessages.append(ChatMessage(kind: .text(text), isAgent: true))
                            while chatMessages.count > 5 { chatMessages.removeFirst() }
                        }
                        feedbackVM.markInteractedIfConnected(convVM.isConnected)
                        // If in full chat mode, mirror into history list immediately
                        if showChatHistoryFullScreen {
                            let now = ISO8601DateFormatter().string(from: Date())
                            historyRows.append(HistoryRow(message: text, is_agent: true, created_at: now))
                        }
                        // Persist agent reply
                        persistConversationMessage(text: text, isAgent: true)
                    }
                    // Receive user transcripts from ElevenLabs ASR and persist/display like typed messages
                    .onReceive(convVM.userText) { text in
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                            chatMessages.append(ChatMessage(kind: .text(text), isAgent: false))
                            while chatMessages.count > 5 { chatMessages.removeFirst() }
                        }
                        feedbackVM.markInteractedIfConnected(convVM.isConnected)
                        if showChatHistoryFullScreen {
                            let now = ISO8601DateFormatter().string(from: Date())
                            historyRows.append(HistoryRow(message: text, is_agent: false, created_at: now))
                        }
                        persistConversationMessage(text: text, isAgent: false)
                    }
                    
                    .onChange(of: scenePhase) { _, newPhase in
                        switch newPhase {
                        case .active:
                            // Resume parallax
                            parallaxController?.start()
                            // Re-ensure background is applied when returning from other pages
                            ensureBackgroundApplied()
                        case .inactive, .background:
                            // Pause background music in the web view when app not active
                            BackgroundMusicManager.shared.pause()
                            parallaxController?.stop()
                        @unknown default:
                            BackgroundMusicManager.shared.pause()
                            parallaxController?.stop()
                        }
                    }
                    .background(
                        ZStack {
                            // Hidden navigation link target for CharactersView
                            NavigationLink(isActive: $navigateToCharacters) {
                                CharactersView { item in
                                    
                                    applyCharacter(item)
                                }
                                .preferredColorScheme(.dark)
                            } label: { EmptyView() }
                            .hidden()

                            // Hidden navigation link to Chat History
                            NavigationLink(destination: ChatHistoryView(characterId: currentCharacterId, agentId: (currentAgentId.isEmpty ? elevenLabsAgentId : currentAgentId), convVM: convVM), isActive: $navigateToChatHistory) { EmptyView() }
                                .hidden()

                            // Placeholder link removed with tab removal
                        }
                    )
                    .overlay(alignment: .topTrailing) {
                        if !showChatHistoryFullScreen {
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
                    }
                    .overlay(alignment: .bottomTrailing) {
                        avatarQuickSwitcher()
                    }
                    .overlay(alignment: .top) {
                        if !showChatHistoryFullScreen { SaveToastView(isVisible: showSavedToast) }
                    }
                    .overlay(alignment: .bottom) {
                        VStack(spacing: 6) {
                            if !showChatHistoryFullScreen {
                            ChatMessagesOverlay(
                                messages: chatMessages,
                                showChatList: showChatList,
                                onSwipeToHide: {
                                    withAnimation(.easeInOut(duration: 0.25)) { showChatList = false }
                                },
                                onTap: {
                                    triggerHaptic(.light)
                                    withAnimation(.easeInOut(duration: 0.25)) { showChatHistoryFullScreen = true }
                                    fetchConversationHistory(reset: true)
                                },
                                calculateOpacity: calculateOpacity,
                                bottomInset: 0,
                                isInputFocused: chatFieldFocused
                            )
                            }
                            
                            if chatFieldFocused && !showChatHistoryFullScreen {
                                QuickMessageChips(onSendMessage: sendMessage)
                            }
                        }
                        .padding(.bottom, 8)
                    }
                    .toolbar {
                        if showChatHistoryFullScreen {
                            ToolbarItem(placement: .topBarLeading) {
                                Button(action: { withAnimation(.easeInOut(duration: 0.25)) { showChatHistoryFullScreen = false } }) { Image(systemName: "chevron.backward") }
                            }
                            ToolbarItemGroup(placement: .bottomBar) {
                                ChatInputBar(
                                    text: $chatText,
                                    isConnected: convVM.isConnected,
                                    isBooting: bootingAgent,
                                    onSend: { msg in
                                        triggerHaptic(.medium)
                                        sendMessage(msg)
                                    },
                                    onToggleMic: {
                                        triggerHaptic(.medium)
                                        if convVM.isConnected {
                                            bootingAgent = false
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                                chatMessages.append(ChatMessage(kind: .text("Conversation stopped")))
                                                while chatMessages.count > 5 { chatMessages.removeFirst() }
                                            }
                                            Task { await convVM.endConversation() }
                                        } else {
                                            bootingAgent = true
                                            Task { await convVM.startConversationIfNeeded(agentId: currentAgentId.isEmpty ? elevenLabsAgentId : currentAgentId) }
                                        }
                                    },
                                    onFocusChanged: { focused in
                                        chatFieldFocused = focused
                                },
                                placeholder: chatPlaceholder()
                                )
                            }
                        } else {
                        ToolbarItem(placement: .topBarLeading) {
                            HStack(spacing: 8) {
                                Button(action: {
                                    triggerHaptic(.medium)
                                    showSettingsSheet = true
                                }) { Image(systemName: "gearshape.fill") }
                                .padding(.horizontal, 4)
                                Button(action: {
                                    triggerHaptic(.medium)
                                    let playing = BackgroundMusicManager.shared.toggle()
                                            DispatchQueue.main.async { self.isBgmOn = playing }
                                }) { Image(systemName: isBgmOn ? "speaker.wave.2.fill" : "speaker.slash.fill") }
                                .padding(.horizontal, 4)
                            }
                        }
                        ToolbarItem(placement: .principal) {
                            VStack(spacing: 2) {
                                Text(displayedCharacterTitle())
                                    .font(.system(size: 17, weight: .bold))
                                    .foregroundStyle(.white)
                                    .shadow(color: .black.opacity(0.28), radius: 6, x: 0, y: 0)
                                    .shadow(color: .black.opacity(0.18), radius: 12, x: 0, y: 0)
                                if !currentRoomName.isEmpty {
                                    Text(currentRoomName)
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.95))
                                        .shadow(color: .black.opacity(0.24), radius: 4, x: 0, y: 0)
                                        .shadow(color: .black.opacity(0.16), radius: 10, x: 0, y: 0)
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
                            ChatInputBar(
                                text: $chatText,
                                isConnected: convVM.isConnected,
                                isBooting: bootingAgent,
                                onSend: { msg in
                                    triggerHaptic(.medium)
                                    sendMessage(msg)
                                },
                                onToggleMic: {
                                    triggerHaptic(.medium)
                                    if convVM.isConnected {
                                        bootingAgent = false
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.9)) {
                                            chatMessages.append(ChatMessage(kind: .text("Conversation stopped")))
                                            while chatMessages.count > 5 { chatMessages.removeFirst() }
                                        }
                                        Task { await convVM.endConversation() }
                                    } else {
                                        bootingAgent = true
                                        Task { await convVM.startConversationIfNeeded(agentId: currentAgentId.isEmpty ? elevenLabsAgentId : currentAgentId) }
                                    }
                                },
                                onFocusChanged: { focused in
                                    chatFieldFocused = focused
                                },
                                placeholder: chatPlaceholder()
                            )
                        }
                        }
                    }
                    .onChange(of: convVM.isConnected) { _, newVal in
                        if newVal { bootingAgent = false }
                        feedbackVM.handleConnectionChange(newVal)
                    }
                    .sheet(isPresented: $showCostumeSheet) {
                        CostumeSheetView(characterId: currentCharacterId) { costume in
                            if let directURL = costume.model_url, !directURL.isEmpty {
                                let escaped = directURL
                                    .replacingOccurrences(of: "\\", with: "\\\\")
                                    .replacingOccurrences(of: "\"", with: "\\\"")
                                let js = "window.loadModelByURL(\"\(escaped)\", \"\(costume.costume_name)\");"
                                loadModelJSWithSync(js)
                                persistModel(url: directURL, name: costume.costume_name)
                                upsertUserCharacterPreference(costumeName: costume.costume_name, costumeURL: directURL, roomName: nil, roomImage: nil, costumeId: costume.id)
                            } else {
                                let modelName = costume.url + ".vrm"
                                let escaped = modelName
                                    .replacingOccurrences(of: "\\", with: "\\\\")
                                    .replacingOccurrences(of: "\"", with: "\\\"")
                                let js = "window.loadModelByName(\"\(escaped)\");"
                                loadModelJSWithSync(js)
                                persistModel(url: nil, name: modelName)
                                upsertUserCharacterPreference(costumeName: modelName, costumeURL: nil, roomName: nil, roomImage: nil, costumeId: costume.id)
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
                            requestBackgroundChange(image: room.image, name: room.name)
                            setUserCurrentRoom(roomId: room.id)
                            currentRoomId = room.id
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
                        SettingsView(authManager: authManager)
                                .preferredColorScheme(.dark)
                    }
                    // Full-screen chat history overlay content
                    if showChatHistoryFullScreen {
                        historyFullScreenView
                    }
                    if chatFieldFocused {
                        Color.clear
                            .contentShape(Rectangle())
                            .onTapGesture {
                                chatFieldFocused = false
                                dismissKeyboard()
                            }
                    }
                }
                .sheet(isPresented: $showNamePrompt) {
                    VStack(spacing: 16) {
                        Text("What should we call you?")
                            .font(.headline)
                            .foregroundStyle(.white)
                        TextField("Your name", text: $pendingDisplayName)
                            .textInputAutocapitalization(.words)
                            .submitLabel(.done)
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(10)
                            .foregroundStyle(.white)
                        Button("Save") {
                            let name = pendingDisplayName.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !name.isEmpty else { return }
                            Task {
                                await authManager.updateDisplayName(name)
                                showNamePrompt = false
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.white.opacity(0.12))
                        .cornerRadius(10)
                        .foregroundStyle(.white)
                    }
                    .padding(20)
                    .background(Color.black.ignoresSafeArea())
                }
                // Satisfaction prompt
                .alert("Are you happy with the app?", isPresented: $feedbackVM.showSatisfactionPrompt) {
                    Button("Yes") { feedbackVM.requestSystemReviewAndMarkRated() }
                    Button("No") { feedbackVM.feedbackText = ""; feedbackVM.showFeedbackSheet = true }
                    Button("Later", role: .cancel) { }
                } message: {
                    Text("We'd love your quick feedback.")
                }
                .sheet(isPresented: $feedbackVM.showFeedbackSheet) {
                    FeedbackSheet(vm: feedbackVM, characterId: currentCharacterId)
                        .preferredColorScheme(.dark)
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                    if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                        let height = max(0, UIScreen.main.bounds.height - frame.origin.y)
                        keyboardHeight = height
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                    keyboardHeight = 0
                }
                // Handle notification clicks to open character chat
                .onReceive(NotificationCenter.default.publisher(for: .openCharacterChat)) { notification in
                    guard let userInfo = notification.userInfo,
                          let data = userInfo["data"] as? CharacterNotificationData,
                          data.openChat else { return }
                    handleNotificationCharacterOpen(characterId: data.characterId)
                }
            }
        }
    }
    
    private func sendMessage(_ message: String) {
        // Add message to chat list
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.1)) {
            chatMessages.append(ChatMessage(kind: .text(message)))
        }
        // Mirror into full chat list if visible
        if showChatHistoryFullScreen {
            let now = ISO8601DateFormatter().string(from: Date())
            historyRows.append(HistoryRow(message: message, is_agent: false, created_at: now))
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
        let userIdString: String? = AuthManager.shared.user?.id.uuidString
        let clientId = AuthManager.shared.isGuest ? (UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId()) : nil
        guard let url = URL(string: SUPABASE_URL + "/rest/v1/conversation") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        setSupabaseAuthHeaders(&req)
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
            URLQueryItem(name: "select", value: "id,name,description,thumbnail_url,avatar,base_model_url,agent_elevenlabs_id"),
            URLQueryItem(name: "is_public", value: "is.true")
        ]
        guard let request = makeSupabaseRequest(path: "/rest/v1/characters", queryItems: query) else { return }
        URLSession.shared.dataTask(with: request) { data, _, _ in
            guard let data = data else { return }
            if let items = try? JSONDecoder().decode([CharacterItem].self, from: data) {
                DispatchQueue.main.async {
                    self.allCharacters = items
                    if let idx = items.firstIndex(where: { $0.id == self.currentCharacterId }) {
                        // Sync selection and state to the persisted/current character
                        self.currentCharacterIndex = idx
                        self.currentCharacterName = items[idx].name
                        self.currentAgentId = items[idx].agent_elevenlabs_id ?? ""
                        // Ensure model/room reflect saved prefs for this character
                        self.loadUserCharacterPreference(fallbackModelName: items[idx].name, fallbackModelURL: items[idx].base_model_url)
                        // Warm up costume thumbnails for the selected character
                        self.prefetchCostumeThumbnails(for: items[idx].id)
                    } else if let first = items.first {
                        // Fallback to first character and fully apply it for consistency
                        self.currentCharacterIndex = 0
                        self.applyCharacter(first)
                    }
                    self.lastCharacterIndex = self.currentCharacterIndex
                    // Preload avatar images for smooth switching
                    prefetchAvatarImages(for: items)
                    // Handle pending notification character open
                    if let pendingId = self.pendingCharacterIdFromNotification,
                       let character = items.first(where: { $0.id == pendingId }) {
                        self.pendingCharacterIdFromNotification = nil
                        self.handleNotificationCharacterOpen(characterId: pendingId)
                    }
                }
            }
        }.resume()
    }

    // MARK: - Avatar Quick Switcher
    private func selectCharacter(at index: Int) {
        guard allCharacters.indices.contains(index) else { return }
        let oldIndex = currentCharacterIndex
        lastCharacterIndex = oldIndex
        lastSelectionDirection = selectionDirection(from: oldIndex, to: index)
        let item = allCharacters[index]
        withAnimation(.spring(response: 0.5, dampingFraction: 0.95, blendDuration: 0.2)) {
            applyCharacter(item)
        }
    }

    private func selectionDirection(from oldIndex: Int, to newIndex: Int) -> Int {
        let count = max(1, allCharacters.count)
        if count == 1 { return 0 }
        let forward = (newIndex - oldIndex + count) % count
        let backward = (oldIndex - newIndex + count) % count
        return forward <= backward ? 1 : -1
    }

    private func handleAvatarTap(_ index: Int) {
        guard allCharacters.indices.contains(index) else { return }
        triggerHaptic(.light)
        let targetId = allCharacters[index].id
        if loadedAvatarIds.contains(targetId) {
            selectCharacter(at: index)
        } else {
            pendingAvatarSelection = index
            // Fallback: proceed after a short delay if cache still not ready
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
                if self.pendingAvatarSelection == index {
                    self.selectCharacter(at: index)
                    self.pendingAvatarSelection = nil
                }
            }
        }
    }

    @ViewBuilder
    private func avatarQuickSwitcher() -> some View {
        if showChatHistoryFullScreen || allCharacters.isEmpty {
            EmptyView()
        } else {
            let inputActive = chatFieldFocused || keyboardHeight > 0
            let count = allCharacters.count
            let current = currentCharacterIndex
            let prev = (current - 1 + count) % count
            let next = (current + 1) % count
            let displayItems: [CharacterItem] = [allCharacters[prev], allCharacters[current], allCharacters[next]]
            VStack(spacing: 14) {
                ForEach(displayItems, id: \.id) { item in
                    let isSelected = item.id == allCharacters[current].id
                    let opacity = isSelected ? 1.0 : 0.5
                    let urlString = item.avatar ?? item.thumbnail_url ?? ""
                    if let url = URL(string: urlString), !urlString.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image.resizable().scaledToFill()
                                    .contentTransition(.opacity)
                                    .onAppear {
                                        loadedAvatarIds.insert(item.id)
                                        if let pending = pendingAvatarSelection, allCharacters.indices.contains(pending), allCharacters[pending].id == item.id {
                                            selectCharacter(at: pending)
                                            pendingAvatarSelection = nil
                                        }
                                    }
                            default:
                                Color.white.opacity(0.2)
                            }
                        }
                        .frame(width: 56, height: 56)
                        .clipShape(Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.85), lineWidth: 2)
                        )
                        .opacity(opacity)
                        .scaleEffect(isSelected ? 1.0 : 0.92)
                        .onTapGesture {
                            if let index = allCharacters.firstIndex(where: { $0.id == item.id }) {
                                handleAvatarTap(index)
                            }
                        }
                        .transition(.asymmetric(
                            insertion: .move(edge: lastSelectionDirection >= 0 ? .bottom : .top).combined(with: .opacity),
                            removal: .move(edge: lastSelectionDirection >= 0 ? .top : .bottom).combined(with: .opacity)
                        ))
                    } else {
                        Circle()
                            .fill(Color.white.opacity(0.15))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Circle()
                                    .stroke(Color.white.opacity(0.85), lineWidth: 2)
                            )
                            .opacity(opacity)
                            .scaleEffect(isSelected ? 1.0 : 0.92)
                            .onTapGesture {
                                if let index = allCharacters.firstIndex(where: { $0.id == item.id }) {
                                    handleAvatarTap(index)
                                }
                            }
                            .transition(.asymmetric(
                                insertion: .move(edge: lastSelectionDirection >= 0 ? .bottom : .top).combined(with: .opacity),
                                removal: .move(edge: lastSelectionDirection >= 0 ? .top : .bottom).combined(with: .opacity)
                            ))
                    }
                }
            }
            .padding(.trailing, 14)
            .padding(.bottom, 96)
            .offset(x: inputActive ? 120 : 0)
            .opacity(inputActive ? 0 : (isModelLoading ? 0.5 : 1.0))
            .allowsHitTesting(!isModelLoading && !inputActive)
            .animation(.spring(response: 0.55, dampingFraction: 0.92, blendDuration: 0.25), value: currentCharacterIndex)
            .animation(.easeInOut(duration: 0.22), value: inputActive)
            .animation(.easeInOut(duration: 0.22), value: keyboardHeight)
        }
    }

    // MARK: - Avatar Prefetching
    private func prefetchAvatarImages(for characters: [CharacterItem]) {
        let urls: [URL] = characters.compactMap { item in
            if let s = item.avatar ?? item.thumbnail_url, let u = URL(string: s) { return u }
            return nil
        }
        let session = URLSession(configuration: .default)
        for url in urls {
            var req = URLRequest(url: url)
            req.cachePolicy = .returnCacheDataElseLoad
            let task = session.dataTask(with: req) { data, response, _ in
                guard let data = data, let response = response else { return }
                let cached = CachedURLResponse(response: response, data: data)
                URLCache.shared.storeCachedResponse(cached, for: req)
            }
            task.resume()
        }
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
        // Persist selected character id only; defer model/background until prefs load
        persistCharacter(id: item.id)

        // Load latest conversation messages for this character
        loadLatestConversation()

        // Load and apply saved outfit and room first; fallback to character base model if none
        loadUserCharacterPreference(fallbackModelName: item.name, fallbackModelURL: item.base_model_url)
    }

    private func loadUserCharacterPreference(fallbackModelName: String?, fallbackModelURL: String?) {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "current_costume_id,current_room_id"),
            URLQueryItem(name: "character_id", value: "eq.\(currentCharacterId)")
        ]
        if let uid = AuthManager.shared.user?.id.uuidString {
            query.append(URLQueryItem(name: "user_id", value: "eq.\(uid)"))
        } else if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId() {
            query.append(URLQueryItem(name: "client_id", value: "eq.\(cid)"))
        }
        guard var req = makeSupabaseRequest(path: "/rest/v1/user_character", queryItems: query) else { return }
        if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            let arr = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] }) ?? []
            let row = arr.first
            
            let costumeId = row?["current_costume_id"] as? String
            let roomId = row?["current_room_id"] as? String
            DispatchQueue.main.async {
                if let rid = roomId, !rid.isEmpty {
                    applyRoomById(rid)
                }
                if let cid = costumeId, !cid.isEmpty {
                    applyCostumeById(cid)
                } else if let fbURL = fallbackModelURL, !fbURL.isEmpty, let fbName = fallbackModelName {
                    let escapedURL = fbURL.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let escapedName = fbName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let js = "window.loadModelByURL(\"\(escapedURL)\", \"\(escapedName)\");"
                    loadModelJSWithSync(js)
                    persistModel(url: fbURL, name: fbName)
                }
                // Do not upsert here; only upsert on explicit user actions (room/costume changes)
            }
        }.resume()
    }

    private func applyRoomById(_ roomId: String) {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "name,image"),
            URLQueryItem(name: "id", value: "eq.\(roomId)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let req = makeSupabaseRequest(path: "/rest/v1/rooms", queryItems: query) else { return }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let row = arr.first,
                  let image = row["image"] as? String else { return }
            let name = row["name"] as? String
            DispatchQueue.main.async {
                requestBackgroundChange(image: image, name: name)
            }
        }.resume()
    }

    private func applyCostumeById(_ costumeId: String) {
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "costume_name,model_url,url"),
            URLQueryItem(name: "id", value: "eq.\(costumeId)"),
            URLQueryItem(name: "limit", value: "1")
        ]
        guard let req = makeSupabaseRequest(path: "/rest/v1/character_costumes", queryItems: query) else { return }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            guard let data = data,
                  let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]],
                  let row = arr.first else { return }
            let name = row["costume_name"] as? String
            let modelURL = row["model_url"] as? String
            let urlName = row["url"] as? String
            DispatchQueue.main.async {
                if let directURL = modelURL, let cname = name, !directURL.isEmpty {
                    let escapedURL = directURL.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let escapedName = cname.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let js = "window.loadModelByURL(\"\(escapedURL)\", \"\(escapedName)\");"
                    loadModelJSWithSync(js)
                    persistModel(url: directURL, name: cname)
                } else if let urlName = urlName {
                    let modelName = urlName + ".vrm"
                    let escaped = modelName.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
                    let js = "window.loadModelByName(\"\(escaped)\");"
                    loadModelJSWithSync(js)
                    persistModel(url: nil, name: modelName)
                }
            }
        }.resume()
    }

    func upsertUserCharacterPreference(costumeName: String?, costumeURL: String?, roomName: String?, roomImage: String?, costumeId: String? = nil, roomId: String? = nil) {
        guard !currentCharacterId.isEmpty else { return }
        let clientId = AuthManager.shared.isGuest ? (UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId()) : nil
        guard let url = URL(string: SUPABASE_URL + "/rest/v1/user_character?on_conflict=owner_key,character_id") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        setSupabaseAuthHeaders(&req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal, resolution=merge-duplicates", forHTTPHeaderField: "Prefer")
        if let cid = clientId { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        var body: [String: Any] = [
            "character_id": currentCharacterId
        ]
        if let uid = AuthManager.shared.user?.id.uuidString { body["user_id"] = uid }
        if let cid = clientId { body["client_id"] = cid }
        // legacy fields removed; we now store only ids
        if let costumeId = costumeId { body["current_costume_id"] = costumeId }
        if let roomId = roomId { body["current_room_id"] = roomId }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
    }

    // Update only current_room_id deterministically. If no row exists, create it.
    func setUserCurrentRoom(roomId: String) {
        guard !currentCharacterId.isEmpty else { return }
        var query: [URLQueryItem] = [
            URLQueryItem(name: "character_id", value: "eq.\(currentCharacterId)")
        ]
        if let uid = AuthManager.shared.user?.id.uuidString {
            query.append(URLQueryItem(name: "user_id", value: "eq.\(uid)"))
        } else if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId() {
            query.append(URLQueryItem(name: "client_id", value: "eq.\(cid)"))
        }
        guard var patchReq = makeSupabaseRequest(path: "/rest/v1/user_character", queryItems: query) else { return }
        patchReq.httpMethod = "PATCH"
        patchReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
        patchReq.setValue("return=representation", forHTTPHeaderField: "Prefer")
        if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { patchReq.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        let body: [String: Any] = [ "current_room_id": roomId ]
        patchReq.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: patchReq) { data, response, _ in
            let rows = (data.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [[String: Any]] }) ?? []
            if rows.isEmpty {
                // Create row if missing
                var postReq = URLRequest(url: URL(string: SUPABASE_URL + "/rest/v1/user_character")!)
                postReq.httpMethod = "POST"
                setSupabaseAuthHeaders(&postReq)
                postReq.setValue("application/json", forHTTPHeaderField: "Content-Type")
                postReq.setValue("return=minimal", forHTTPHeaderField: "Prefer")
                if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { postReq.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
                var create: [String: Any] = [
                    "character_id": currentCharacterId,
                    "current_room_id": roomId
                ]
                if let uid = AuthManager.shared.user?.id.uuidString { create["user_id"] = uid }
                if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { create["client_id"] = cid }
                postReq.httpBody = try? JSONSerialization.data(withJSONObject: create)
                URLSession.shared.dataTask(with: postReq).resume()
            }
        }.resume()
    }

    // MARK: - Model/Background Synchronization Helpers
    private func requestBackgroundChange(image: String, name: String?) {
        pendingBackgroundImage = image
        pendingRoomNameQueued = name
        // Ensure background music never auto-enables on background change
        muteBgmIfNeeded()
        if !isModelLoading { applyPendingBackgroundIfAny() }
    }

    private func applyPendingBackgroundIfAny() {
        guard let image = pendingBackgroundImage else { return }
        let escaped = image.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let script = "window.setBackgroundImage&&window.setBackgroundImage(\"\(escaped)\");"
        webViewRef?.evaluateJavaScript(script)
        // Re-mute BGM after DOM style change in case page-side code toggles it
        muteBgmIfNeeded()
        if let rn = pendingRoomNameQueued { currentRoomName = rn }
        persistRoom(name: pendingRoomNameQueued ?? "", url: image)
        pendingBackgroundImage = nil
        pendingRoomNameQueued = nil
    }

    private func ensureBackgroundApplied() {
        let bg = UserDefaults.standard.string(forKey: PersistKeys.backgroundURL) ?? ""
        guard !bg.isEmpty else { return }
        let escaped = bg.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let js = """
        (function(){try{
          var cs = getComputedStyle(document.body).backgroundImage||'';
          if(!cs || cs==='none'){
            document.body.style.backgroundColor = '#000';
            var img=new Image();
            img.onload=function(){document.body.style.backgroundImage="url('"+"\(escaped)"+"')";document.body.style.backgroundColor='';};
            img.onerror=function(){};
            img.src="\(escaped)";
          }
        }catch(e){}})();
        """
        webViewRef?.evaluateJavaScript(js)
    }

    private func loadModelByURLWithSync(url: String, name: String) {
        let escapedURL = url.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let escapedName = name.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        let js = "window.loadModelByURL(\"\(escapedURL)\", \"\(escapedName)\");"
        loadModelJSWithSync(js)
    }

    private func loadModelJSWithSync(_ js: String) {
        isModelLoading = true
        // Try to await a possible Promise; otherwise still resolve and continue
        let wrapped = "(async()=>{try{const r=(function(){\n\(js)\n})(); if(r&&typeof r.then==='function'){await r;} return 'READY';}catch(e){return 'READY';}})();"
        webViewRef?.evaluateJavaScript(wrapped, completionHandler: { _, _ in
            // Keep BGM muted unless user toggles explicitly
            muteBgmIfNeeded()
            self.isModelLoading = false
            self.applyPendingBackgroundIfAny()
        })
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
        if let uid = AuthManager.shared.user?.id.uuidString {
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

    // MARK: - Rooms ordering and swipe sequencing
    private func fetchRoomsOrder() {
        let urlString = "https://n8n8n.top/webhook/rooms"
        guard let url = URL(string: urlString) else { return }
        URLSession.shared.dataTask(with: url) { data, _, _ in
            guard let data = data, var rooms = try? JSONDecoder().decode([RoomItem].self, from: data) else { return }
            // Sort ascending by created_at to match RoomSheet
            rooms.sort { ($0.created_at) < ($1.created_at) }
            DispatchQueue.main.async { self.allRooms = rooms }
        }.resume()
    }

    private func advanceRoom(by delta: Int) {
        guard !allRooms.isEmpty else {
            // Fallback to web page behavior if we don't have ordering yet
            if delta > 0 { webViewRef?.evaluateJavaScript("window.nextBackground&&window.nextBackground();") }
            else { webViewRef?.evaluateJavaScript("window.prevBackground&&window.prevBackground();") }
            // Keep legacy capture as last resort
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) { captureAndSaveCurrentBackgroundAndRoom() }
            return
        }
        // Determine current index from id or persisted background image
        let currentIndex: Int = {
            if let rid = currentRoomId, let idx = allRooms.firstIndex(where: { $0.id == rid }) { return idx }
            let bg = UserDefaults.standard.string(forKey: PersistKeys.backgroundURL) ?? ""
            if !bg.isEmpty, let idx = allRooms.firstIndex(where: { $0.image == bg }) { return idx }
            return 0
        }()
        let count = allRooms.count
        var newIndex = (currentIndex + delta) % count
        if newIndex < 0 { newIndex += count }
        let room = allRooms[newIndex]
        currentRoomId = room.id
        currentRoomName = room.name
        requestBackgroundChange(image: room.image, name: room.name)
        setUserCurrentRoom(roomId: room.id)
    }

    // Feedback submission moved to FeedbackViewModel

    // MARK: - Full-screen Chat History Helpers
    private struct HistoryRow: Decodable, Identifiable {
        let message: String
        let is_agent: Bool
        let created_at: String
        var id: String { created_at + "|" + String(message.hashValue) }
        var date: Date { ISO8601DateFormatter().date(from: created_at) ?? Date() }
    }

    private func fetchConversationHistory(reset: Bool) {
        guard !currentCharacterId.isEmpty else { return }
        if historyIsFetching { return }
        if reset { historyOldestCursor = nil; historyRows.removeAll(); historyReachedEnd = false }
        historyIsFetching = true
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "message,is_agent,created_at"),
            URLQueryItem(name: "character_id", value: "eq.\(currentCharacterId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: String(historyBatchSize))
        ]
        if let cursor = historyOldestCursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "created_at", value: "lt.\(cursor)"))
        }
        if let uid = AuthManager.shared.user?.id.uuidString {
            query.append(URLQueryItem(name: "user_id", value: "eq.\(uid)"))
        } else if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId() {
            query.append(URLQueryItem(name: "client_id", value: "eq.\(cid)"))
        }
        guard var req = makeSupabaseRequest(path: "/rest/v1/conversation", queryItems: query) else { historyIsFetching = false; return }
        if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                historyIsFetching = false
                guard let data = data, let fetched = try? JSONDecoder().decode([HistoryRow].self, from: data) else { return }
                if fetched.isEmpty { historyReachedEnd = true; return }
                let ordered = fetched.reversed()
                if reset {
                    historyRows = Array(ordered)
                } else {
                    historyRows.insert(contentsOf: ordered, at: 0)
                }
                historyOldestCursor = historyRows.first?.created_at
            }
        }.resume()
    }

    private func toggleHistoryTimestamp(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if historyShowTimeFor.contains(id) { historyShowTimeFor.remove(id) } else { historyShowTimeFor.insert(id) }
        }
    }

    @ViewBuilder
    private var historyFullScreenView: some View {
        VStack(spacing: 0) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        Color.clear.frame(height: 1).id("top").onAppear { fetchConversationHistory(reset: false) }
                        if historyReachedEnd {
                            HStack { Spacer(); Text("End of the conversation")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(.white.opacity(0.8))
                                Spacer() }
                                .padding(.vertical, 8)
                        }
                        ForEach(Array(historyRows.enumerated()), id: \.element.id) { pair in
                            let r = pair.element
                            HStack(alignment: .bottom, spacing: 0) {
                                ChatMessageBubble(
                                    message: ChatMessage(kind: .text(r.message), isAgent: r.is_agent),
                                    playbackProgress: 0,
                                    isPlaying: false,
                                    onPlayPause: {},
                                    lineLimit: nil,
                                    alignAgentTrailing: true
                                )
                                .onTapGesture { toggleHistoryTimestamp(r.id) }
                                .frame(maxWidth: .infinity, alignment: r.is_agent ? .trailing : .leading)
                            }
                            .id(r.id)
                            if historyShowTimeFor.contains(r.id) {
                                Text(historyTimestampString(for: r.date))
                                    .font(.footnote)
                                    .foregroundStyle(.white.opacity(0.8))
                                    .frame(maxWidth: .infinity, alignment: r.is_agent ? .trailing : .leading)
                                    .transition(.opacity.combined(with: .move(edge: .top)))
                            }
                        }
                        if historyIsFetching { HStack { Spacer(); ProgressView().tint(.white); Spacer() } }
                        // Bottom sentinel for reliable scroll-to-bottom
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 12)
                }
                .scrollIndicators(.hidden)
                // Keep list above the bottom input by reserving insets instead of fixed padding
                .safeAreaInset(edge: .bottom) {
                    Color.clear.frame(height: max(72, keyboardHeight + 72))
                }
                .onAppear {
                    if historyRows.isEmpty { fetchConversationHistory(reset: true) }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                .onChange(of: historyRows.count) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
                .onChange(of: keyboardHeight) { _, _ in
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo("bottom", anchor: .bottom) }
                    }
                }
            }
        }
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded { chatFieldFocused = false; dismissKeyboard() })
        .simultaneousGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy), dx > 40 {
                        withAnimation(.easeInOut(duration: 0.25)) { showChatHistoryFullScreen = false }
                    }
                }
        )
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                let height = max(0, UIScreen.main.bounds.height - frame.origin.y)
                keyboardHeight = height
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .ignoresSafeArea(edges: .bottom)
    }

    private func historyTimestampString(for date: Date) -> String {
        let fmt = DateFormatter(); fmt.locale = Locale.current
        fmt.dateStyle = .medium; fmt.timeStyle = .short
        return fmt.string(from: date)
    }

    private func changeCharacter(by delta: Int) {
        guard !allCharacters.isEmpty else { return }
        let count = allCharacters.count
        var newIndex = (currentCharacterIndex + delta) % count
        if newIndex < 0 { newIndex += count }
        let item = allCharacters[newIndex]
        applyCharacter(item)
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
    
    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        #if canImport(UIKit)
        guard hapticsEnabled else { return }
        let impact = UIImpactFeedbackGenerator(style: style)
        impact.impactOccurred()
        #endif
    }

    private func muteBgmIfNeeded() {
        guard !autoPlayMusic else { return }
        webViewRef?.evaluateJavaScript("(function(){try{return window.setBgm&&window.setBgm(false);}catch(e){return false}})();")
    }

    // MARK: - Notification Handling
    private func handleNotificationCharacterOpen(characterId: String) {
        // Find the character in allCharacters or fetch if not loaded
        if let character = allCharacters.first(where: { $0.id == characterId }) {
            // Switch to the character
            applyCharacter(character)
            // Open full chat mode after a brief delay to ensure character is loaded
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.easeInOut(duration: 0.25)) {
                    showChatHistoryFullScreen = true
                    fetchConversationHistory(reset: true)
                }
            }
        } else {
            // Character not in list yet, fetch characters first
            fetchCharactersList()
            // Store pending character ID to open after fetch
            pendingCharacterIdFromNotification = characterId
        }
    }
}

// Minimal legal markdown strings (reuse of Settings content)
private let LegalTextTerms = """
# Terms of Use
_Last updated: October 30, 2025_

Use of this app is subject to our terms. You must be 13+ (or local equivalent) and agree not to misuse the app or infringe others’ rights. We may update features and terms; continued use means you accept the changes. The app is provided “as is.” To the maximum extent allowed by law we disclaim warranties and limit liability. See Settings → Terms of Use for the full text.
"""

private let LegalTextPrivacy = """
# Privacy Policy
_Last updated: October 30, 2025_

We collect minimal data to run the app (account identifiers if you sign in, on‑device preferences, and diagnostics). We don’t sell data. See Settings → Privacy Policy for details on collection, use, sharing, and choices.
"""

private struct LegalSheetView: View {
    let title: String
    let text: String
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 10) {
                    if let attr = try? AttributedString(markdown: text) {
                        Text(attr).foregroundStyle(.white).lineSpacing(6)
                    } else {
                        Text(text).foregroundStyle(.white).lineSpacing(6)
                    }
                }
                .padding(18)
            }
            .background(Color.black.ignoresSafeArea())
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.large])
        .presentationBackground(.black)
        .presentationDragIndicator(.hidden)
    }
}

// moved to UIComponents.swift

// moved to UIComponents.swift

// No custom floating buttons; using default Toolbar items above

#Preview {
    ContentView()
}
