import CoreGraphics
@testable import UrbanHarvest

/// A 0.1 × 0.1 detection centered on (x, y).
func detection(_ x: CGFloat, _ y: CGFloat, _ bucket: FruitBucket = .good, label: String? = nil) -> FruitDetection {
    FruitDetection(
        label: label ?? (bucket == .good ? "fresh" : "rotten"),
        bucket: bucket,
        confidence: 0.9,
        boundingBox: CGRect(x: x - 0.05, y: y - 0.05, width: 0.1, height: 0.1)
    )
}

/// Predictor whose answer is looked up from a closure, for deterministic ranking tests.
final class StubPredictor: YieldPredicting, @unchecked Sendable {
    let isDemo = true
    let target: PredictionTarget
    private let function: (AdvisorInput) -> Double
    private(set) var calls: [AdvisorInput] = []

    init(target: PredictionTarget, _ function: @escaping (AdvisorInput) -> Double) {
        self.target = target
        self.function = function
    }

    func predict(_ input: AdvisorInput) throws -> Double {
        calls.append(input)
        return function(input)
    }
}
