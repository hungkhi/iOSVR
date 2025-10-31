import SwiftUI

// MARK: - Chat Message Model
struct ChatMessage: Identifiable, Equatable {
    enum Kind: Equatable { 
        case text(String)
        case voice(url: URL, duration: Int, samples: [Float])
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
            }
        }
    }
    
    private func textMessageView(text: String) -> some View {
        Text(text)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(.white)
            .lineLimit(nil)
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
            .frame(maxWidth: maxWidth, alignment: .leading)
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
        .frame(maxWidth: maxWidth, alignment: .leading)
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
}

// MARK: - Chat Messages Overlay
struct ChatMessagesOverlay: View {
    let messages: [ChatMessage]
    let showChatList: Bool
    let onSwipeToHide: () -> Void
    var onTap: (() -> Void)? = nil
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
                onPlayPause: { }
            )
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .id(message.id)
        .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
        .opacity(calculateOpacity(index))
        .onTapGesture { onTap?() }
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
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            TextField("", text: $text, prompt: Text("Ask Anything").foregroundStyle(.white))
                .textFieldStyle(.plain)
                .textInputAutocapitalization(.sentences)
                .disableAutocorrection(false)
                .background(Color.clear)
                .frame(maxWidth: .infinity)
                .focused($isFocused)

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

