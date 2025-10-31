import SwiftUI
import Combine
import StoreKit
import Auth

final class FeedbackViewModel: ObservableObject {
    @Published var showSatisfactionPrompt: Bool = false
    @Published var showFeedbackSheet: Bool = false
    @Published var currentRating: Int = 5
    @Published var feedbackText: String = ""
    @Published var agentSessionHadMessages: Bool = false

    private var hasRatedApp: Bool {
        get { UserDefaults.standard.bool(forKey: PersistKeys.hasRatedApp) }
        set { UserDefaults.standard.set(newValue, forKey: PersistKeys.hasRatedApp) }
    }

    private var lastReviewPromptAt: Date? {
        get {
            if let s = UserDefaults.standard.string(forKey: PersistKeys.lastReviewPromptAt), let t = TimeInterval(s) { return Date(timeIntervalSince1970: t) }
            return nil
        }
        set {
            if let d = newValue { UserDefaults.standard.set(String(d.timeIntervalSince1970), forKey: PersistKeys.lastReviewPromptAt) }
        }
    }

    private func shouldShowPrompt() -> Bool {
        if hasRatedApp { return false }
        guard let last = lastReviewPromptAt else { return true }
        // 7 days cooldown
        return Date().timeIntervalSince(last) > 7 * 24 * 60 * 60
    }

    func markInteractedIfConnected(_ isConnected: Bool) {
        if isConnected { agentSessionHadMessages = true }
    }

    func handleConnectionChange(_ isConnected: Bool) {
        if isConnected {
            agentSessionHadMessages = false
        } else {
            if agentSessionHadMessages && shouldShowPrompt() {
                showSatisfactionPrompt = true
                lastReviewPromptAt = Date()
            }
        }
    }

    func requestSystemReviewAndMarkRated() {
        #if canImport(UIKit)
        if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene {
            SKStoreReviewController.requestReview(in: scene)
        } else {
            SKStoreReviewController.requestReview()
        }
        #else
        SKStoreReviewController.requestReview()
        #endif
        showSatisfactionPrompt = false
    }

    // Note: Apple does not expose user's star value from the system dialog.
    // We only mark locally that the review prompt was shown, to avoid re-prompting.

    func submitFeedback(characterId: String) {
        let trimmed = feedbackText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let userIdString: String? = AuthManager.shared.user?.id.uuidString
        let clientId = AuthManager.shared.isGuest ? (UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId()) : nil
        guard let url = URL(string: SUPABASE_URL + "/rest/v1/app_feedback") else { return }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        setSupabaseAuthHeaders(&req)
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("return=minimal", forHTTPHeaderField: "Prefer")
        if let cid = clientId { req.setValue(cid, forHTTPHeaderField: "X-Client-Id") }
        var body: [String: Any] = [
            "character_id": characterId,
            "feedback": trimmed
        ]
        if let userId = userIdString { body["user_id"] = userId }
        if let clientId = clientId { body["client_id"] = clientId }
        req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        URLSession.shared.dataTask(with: req).resume()
        showFeedbackSheet = false
    }
}

struct RatingSheet: View {
    @ObservedObject var vm: FeedbackViewModel
    let characterId: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Rate your experience")
                    .font(.headline)
                    .foregroundStyle(.white)
                HStack(spacing: 8) {
                    ForEach(1...5, id: \.self) { star in
                        Image(systemName: vm.currentRating >= star ? "star.fill" : "star")
                            .foregroundStyle(.yellow)
                            .font(.system(size: 28))
                            .onTapGesture { vm.currentRating = star }
                    }
                }
                Button("Submit") { vm.requestSystemReviewAndMarkRated() }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(10)
                    .foregroundStyle(.white)
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Rating")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.fraction(0.3), .medium])
        .presentationBackground(.ultraThinMaterial.opacity(0.2))
    }
}

struct FeedbackSheet: View {
    @ObservedObject var vm: FeedbackViewModel
    let characterId: String

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("How can we improve?")
                    .font(.headline)
                    .foregroundStyle(.white)
                TextEditor(text: $vm.feedbackText)
                    .frame(minHeight: 140)
                    .padding(8)
                    .scrollContentBackground(.hidden)
                    .background(Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .foregroundStyle(.white)
                Button("Send") {
                    #if canImport(UIKit)
                    UIImpactFeedbackGenerator(style: .medium).impactOccurred()
                    #endif
                    vm.submitFeedback(characterId: characterId)
                }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.12))
                    .cornerRadius(10)
                    .foregroundStyle(.white)
                    .disabled(vm.feedbackText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .navigationTitle("Feedback")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
        .presentationDetents([.fraction(0.4), .large])
        .presentationBackground(.ultraThinMaterial.opacity(0.2))
    }
}


