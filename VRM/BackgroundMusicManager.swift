import Foundation
import AVFoundation

final class BackgroundMusicManager {
    static let shared = BackgroundMusicManager()

    private var player: AVPlayer?
    private let urlString: String = "https://pub-14a49f54cd754145a7362876730a1a52.r2.dev/sensual-escape-139637.mp3"

    private init() {}

    var isPlaying: Bool {
        guard let p = player else { return false }
        return p.timeControlStatus == .playing
    }

    private func ensurePlayer() {
        if player == nil, let url = URL(string: urlString) {
            player = AVPlayer(url: url)
            player?.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(forName: .AVPlayerItemDidPlayToEndTime, object: player?.currentItem, queue: .main) { [weak self] _ in
                self?.player?.seek(to: .zero)
                self?.player?.play()
            }
        }
    }

    func play() {
        ensurePlayer()
        guard let player else { return }
        #if canImport(UIKit)
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.ambient, options: [.mixWithOthers])
        try? session.setActive(true, options: [])
        #endif
        player.play()
    }

    func pause() {
        player?.pause()
    }

    @discardableResult
    func toggle() -> Bool {
        if isPlaying {
            pause()
            return false
        } else {
            play()
            return true
        }
    }
}


