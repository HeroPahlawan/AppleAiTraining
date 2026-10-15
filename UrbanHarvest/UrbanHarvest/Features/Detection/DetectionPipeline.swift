import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// Detector → tracker → counter for live frames. Thread-safe: frames arrive
/// on the camera queue, while start/pause/reset come from the main thread.
final class DetectionPipeline: @unchecked Sendable {
    struct Snapshot {
        var visible: [TrackedFruit]
        var countedIDs: Set<Int>
        var counts: FruitCounts
        /// Upright frame size in pixels.
        var frameSize: CGSize
    }

    private let detector: FruitDetecting
    private let lock = NSLock()
    private var tracker: CentroidTracker
    private var counter: FruitCounter
    private var running = false

    init(detector: FruitDetecting, config: CountingConfig) {
        self.detector = detector
        self.tracker = CentroidTracker(config: config)
        self.counter = FruitCounter(config: config)
    }

    var isRunning: Bool {
        get { lock.withLock { running } }
        set { lock.withLock { running = newValue } }
    }

    func update(config: CountingConfig) {
        lock.withLock {
            tracker.maxMatchDistance = CGFloat(config.maxMatchDistance)
            tracker.maxMissedFrames = config.maxMissedFrames
            counter.config = config
        }
    }

    func reset() {
        lock.withLock {
            tracker.reset()
            counter.reset()
        }
    }

    /// Returns `nil` while paused or when detection fails.
    func process(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Snapshot? {
        guard isRunning else { return nil }
        guard let detections = try? detector.detect(pixelBuffer: pixelBuffer, orientation: orientation) else {
            return nil
        }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let sideways: [CGImagePropertyOrientation] = [.left, .right, .leftMirrored, .rightMirrored]
        let rotated = sideways.contains(orientation)
        let frameSize = rotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height)

        return lock.withLock { () -> Snapshot? in
            // Paused while detection was running: drop the frame.
            guard running else { return nil }
            let visible = tracker.update(with: detections)
            counter.process(visible)
            let counted = Set(visible.map(\.id).filter(counter.isCounted))
            return Snapshot(visible: visible, countedIDs: counted, counts: counter.counts, frameSize: frameSize)
        }
    }
}
