import SwiftUI

// MARK: - Top Right Control Buttons
struct ControlButtonsView: View {
    let onRoomTap: () -> Void
    let onDanceTap: () -> Void
    let onLoveTap: () -> Void
    let onCostumeTap: () -> Void
    let onCameraTap: () -> Void
    let showChatList: Bool
    let hasMessages: Bool
    let onToggleChat: () -> Void
    
    var body: some View {
        VStack(spacing: 6) {
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onRoomTap()
            }) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .clipShape(Circle())
            
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onDanceTap()
            }) {
                Image(systemName: "shuffle")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .clipShape(Circle())
            
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onLoveTap()
            }) {
                Image(systemName: "heart")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .clipShape(Circle())
            
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onCostumeTap()
            }) {
                Image(systemName: "tshirt")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .clipShape(Circle())
            
            Button(action: {
                let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                impactFeedback.impactOccurred()
                onCameraTap()
            }) {
                Image(systemName: "camera")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(width: 32, height: 32)
                    .contentShape(Circle())
            }
            .buttonStyle(.glass)
            .buttonBorderShape(.circle)
            .clipShape(Circle())
            
            if hasMessages {
                Button(action: {
                    let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
                    impactFeedback.impactOccurred()
                    onToggleChat()
                }) {
                    Image(systemName: showChatList ? "xmark" : "text.bubble.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .contentShape(Circle())
                }
                .buttonStyle(.glass)
                .buttonBorderShape(.circle)
                .clipShape(Circle())
            }
        }
        .padding(.trailing, 8)
        .padding(.top, 6)
    }
}

// MARK: - Save Toast
struct SaveToastView: View {
    let isVisible: Bool
    
    var body: some View {
        if isVisible {
            Text("Saved to Photos")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.black)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(Color.white)
                .clipShape(Capsule())
                .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
                .padding(.top, 0)
                .offset(y: -16)
        }
    }
}

