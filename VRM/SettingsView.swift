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

    private var subscriptionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Subscription").foregroundStyle(.white.opacity(0.9)).font(.headline)
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    Text("SuperGrok").font(.headline).foregroundStyle(.white)
                    Text("Upgrade for higher limits").font(.subheadline).foregroundStyle(.white.opacity(0.9))
                }
                Spacer()
                Button("Upgrade") {}
                    .padding(.horizontal, 14).padding(.vertical, 8)
                    .background(Color.white.opacity(0.18))
                    .cornerRadius(10)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(Color.blue.opacity(0.35)))
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
            NavigationLink(destination: LegalTextView(title: "Terms of Use", text: LegalText.terms)) { rowContent(icon: "doc.text", title: "Terms of Use") }
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

// MARK: - Legal Texts
private enum LegalText {
    static let terms = """
    # Terms of Use
    _Last updated: October 30, 2025_

    Welcome to VRM. These Terms explain your rights and responsibilities when using the app. Please read them carefully.

    ---
    ## Quick summary
    - You get a personal, revocable license to use the app.
    - You’re responsible for content you load or share.
    - Play nice: no abuse, spam, or breaking the law.
    - We may integrate third‑party services; their rules apply too.
    - The app is provided “as is,” with no guarantees.

    ---
    ## 1. Eligibility
    You must be at least 13 (or older if your local law requires). If you are under the age of majority, use the app only with a parent/guardian’s consent.

    ## 2. License & restrictions
    We grant you a limited, personal, non‑exclusive, non‑transferable, revocable license to use the app. You may not reverse‑engineer, copy, resell, or misuse the app except where allowed by law.

    ## 3. Your content
    You’re responsible for any models, media, or text you load or share. Only use content you have the right to use. Don’t upload anything illegal, harmful, or that infringes others’ rights.

    ## 4. Acceptable use
    Don’t attempt to disrupt the app, bypass limits, harass others, scrape data without permission, or violate applicable laws.

    ## 5. Third‑party services
    The app may rely on outside services (e.g., hosting, speech, analytics). Those are governed by their own terms and privacy policies.

    ## 6. Ownership
    We and our licensors own all rights in the app (excluding your content). Trademarks and logos belong to their owners.

    ## 7. Changes & updates
    We may update features and these Terms. We’ll give reasonable notice of material changes, and continuing to use the app means you accept them.

    ## 8. Termination
    We may suspend or terminate access if you violate these Terms or the law. When terminated, your license ends and you must stop using the app.

    ## 9. Disclaimers
    THE APP IS PROVIDED “AS IS” AND “AS AVAILABLE.” TO THE FULLEST EXTENT PERMITTED BY LAW, WE DISCLAIM ALL WARRANTIES (EXPRESS OR IMPLIED), INCLUDING MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON‑INFRINGEMENT.

    ## 10. Limitation of liability
    TO THE FULLEST EXTENT PERMITTED BY LAW, WE ARE NOT LIABLE FOR INDIRECT, INCIDENTAL, SPECIAL, CONSEQUENTIAL, EXEMPLARY, OR PUNITIVE DAMAGES, OR ANY LOSS OF DATA, PROFITS, OR GOODWILL. OUR TOTAL LIABILITY FOR ANY CLAIM WILL NOT EXCEED WHAT YOU PAID FOR THE APP IN THE PREVIOUS 12 MONTHS (OR USD $0 IF NONE).

    ## 11. Indemnity
    You agree to defend and hold us harmless from claims arising out of your misuse of the app or breach of these Terms.

    ## 12. Governing law
    These Terms are governed by the laws of your place of residence, unless local law requires otherwise. Disputes will be resolved in courts with jurisdiction where you live.

    ## 13. Contact
    Questions? Open the app’s Settings and choose Support.
    """
    static let privacy = """
    # Privacy Policy
    _Last updated: October 30, 2025_

    We care about your privacy. This Policy explains what we collect, why we collect it, and how you can control it.

    ---
    ## What we collect
    - **Account info** (if you sign in): identifiers and basic profile details like email and display name.
    - **On‑device preferences**: things like haptics, auto‑play music, and auto‑enter talking mode (stored using system storage on your device).
    - **Diagnostics**: crash reports and performance signals that help us keep the app reliable.
    - **Content sources**: when you load models/backgrounds from URLs, those assets are fetched directly from the hosts you choose.

    ## How we use it
    - Provide and improve the app’s features
    - Remember your preferences
    - Communicate important updates or respond to support requests
    - Maintain safety, security, and legal compliance

    ## Sharing
    We do not sell your data. We may share limited information with trusted providers that host infrastructure, speech/voice, or analytics for us—strictly to deliver the service and under confidentiality obligations.

    ## Retention
    - Account‑linked data is retained while needed to operate the app or meet legal requirements.
    - On‑device preferences stay on your device until you reset them or uninstall the app.

    ## Your choices
    - Change settings anytime in the app.
    - If supported, delete your account via Settings → Edit profile → Delete Account (subscriptions are cancelled and cannot be recovered).

    ## Security
    We use reasonable safeguards, but no system is perfectly secure. Please use strong device security.

    ## Children
    If you’re under the legal age in your region, use the app only with parental consent and supervision.

    ## International transfers
    Data may be processed in other countries. We take steps to protect it appropriately.

    ## Changes
    We may update this Policy; continued use means you accept the new version. For important changes, we’ll provide reasonable notice.

    ## Contact
    For privacy questions, use the Support option in Settings.
    """
}

private struct LegalTextView: View {
    let title: String
    let text: String
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                if let attr = try? AttributedString(markdown: text) {
                    Text(attr)
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    Text(text)
                        .foregroundStyle(.white)
                        .lineSpacing(6)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(18)
        }
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


