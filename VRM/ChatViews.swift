import SwiftUI
import AVKit
import AVFoundation

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    enum Kind: Equatable { 
        case text(String)
        case voice(url: URL, duration: Int, samples: [Float])
        case media(url: String, thumbnail: String?)
    }
    let id: UUID = UUID()
    var kind: Kind
    var isAgent: Bool = false
}

// MARK: - Chat Message Bubble
struct ChatMessageBubble: View {
    let message: ChatMessage
    let playbackProgress: Double
    let isPlaying: Bool
    let onPlayPause: () -> Void
    var lineLimit: Int? = nil
    var alignAgentTrailing: Bool = false
    
    private var backgroundColor: Color {
        // Agent messages: stronger pink; User messages: translucent black
        message.isAgent ? Color.pink.opacity(0.30) : Color.black.opacity(0.55)
    }
    
    private var strokeColor: Color {
        message.isAgent ? Color.pink.opacity(0.40) : Color.white.opacity(0.15)
    }
    
    private var maxWidth: CGFloat {
        UIScreen.main.bounds.width * (2.0/3.0)
    }
    
    var body: some View {
        Group {
            switch message.kind {
            case .text(let text):
                textMessageView(text: text)
            case .voice(let url, let duration, let samples):
                voiceMessageView(url: url, duration: duration, samples: samples)
            case .media(let url, let thumbnail):
                mediaMessageView(url: url, thumbnail: thumbnail)
            }
        }
    }
    
    private func textMessageView(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(lineLimit)
            .truncationMode(.tail)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .multilineTextAlignment(.leading)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .stroke(strokeColor, lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
            .frame(maxWidth: maxWidth, alignment: (alignAgentTrailing && message.isAgent) ? .trailing : .leading)
    }
    
    private func voiceMessageView(url: URL, duration: Int, samples: [Float]) -> some View {
        HStack(spacing: 10) {
            Button(action: onPlayPause) {
                Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.black)
                    .frame(width: 28, height: 28)
                    .background(Color.white.opacity(0.6))
                    .clipShape(Circle())
            }
            WaveformView(samples: samples)
                .frame(width: 160, height: 22)
            Text("\(duration)s")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: maxWidth, alignment: (alignAgentTrailing && message.isAgent) ? .trailing : .leading)
        .background(voiceMessageBackground)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
    }
    
    private var voiceMessageBackground: some View {
        GeometryReader { geo in
            let p = playbackProgress
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.55))
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Color.white.opacity(0.85))
                    .frame(width: max(0, min(1, p)) * geo.size.width)
            }
        }
    }
    
    private func mediaMessageView(url: String, thumbnail: String?) -> some View {
        let isVideo = url.lowercased().hasSuffix(".mp4") || url.lowercased().hasSuffix(".mov") || url.lowercased().contains("video")
        let bubbleWidth = min(maxWidth, 200)
        let mediaURL = URL(string: url)
        
        return Group {
            if isVideo {
                // For videos, show placeholder with play icon that generates thumbnail
                ChatMediaPlaceholderView(
                    isVideo: true,
                    videoURL: url,
                    bubbleWidth: bubbleWidth,
                    backgroundColor: backgroundColor,
                    strokeColor: strokeColor
                )
            } else if let imgURL = mediaURL {
                // For images, display directly
                ZStack {
                    AsyncImage(url: imgURL) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill()
                                .clipped()
                        case .empty:
                            backgroundColor
                                .overlay(
                                    ProgressView()
                                        .tint(.white.opacity(0.6))
                                )
                        case .failure(_):
                            backgroundColor
                                .overlay(
                                    Image(systemName: "photo")
                                        .font(.system(size: 24))
                                        .foregroundStyle(.white.opacity(0.5))
                                )
                        @unknown default:
                            backgroundColor
                        }
                    }
                }
                .frame(width: bubbleWidth, height: bubbleWidth)
                .background(backgroundColor)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(strokeColor, lineWidth: 1)
                )
                .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
                .onAppear {
                    // Debug: Log the image URL being loaded
                    debugPrint("ChatViews: Loading image from URL: \(url)")
                }
            } else {
                // Invalid URL
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(backgroundColor)
                    .frame(width: bubbleWidth, height: bubbleWidth)
                    .overlay(
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 24))
                            .foregroundStyle(.white.opacity(0.5))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(strokeColor, lineWidth: 1)
                    )
            }
        }
        .frame(maxWidth: maxWidth, alignment: (alignAgentTrailing && message.isAgent) ? .trailing : .leading)
    }
}

// MARK: - Chat Media Placeholder
private struct ChatMediaPlaceholderView: View {
    let isVideo: Bool
    let videoURL: String?
    let bubbleWidth: CGFloat
    let backgroundColor: Color
    let strokeColor: Color
    @State private var thumbnailImage: UIImage? = nil
    @State private var isLoadingThumbnail: Bool = false
    
    var body: some View {
        ZStack {
            if let thumbnailImage = thumbnailImage {
                Image(uiImage: thumbnailImage)
                    .resizable()
                    .scaledToFill()
                
                // Show play icon overlay for videos
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 32, weight: .regular))
                    .foregroundStyle(.white.opacity(0.85))
                    .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
            } else {
                backgroundColor
                
                if isLoadingThumbnail {
                    ProgressView()
                        .tint(.white.opacity(0.6))
                } else {
                    // Show play icon for videos
                    if isVideo {
                        Image(systemName: "play.circle.fill")
                            .font(.system(size: 32, weight: .regular))
                            .foregroundStyle(.white.opacity(0.6))
                    } else {
                        Image(systemName: "photo")
                            .font(.system(size: 24, weight: .regular))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }
            }
        }
        .frame(width: bubbleWidth, height: bubbleWidth)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(strokeColor, lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.25), radius: 3, x: 0, y: 1)
        .onAppear {
            // Try to generate thumbnail from video URL
            if isVideo, let videoURLString = videoURL, let url = URL(string: videoURLString) {
                Task {
                    isLoadingThumbnail = true
                    if let thumbnail = await generateVideoThumbnail(from: url) {
                        await MainActor.run {
                            thumbnailImage = thumbnail
                            isLoadingThumbnail = false
                        }
                    } else {
                        await MainActor.run {
                            isLoadingThumbnail = false
                        }
                    }
                }
            }
        }
    }
    
    private func generateVideoThumbnail(from url: URL) async -> UIImage? {
        let asset = AVAsset(url: url)
        let imageGenerator = AVAssetImageGenerator(asset: asset)
        imageGenerator.appliesPreferredTrackTransform = true
        
        do {
            let cgImage = try await imageGenerator.image(at: .zero).image
            return UIImage(cgImage: cgImage)
        } catch {
            return nil
        }
    }
}

// MARK: - Chat Messages Overlay
struct ChatMessagesOverlay: View {
    let messages: [ChatMessage]
    let showChatList: Bool
    let onSwipeToHide: () -> Void
    var onTap: (() -> Void)? = nil
    var onMediaTap: ((String, String?) -> Void)? = nil
    let calculateOpacity: (Int) -> Double
    let bottomInset: CGFloat
    let isInputFocused: Bool
    
    private var scrollOffset: CGFloat {
        showChatList ? 0 : -UIScreen.main.bounds.width
    }
    
    var body: some View {
        GeometryReader { geo in
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                if !messages.isEmpty {
                    chatScrollContent(geometry: geo)
                }
            }
        }
        .padding(.bottom, 0)
        // Remove broad tap capture to avoid interfering with other controls
    }
    
    private func chatScrollContent(geometry: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(messages.enumerated()), id: \.element.id) { pair in
                let index = pair.offset
                let message = pair.element
                messageRow(index: index, message: message)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 4)
        .padding(.bottom, bottomInset)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxHeight: min(geometry.size.height - bottomInset, UIScreen.main.bounds.height * 0.5))
        .animation(.spring(response: 0.35, dampingFraction: 0.9, blendDuration: 0.1), value: messages)
        .offset(x: scrollOffset)
        .opacity(showChatList ? 1 : 0)
        .highPriorityGesture(
            DragGesture(minimumDistance: 20, coordinateSpace: .local)
                .onEnded { value in
                    let dx = value.translation.width
                    let dy = value.translation.height
                    if abs(dx) > abs(dy), dx < -40 {
                        onSwipeToHide()
                    }
                }
        )
    }
    
    private func messageRow(index: Int, message: ChatMessage) -> some View {
        return HStack(alignment: .bottom, spacing: 0) {
            ChatMessageBubble(
                message: message,
                playbackProgress: 0.0,
                isPlaying: false,
                onPlayPause: { },
                lineLimit: (index == messages.count - 1 ? nil : 3)
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(message.id)
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
        .opacity(calculateOpacity(index))
        .onTapGesture {
            if case .media(let url, let thumbnail) = message.kind {
                onMediaTap?(url, thumbnail)
            } else {
                onTap?()
            }
        }
    }
}

// MARK: - Chat Media Lightbox
struct ChatMediaLightbox: View {
    let mediaURL: String
    let thumbnail: String?
    let onClose: () -> Void
    @State private var isMuted: Bool = false
    @State private var dragY: CGFloat = 0
    
    var isVideo: Bool {
        mediaURL.lowercased().hasSuffix(".mp4") || 
        mediaURL.lowercased().hasSuffix(".mov") || 
        mediaURL.lowercased().contains("video")
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea().opacity(max(0.2, 1 - abs(dragY)/400.0))
                
                if isVideo {
                    if let url = URL(string: mediaURL) {
                        MutedLoopingVideoView(urlString: mediaURL, isMuted: isMuted)
                            .ignoresSafeArea()
                            .offset(y: dragY)
                    } else {
                        VStack {
                            ProgressView().tint(.white)
                            Text("Invalid video URL")
                                .foregroundStyle(.white.opacity(0.8))
                                .padding(.top, 8)
                        }
                    }
                } else if let url = URL(string: mediaURL) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFit()
                                .ignoresSafeArea()
                        case .empty:
                            ProgressView().tint(.white)
                        case .failure(_):
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 48))
                                    .foregroundStyle(.white.opacity(0.5))
                                Text("Failed to load image")
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(.top, 8)
                            }
                        @unknown default:
                            ProgressView().tint(.white)
                        }
                    }
                    .offset(y: dragY)
                } else {
                    VStack {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 48))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Invalid media URL")
                            .foregroundStyle(.white.opacity(0.7))
                            .padding(.top, 8)
                    }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if isVideo {
                    ToolbarItem(placement: .topBarLeading) {
                        Button(action: { isMuted.toggle() }) {
                            Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                                .foregroundStyle(.white)
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onClose) {
                        Image(systemName: "xmark")
                            .foregroundStyle(.white)
                    }
                }
            }
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        dragY = value.translation.height
                    }
                    .onEnded { value in
                        let dy = value.translation.height
                        if dy > 120 {
                            onClose()
                            return
                        }
                        withAnimation(.easeOut(duration: 0.2)) {
                            dragY = 0
                        }
                    }
            )
        }
        .onAppear {
            isMuted = false
            // Ensure audio session is set up for video playback
            if isVideo {
                let session = AVAudioSession.sharedInstance()
                do {
                    try session.setCategory(.playback, mode: .moviePlayback, options: [.mixWithOthers])
                    try session.setActive(true, options: [])
                } catch {
                    // Audio session configuration failed, but continue anyway
                }
            }
        }
    }
}

// MARK: - Quick Message Chips
struct QuickMessageChips: View {
    let onSendMessage: (String) -> Void
    
    var body: some View {
        HStack(spacing: 8) {
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onSendMessage("Dance for me")
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
                onSendMessage("Kiss me")
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
                onSendMessage("Clothe off")
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

// MARK: - Reusable Chat Input Bar
struct ChatInputBar: View {
    @Binding var text: String
    var isConnected: Bool
    var isBooting: Bool
    var onSend: (String) -> Void
    var onToggleMic: () -> Void
    var onFocusChanged: (Bool) -> Void = { _ in }
    var placeholder: String = "Ask Anything"
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField("", text: $text, prompt: Text(placeholder).foregroundStyle(.primary))
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .background(Color.clear)
                .frame(maxWidth: .infinity)
                .focused($isFocused)
                .onChange(of: isFocused) { _, newVal in
                    onFocusChanged(newVal)
                }

            if isFocused || !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button(action: {
                    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    onSend(trimmed)
                    text = ""
                }) {
                    Image(systemName: "paperplane.fill")
                }
                .transition(.opacity.combined(with: .scale))
            } else {
                Button(action: { onToggleMic() }) {
                    if isBooting {
                        ProgressView()
                            .progressViewStyle(.circular)
                            .padding(.trailing, -6)
                    } else if isConnected {
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

