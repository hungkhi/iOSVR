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
                            Text("Terms of Use")
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
        .sheet(isPresented: $showTermsSheet) { OnboardingLegalSheetView(title: "Terms of Use", text: OnboardingLegalTextTerms) }
        .sheet(isPresented: $showPrivacySheet) { OnboardingLegalSheetView(title: "Privacy Policy", text: OnboardingLegalTextPrivacy) }
    }
}

// MARK: - Local Legal Content for Onboarding
private let OnboardingLegalTextTerms = """
# Terms of Use
_Last updated: October 30, 2025_

Use of this app is subject to our terms. You must be 13+ (or local equivalent) and agree not to misuse the app or infringe others’ rights. We may update features and terms; continued use means you accept the changes. The app is provided “as is.”
"""

private let OnboardingLegalTextPrivacy = """
# Privacy Policy
_Last updated: October 30, 2025_

We collect minimal data to run the app (account identifiers if you sign in, on‑device preferences, diagnostics). We don’t sell data. See Settings for details.
"""

private struct OnboardingLegalSheetView: View {
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

