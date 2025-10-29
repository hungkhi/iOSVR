import SwiftUI

struct CharacterCardView: View {
    let item: CharacterItem
    private let cornerRadius: CGFloat = 20
    // Match ContentView paddings/spacings to keep width under 50%
    private let horizontalPadding: CGFloat = 16
    private let interItemSpacing: CGFloat = 16
    private let contentPadding: CGFloat = 16

    var body: some View {
        let screenWidth = UIScreen.main.bounds.width
        let targetWidth = max(0, (screenWidth - horizontalPadding * 2 - interItemSpacing) / 2.0)

        ZStack(alignment: .bottomLeading) {
            // Image background
            ZStack(alignment: .topLeading) {
                if let urlStr = item.thumbnail_url, let url = URL(string: urlStr) {
                    AsyncImage(url: url) { phase in
                        switch phase {
                        case .success(let image):
                            image
                                .resizable()
                                .scaledToFill() // crop to fill card
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .clipped()
                        case .failure(_):
                            Color.white.opacity(0.06)
                        case .empty:
                            ZStack { Color.white.opacity(0.06); ProgressView().tint(.white) }
                        @unknown default:
                            Color.white.opacity(0.06)
                        }
                    }
                } else {
                    Color.white.opacity(0.06)
                }
                Text("18+")
                    .font(.system(size: 12, weight: .bold))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .background(Color.black.opacity(0.35))
                    .foregroundStyle(.white)
                    .clipShape(Capsule())
                    // Position badge away from edges; slightly reduce top padding
                    .padding(.leading, contentPadding + 20)
                    .padding(.top, contentPadding )
            }

            // Gradient and text
            LinearGradient(
                colors: [Color.black.opacity(0.0), Color.black.opacity(0.85)],
                startPoint: .top,
                endPoint: .bottom
            )
            // Ensure the gradient covers full card width so it doesn't affect text layout
            .frame(maxWidth: .infinity)
            .frame(height: 180)

            VStack(alignment: .leading, spacing: 6) {
                Text(item.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.white)
                    .shadow(color: .black.opacity(0.5), radius: 3, x: 0, y: 2)
                    .multilineTextAlignment(.leading)
                    .lineLimit(2)
                if let d = item.description, !d.isEmpty {
                    Text(d)
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.9))
                        .multilineTextAlignment(.leading)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            // Extra horizontal padding prevents glyph overhang (e.g., "S") from being clipped by rounded edges
            .padding(.horizontal, contentPadding + 20)
            .padding(.bottom, contentPadding + 6)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        // Force width less than 50% accounting for outer paddings and spacing
        .frame(width: targetWidth, height: targetWidth * 1.3)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .contentShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
    }
}


