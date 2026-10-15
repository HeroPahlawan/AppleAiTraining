import Foundation

@MainActor
final class AdvisorViewModel: ObservableObject {
    @Published var input = AdvisorInput.default {
        didSet {
            guard input != oldValue else { return }
            advisories = AdvisoryRules.evaluate(input)
            // A result for different inputs would be misleading.
            result = nil
        }
    }

    @Published private(set) var result: WhatIfResult?
    @Published private(set) var advisories: [Advisory] = AdvisoryRules.evaluate(.default)
    @Published var errorMessage: String?

    var analyzer = WhatIfAnalyzer()

    var validationError: String? {
        FeatureSchema.validationError(for: input)
    }

    func analyze(using predictor: YieldPredicting) {
        guard validationError == nil else { return }
        do {
            result = try analyzer.analyze(input, using: predictor)
            errorMessage = nil
        } catch {
            result = nil
            errorMessage = "Prediksi gagal: \(error.localizedDescription)"
        }
    }

    func resetInput() {
        input = .default
    }
}
