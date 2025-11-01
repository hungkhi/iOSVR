import SwiftUI
import Auth

// MARK: - Rebuilt ChatHistoryView
struct ChatHistoryView: View {
    let characterId: String
    let agentId: String
    @ObservedObject var convVM: ConversationViewModel

    // Data
    @State private var rows: [Row] = []
    @State private var isFetching: Bool = false
    private let batchSize: Int = 15
    @State private var oldestCursor: String? = nil // ISO timestamp string of oldest loaded row

    // UI
    @State private var draft: String = ""
    @State private var backgroundURL: URL? = URL(string: UserDefaults.standard.string(forKey: PersistKeys.backgroundURL) ?? "")
    @State private var bootingAgent: Bool = false

    var body: some View {
        ZStack {
            // Background same as homepage
            if let url = backgroundURL {
                AsyncImage(url: url) { phase in
                    if case .success(let img) = phase { img.resizable().scaledToFill().ignoresSafeArea() }
                    else { Color.black.ignoresSafeArea() }
                }
            } else { Color.black.ignoresSafeArea() }
            LinearGradient(colors: [Color.black.opacity(0.0), Color.black.opacity(0.85)], startPoint: .center, endPoint: .bottom).ignoresSafeArea()

            VStack(spacing: 0) {
                // Messages
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            // Top sentinel to fetch previous pages
                            Color.clear.frame(height: 1)
                                .id("top")
                                .onAppear { loadMoreIfNeeded() }

                            ForEach(Array(rows.enumerated()), id: \.element.id) { pair in
                                let r = pair.element
                                if shouldShowHeader(at: pair.offset) {
                                    dateHeader(for: r.date)
                                }
                                HStack(alignment: .bottom, spacing: 0) {
                                    ChatMessageBubble(
                                        message: parseMessageToChatMessage(r.message, isAgent: r.is_agent),
                                        playbackProgress: 0,
                                        isPlaying: false,
                                        onPlayPause: {},
                                        lineLimit: nil,
                                        alignAgentTrailing: true,
                                        showFullMediaPreview: true
                                    )
                                    .onTapGesture {
                                        if case .media(let url, let thumbnail) = parseMessageToChatMessage(r.message, isAgent: r.is_agent).kind {
                                            // Handle media tap - could open lightbox here if needed
                                        } else {
                                            toggleTime(r.id)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: r.is_agent ? .trailing : .leading)
                                }
                                .id(r.id)
                                if showTimeFor.contains(r.id) {
                                    Text(timestampString(for: r.date))
                                        .font(.footnote)
                                        .foregroundStyle(.white.opacity(0.8))
                                        .frame(maxWidth: .infinity, alignment: r.is_agent ? .trailing : .leading)
                                        .transition(.opacity.combined(with: .move(edge: .top)))
                                }
                            }
                            if isFetching { HStack { Spacer(); ProgressView().tint(.white); Spacer() } }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 12)
                    }
                    .scrollIndicators(.hidden)
                    .onAppear {
                        if rows.isEmpty { fetch(reset: true) }
                        scrollToBottom(proxy)
                    }
                    .onChange(of: rows.count) { _, _ in
                        scrollToBottom(proxy)
                    }
                    .onReceive(convVM.agentText) { text in
                        // Append live agent messages while on this page
                        rows.append(Row(message: text, is_agent: true, created_at: String(Date().timeIntervalSince1970)))
                        scrollToBottom(proxy)
                    }
                    .onReceive(convVM.userText) { text in
                        // Append live user transcripts while on this page
                        rows.append(Row(message: text, is_agent: false, created_at: isoNow()))
                        scrollToBottom(proxy)
                    }
                }

                // Input bar (same as homepage)
                ChatInputBar(
                    text: $draft,
                    isConnected: convVM.isConnected,
                    isBooting: bootingAgent,
                    onSend: { msg in send(msg) },
                    onToggleMic: {
                        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                        impactFeedback.impactOccurred()
                        if convVM.isConnected {
                            bootingAgent = false
                            rows.append(Row(message: "Conversation stopped", is_agent: false, created_at: isoNow()))
                            Task { await convVM.endConversation() }
                        } else {
                            bootingAgent = true
                            Task { await convVM.startConversationIfNeeded(agentId: agentId) }
                        }
                    },
                    placeholder: (bootingAgent ? "Setting up the conversation..." : (convVM.isConnected ? "Talking..." : "Ask Anything"))
                )
                .background(Color.black.opacity(0.25).ignoresSafeArea(edges: .bottom))
            }
        }
        .navigationTitle("Chat History")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: convVM.isConnected) { _, newVal in if newVal { bootingAgent = false } }
    }

    // MARK: - Networking
    private func fetch(reset: Bool) {
        guard !characterId.isEmpty else { return }
        if isFetching { return }
        if reset { oldestCursor = nil; rows.removeAll() }
        isFetching = true
        var query: [URLQueryItem] = [
            URLQueryItem(name: "select", value: "message,is_agent,created_at"),
            URLQueryItem(name: "character_id", value: "eq.\(characterId)"),
            URLQueryItem(name: "order", value: "created_at.desc"),
            URLQueryItem(name: "limit", value: String(batchSize))
        ]
        if let cursor = oldestCursor, !cursor.isEmpty {
            query.append(URLQueryItem(name: "created_at", value: "lt.\(cursor)"))
        }
        if let uid = AuthManager.shared.user?.id.uuidString {
            query.append(URLQueryItem(name: "user_id", value: "eq.\(uid)"))
        } else if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId() {
            query.append(URLQueryItem(name: "client_id", value: "eq.\(cid)"))
        }
        guard var req = makeSupabaseRequest(path: "/rest/v1/conversation", queryItems: query) else { isFetching = false; return }
        if AuthManager.shared.isGuest, let cid = UserDefaults.standard.string(forKey: PersistKeys.clientId) { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        URLSession.shared.dataTask(with: req) { data, _, _ in
            DispatchQueue.main.async {
                isFetching = false
                guard let data = data, let fetched = try? JSONDecoder().decode([Row].self, from: data) else { return }
                if fetched.isEmpty { return }
                // fetched is newest->oldest; display oldest->newest
                let ordered = fetched.reversed()
                if reset {
                    rows = Array(ordered)
                } else {
                    rows.insert(contentsOf: ordered, at: 0)
                }
                oldestCursor = rows.first?.created_at
            }
        }.resume()
    }

    private func loadMoreIfNeeded() { fetch(reset: false) }

    // MARK: - Send
    private func send(_ text: String) {
        Task { await convVM.sendText(text) }
        rows.append(Row(message: text, is_agent: false, created_at: isoNow()))
    }
    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            if let last = rows.last { withAnimation(.easeOut(duration: 0.2)) { proxy.scrollTo(last.id, anchor: .bottom) } }
        }
    }

    // MARK: - Model
    struct Row: Decodable, Identifiable {
        let message: String
        let is_agent: Bool
        let created_at: String
        var id: String { created_at + "|" + String(message.hashValue) }
        var date: Date { ChatHistoryView.isoParser.date(from: created_at) ?? Date() }
    }
    // Timestamp toggling state
    @State private var showTimeFor: Set<String> = []
    private func toggleTime(_ id: String) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if showTimeFor.contains(id) { showTimeFor.remove(id) } else { showTimeFor.insert(id) }
        }
    }
    private func shouldShowHeader(at index: Int) -> Bool {
        guard rows.indices.contains(index) else { return false }
        if index == 0 { return true }
        let d0 = calendar.startOfDay(for: rows[index-1].date)
        let d1 = calendar.startOfDay(for: rows[index].date)
        return d0 != d1
    }
    private func dateHeader(for date: Date) -> some View {
        Text(dayLabel(for: date))
            .font(.footnote.weight(.semibold))
            .foregroundStyle(.white.opacity(0.9))
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Color.white.opacity(0.12))
            .clipShape(Capsule())
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
    private func dayLabel(for date: Date) -> String {
        if calendar.isDateInToday(date) { return "Today" }
        if calendar.isDateInYesterday(date) { return "Yesterday" }
        let sameYear = calendar.component(.year, from: date) == calendar.component(.year, from: Date())
        let fmt = DateFormatter(); fmt.locale = Locale.current
        fmt.dateFormat = sameYear ? "M/d" : "M/d/yyyy"
        return fmt.string(from: date)
    }
    private func timestampString(for date: Date) -> String {
        let fmt = DateFormatter(); fmt.locale = Locale.current
        fmt.dateStyle = .medium; fmt.timeStyle = .short
        return fmt.string(from: date)
    }
    private var calendar: Calendar { var c = Calendar.current; c.locale = Locale.current; return c }
    private static let isoParser: ISO8601DateFormatter = ISO8601DateFormatter()
    private func isoNow() -> String { ISO8601DateFormatter().string(from: Date()) }
    
    // Helper to parse message string to ChatMessage
    private func parseMessageToChatMessage(_ message: String, isAgent: Bool) -> ChatMessage {
        if message.hasPrefix("MEDIA:") {
            // Simply extract the URL after "MEDIA:" prefix
            let url = String(message.dropFirst(6)) // Drop "MEDIA:"
            return ChatMessage(kind: .media(url: url, thumbnail: nil), isAgent: isAgent)
        } else {
            return ChatMessage(kind: .text(message), isAgent: isAgent)
        }
    }
}


