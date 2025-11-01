import SwiftUI

struct ProBadge: View {
    let tier: SubscriptionTier
    
    var body: some View {
        Group {
            if tier != .free {
                Text(tier == .unlimited ? "Unlimited" : "Pro")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(
                        LinearGradient(
                            colors: tier == .unlimited 
                                ? [Color.purple, Color.blue]
                                : [Color.blue, Color.cyan],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
            }
        }
    }
}

