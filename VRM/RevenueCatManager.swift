import Foundation
import Combine
import RevenueCat

class RevenueCatManager: ObservableObject {
    static let shared = RevenueCatManager()
    
    @Published var offerings: Offerings?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var customerInfo: CustomerInfo?
    
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        configureRevenueCat()
    }
    
    func configureRevenueCat() {
        // TODO: Replace with your actual RevenueCat API key
        // You can find this in your RevenueCat dashboard under Project Settings > API Keys
        guard let apiKey = getRevenueCatAPIKey() else {
            print("RevenueCat: API key not found")
            return
        }
        
        Purchases.configure(withAPIKey: apiKey)
        Purchases.shared.delegate = self
        
        // Set user ID if available
        if let userId = AuthManager.shared.user?.id.uuidString {
            Purchases.shared.logIn(userId) { customerInfo, created, error in
                if let error = error {
                    print("RevenueCat: Login error: \(error.localizedDescription)")
                } else {
                    print("RevenueCat: User logged in")
                    self.customerInfo = customerInfo
                    self.updateSubscriptionStatus(from: customerInfo)
                }
            }
        }
        
        // Fetch offerings
        loadOfferings()
    }
    
    private func getRevenueCatAPIKey() -> String? {
        // Try to get from Info.plist first
        if let apiKey = Bundle.main.object(forInfoDictionaryKey: "RevenueCatAPIKey") as? String, !apiKey.isEmpty {
            return apiKey
        }
        
        // Try environment variable
        if let apiKey = ProcessInfo.processInfo.environment["REVENUECAT_API_KEY"], !apiKey.isEmpty {
            return apiKey
        }
        
        // RevenueCat Public SDK Key (found via MCP)
        // This is the production key for iOS
        return "appl_UZSSZyNxPxQZiXaJZqZluopRHdR"
    }
    
    func loadOfferings() {
        isLoading = true
        errorMessage = nil
        
        Purchases.shared.getOfferings { offerings, error in
            DispatchQueue.main.async {
                self.isLoading = false
                
                if let error = error {
                    self.errorMessage = error.localizedDescription
                    print("RevenueCat: Error fetching offerings: \(error.localizedDescription)")
                } else if let offerings = offerings {
                    self.offerings = offerings
                    print("RevenueCat: Loaded \(offerings.all.count) offerings")
                    
                    // Also refresh customer info
                    self.refreshCustomerInfo()
                }
            }
        }
    }
    
    func refreshCustomerInfo() {
        Purchases.shared.getCustomerInfo { customerInfo, error in
            DispatchQueue.main.async {
                if let error = error {
                    print("RevenueCat: Error fetching customer info: \(error.localizedDescription)")
                } else if let customerInfo = customerInfo {
                    self.customerInfo = customerInfo
                    self.updateSubscriptionStatus(from: customerInfo)
                }
            }
        }
    }
    
    private func updateSubscriptionStatus(from customerInfo: CustomerInfo?) {
        guard let customerInfo = customerInfo else { return }
        
        // Determine tier from RevenueCat entitlements
        let tier: SubscriptionTier
        if customerInfo.entitlements.all["unlimited"]?.isActive == true {
            tier = .unlimited
        } else if customerInfo.entitlements.all["pro"]?.isActive == true {
            tier = .pro
        } else {
            tier = .free
        }
        
        SubscriptionManager.shared.updateTier(tier)
        print("RevenueCat: Updated subscription tier to \(tier.rawValue)")
    }
    
    func purchase(package: RevenueCat.Package, completion: @escaping (Bool, Error?) -> Void) {
        Purchases.shared.purchase(package: package) { transaction, customerInfo, error, userCancelled in
            DispatchQueue.main.async {
                if userCancelled {
                    completion(false, nil)
                    return
                }
                
                if let error = error {
                    completion(false, error)
                    return
                }
                
                if let customerInfo = customerInfo {
                    self.customerInfo = customerInfo
                    self.updateSubscriptionStatus(from: customerInfo)
                    completion(true, nil)
                } else {
                    completion(false, NSError(domain: "RevenueCat", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                }
            }
        }
    }
    
    func restorePurchases(completion: @escaping (Bool, Error?) -> Void) {
        Purchases.shared.restorePurchases { customerInfo, error in
            DispatchQueue.main.async {
                if let error = error {
                    completion(false, error)
                    return
                }
                
                if let customerInfo = customerInfo {
                    self.customerInfo = customerInfo
                    self.updateSubscriptionStatus(from: customerInfo)
                    completion(true, nil)
                } else {
                    completion(false, NSError(domain: "RevenueCat", code: -1, userInfo: [NSLocalizedDescriptionKey: "Unknown error"]))
                }
            }
        }
    }
}

extension RevenueCatManager: PurchasesDelegate {
    func purchases(_ purchases: Purchases, receivedUpdated customerInfo: CustomerInfo) {
        DispatchQueue.main.async {
            self.customerInfo = customerInfo
            self.updateSubscriptionStatus(from: customerInfo)
        }
    }
    
    func purchases(_ purchases: Purchases, readyForPromotedProduct product: StoreProduct, purchase startPurchase: @escaping StartPurchaseBlock) {
        // Handle promoted purchases if needed
        startPurchase { transaction, customerInfo, error, cancelled in
            // Handle purchase completion
        }
    }
}

