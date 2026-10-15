import Foundation

/// The inputs a farmer can change. Weather and field size are never varied.
enum ControllableFactor: String, CaseIterable, Identifiable {
    case irrigation
    case harvestTiming

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .irrigation: return "Irigasi"
        case .harvestTiming: return "Waktu panen"
        }
    }
}

/// A single change to ONE controllable input.
enum ControllableChange: Hashable {
    case irrigation(from: IrrigationLevel, to: IrrigationLevel)
    case harvestTiming(from: HarvestTiming, to: HarvestTiming)

    var factor: ControllableFactor {
        switch self {
        case .irrigation: return .irrigation
        case .harvestTiming: return .harvestTiming
        }
    }

    func applied(to input: AdvisorInput) -> AdvisorInput {
        var copy = input
        switch self {
        case .irrigation(_, let to): copy.irrigation = to
        case .harvestTiming(_, let to): copy.harvestTiming = to
        }
        return copy
    }

    /// Every alternative value for every controllable input, one at a time.
    static func alternatives(for input: AdvisorInput) -> [ControllableChange] {
        let irrigation = IrrigationLevel.allCases
            .filter { $0 != input.irrigation }
            .map { ControllableChange.irrigation(from: input.irrigation, to: $0) }
        let timing = HarvestTiming.allCases
            .filter { $0 != input.harvestTiming }
            .map { ControllableChange.harvestTiming(from: input.harvestTiming, to: $0) }
        return irrigation + timing
    }
}

/// One what-if scenario: the prediction if only `change` were made.
struct WhatIfSuggestion: Identifiable, Equatable {
    let change: ControllableChange
    let target: PredictionTarget
    let baseline: Double
    let predicted: Double

    var id: ControllableChange { change }

    /// Positive = better, in target units (percentage points or kg/m²).
    var improvement: Double {
        target.higherIsBetter ? predicted - baseline : baseline - predicted
    }
}

struct WhatIfResult: Equatable {
    let input: AdvisorInput
    let target: PredictionTarget
    let baseline: Double
    /// Best changes first, at most `maxSuggestions`, each better than the baseline.
    let suggestions: [WhatIfSuggestion]
    /// Every scenario that was evaluated, best first.
    let allScenarios: [WhatIfSuggestion]
}

/// Re-runs the predictor with each controllable input changed one at a time,
/// keeping weather and field size fixed, and ranks the results.
struct WhatIfAnalyzer {
    var maxSuggestions = 3
    /// Smallest improvement worth suggesting. `nil` uses a per-target default.
    var minimumImprovement: Double?

    func analyze(_ input: AdvisorInput, using predictor: YieldPredicting) throws -> WhatIfResult {
        let target = predictor.target
        let baseline = try predictor.predict(input)

        var scenarios: [WhatIfSuggestion] = []
        for change in ControllableChange.alternatives(for: input) {
            let predicted = try predictor.predict(change.applied(to: input))
            scenarios.append(WhatIfSuggestion(change: change, target: target, baseline: baseline, predicted: predicted))
        }

        // Stable sort: on ties, keep the declaration order (irrigation before timing).
        let ranked = scenarios.enumerated()
            .sorted { lhs, rhs in
                if lhs.element.improvement != rhs.element.improvement {
                    return lhs.element.improvement > rhs.element.improvement
                }
                return lhs.offset < rhs.offset
            }
            .map(\.element)

        let threshold = minimumImprovement ?? Self.defaultMinimumImprovement(for: target)
        let suggestions = Array(ranked.filter { $0.improvement >= threshold }.prefix(max(0, maxSuggestions)))

        return WhatIfResult(input: input, target: target, baseline: baseline, suggestions: suggestions, allScenarios: ranked)
    }

    static func defaultMinimumImprovement(for target: PredictionTarget) -> Double {
        switch target {
        case .defectRate: return 0.5      // half a percentage point
        case .yieldPerArea: return 0.05   // 50 g per m²
        }
    }
}
