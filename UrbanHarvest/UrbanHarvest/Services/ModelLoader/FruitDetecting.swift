import CoreGraphics
import CoreVideo
import ImageIO

/// One detected fruit in a single frame.
struct FruitDetection: Equatable {
    /// Raw label from the model (e.g. "rotten_apple").
    var label: String
    var bucket: FruitBucket
    var confidence: Float
    /// Normalized (0...1) rectangle, origin at the TOP-LEFT of the upright image.
    var boundingBox: CGRect

    var center: CGPoint { CGPoint(x: boundingBox.midX, y: boundingBox.midY) }
}

/// Anything that can find fruit in an image. Implemented by the Core ML
/// detector and by the demo-mode mock, so they are interchangeable.
///
/// Methods are synchronous and are called from a background queue.
protocol FruitDetecting: AnyObject, Sendable {
    /// True for the mock (shows the "Demo mode" badge).
    var isDemo: Bool { get }

    /// A frame from the live camera. Called repeatedly; implementations may keep state between frames.
    func detect(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [FruitDetection]

    /// A single still photo.
    func detect(image: CGImage, orientation: CGImagePropertyOrientation) throws -> [FruitDetection]
}
