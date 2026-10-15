import CoreGraphics
import CoreVideo
import Foundation
import ImageIO

/// Demo-mode detector. Ignores the pixels and returns random boxes.
///
/// For live frames the boxes drift down the screen like fruit passing under a
/// phone, so the tracker and the counting line behave realistically. For a
/// still photo it returns a random scatter of boxes.
final class MockFruitDetector: FruitDetecting, @unchecked Sendable {
    let isDemo = true

    private struct SimulatedFruit {
        var center: CGPoint
        var size: CGFloat
        var speed: CGFloat
        var drift: CGFloat
        var bucket: FruitBucket
        var confidence: Float
    }

    private let lock = NSLock()
    private var fruits: [SimulatedFruit] = []
    private var generator: SeededGenerator
    private let defectProbability: Double

    init(defectProbability: Double = 0.2, seed: UInt64 = UInt64.random(in: 0...UInt64.max)) {
        self.defectProbability = defectProbability
        self.generator = SeededGenerator(seed: seed)
    }

    func detect(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [FruitDetection] {
        lock.lock()
        defer { lock.unlock() }
        step()
        return fruits.map { detection(for: $0) }
    }

    func detect(image: CGImage, orientation: CGImagePropertyOrientation) throws -> [FruitDetection] {
        lock.lock()
        defer { lock.unlock() }
        let count = Int.random(in: 4...9, using: &generator)
        var result: [FruitDetection] = []
        for _ in 0..<count {
            let size = CGFloat.random(in: 0.12...0.2, using: &generator)
            let fruit = SimulatedFruit(
                center: CGPoint(
                    x: CGFloat.random(in: size...(1 - size), using: &generator),
                    y: CGFloat.random(in: size...(1 - size), using: &generator)
                ),
                size: size,
                speed: 0,
                drift: 0,
                bucket: randomBucket(),
                confidence: Float.random(in: 0.6...0.98, using: &generator)
            )
            result.append(detection(for: fruit))
        }
        return result
    }

    // MARK: Simulation

    private func step() {
        for index in fruits.indices {
            fruits[index].center.y += fruits[index].speed
            fruits[index].center.x += fruits[index].drift
        }
        fruits.removeAll { $0.center.y - $0.size / 2 > 1 }

        if fruits.count < 4, Double.random(in: 0...1, using: &generator) < 0.08 {
            let size = CGFloat.random(in: 0.12...0.18, using: &generator)
            fruits.append(
                SimulatedFruit(
                    center: CGPoint(x: CGFloat.random(in: 0.15...0.85, using: &generator), y: -size / 2),
                    size: size,
                    speed: CGFloat.random(in: 0.006...0.012, using: &generator),
                    drift: CGFloat.random(in: -0.001...0.001, using: &generator),
                    bucket: randomBucket(),
                    confidence: Float.random(in: 0.6...0.98, using: &generator)
                )
            )
        }
    }

    private func randomBucket() -> FruitBucket {
        Double.random(in: 0...1, using: &generator) < defectProbability ? .defect : .good
    }

    private func detection(for fruit: SimulatedFruit) -> FruitDetection {
        // Small jitter, like a real detector.
        let jitter = CGFloat.random(in: -0.004...0.004, using: &generator)
        let box = CGRect(
            x: fruit.center.x - fruit.size / 2 + jitter,
            y: fruit.center.y - fruit.size / 2 + jitter,
            width: fruit.size,
            height: fruit.size
        )
        return FruitDetection(
            label: fruit.bucket == .good ? "fresh" : "rotten",
            bucket: fruit.bucket,
            confidence: fruit.confidence,
            boundingBox: box
        )
    }
}
