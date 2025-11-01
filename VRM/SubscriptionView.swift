import SwiftUI
import StoreKit
import Combine

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    let contentName: String
    let contentType: ContentType
    let requiredTier: SubscriptionTier
    
    enum ContentType {
        case character
        case room
        case costume
        case media
        
        var displayName: String {
            switch self {
            case .character: return "Character"
            case .room: return "Background"
            case .costume: return "Costume"
            case .media: return "Media"
            }
        }
    }
    
    @StateObject private var subscriptionManager = SubscriptionManager.shared
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Header
                        VStack(spacing: 12) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 48))
                                .foregroundStyle(.white.opacity(0.9))
                            
                            Text("Premium \(contentType.displayName)")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                            
                            Text("This \(contentType.displayName.lowercased()) is available for \(requiredTier.displayName) subscribers")
                                .font(.system(size: 16))
                                .foregroundStyle(.white.opacity(0.7))
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        .padding(.top, 40)
                        
                        // Content Name
                        Text(contentName)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.1))
                            )
                        
                        // Subscription Plans
                        VStack(spacing: 16) {
                            ForEach(SubscriptionPlan.allPlans, id: \.id) { plan in
                                SubscriptionPlanCard(
                                    plan: plan,
                                    isSelected: subscriptionManager.selectedPlan?.id == plan.id,
                                    isRecommended: plan.isRecommended
                                ) {
                                    subscriptionManager.selectedPlan = plan
                                }
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        // Subscribe Button
                        Button(action: {
                            purchaseSubscription()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    Text(subscriptionManager.selectedPlan != nil ? "Subscribe to \(subscriptionManager.selectedPlan!.displayName)" : "Select a Plan")
                                        .font(.system(size: 18, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(subscriptionManager.selectedPlan != nil ? Color.blue : Color.gray.opacity(0.3))
                            )
                        }
                        .disabled(isLoading || subscriptionManager.selectedPlan == nil)
                        .padding(.horizontal, 20)
                        
                        if let errorMessage = errorMessage {
                            Text(errorMessage)
                                .font(.system(size: 14))
                                .foregroundStyle(.red)
                                .padding(.horizontal, 20)
                        }
                        
                        // Terms
                        Text("Subscription automatically renews. Cancel anytime in App Store settings.")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                            .padding(.bottom, 20)
                    }
                }
            }
            .navigationTitle("Subscription")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundStyle(.white)
                }
            }
            .preferredColorScheme(.dark)
        }
    }
    
    private func purchaseSubscription() {
        guard let plan = subscriptionManager.selectedPlan else { return }
        isLoading = true
        errorMessage = nil
        
        // TODO: Implement StoreKit 2 purchase logic
        // For now, simulate a purchase
        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            await MainActor.run {
                subscriptionManager.updateTier(plan.tier)
                isLoading = false
                dismiss()
            }
        }
    }
}

// MARK: - Subscription Plan
struct SubscriptionPlan: Identifiable {
    let id: String
    let displayName: String
    let tier: SubscriptionTier
    let price: String
    let features: [String]
    let isRecommended: Bool
    
    static let allPlans: [SubscriptionPlan] = [
        SubscriptionPlan(
            id: "pro_monthly",
            displayName: "Pro",
            tier: .pro,
            price: "$9.99/month",
            features: [
                "Access to Pro characters",
                "Access to Pro backgrounds",
                "Access to Pro costumes",
                "Unlimited conversations"
            ],
            isRecommended: true
        ),
        SubscriptionPlan(
            id: "unlimited_monthly",
            displayName: "Unlimited",
            tier: .unlimited,
            price: "$19.99/month",
            features: [
                "Everything in Pro",
                "Access to Unlimited tier content",
                "Priority support",
                "Early access to new features"
            ],
            isRecommended: false
        )
    ]
}

// MARK: - Subscription Plan Card
struct SubscriptionPlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isRecommended: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(plan.displayName)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundStyle(.white)
                            
                            if isRecommended {
                                Text("RECOMMENDED")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(
                                        Capsule()
                                            .fill(Color.blue)
                                    )
                            }
                        }
                        
                        Text(plan.price)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundStyle(isSelected ? .blue : .white.opacity(0.3))
                }
                
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(plan.features, id: \.self) { feature in
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.green)
                            Text(feature)
                                .font(.system(size: 14))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16)
                    .fill(isSelected ? Color.blue.opacity(0.2) : Color.white.opacity(0.05))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(isSelected ? Color.blue : Color.white.opacity(0.1), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
    }
}

// MARK: - Subscription Manager
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    
    @Published var currentTier: SubscriptionTier = .free
    @Published var selectedPlan: SubscriptionPlan?
    
    private init() {
        // Load subscription tier from UserDefaults
        if let savedTier = UserDefaults.standard.string(forKey: "subscription.tier"),
           let tier = SubscriptionTier(rawValue: savedTier) {
            currentTier = tier
        }
    }
    
    func updateTier(_ tier: SubscriptionTier) {
        currentTier = tier
        UserDefaults.standard.set(tier.rawValue, forKey: "subscription.tier")
    }
    
    func hasAccess(to requiredTier: SubscriptionTier) -> Bool {
        switch requiredTier {
        case .free:
            return true
        case .pro:
            return currentTier == .pro || currentTier == .unlimited
        case .unlimited:
            return currentTier == .unlimited
        }
    }
    
    func checkAccessAndShowSubscriptionIfNeeded(
        requiredTier: SubscriptionTier,
        contentName: String,
        contentType: SubscriptionView.ContentType,
        showingSubscription: Binding<Bool>
    ) -> Bool {
        if hasAccess(to: requiredTier) {
            return true
        } else {
            showingSubscription.wrappedValue = true
            return false
        }
    }
}

