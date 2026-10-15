import Foundation

/// Demo-mode predictor: a simple hand-written rule set.
///
/// The same formula (plus noise) generated `sample_training_data.csv`
/// (see scripts/generate_sample_csv.py), so a model trained on that CSV
/// behaves roughly like this mock.
final class MockYieldPredictor: YieldPredicting, @unchecked Sendable {
    let isDemo = true
    let target: PredictionTarget

    init(target: PredictionTarget = .defectRate) {
        self.target = target
    }

    func predict(_ input: AdvisorInput) throws -> Double {
        switch target {
        case .defectRate: return HarvestFormula.defectRate(input)
        case .yieldPerArea: return HarvestFormula.yieldPerArea(input)
        }
    }
}

/// Rule-of-thumb harvest model. Keep in sync with scripts/generate_sample_csv.py.
enum HarvestFormula {
    /// Defect rate in percent (1...60).
    static func defectRate(_ input: AdvisorInput) -> Double {
        var rate: Double
        switch input.fruitType {
        case .apple: rate = 8
        case .orange: rate = 9
        case .mango: rate = 11
        case .tomato: rate = 12
        case .banana: rate = 10
        case .strawberry: rate = 15
        }

        switch input.rainfall {
        case .low: break
        case .medium: rate += 2
        case .high: rate += 6
        }

        switch input.temperature {
        case .cool: rate -= 1
        case .normal: break
        case .hot: rate += 4
        }

        switch input.sky {
        case .sunny: break
        case .cloudy: rate += 1
        case .rainy: rate += 4
        }

        switch input.irrigation {
        case .low: rate += input.rainfall == .low ? 4 : 2       // water stress, cracking
        case .medium: break
        case .high: rate += input.rainfall == .high ? 6 : 1     // waterlogging, rot
        }

        switch input.harvestTiming {
        case .early: rate -= 2
        case .onTime: break
        case .late:
            rate += 7                                           // overripe, rot
            if input.temperature == .hot { rate += 3 }
            if input.sky == .rainy { rate += 2 }
        }

        // Larger fields are harder to harvest on time.
        let area = max(input.fieldAreaM2, 1)
        rate += min(max(1.5 * log10(area / 1_000), -1.5), 4.5)

        return min(max(rate, 1), 60)
    }

    /// Yield in kg per square metre.
    static func yieldPerArea(_ input: AdvisorInput) -> Double {
        var value: Double
        switch input.fruitType {
        case .apple: value = 3.0
        case .orange: value = 2.5
        case .mango: value = 2.0
        case .tomato: value = 6.0
        case .banana: value = 4.0
        case .strawberry: value = 1.5
        }

        switch input.rainfall {
        case .low: value *= input.irrigation == .low ? 0.75 : 0.9
        case .medium: break
        case .high: value *= 0.95
        }

        switch input.temperature {
        case .cool: value *= 0.9
        case .normal: break
        case .hot: value *= 0.88
        }

        switch input.sky {
        case .sunny: value *= 1.05
        case .cloudy: break
        case .rainy: value *= 0.92
        }

        switch input.irrigation {
        case .low: value *= 0.85
        case .medium: break
        case .high: value *= input.rainfall == .high ? 0.95 : 1.05
        }

        switch input.harvestTiming {
        case .early: value *= 0.88
        case .onTime: break
        case .late: value *= 0.93
        }

        // Defective fruit is partly lost.
        value *= 1 - defectRate(input) / 100 * 0.5
        return (value * 100).rounded() / 100
    }
}
