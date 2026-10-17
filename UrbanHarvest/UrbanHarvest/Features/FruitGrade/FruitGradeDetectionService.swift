import CoreImage
import CoreVideo
import ImageIO
import SwiftUI

/// Runs the injected detector for FruitGrade: still photos and a live camera feed.
@MainActor
@Observable
final class FruitGradeDetectionService {
    enum LiveFeed: Equatable {
        case camera
        /// No camera (e.g. the Simulator) but the demo detector needs no pixels.
        case simulated
        case unavailable
    }

    enum AnalysisError: LocalizedError {
        case unreadableImage

        var errorDescription: String? { "The image could not be read." }
    }

    static let noFruitMessage = "The model couldn't find an apple, banana, guava, lime, orange or pomegranate in this image."

    /// Highest-confidence detection in the latest live frame.
    private(set) var liveTop: FruitDetection?
    private(set) var frameSize = CGSize(width: 720, height: 1280)
    private(set) var liveFeed: LiveFeed = .unavailable

    let camera = CameraManager()
    let modelName: String
    private let detector: FruitDetecting
    private let processor: LiveFrameProcessor
    private var simulatedTimer: DispatchSourceTimer?

    var isDemo: Bool { detector.isDemo }

    init(detector: FruitDetecting, modelName: String) {
        self.detector = detector
        self.modelName = modelName
        let processor = LiveFrameProcessor(detector: detector)
        self.processor = processor

        camera.onFrame = { @Sendable [weak self] buffer, orientation in
            guard let result = processor.process(buffer, orientation: orientation) else { return }
            Task { @MainActor [weak self] in
                self?.applyLive(result)
            }
        }
    }

    // MARK: Still photos

    /// Returns `nil` when the model finds no fruit in the image.
    func analyze(image: UIImage, mode: FruitGradeMode) async throws -> FruitGradeDetection? {
        guard let input = image.visionInput else { throw AnalysisError.unreadableImage }
        let detector = self.detector
        let cgImage = input.image
        let orientation = input.orientation
        let detections = try await Task.detached(priority: .userInitiated) {
            try detector.detect(image: cgImage, orientation: orientation)
        }.value

        guard let top = detections.max(by: { $0.confidence < $1.confidence }) else { return nil }
        return FruitGradeDetection(top: top, detectedCount: detections.count, image: image, mode: mode, modelName: modelName)
    }

    // MARK: Live

    func startLive() {
        if CameraManager.isCameraAvailable {
            liveFeed = .camera
            camera.start()
        } else if detector.isDemo {
            liveFeed = .simulated
            startSimulatedFeed()
        } else {
            liveFeed = .unavailable
        }
    }

    func stopLive() {
        camera.stop()
        stopSimulatedFeed()
        processor.clear()
        liveTop = nil
    }

    /// Still image of the most recent live frame, for the shutter button.
    func captureFrame() -> UIImage? {
        processor.latestImage()
    }

    private func applyLive(_ result: LiveFrameProcessor.Result) {
        guard liveFeed != .unavailable else { return }
        liveTop = result.detections.max(by: { $0.confidence < $1.confidence })
        if result.frameSize != frameSize {
            frameSize = result.frameSize
        }
    }

    /// Feeds a blank portrait frame ~15 times a second so the demo detector works without a camera.
    private func startSimulatedFeed() {
        guard simulatedTimer == nil,
              let blank = LiveFrameProcessor.makeBlankPixelBuffer(width: 72, height: 128) else { return }
        let processor = self.processor
        // Created once and only ever read on the timer queue.
        nonisolated(unsafe) let buffer = blank
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "UrbanHarvest.fruitGrade.simulatedFeed"))
        timer.schedule(deadline: .now(), repeating: .milliseconds(66))
        timer.setEventHandler { @Sendable [weak self] in
            guard let result = processor.process(buffer, orientation: .up) else { return }
            Task { @MainActor [weak self] in
                self?.applyLive(result)
            }
        }
        timer.resume()
        simulatedTimer = timer
    }

    private func stopSimulatedFeed() {
        simulatedTimer?.cancel()
        simulatedTimer = nil
    }
}

/// Runs detection on camera frames (background queue) and keeps the latest frame for capture.
private final class LiveFrameProcessor: @unchecked Sendable {
    struct Result {
        var detections: [FruitDetection]
        /// Upright frame size in pixels.
        var frameSize: CGSize
    }

    private let detector: FruitDetecting
    private let lock = NSLock()
    private var latest: (buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation)?
    private let context = CIContext()

    init(detector: FruitDetecting) {
        self.detector = detector
    }

    func process(_ buffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) -> Result? {
        lock.withLock { latest = (buffer, orientation) }
        guard let detections = try? detector.detect(pixelBuffer: buffer, orientation: orientation) else { return nil }

        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        let sideways: [CGImagePropertyOrientation] = [.left, .right, .leftMirrored, .rightMirrored]
        let size = sideways.contains(orientation)
            ? CGSize(width: height, height: width)
            : CGSize(width: width, height: height)
        return Result(detections: detections, frameSize: size)
    }

    func latestImage() -> UIImage? {
        guard let frame = lock.withLock({ latest }) else { return nil }
        let image = CIImage(cvPixelBuffer: frame.buffer).oriented(frame.orientation)
        guard let cgImage = context.createCGImage(image, from: image.extent) else { return nil }
        return UIImage(cgImage: cgImage)
    }

    func clear() {
        lock.withLock { latest = nil }
    }

    static func makeBlankPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        return status == kCVReturnSuccess ? buffer : nil
    }
}
