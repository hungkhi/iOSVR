import SwiftUI

struct OnboardingView: View {
    let onModelReady: () -> Void
    @StateObject private var authManager = AuthManager.shared

    // Age gate
    @AppStorage("ageVerified18") private var ageVerified18: Bool = false
    @State private var showAgeConfirm: Bool = false
    @State private var showAgeBlocked: Bool = false

    // Legal sheets
    @State private var showTermsSheet: Bool = false
    @State private var showPrivacySheet: Bool = false

    var body: some View {
        ZStack {
            // Background
            LinearGradient(colors: [Color.black, Color.black.opacity(0.85)], startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
            VStack(spacing: 20) {
                Spacer(minLength: 40)
                // App logo / hero
                ZStack {
                    Circle().fill(Color.white.opacity(0.08)).frame(width: 120, height: 120)
                    Group {
                        #if canImport(UIKit)
                        if let img = (UIImage(named: "Splash") ?? (Bundle.main.path(forResource: "Splash", ofType: "png").flatMap { UIImage(contentsOfFile: $0) })) {
                            Image(uiImage: img)
                                .resizable()
                                .scaledToFill()
                        } else {
                            Image(systemName: "cube.fill").font(.system(size: 52, weight: .bold)).foregroundStyle(.white)
                        }
                        #else
                        Image("Splash")
                            .resizable()
                            .scaledToFill()
                        #endif
                    }
                    .frame(width: 110, height: 110)
                    .clipShape(Circle())
                }
                Text("Welcome to VIVIVI")
                    .font(.system(size: 32, weight: .bold))
                    .foregroundStyle(.white)
                Text("Bring your characters to life.")
                    .foregroundStyle(.white.opacity(0.8))
                    .padding(.bottom, 8)
                if let errorMsg = authManager.errorMessage {
                    Text(errorMsg).foregroundStyle(.red).padding(.horizontal)
                }
                Spacer()
                // Bottom primary sign-in button
                Button(action: { if ageVerified18 { authManager.signInWithApple() } else { showAgeConfirm = true } }) {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                        Text("Sign in with Apple")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.white.opacity(0.14))
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 22)
                }
                .disabled(authManager.isLoading || !ageVerified18)

                // Legal note
                VStack(spacing: 4) {
                    Text("By signing in with Apple, you agree to our")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                    HStack(spacing: 6) {
                        Button(action: { showTermsSheet = true }) {
                            Text("Terms of Service")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .underline()
                        }
                        Text("and")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.7))
                        Button(action: { showPrivacySheet = true }) {
                            Text("Privacy Policy")
                                .font(.footnote.weight(.semibold))
                                .foregroundStyle(.white)
                                .underline()
                        }
                    }
                }
                .padding(.bottom, 8)
            }
        }
        .toolbar {
            // Guest Mode in top-right navbar
            ToolbarItem(placement: .topBarTrailing) {
                Button(action: {
                    guard ageVerified18 else { showAgeConfirm = true; return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        authManager.continueAsGuest()
                    }
                }) {
                    Text("Guest Mode")
                }
                .disabled(authManager.isLoading || !ageVerified18)
            }
        }
        .onAppear {
            onModelReady()
            if !ageVerified18 { showAgeConfirm = true }
        }
        .alert("Are you 18 or older?", isPresented: $showAgeConfirm) {
            Button("Yes, I am 18+") {
                ageVerified18 = true
            }
            Button("I'm under 18", role: .cancel) {
                showAgeBlocked = true
                // Re-show the age confirmation after the blocked alert
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showAgeConfirm = true
                }
            }
        } message: {
            Text("You must confirm you are 18+ to use this app.")
        }
        .alert("Sorry, you must be 18+ to use this app.", isPresented: $showAgeBlocked) {
            Button("OK", role: .cancel) {
                // Re-show the age confirmation after acknowledging the blocked message
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    showAgeConfirm = true
                }
            }
        }
        // Legal sheets
        .sheet(isPresented: $showTermsSheet) { OnboardingLegalSheetView(title: "Terms of Service", text: OnboardingLegalTextTerms) }
        .sheet(isPresented: $showPrivacySheet) { OnboardingLegalSheetView(title: "Privacy Policy", text: OnboardingLegalTextPrivacy) }
    }
}

// MARK: - Local Legal Content for Onboarding
private func loadLegalText(from filename: String) -> String {
    // Try to load from bundle first
    if let url = Bundle.main.url(forResource: filename, withExtension: "md"),
       let content = try? String(contentsOf: url, encoding: .utf8) {
        return content
    }
    // Fallback to embedded content
    return filename == "TermsOfService" ? OnboardingLegalTextTermsEmbedded : OnboardingLegalTextPrivacyEmbedded
}

private let OnboardingLegalTextTermsEmbedded = """
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

private let OnboardingLegalTextPrivacyEmbedded = """
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

private let OnboardingLegalTextTerms = loadLegalText(from: "TermsOfService")
private let OnboardingLegalTextPrivacy = loadLegalText(from: "PrivacyPolicy")

// MARK: - Beautified Markdown View (shared)
struct BeautifiedMarkdownView: View {
    let markdown: String
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(parseMarkdown(), id: \.id) { element in
                element.view
            }
        }
    }
    
    private func parseMarkdown() -> [MarkdownElement] {
        var elements: [MarkdownElement] = []
        let lines = markdown.components(separatedBy: .newlines)
        var currentParagraph: [String] = []
        var i = 0
        
        while i < lines.count {
            let line = lines[i]
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            // Empty line - end current paragraph
            if trimmed.isEmpty {
                if !currentParagraph.isEmpty {
                    elements.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                i += 1
                continue
            }
            
            // H1 - Main title
            if trimmed.hasPrefix("# ") && !trimmed.hasPrefix("##") {
                if !currentParagraph.isEmpty {
                    elements.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                let content = String(trimmed.dropFirst(2))
                elements.append(.heading1(content))
                i += 1
                continue
            }
            
            // H2 - Section headings
            if trimmed.hasPrefix("## ") && !trimmed.hasPrefix("###") {
                if !currentParagraph.isEmpty {
                    elements.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                let content = String(trimmed.dropFirst(3))
                elements.append(.heading2(content))
                i += 1
                continue
            }
            
            // H3 - Sub-section headings
            if trimmed.hasPrefix("### ") {
                if !currentParagraph.isEmpty {
                    elements.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                let content = String(trimmed.dropFirst(4))
                elements.append(.heading3(content))
                i += 1
                continue
            }
            
            // List items (starting with -)
            if trimmed.hasPrefix("- ") {
                if !currentParagraph.isEmpty {
                    elements.append(.paragraph(currentParagraph.joined(separator: " ")))
                    currentParagraph = []
                }
                let content = String(trimmed.dropFirst(2))
                elements.append(.listItem(content))
                i += 1
                continue
            }
            
            // Regular paragraph text
            currentParagraph.append(line)
            i += 1
        }
        
        // Add remaining paragraph
        if !currentParagraph.isEmpty {
            elements.append(.paragraph(currentParagraph.joined(separator: " ")))
        }
        
        return elements
    }
    
    private enum MarkdownElement: Identifiable {
        case heading1(String)
        case heading2(String)
        case heading3(String)
        case paragraph(String)
        case listItem(String)
        
        var id: String {
            switch self {
            case .heading1(let text): return "h1-\(text.prefix(50))"
            case .heading2(let text): return "h2-\(text.prefix(50))"
            case .heading3(let text): return "h3-\(text.prefix(50))"
            case .paragraph(let text): return "p-\(text.prefix(20))"
            case .listItem(let text): return "li-\(text.prefix(20))"
            }
        }
        
        @ViewBuilder
        var view: some View {
            switch self {
            case .heading1(let text):
                Text(parseInlineFormatting(text))
                    .font(.system(size: 28, weight: .bold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.top, 24)
                    .padding(.bottom, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .heading2(let text):
                Text(parseInlineFormatting(text))
                    .font(.system(size: 22, weight: .semibold, design: .default))
                    .foregroundStyle(.white)
                    .padding(.top, 20)
                    .padding(.bottom, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .heading3(let text):
                Text(parseInlineFormatting(text))
                    .font(.system(size: 18, weight: .semibold, design: .default))
                    .foregroundStyle(.white.opacity(0.95))
                    .padding(.top, 16)
                    .padding(.bottom, 4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .paragraph(let text):
                Text(parseInlineFormatting(text))
                    .font(.system(size: 15, weight: .regular, design: .default))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineSpacing(8)
                    .padding(.vertical, 6)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
            case .listItem(let text):
                HStack(alignment: .top, spacing: 12) {
                    Text("•")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                        .padding(.top, 2)
                    Text(parseInlineFormatting(text))
                        .font(.system(size: 15, weight: .regular, design: .default))
                        .foregroundStyle(.white.opacity(0.9))
                        .lineSpacing(6)
                }
                .padding(.vertical, 4)
                .padding(.leading, 4)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        
        private func parseInlineFormatting(_ text: String) -> AttributedString {
            // Try to parse as markdown first
            if let attributed = try? AttributedString(markdown: text, options: AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
                // Apply custom styling to bold text
                var styled = attributed
                for run in styled.runs {
                    if run.inlinePresentationIntent?.contains(.stronglyEmphasized) == true {
                        let range = run.range
                        #if canImport(UIKit)
                        styled[range].font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                        #elseif canImport(AppKit)
                        styled[range].font = NSFont.systemFont(ofSize: 15, weight: .semibold)
                        #endif
                    }
                }
                return styled
            }
            
            // Fallback: manual bold parsing
            var result = AttributedString(text)
            let boldPattern = try! NSRegularExpression(pattern: "\\*\\*(.+?)\\*\\*", options: [])
            let nsString = text as NSString
            let matches = boldPattern.matches(in: text, options: [], range: NSRange(location: 0, length: nsString.length))
            
            for match in matches.reversed() {
                let fullRange = match.range
                let contentRange = match.range(at: 1)
                
                if let fullSwiftRange = Range(fullRange, in: result),
                   let contentSwiftRange = Range(contentRange, in: result) {
                    let boldText = String(result[contentSwiftRange].characters)
                    var boldAttributed = AttributedString(boldText)
                    #if canImport(UIKit)
                    boldAttributed.font = UIFont.systemFont(ofSize: 15, weight: .semibold)
                    #elseif canImport(AppKit)
                    boldAttributed.font = NSFont.systemFont(ofSize: 15, weight: .semibold)
                    #endif
                    result.replaceSubrange(fullSwiftRange, with: boldAttributed)
                }
            }
            
            return result
        }
    }
}

private struct OnboardingLegalSheetView: View {
    let title: String
    let text: String
    var body: some View {
        NavigationStack {
            ScrollView {
                BeautifiedMarkdownView(markdown: text)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 18)
            }
            .scrollIndicators(.hidden)
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

