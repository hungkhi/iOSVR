import SwiftUI
import AVFoundation
import WebKit
import Photos

// moved to UIComponents.swift

// moved to UIComponents.swift

// ContentView - UPDATED FOR FULLSCREEN
struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var webViewRef: WKWebView? = nil
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
    @State private var currentRoomName: String = ""
    @State private var isBgmOn: Bool = true
    @State private var chatMessages: [String] = []
    @FocusState private var chatFieldFocused: Bool
    // Voice recording state
    @State private var isRecording: Bool = false
    @State private var audioRecorder: AVAudioRecorder? = nil
    @State private var audioMeterLevel: Float = 0.0
    @State private var recordingStartTime: Date? = nil
    @State private var recordedFileURL: URL? = nil
    @State private var meterTimer: Timer? = nil
    // Characters for swipe navigation
    @State private var allCharacters: [CharacterItem] = []
    @State private var currentCharacterIndex: Int = 0
    // Parallax controller
    @State private var parallaxController: ParallaxController? = nil
    // Toast for save confirmation
    @State private var showSavedToast: Bool = false
    var body: some View {
        NavigationStack {
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
                    webViewRef?.evaluateJavaScript("(function(){try{return window.setBgm&&window.setBgm(true);}catch(e){return false}})();") { _, _ in }
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
                    // Sync initial BGM state
                    webViewRef?.evaluateJavaScript("(function(){try{return window.isBgmPlaying&&window.isBgmPlaying();}catch(e){return false}})();") { result, _ in
                        if let playing = result as? Bool {
                            DispatchQueue.main.async { self.isBgmOn = playing }
                        }
                    }
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
                    VStack(spacing: 6) {
                        Button(action: { 
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            showRoomSheet = true
                        }) {
                            Image(systemName: "mappin.and.ellipse")
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
                            Image(systemName: "shuffle")
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

                        // Camera capture button
                        Button(action: {
                            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                            impactFeedback.impactOccurred()
                            captureAndSaveSnapshot()
                        }) {
                            Image(systemName: "camera")
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
                .overlay(alignment: .top) {
                    if showSavedToast {
                        Text("Saved to Photos")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(.black)
                            .padding(.horizontal, 18)
                            .padding(.vertical, 10)
                            .background(Color.white)
                            .clipShape(Capsule())
                            .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
                            .padding(.top, 0)
                            .offset(y: -16)
                    }
                }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 8) {
                        // Live chat messages list - vertical, bottom aligned, fades when older
                        if !chatMessages.isEmpty {
                            // Non-scrollable chat list to avoid gesture conflicts; bottom-aligned
                            LazyVStack(alignment: .leading, spacing: 6) {
                                ForEach(chatMessages.indices, id: \.self) { index in
                                    Text(chatMessages[index])
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundStyle(.black)
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 8)
                                        .background(Color.white.opacity(0.55))
                                        .clipShape(Capsule())
                                        .overlay(
                                            Capsule().stroke(Color.white.opacity(0.15), lineWidth: 1)
                                        )
                                        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                                        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                                        .opacity(calculateOpacity(for: index))
                                }
                            }
                            .animation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.1), value: chatMessages)
                            .frame(height: 200, alignment: .bottomLeading)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 2)
                            .clipped()
                            .allowsHitTesting(false)
                        }
                        
                        // Preset quick message chips - only show when input is focused (keyboard visible)
                        if chatFieldFocused {
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
                        .padding(6)
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
                            // When recording, show a simple sound bar in place of input
                            if isRecording {
                                ZStack(alignment: .leading) {
                                    Capsule()
                                        .fill(Color.white.opacity(0.08))
                                        .frame(height: 34)
                                    // bar width follows audioMeterLevel (0..1)
                                    Capsule()
                                        .fill(Color.white.opacity(0.45))
                                        .frame(width: max(14, CGFloat(max(0.0, min(1.0, audioMeterLevel))) * 220), height: 34)
                                        .animation(.linear(duration: 0.1), value: audioMeterLevel)
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                            TextField("Ask Anything", text: $chatText)
                                .textFieldStyle(.plain)
                                .textInputAutocapitalization(.sentences)
                                .disableAutocorrection(false)
                                .background(Color.clear)
                                .frame(maxWidth: .infinity)
                                .focused($chatFieldFocused)
                            }
                            if isRecording {
                                // Recording controls: stop and send
                                Button(action: { stopRecording(send: false) }) {
                                    Image(systemName: "stop.fill")
                                }
                                Button(action: { stopRecording(send: true) }) {
                                    Image(systemName: "paperplane.fill")
                                }
                            } else if chatFieldFocused {
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
                                    startRecording()
                                }) {
                                    Image(systemName: "mic.fill")
                                }
                                .transition(.opacity.combined(with: .scale))
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
        }
    }
    
    private func sendMessage(_ message: String) {
        // Add message to chat list
        withAnimation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.1)) {
        chatMessages.append(message)
        }
        
        // Keep only last 10 messages to prevent memory issues
        if chatMessages.count > 10 {
            withAnimation(.easeInOut(duration: 0.2)) {
            chatMessages.removeFirst()
            }
        }
        
        // Auto-scroll to latest message
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            // Scroll to end would be handled by ScrollViewReader if needed
        }
        
        // TODO: Send message to web view or API
        // webViewRef?.evaluateJavaScript("sendMessage('\(message)');")
    }
    
    // MARK: - Voice Recording
    private func startRecording() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker])
            try session.setActive(true)
            switch session.recordPermission {
            case .granted:
                break
            case .undetermined:
                session.requestRecordPermission { granted in
                    DispatchQueue.main.async {
                        if granted { startRecording() }
                    }
                }
                return
            default:
                return
            }
            let url = FileManager.default.temporaryDirectory.appendingPathComponent("voice_\(UUID().uuidString).m4a")
            let settings: [String: Any] = [
                AVFormatIDKey: Int(kAudioFormatMPEG4AAC),
                AVSampleRateKey: 44100,
                AVNumberOfChannelsKey: 1,
                AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
            ]
            audioRecorder = try AVAudioRecorder(url: url, settings: settings)
            audioRecorder?.isMeteringEnabled = true
            audioRecorder?.prepareToRecord()
            audioRecorder?.record()
            isRecording = true
            recordingStartTime = Date()
            recordedFileURL = url
            chatFieldFocused = false
            meterTimer?.invalidate()
            meterTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { _ in
                audioRecorder?.updateMeters()
                let power = audioRecorder?.averagePower(forChannel: 0) ?? -160
                let normalized = max(0.0, min(1.0, (power + 60) / 60))
                audioMeterLevel = Float(normalized)
            }
        } catch {
            isRecording = false
        }
    }

    private func stopRecording(send: Bool) {
        meterTimer?.invalidate()
        meterTimer = nil
        audioRecorder?.stop()
        let fileURL = recordedFileURL
        audioRecorder = nil
        isRecording = false
        audioMeterLevel = 0
        let duration: Int
        if let start = recordingStartTime {
            duration = max(0, Int(Date().timeIntervalSince(start).rounded()))
        } else {
            duration = 0
        }
        recordingStartTime = nil
        if send {
            withAnimation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.1)) {
                chatMessages.append("🎤 Voice message \(max(1, duration))s")
            }
            // fileURL contains the recorded audio for further processing/upload if needed
            _ = fileURL
        }
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

// moved to UIComponents.swift

private extension ContentView {
    func persistCharacter(id: String) {
        UserDefaults.standard.set(id, forKey: PersistKeys.characterId)
    }
    func persistModel(url: String?, name: String?) {
        if let url = url { UserDefaults.standard.set(url, forKey: PersistKeys.modelURL) } else { UserDefaults.standard.removeObject(forKey: PersistKeys.modelURL) }
        if let name = name { UserDefaults.standard.set(name, forKey: PersistKeys.modelName) }
    }
    func persistRoom(name: String, url: String) {
        UserDefaults.standard.set(url, forKey: PersistKeys.backgroundURL)
        UserDefaults.standard.set(name, forKey: PersistKeys.roomName)
    }
    func captureAndSaveCurrentBackgroundAndRoom() {
        let bgJS = "(function(){try{const s=getComputedStyle(document.body).backgroundImage;const m=s&&s.match(/url\\(\\\"?([^\\\"]+)\\\"?\\)/);return m?m[1]:'';}catch(e){return ''}})();"
        webViewRef?.evaluateJavaScript(bgJS) { result, _ in
            if let url = result as? String, !url.isEmpty {
                UserDefaults.standard.set(url, forKey: PersistKeys.backgroundURL)
            }
        }
        webViewRef?.evaluateJavaScript("(function(){try{return window.getCurrentRoomName&&window.getCurrentRoomName();}catch(e){return ''}})();") { result, _ in
            if let name = result as? String {
                UserDefaults.standard.set(name, forKey: PersistKeys.roomName)
                DispatchQueue.main.async { self.currentRoomName = name }
            }
        }
    }
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

// moved to UIComponents.swift

// moved to UIComponents.swift

// No custom floating buttons; using default Toolbar items above

#Preview {
    ContentView()
}
