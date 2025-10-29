import SwiftUI

struct PulsingCircleView: View {
    // 0...1 volume from agent
    var volume: Double
    @State private var idle = false
    
    private var baseSize: CGFloat { 24 }
    private var scaleFromVolume: CGFloat { CGFloat(1.0 + min(max(volume, 0.0), 1.0) * 0.7) }
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.35))
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(idle ? 1.05 : 0.95)
                .opacity(0.6)
            Circle()
                .fill(Color.white.opacity(0.55))
                .frame(width: baseSize, height: baseSize)
                .scaleEffect(scaleFromVolume)
                .opacity(0.8)
            Circle()
                .fill(Color.white)
                .frame(width: baseSize, height: baseSize)
        }
        .animation(.easeOut(duration: 0.08), value: volume)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                idle.toggle()
            }
        }
    }
}

