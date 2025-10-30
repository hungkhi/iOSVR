import SwiftUI

struct PulsingCircleView: View {
    // 0...1 volume from agent
    var volume: Double
    @State private var idle = false
    
    private var baseSize: CGFloat { 24 }
    private var clampedVolume: Double { min(max(volume, 0.0), 1.0) }
    private var scaleFromVolume: CGFloat { CGFloat(1.0 + clampedVolume * 0.7) }
    private var overallOpacity: Double { 0.35 + clampedVolume * 0.65 }
    
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
        .opacity(overallOpacity)
        .offset(x: 4) // nudge slightly to the right
        .animation(.easeOut(duration: 0.08), value: clampedVolume)
        .onAppear {
            withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                idle.toggle()
            }
        }
    }
}

