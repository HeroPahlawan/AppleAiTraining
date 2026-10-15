import CoreML

/// Runs a Create ML tabular regressor.
///
/// Inputs are built from `FeatureSchema` and converted to whatever type the
/// model declares for each column (text, Double or Int), so it does not matter
/// how Create ML inferred the column types.
final class CoreMLYieldPredictor: YieldPredicting, @unchecked Sendable {
    let isDemo = false
    let target: PredictionTarget

    private let model: MLModel
    private let outputName: String

    /// - Parameter configuredTarget: from ClassMapping.json; `nil` = detect from the model's output name.
    init(model: MLModel, configuredTarget: PredictionTarget?) {
        self.model = model

        let outputs = model.modelDescription.outputDescriptionsByName
        let numericOutputs = outputs.values
            .filter { $0.type == .double || $0.type == .int64 }
            .map(\.name)
            .sorted()

        let detected = PredictionTarget.allCases.first { outputs[$0.rawValue] != nil }
        let target = configuredTarget ?? detected ?? .defectRate
        self.target = target

        if outputs[target.rawValue] != nil {
            outputName = target.rawValue
        } else {
            outputName = model.modelDescription.predictedFeatureName ?? numericOutputs.first ?? target.rawValue
        }
    }

    func predict(_ input: AdvisorInput) throws -> Double {
        let provider = try MLDictionaryFeatureProvider(dictionary: modelInputs(for: input))
        let output = try model.prediction(from: provider)

        guard let value = output.featureValue(for: outputName) else {
            throw PredictionError.missingOutput(outputName)
        }
        let number: Double
        switch value.type {
        case .double: number = value.doubleValue
        case .int64: number = Double(value.int64Value)
        default: throw PredictionError.invalidValue
        }
        guard number.isFinite else { throw PredictionError.invalidValue }
        return min(max(number, target.validRange.lowerBound), target.validRange.upperBound)
    }

    private func modelInputs(for input: AdvisorInput) -> [String: MLFeatureValue] {
        let features = FeatureSchema.features(from: input)
        var result: [String: MLFeatureValue] = [:]

        for (name, description) in model.modelDescription.inputDescriptionsByName {
            guard let raw = features[name] else { continue }
            switch description.type {
            case .string:
                result[name] = MLFeatureValue(string: "\(raw)")
            case .double:
                if let number = raw as? Double { result[name] = MLFeatureValue(double: number) }
            case .int64:
                if let number = raw as? Double { result[name] = MLFeatureValue(int64: Int64(number.rounded())) }
            default:
                continue
            }
        }
        return result
    }
}
