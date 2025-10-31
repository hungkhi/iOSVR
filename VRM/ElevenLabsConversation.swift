import Foundation
import Combine
import ElevenLabs
import Auth
import WebKit

@MainActor
final class ConversationViewModel: ObservableObject {
    @Published var conversation: Conversation?
    // Keep UI simple and avoid SDK-specific message types for now
    @Published var isConnected = false
    @Published var isMuted = false
    // Latest normalized 0...1 volume for UI pulse
    @Published var agentVolume: Double = 0.0

    private var cancellables = Set<AnyCancellable>()
    // Emit agent text messages
    let agentText = PassthroughSubject<String, Never>()
    // Emit user transcripts recognized by ElevenLabs ASR
    let userText = PassthroughSubject<String, Never>()

    func startConversationIfNeeded(agentId: String) async {
        if conversation != nil { return }
        await startConversation(agentId: agentId)
    }

    func startConversation(agentId: String) async {
        do {
            let config = ConversationConfig()
            conversation = try await ElevenLabs.startConversation(
                agentId: agentId,
                config: config
            )
            setupObservers()
        } catch {
            // Swallow errors to avoid console noise; UI can reflect state via isConnected
        }
    }

    // Forward volume (0..1) to the web view for lipsync
    func pushMouthOpen(_ volume: Double, webView: WKWebView?) {
        let v = max(0.0, min(1.0, volume))
        let js = "(function(){try{window.setMouthOpen&&window.setMouthOpen(\(v));}catch(e){}})();"
        webView?.evaluateJavaScript(js)
        // Also reflect on UI pulse
        agentVolume = v
    }

    func endConversation() async {
        await conversation?.endConversation()
        conversation = nil
        isConnected = false
    }

    func toggleMute() async {
        guard let conversation else { return }
        do { try await conversation.toggleMute() } catch { }
    }

    func sendText(_ text: String) async {
        guard let conversation, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        do {
            try await conversation.sendMessage(text)
        } catch { }
    }

    private func setupObservers() {
        guard let conversation else { return }
        conversation.$state
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                // Assume active once we have a state callback
                self?.isConnected = (self?.conversation != nil)
            }
            .store(in: &cancellables)

        // Forward latest text content by role (best-effort; relies on SDK types)
        conversation.$messages
            .receive(on: DispatchQueue.main)
            .compactMap { $0.last }
            .sink { [weak self] msg in
                // Expect properties: role and content
                // Guard by stringifying role to avoid compile issues across versions
                let roleString = String(describing: msg.role)
                if roleString.lowercased().contains("agent") {
                    self?.agentText.send(msg.content)
                } else if roleString.lowercased().contains("user") {
                    self?.userText.send(msg.content)
                }
            }
            .store(in: &cancellables)

        conversation.$isMuted
            .receive(on: DispatchQueue.main)
            .sink { [weak self] in self?.isMuted = $0 }
            .store(in: &cancellables)
    }
}


