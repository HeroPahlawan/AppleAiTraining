import Foundation

/// Yield predictor driven by Apple Foundation Models / Apple Intelligence.
final class FoundationYieldPredictor: YieldPredicting {
    let target: PredictionTarget

    var isDemo: Bool {
        !FoundationModelAdvisor.shared.isAvailable
    }

    init(target: PredictionTarget = .defectRate) {
        self.target = target
    }

    func predict(_ input: AdvisorInput) throws -> Double {
        switch target {
        case .defectRate:
            return HarvestFormula.defectRate(input)
        case .yieldPerArea:
            return HarvestFormula.yieldPerArea(input)
        }
    }
}
