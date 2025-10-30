import Foundation
import Supabase
import AuthenticationServices
import Combine
import Auth

class AuthManager: NSObject, ObservableObject {
    static let shared = AuthManager()

    private let client: SupabaseClient
    @Published var session: Session?
    @Published var user: User?
    @Published var isLoading: Bool = false
    @Published var errorMessage: String? = nil
    @Published var isGuest: Bool = false

    override private init() {
        self.client = SupabaseClient(
            supabaseURL: URL(string: SUPABASE_URL)!,
            supabaseKey: SUPABASE_ANON_KEY
        )
        super.init()
    }

    func signInWithApple() {
        isLoading = true
        errorMessage = nil
        let provider = ASAuthorizationAppleIDProvider()
        let request = provider.createRequest()
        request.requestedScopes = [.fullName, .email]
        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    @MainActor
    func logout() async {
        isLoading = true
        defer { isLoading = false }
        do {
            try await client.auth.signOut()
            self.session = nil
            self.user = nil
            self.isGuest = false
        } catch {
            self.errorMessage = error.localizedDescription
        }
    }

    func continueAsGuest() {
        // Enable guest mode to bypass sign-in for simulator testing
        errorMessage = nil
        isGuest = true
    }
}

extension AuthManager: ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        #if canImport(UIKit)
        return UIApplication.shared.windows.first { $0.isKeyWindow } ?? ASPresentationAnchor()
        #else
        return ASPresentationAnchor()
        #endif
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let appleIDCredential = authorization.credential as? ASAuthorizationAppleIDCredential,
              let identityTokenData = appleIDCredential.identityToken,
              let idToken = String(data: identityTokenData, encoding: .utf8)
        else {
            self.errorMessage = "Failed to get Apple identity token"
            self.isLoading = false
            return
        }
        Task {
            do {
                let _ = try await client.auth.signInWithIdToken(
                    credentials: OpenIDConnectCredentials(
                        provider: .apple,
                        idToken: idToken
                    )
                )
                let session = try? await client.auth.session
                let user = try? await client.auth.currentUser
                await MainActor.run {
                    self.session = session
                    self.user = user
                    self.isLoading = false
                }
            } catch {
                await MainActor.run {
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                }
            }
        }
    }

    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        self.errorMessage = error.localizedDescription
        self.isLoading = false
    }
}
