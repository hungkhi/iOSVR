import SwiftUI
import StoreKit
import Combine
import RevenueCat

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
    @StateObject private var revenueCatManager = RevenueCatManager.shared
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
                        if revenueCatManager.isLoading {
                            ProgressView()
                                .tint(.white)
                                .padding(.vertical, 40)
                        } else if let offerings = revenueCatManager.offerings, let currentOffering = offerings.current, !currentOffering.availablePackages.isEmpty {
                            VStack(spacing: 16) {
                                ForEach(currentOffering.availablePackages, id: \.identifier) { package in
                                    if let plan = SubscriptionPlan.fromRevenueCatPackage(package) {
                                        SubscriptionPlanCard(
                                            plan: plan,
                                            isSelected: subscriptionManager.selectedPackage?.identifier == package.identifier,
                                            isRecommended: false
                                        ) {
                                            subscriptionManager.selectedPackage = package
                                            subscriptionManager.selectedPlan = plan
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal, 20)
                        } else if let errorMessage = revenueCatManager.errorMessage {
                            VStack(spacing: 12) {
                                Text("Failed to load subscriptions")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.red)
                                
                                Text(errorMessage)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.red.opacity(0.9))
                                    .multilineTextAlignment(.center)
                                
                                Text("Troubleshooting:")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .padding(.top, 8)
                                
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("1. Ensure StoreKit Configuration is set in Scheme → Run → Options")
                                    Text("2. Verify products exist in RevenueCat dashboard")
                                    Text("3. Check that products match StoreKit file IDs")
                                    Text("4. Ensure a current Offering is configured in RevenueCat")
                                }
                                .font(.system(size: 12))
                                .foregroundStyle(.white.opacity(0.7))
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                        } else if let offerings = revenueCatManager.offerings, let current = offerings.current, current.availablePackages.isEmpty {
                            VStack(spacing: 12) {
                                Text("No subscription packages available")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.orange)
                                
                                Text("The current offering exists but has no packages. Please add products to your Offering in the RevenueCat dashboard.")
                                    .font(.system(size: 14))
                                    .foregroundStyle(.white.opacity(0.8))
                                    .multilineTextAlignment(.center)
                            }
                            .padding(.horizontal, 20)
                            .padding(.vertical, 20)
                        } else {
                            // Fallback to default plans if RevenueCat is not configured
                            VStack(spacing: 16) {
                                ForEach(SubscriptionPlan.defaultPlans, id: \.id) { plan in
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
                        }
                        
                        // Subscribe Button
                        Button(action: {
                            purchaseSubscription()
                        }) {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .tint(.white)
                                } else {
                                    if let plan = subscriptionManager.selectedPlan {
                                        Text("Subscribe to \(plan.displayName)")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                    } else {
                                        Text("Select a Plan")
                                            .font(.system(size: 18, weight: .semibold))
                                            .foregroundStyle(.white)
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .frame(height: 56)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(subscriptionManager.selectedPlan != nil ? Color.blue : Color.gray.opacity(0.3))
                            )
                        }
                        .disabled(isLoading || subscriptionManager.selectedPlan == nil || revenueCatManager.isLoading)
                        .padding(.horizontal, 20)
                        
                        // Restore Purchases Button
                        Button(action: {
                            restorePurchases()
                        }) {
                            Text("Restore Purchases")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(.white.opacity(0.7))
                        }
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
        .onAppear {
            // Load offerings when view appears
            if revenueCatManager.offerings == nil {
                revenueCatManager.loadOfferings()
            }
        }
    }
    
    private func purchaseSubscription() {
        guard let plan = subscriptionManager.selectedPlan else { return }
        
        // Use RevenueCat package if available, otherwise fallback
        if let package = subscriptionManager.selectedPackage {
            isLoading = true
            errorMessage = nil
            
            revenueCatManager.purchase(package: package) { success, error in
                DispatchQueue.main.async {
                    self.isLoading = false
                    
                    if success {
                        self.dismiss()
                    } else if let error = error {
                        self.errorMessage = error.localizedDescription
                    }
                }
            }
        } else {
            // Fallback: simulate purchase (should not happen if RevenueCat is properly configured)
            isLoading = true
            errorMessage = nil
            
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
    
    private func restorePurchases() {
        isLoading = true
        errorMessage = nil
        
        revenueCatManager.restorePurchases { success, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if success {
                    self.dismiss()
                } else if let error = error {
                    self.errorMessage = error.localizedDescription
                }
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
    
    static func fromRevenueCatPackage(_ package: RevenueCat.Package) -> SubscriptionPlan? {
        let storeProduct = package.storeProduct
        let productId = package.identifier
        
        // Determine tier from product identifier
        let tier: SubscriptionTier
        let displayName: String
        let features: [String]
        
        if productId.contains("unlimited") || productId.contains("Unlimited") {
            tier = .unlimited
            displayName = "Unlimited"
            features = [
                "Everything in Pro",
                "Access to Unlimited tier content",
                "Priority support",
                "Early access to new features"
            ]
        } else if productId.contains("pro") || productId.contains("Pro") {
            tier = .pro
            displayName = "Pro"
            features = [
                "Access to Pro characters",
                "Access to Pro backgrounds",
                "Access to Pro costumes",
                "Unlimited conversations"
            ]
        } else {
            // Default to pro if unclear
            tier = .pro
            displayName = "Pro"
            features = [
                "Access to Pro characters",
                "Access to Pro backgrounds",
                "Access to Pro costumes",
                "Unlimited conversations"
            ]
        }
        
        // Get localized price string
        // Format price manually using price (Decimal) and currencyCode
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = storeProduct.currencyCode
        formatter.locale = Locale.current
        let priceString = formatter.string(from: storeProduct.price as NSDecimalNumber) ?? "$0.00"
        
        // Determine period suffix
        var finalPriceString = priceString
        if let period = storeProduct.subscriptionPeriod {
            switch period.unit {
            case .month:
                finalPriceString = "\(priceString)/month"
            case .year:
                finalPriceString = "\(priceString)/year"
            case .week:
                finalPriceString = "\(priceString)/week"
            default:
                finalPriceString = priceString
            }
        }
        
        return SubscriptionPlan(
            id: productId,
            displayName: displayName,
            tier: tier,
            price: finalPriceString,
            features: features,
            isRecommended: false
        )
    }
    
    static let defaultPlans: [SubscriptionPlan] = [
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
    @Published var selectedPackage: RevenueCat.Package?
    
    private init() {
        // Load subscription tier from UserDefaults
        if let savedTier = UserDefaults.standard.string(forKey: "subscription.tier"),
           let tier = SubscriptionTier(rawValue: savedTier) {
            currentTier = tier
        }
        
        // Refresh from RevenueCat on init
        RevenueCatManager.shared.refreshCustomerInfo()
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

