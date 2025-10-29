import CoreMotion
import SwiftUI

// MARK: - Parallax Controller: translates device tilt to dx/dy
final class ParallaxController {
    private let motion = CMMotionManager()
    private let onUpdate: (_ dx: CGFloat, _ dy: CGFloat) -> Void
    private var running: Bool = false

    init(onUpdate: @escaping (_ dx: CGFloat, _ dy: CGFloat) -> Void) {
        self.onUpdate = onUpdate
    }

    func start() {
        guard !running else { return }
        running = true
        guard motion.isDeviceMotionAvailable else { return }
        motion.deviceMotionUpdateInterval = 1.0 / 60.0
        motion.startDeviceMotionUpdates(to: .main) { [weak self] data, _ in
            guard let self, self.running, let dm = data else { return }
            let g = dm.gravity
            let maxTilt: Double = 0.35
            let tiltX = max(-maxTilt, min(maxTilt, g.x))
            let tiltY = max(-maxTilt, min(maxTilt, g.y))
            let translateX = CGFloat(tiltX) * 70
            self.onUpdate(translateX, 0)
        }
    }

    func stop() {
        guard running else { return }
        running = false
        motion.stopDeviceMotionUpdates()
    }
}


