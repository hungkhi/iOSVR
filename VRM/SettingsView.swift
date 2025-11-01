import SwiftUI
import Auth

struct SettingsView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss

    // Persisted toggles
    @AppStorage("settings.kidsMode") private var kidsMode: Bool = false
    @AppStorage("settings.nsfw") private var enableNSFW: Bool = false
    @AppStorage("settings.dictation") private var enableDictation: Bool = false
    @AppStorage("settings.voiceMode") private var openInVoiceMode: Bool = false
    @AppStorage("settings.hapticsEnabled") private var hapticsEnabled: Bool = true
    @AppStorage("settings.autoPlayMusic") private var autoPlayMusic: Bool = false
    @AppStorage("settings.autoEnterTalking") private var autoEnterTalking: Bool = false

    // Name editor (legacy sheet retained for quick rename entry points)
    @State private var showNameEditor: Bool = false
    @State private var editedName: String = ""

    private var displayName: String {
        let raw = authManager.user?.userMetadata["display_name"].map { String(describing: $0) } ?? ""
        if !raw.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty { return raw }
        let email = authManager.user?.email ?? ""
        let fallback = email.split(separator: "@").first.map(String.init) ?? "User"
        return fallback
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    profileCard
                    subscriptionCard
                    generalSection
                    parentalSection
                    // Voice section shown without a title per requirement
                    voiceSection
                    dataInfoSection
                    legalSection
                    supportSection
                    signOutButton
                    versionFooter
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .scrollIndicators(.hidden)
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button(action: { dismiss() }) { Image(systemName: "xmark") } } }
        }
        .sheet(isPresented: $showNameEditor) {
            VStack(spacing: 16) {
                Text("What should we call you?")
                    .font(.headline)
                    .foregroundStyle(.white)
                TextField("Your name", text: $editedName)
                    .textInputAutocapitalization(.words)
                    .submitLabel(.done)
                    .padding()
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(10)
                    .foregroundStyle(.white)
                Button("Save") {
                    let name = editedName.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
                    guard !name.isEmpty else { return }
                    Task { await authManager.updateDisplayName(name); showNameEditor = false }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.white.opacity(0.12))
                .cornerRadius(10)
                .foregroundStyle(.white)
            }
            .padding(20)
            .background(Color.black.ignoresSafeArea())
            .onAppear { editedName = displayName }
        }
    }

    private var profileCard: some View {
        NavigationLink(destination: EditProfileView(authManager: authManager)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(Color.white.opacity(0.15)).frame(width: 56, height: 56)
                    Text(String(displayName.prefix(1))).font(.system(size: 24, weight: .medium)).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 4) {
                    Text(displayName).font(.headline).foregroundStyle(.white)
                    Text(authManager.user?.email ?? "").foregroundStyle(.white.opacity(0.7))
                        .font(.subheadline)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.6))
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var showSubscription: Bool = false
    
    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription").foregroundStyle(.white.opacity(0.9)).font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 8) {
                        Text(subscriptionManager.currentTier.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if subscriptionManager.currentTier != .free {
                            ProBadge(tier: subscriptionManager.currentTier)
                        }
                    }
                    Text(subscriptionManager.currentTier == .free ? "Upgrade to unlock premium content" : "Active subscription")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Button(subscriptionManager.currentTier == .free ? "Upgrade" : "Manage") {
                    showSubscription = true
                }
                .padding(.horizontal, 14).padding(.vertical, 8)
                .background(Color.white.opacity(0.18))
                .cornerRadius(10)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue.opacity(0.35)))
        }
        .sheet(isPresented: $showSubscription) {
            SubscriptionView(
                contentName: "Premium Features",
                contentType: .character,
                requiredTier: subscriptionManager.currentTier == .free ? .pro : subscriptionManager.currentTier
            )
            .preferredColorScheme(.dark)
        }
    }

    private var generalSection: some View {
        settingsGroup(title: "Preferences") {
            toggleRow(icon: "iphone.radiowaves.left.and.right", title: "Haptics", isOn: $hapticsEnabled)
            toggleRow(icon: "music.note", title: "Auto play music", isOn: $autoPlayMusic)
            toggleRow(icon: "waveform", title: "Auto enter talking mode", isOn: $autoEnterTalking)
            groupRow(icon: "globe", title: "App Language", trailing: { Text("English").foregroundStyle(.white.opacity(0.8)) }) { }
        }
    }

    private var parentalSection: some View {
        settingsGroup(title: "") {
            toggleRow(icon: "18.circle", title: "Enable NSFW", isOn: $enableNSFW)
        }
    }

    private var voiceSection: some View {
        settingsGroup(title: "") {
            // Intentionally left blank per requirements (removed Companions, Dictation, Open in Voice Mode)
        }
    }

    // playbackSection merged into Preferences

    private var dataInfoSection: some View {
        settingsGroup(title: "Data & Information") {
            // Intentionally left blank per requirements (removed Share Links, Data Controls, Recently Deleted)
        }
    }

    private var legalSection: some View {
        settingsGroup(title: "") {
            NavigationLink(destination: LegalTextView(title: "Terms of Service", text: LegalText.terms)) { rowContent(icon: "doc.text", title: "Terms of Service") }
            NavigationLink(destination: LegalTextView(title: "Privacy Policy", text: LegalText.privacy)) { rowContent(icon: "lock.shield", title: "Privacy Policy") }
        }
    }

    private var supportSection: some View {
        settingsGroup(title: "") {
            NavigationLink(destination: FeedbackFormView(kind: .problem)) { rowContent(icon: "lifepreserver", title: "Report a Problem") }
            NavigationLink(destination: FeedbackFormView(kind: .feature)) { rowContent(icon: "star", title: "Feature Request") }
        }
    }

    private var signOutButton: some View {
        Button(action: { Task { await authManager.logout(); dismiss() } }) {
            HStack {
                Image(systemName: "arrowshape.turn.up.left")
                Text("Sign Out")
                Spacer()
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
        }
        .buttonStyle(.plain)
    }

    private var versionFooter: some View {
        Text("VERSION 1.0.0")
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.5))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }

    private func settingsGroup<Content: View>(title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if !title.isEmpty {
                Text(title)
                    .foregroundStyle(.white.opacity(0.92))
                    .font(.title3.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, 4)
                    .padding(.bottom, 10) // equal gap before the card
            }
            VStack(spacing: 1) { content() }
                .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.white.opacity(0.06)))
        }
        .padding(.vertical, 8) // equal outer spacing between groups
    }

    private func groupRow<Trailing: View>(icon: String, title: String, @ViewBuilder trailing: () -> Trailing = { EmptyView() }, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            rowContent(icon: icon, title: title, trailing: trailing())
        }
        .buttonStyle(.plain)
    }

    private func toggleRow(icon: String, title: String, isOn: Binding<Bool>) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(.white)
            Text(title).foregroundStyle(.white)
            Spacer()
            Toggle("", isOn: isOn).labelsHidden()
        }
        .padding(16)
    }

    private func openURL(_ s: String) {
        guard let url = URL(string: s) else { return }
        #if canImport(UIKit)
        UIApplication.shared.open(url)
        #endif
    }

    private func rowContent<Trailing: View>(icon: String, title: String, trailing: Trailing = EmptyView()) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon).frame(width: 22).foregroundStyle(.white)
            Text(title).foregroundStyle(.white)
            Spacer()
            trailing
            Image(systemName: "chevron.right").foregroundStyle(.white.opacity(0.6))
        }
        .padding(16)
    }
}

// MARK: - Legal Texts Helper
private func loadLegalText(from filename: String) -> String {
    // Try to load from bundle first
    if let url = Bundle.main.url(forResource: filename, withExtension: "md"),
       let content = try? String(contentsOf: url, encoding: .utf8) {
        return content
    }
    // Fallback to embedded content
    return filename == "TermsOfService" ? LegalText.termsEmbedded : LegalText.privacyEmbedded
}

// MARK: - Legal Texts
private enum LegalText {
    static let termsEmbedded = """
# TERMS OF SERVICE – VIVIVI

**Last Updated: 1 November 2025**

## 1. Acceptance of Terms

By downloading, accessing, or using VIVIVI ("the App", "we", "us", "our"), you agree to be bound by these Terms of Service ("Terms"). If you do not agree, do not use the App.

## 2. Eligibility

You must be at least 18 years of age to use VIVIVI.

By using the App, you certify that you meet the legal age required in your country or region to access AI companion or mature-themed content.

## 3. Description of Service

VIVIVI provides:

- 3D AI-powered companion characters for entertainment and social interaction
- Real-time AI chat and voice call conversations
- Character customization, outfits, dancing, media creation, and interactive environments

All characters and interactions are fictional and for entertainment purposes only. No real person is represented or implied.

## 4. User Conduct

You agree not to:

- Use the App for unlawful, harmful, or abusive purposes
- Exploit, harass, threaten, or engage in inappropriate behavior toward any in-app characters or other users
- Upload harmful, explicit, hateful, violent, or discriminatory content
- Interfere with the App's functionality, security, or servers

Violations may result in warnings, suspension, or permanent termination without refund.

## 5. In-App Purchases & Subscriptions

Some VIVIVI features may require payment (one-time purchases or subscriptions).

- Payments and subscriptions are processed through the Apple App Store / Google Play Store, based on your device.
- Subscription fees renew automatically unless canceled at least 24 hours before the renewal date via your store account settings.
- Refunds follow the App Store / Google Play refund policies and are not issued directly by VIVIVI unless required by law.

## 6. Intellectual Property

All content, including characters, designs, graphics, animations, audio, code, and AI systems, are owned by or licensed to VIVIVI. You may not copy, distribute, modify, sell, or reproduce any part of the App.

## 7. User-Generated Content

If the App allows you to upload or generate content (e.g., chat, voice, images, media):

- You retain ownership of the content you create.
- You grant us a worldwide, non-exclusive, royalty-free license to store, process, display, and use such content to operate and improve VIVIVI.
- You must have the legal right to any content you upload.
- We reserve the right to remove content that violates these Terms or legal requirements.

## 8. AI Interaction Disclaimer

VIVIVI uses artificial intelligence to generate responses, voices, and character behaviors.

Responses may sometimes be inaccurate, fictional, or unexpected. Do not rely on AI-generated content for real-life professional, medical, legal, or financial decisions.

## 9. Well-Being and Responsible Use

VIVIVI is intended for entertainment and emotional companionship, not as a substitute for real-world relationships, therapy, or mental-health services. If you experience distress or emotional dependency, seek support from qualified professionals.

## 10. Termination

We may suspend or terminate your access to the App at our discretion to protect users, maintain security, enforce policies, or comply with legal requirements.

## 11. Limitation of Liability

To the fullest extent permitted by law, VIVIVI is provided "as is" and "as available". We are not liable for:

- Damages resulting from App use or inability to use the App
- AI-generated content or third-party services
- Loss of data or interruptions beyond our reasonable control

Your use of the App is at your own risk.

## 12. Changes to Terms

We may update these Terms from time to time. Continued use after updates means you accept the revised Terms. We will notify users of material changes when required by law.

## 13. Contact

For questions or concerns regarding these Terms, contact:

**Email:** arthurbijan@gmail.com
"""
    
    static let privacyEmbedded = """
# PRIVACY POLICY – VIVIVI

**Last Updated: 1 November 2025**

## 1. Introduction

This Privacy Policy explains how VIVIVI ("we", "us", "our") collects, uses, and protects your data when you use the App. By using VIVIVI, you agree to this Policy.

## 2. Information We Collect

### A. Information You Provide

- Account information (e.g., username, email, age verification)
- Chat messages, voice recordings, or interactions with AI
- Profile settings, preferences, and character customization data
- Media or files you upload voluntarily

### B. Automatically Collected Data

- Device information (model, OS version, IP address, language)
- App usage statistics and interaction logs
- Crash analytics, diagnostics, and performance data

### C. Permissions & Optional Data

VIVIVI may ask for permission to access:

- Microphone (for voice calls)
- Photos or storage (to save or upload media)

You may decline permissions, but some features may not function.

VIVIVI does not collect biometric or sensitive health data.

## 3. How We Use Your Data

We use data to:

- Provide and improve app features and AI interactions
- Personalize character responses, environments, and user experience
- Process purchases, subscriptions, and customer support
- Ensure security, prevent abuse, and enforce policies
- Improve AI models (data may be anonymized when used for training)

We do not sell your personal data.

## 4. Data Sharing

We may share information only with:

- Trusted service providers (hosting, analytics, AI processing, payment systems)
- Authorities if required by law, safety, or legal obligations

We do not share your data with advertisers for targeted ad sales.

## 5. Data Storage & Security

- Data may be stored on encrypted, secure cloud servers.
- We use reasonable administrative, technical, and physical safeguards to protect data.
- No method of data transmission or storage is fully secure, and we cannot guarantee absolute security.

## 6. Your Rights

Depending on your region, you may request to:

- Access, correct, or update your data
- Request data deletion or account removal
- Withdraw consent or restrict certain data uses
- Request a copy (export) of your data

Please contact us with your request.

## 7. Children's Privacy

VIVIVI is not intended for individuals under 18.

We do not knowingly collect data from minors. If such data is discovered, we will delete it promptly.

## 8. Cookies & Tracking Technologies

We may use cookies or similar technologies to improve experience and functionality. You may disable cookies in device or browser settings, but some features may not work correctly.

## 9. Third-Party Services

VIVIVI may contain links or integrations with third-party services (e.g., Apple, Google, analytics platforms). Their privacy practices are governed by their respective Privacy Policies.

## 10. Changes to This Policy

We may update this Privacy Policy periodically. Continued use after changes indicates acceptance of the updated Policy. Users will be notified when legally required.

## 11. Contact

For privacy inquiries or data requests, contact:

**Email:** arthurbijan@gmail.com
"""
    
    static var terms: String { loadLegalText(from: "TermsOfService") }
    static var privacy: String { loadLegalText(from: "PrivacyPolicy") }
}

private struct LegalTextView: View {
    let title: String
    let text: String
    var body: some View {
        ScrollView {
            BeautifiedMarkdownView(markdown: text)
                .padding(.horizontal, 20)
                .padding(.vertical, 18)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { printDoc() } label: { Image(systemName: "printer") } } }
        .background(Color.black.ignoresSafeArea())
    }

    private func printDoc() {
        #if canImport(UIKit)
        let fmt = UISimpleTextPrintFormatter(text: text)
        let pc = UIPrintInteractionController.shared
        pc.printFormatter = fmt
        pc.present(animated: true, completionHandler: nil)
        #endif
    }
}

// MARK: - Feedback Form
private struct FeedbackFormView: View {
    enum Kind { case problem, feature }
    let kind: Kind
    @State private var subject: String = ""
    @State private var details: String = ""
    @State private var isSubmitting: Bool = false
    @State private var submitMessage: String? = nil
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                // Subject (auto-filled, read-only)
                Text("Subject").foregroundStyle(.white.opacity(0.9)).font(.headline)
                Text(subject)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(14)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .foregroundStyle(.white.opacity(0.85))

                // Details
                Text("Details").foregroundStyle(.white.opacity(0.9)).font(.headline)
                TextEditor(text: $details)
                    .frame(minHeight: 220)
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(16)
                    .foregroundStyle(.white)

            }
            .padding(16)
        }
        .scrollIndicators(.hidden)
        .navigationTitle(kind == .problem ? "Report a Problem" : "Feature Request")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button(isSubmitting ? "Sending…" : "Send") { submit() }
                    .disabled(isSubmitting || details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .onAppear {
            subject = (kind == .problem) ? "Bug report" : "Feature request"
        }
        .alert(item: Binding(get: { submitMessage.map { Ident(msg: $0) } }, set: { _ in submitMessage = nil })) { ident in
            Alert(title: Text("Thank you!"), message: Text(ident.msg), dismissButton: .default(Text("OK")))
        }
    }
    private func submit() {
        isSubmitting = true
        let kindString = (kind == .problem ? "problem" : "feature")
        // 1) Save to Supabase via REST
        if let url = URL(string: SUPABASE_URL + "/rest/v1/feedback") {
            var req = URLRequest(url: url)
            req.httpMethod = "POST"
            setSupabaseAuthHeaders(&req)
            req.setValue("application/json", forHTTPHeaderField: "Content-Type")
            req.setValue("return=representation", forHTTPHeaderField: "Prefer")
            let userId = AuthManager.shared.user?.id.uuidString
            let clientId = AuthManager.shared.isGuest ? (UserDefaults.standard.string(forKey: PersistKeys.clientId) ?? ensureClientId()) : nil
            var body: [String: Any] = [
                "kind": kindString,
                "subject": subject,
                "message": details
            ]
            if let uid = userId { body["user_id"] = uid }
            if let cid = clientId { body["client_id"] = cid }
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
            URLSession.shared.dataTask(with: req) { _, _, _ in }.resume()
        }
        // 2) Fire off an email via mailto fallback for now
        #if canImport(UIKit)
        let emailBody = "Type: \(kindString)\nSubject: \(subject)\n\n\(details)"
        let enc = emailBody.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
        if let mail = URL(string: "mailto:hung@eduto.asia?subject=VRM%20\(kindString.capitalized)%20Feedback&body=\(enc)") {
            UIApplication.shared.open(mail)
        }
        #endif
        isSubmitting = false
        submitMessage = "We’ve recorded your \(kindString) and emailed the team. Thank you for helping improve VRM!"
    }
    private struct Ident: Identifiable { let id = UUID(); let msg: String }
}

// MARK: - Edit Profile Screen
private struct EditProfileView: View {
    @ObservedObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var birthYear: String = ""
    @State private var showingBirthYearPicker: Bool = false
    @State private var showDeleteConfirm: Bool = false
    @State private var showFinalConfirm: Bool = false

    private var displayInitial: String { String((firstName.isEmpty ? (authManager.user?.userMetadata["display_name"].map { String(describing: $0) } ?? "U") : firstName).prefix(1)) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ZStack {
                        Circle().fill(Color.white.opacity(0.15)).frame(width: 84, height: 84)
                        Text(displayInitial).font(.system(size: 34, weight: .medium)).foregroundStyle(.white)
                    }
                    .padding(.top, 8)

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Name").foregroundStyle(.white.opacity(0.8))
                        VStack(spacing: 12) {
                            TextField("First name", text: $firstName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(16)
                                .foregroundStyle(.white)
                            TextField("Last name", text: $lastName)
                                .textInputAutocapitalization(.words)
                                .padding()
                                .background(Color.white.opacity(0.08))
                                .cornerRadius(16)
                                .foregroundStyle(.white)
                        }
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Birth Year").foregroundStyle(.white.opacity(0.8))
                        Button(action: { showingBirthYearPicker = true }) {
                            HStack {
                                Text(birthYear.isEmpty ? "Edit Birth Year" : birthYear)
                                    .foregroundStyle(Color.blue)
                                Spacer()
                            }
                            .padding()
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(16)
                        }
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Danger Zone").foregroundStyle(.red)
                        Button(role: .destructive) { showDeleteConfirm = true } label: {
                            HStack { Image(systemName: "trash"); Text("Delete Account"); Spacer() }
                        }
                        .padding()
                        .background(Color.red.opacity(0.12))
                        .cornerRadius(12)
                    }
                    .padding(.top, 8)
                }
                .padding(16)
            }
            .navigationTitle("Edit profile")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") { save() }
                }
            }
        }
        .onAppear { seed() }
        .sheet(isPresented: $showingBirthYearPicker) {
            YearPickerSheet(selected: $birthYear)
                .preferredColorScheme(.dark)
        }
        .alert("Delete Account?", isPresented: $showDeleteConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Continue", role: .destructive) { showFinalConfirm = true }
        } message: {
            Text("This will permanently delete your account. Your subscription cannot be recovered and will be cancelled immediately after deletion.")
        }
        .alert("Are you absolutely sure?", isPresented: $showFinalConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Account", role: .destructive) { Task { await authManager.deleteAccountLocally(); dismiss() } }
        } message: {
            Text("All data associated with your account will be removed. This action cannot be undone.")
        }
    }

    private func seed() {
        let raw = authManager.user?.userMetadata["display_name"].map { String(describing: $0) } ?? ""
        if !raw.isEmpty {
            let parts = raw.split(separator: " ", maxSplits: 1).map(String.init)
            firstName = parts.first ?? ""
            lastName = parts.count > 1 ? parts[1] : ""
        }
        if let byRaw = authManager.user?.userMetadata["birth_year"].map({ String(describing: $0) }), !byRaw.isEmpty { birthYear = byRaw }
    }

    private func save() {
        let name = [firstName, lastName].filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.joined(separator: " ")
        Task {
            if !name.isEmpty { await authManager.updateDisplayName(name) }
            if let year = Int(birthYear) { await authManager.updateBirthYear(year) }
            dismiss()
        }
    }
}

private struct YearPickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selected: String
    @State private var year: Int = Calendar.current.component(.year, from: Date()) - 20
    private let years: [Int] = Array((1900...Calendar.current.component(.year, from: Date())).reversed())
    var body: some View {
        NavigationStack {
            Picker("Birth Year", selection: $year) {
                ForEach(years, id: \.self) { Text(String($0)).tag($0) }
            }
            .pickerStyle(.wheel)
            .navigationTitle("Birth Year")
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { selected = String(year); dismiss() } } }
            .onAppear { if let i = Int(selected) { year = i } }
        }
    }
}


