import SwiftUI

// MARK: - Minimal Waveforms
struct WaveformView: View {
    var samples: [Float]
    var body: some View {
        GeometryReader { geo in
            let barWidth: CGFloat = max(2, geo.size.width / CGFloat(max(1, samples.count)) - 2)
            let maxHeight = geo.size.height
            HStack(alignment: .center, spacing: 2) {
                ForEach(Array(samples.enumerated()), id: \.offset) { _, s in
                    Capsule()
                        .fill(Color.black.opacity(0.8))
                        .frame(width: barWidth, height: max(2, CGFloat(max(0.05, CGFloat(s))) * maxHeight))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
    }
}

struct RecordingWaveformView: View {
    var samples: [Float]
    var body: some View {
        GeometryReader { geo in
            let count = max(20, samples.count)
            let display = Array(samples.suffix(30))
            let maxHeight = geo.size.height
            HStack(spacing: 3) {
                ForEach(0..<min(30, count), id: \.self) { i in
                    let s: CGFloat = display.isEmpty ? 0.2 : CGFloat(display[display.index(display.startIndex, offsetBy: i % display.count)])
                    Capsule()
                        .fill(Color.black.opacity(0.85))
                        .frame(width: 4, height: max(3, s * maxHeight))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.white.opacity(0.08))
            .clipShape(Capsule())
        }
    }
}

