import Foundation

@MainActor
final class AdvisorViewModel: ObservableObject {
    @Published var input = AdvisorInput.default {
        didSet {
            guard input != oldValue else { return }
            advisories = AdvisoryRules.evaluate(input)
            // A result for different inputs would be misleading.
            result = nil
            aiSummary = nil
            aiEnglishSummary = nil
            isUsingFoundationModel = false
        }
    }

    @Published private(set) var result: WhatIfResult?
    @Published private(set) var advisories: [Advisory] = AdvisoryRules.evaluate(.default)
    @Published private(set) var aiSummary: String?
    @Published private(set) var aiEnglishSummary: String?
    @Published private(set) var isUsingFoundationModel = false
    @Published private(set) var isAnalyzing = false
    @Published var errorMessage: String?

    var analyzer = WhatIfAnalyzer()

    var validationError: String? {
        FeatureSchema.validationError(for: input)
    }

    func analyze(using predictor: YieldPredicting) async {
        guard validationError == nil else { return }
        isAnalyzing = true
        errorMessage = nil
        defer { isAnalyzing = false }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), FoundationModelAdvisor.shared.isAvailable {
            do {
                let analysis = try await FoundationModelAdvisor.shared.analyze(input: input)
                result = analysis.result
                advisories = analysis.advisories
                aiSummary = analysis.summary
                aiEnglishSummary = analysis.englishSummary
                isUsingFoundationModel = true
                errorMessage = nil
                return
            } catch {
                // If on-device foundation model encounters an issue, fall back gracefully
                print("Foundation model analysis error: \(error), falling back to rule analyzer")
            }
        }
        #endif

        // Fallback to standard tabular predictor and rules
        do {
            result = try analyzer.analyze(input, using: predictor)
            advisories = AdvisoryRules.evaluate(input)
            aiSummary = nil
            aiEnglishSummary = nil
            isUsingFoundationModel = false
            errorMessage = nil
        } catch {
            result = nil
            errorMessage = "Prediksi gagal: \(error.localizedDescription)"
        }
    }

    func resetInput() {
        input = .default
        result = nil
        aiSummary = nil
        aiEnglishSummary = nil
        isUsingFoundationModel = false
        errorMessage = nil
    }
}
