import Foundation
#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26.0, *)
@Generable(description: "Laporan analisis panen berbasis model kecerdasan buatan")
struct FoundationHarvestReport {
    @Guide(description: "Perkiraan persentase buah cacat antara 1.0 sampai 90.0 persen untuk kondisi saat ini", .range(1.0...90.0))
    var estimatedDefectRate: Double

    @Guide(description: "Ringkasan analisis kondisi panen dalam bahasa Indonesia yang padat dan jelas (1-2 kalimat)")
    var summary: String

    @Guide(description: "Concise summary of harvest analysis in English (1-2 sentences)")
    var englishSummary: String

    @Guide(description: "Daftar 2 sampai 4 tips atau peringatan pertanian yang relevan")
    var advisories: [FoundationAdvisoryItem]

    @Guide(description: "Daftar 1 sampai 3 saran perubahan faktor panen untuk menurunkan persentase cacat")
    var suggestions: [FoundationSuggestionItem]
}

@available(iOS 26.0, *)
@Generable(description: "Item peringatan atau tips pertanian")
struct FoundationAdvisoryItem {
    @Guide(description: "Tingkat keparahan: 'info', 'warning', atau 'critical'")
    var severity: String

    @Guide(description: "Judul singkat dalam bahasa Indonesia")
    var title: String

    @Guide(description: "Pesan saran atau peringatan praktis dalam bahasa Indonesia")
    var message: String

    @Guide(description: "Short title in English")
    var englishTitle: String

    @Guide(description: "Practical advice or warning message in English")
    var englishMessage: String
}

@available(iOS 26.0, *)
@Generable(description: "Saran penyesuaian faktor panen")
struct FoundationSuggestionItem {
    @Guide(description: "Faktor yang diubah: 'irrigation' atau 'harvestTiming'")
    var factor: String

    @Guide(description: "Nilai pengaturan baru yang disarankan: 'low', 'medium', 'high', 'early', 'onTime', atau 'late'")
    var targetValue: String

    @Guide(description: "Perkiraan persentase cacat baru yang lebih rendah jika pengaturan ini diubah", .range(1.0...90.0))
    var improvedDefectRate: Double
}
#endif

/// Result package produced by the AI Advisor analysis.
struct FoundationAdvisorAnalysis: Sendable {
    var result: WhatIfResult
    var advisories: [Advisory]
    var summary: String
    var englishSummary: String
}

/// Provides AI-powered harvest recommendations, risk analysis, and yield predictions
/// using Apple's on-device FoundationModels framework.
final class FoundationModelAdvisor: Sendable {
    static let shared = FoundationModelAdvisor()

    private init() {}

    /// Checks if Apple's on-device SystemLanguageModel is available on the current device and OS.
    var isAvailable: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            return SystemLanguageModel.default.isAvailable
        }
        #endif
        return false
    }

    /// Generates structured harvest analysis using on-device FoundationModels.
    func analyze(input: AdvisorInput) async throws -> FoundationAdvisorAnalysis {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            guard SystemLanguageModel.default.isAvailable else {
                throw FoundationAdvisorError.modelUnavailable
            }

            let instructions = """
            You are an expert agronomist and fruit farming advisor in Indonesia.
            Analyze harvest conditions (crop, field area, weather, rainfall, temperature, irrigation, harvest timing) to estimate harvest defect rate (percentage between 1.0 and 90.0%) and provide actionable recommendations.
            Always provide clear advice in both Indonesian (Bahasa Indonesia) and English.
            """

            let session = LanguageModelSession(
                model: .default,
                instructions: instructions
            )

            let prompt = """
            Analyze harvest conditions:
            - Fruit: \(input.fruitType.displayName) (\(input.fruitType.englishName))
            - Field area: \(Int(input.fieldAreaM2)) m²
            - Rainfall: \(input.rainfall.displayName) (\(input.rainfall.rawValue))
            - Temperature: \(input.temperature.displayName) (\(input.temperature.rawValue))
            - Sky condition: \(input.sky.displayName) (\(input.sky.rawValue))
            - Irrigation level: \(input.irrigation.displayName) (\(input.irrigation.rawValue))
            - Harvest timing: \(input.harvestTiming.displayName) (\(input.harvestTiming.rawValue))

            Estimate the baseline defect percentage (0 to 100).
            Provide 2 to 4 high-priority warnings or tips (advisories) with severity ('info', 'warning', or 'critical').
            Suggest 1 to 2 actionable changes to irrigation ('low', 'medium', 'high') or harvest timing ('early', 'onTime', 'late') that improve outcome.
            """

            let response = try await session.respond(to: prompt, generating: FoundationHarvestReport.self)
            let report = response.content

            return convertReport(report, for: input)
        }
        #endif

        throw FoundationAdvisorError.unsupportedPlatform
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func convertReport(_ report: FoundationHarvestReport, for input: AdvisorInput) -> FoundationAdvisorAnalysis {
        let baseline = max(1.0, min(90.0, report.estimatedDefectRate))

        // Convert advisories
        var advisories: [Advisory] = report.advisories.enumerated().map { index, item in
            let severity: Advisory.Severity
            switch item.severity.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) {
            case "critical", "kritis":
                severity = .critical
            case "warning", "peringatan":
                severity = .warning
            default:
                severity = .info
            }

            return Advisory(
                id: "ai-advisory-\(index)-\(abs(item.title.hashValue))",
                severity: severity,
                title: item.title,
                message: item.message,
                englishTitle: item.englishTitle,
                englishMessage: item.englishMessage
            )
        }

        // Sort by severity (critical first)
        advisories.sort { $0.severity > $1.severity }
        if advisories.isEmpty {
            advisories = AdvisoryRules.evaluate(input)
        }

        // Convert suggestions
        var suggestions: [WhatIfSuggestion] = []
        var evaluatedScenarios: [WhatIfSuggestion] = []

        for item in report.suggestions {
            let factorLower = item.factor.lowercased()
            let valLower = item.targetValue.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

            if factorLower.contains("irrig") || factorLower.contains("air") {
                let targetLevel: IrrigationLevel? = {
                    if valLower.contains("low") || valLower.contains("rendah") || valLower.contains("sedikit") { return .low }
                    if valLower.contains("med") || valLower.contains("sedang") { return .medium }
                    if valLower.contains("high") || valLower.contains("tinggi") || valLower.contains("banyak") { return .high }
                    return nil
                }()

                if let targetLevel, targetLevel != input.irrigation {
                    let change = ControllableChange.irrigation(from: input.irrigation, to: targetLevel)
                    let predicted = min(baseline - 0.5, max(1.0, item.improvedDefectRate))
                    if !suggestions.contains(where: { $0.change == change }) {
                        let suggestion = WhatIfSuggestion(
                            change: change,
                            target: .defectRate,
                            baseline: baseline,
                            predicted: predicted
                        )
                        suggestions.append(suggestion)
                        evaluatedScenarios.append(suggestion)
                    }
                }
            } else if factorLower.contains("tim") || factorLower.contains("waktu") || factorLower.contains("panen") {
                let targetTiming: HarvestTiming? = {
                    if valLower.contains("earl") || valLower.contains("awal") { return .early }
                    if valLower.contains("ontime") || valLower.contains("on_time") || valLower.contains("tepat") { return .onTime }
                    if valLower.contains("late") || valLower.contains("lambat") || valLower.contains("tunda") { return .late }
                    return nil
                }()

                if let targetTiming, targetTiming != input.harvestTiming {
                    let change = ControllableChange.harvestTiming(from: input.harvestTiming, to: targetTiming)
                    let predicted = min(baseline - 0.5, max(1.0, item.improvedDefectRate))
                    if !suggestions.contains(where: { $0.change == change }) {
                        let suggestion = WhatIfSuggestion(
                            change: change,
                            target: .defectRate,
                            baseline: baseline,
                            predicted: predicted
                        )
                        suggestions.append(suggestion)
                        evaluatedScenarios.append(suggestion)
                    }
                }
            }
        }

        // Fill remaining alternatives if needed
        for change in ControllableChange.alternatives(for: input) {
            if !evaluatedScenarios.contains(where: { $0.change == change }) {
                // Approximate relative difference from standard formulas
                let formulaRate = HarvestFormula.defectRate(change.applied(to: input))
                let baseFormulaRate = HarvestFormula.defectRate(input)
                let delta = formulaRate - baseFormulaRate
                let approxPredicted = max(1.0, min(95.0, baseline + delta))
                let scenario = WhatIfSuggestion(
                    change: change,
                    target: .defectRate,
                    baseline: baseline,
                    predicted: approxPredicted
                )
                evaluatedScenarios.append(scenario)
                if scenario.improvement >= 0.5 && !suggestions.contains(where: { $0.change == change }) {
                    suggestions.append(scenario)
                }
            }
        }

        // Sort suggestions by improvement descending
        suggestions.sort { $0.improvement > $1.improvement }
        if suggestions.count > 3 {
            suggestions = Array(suggestions.prefix(3))
        }

        evaluatedScenarios.sort { $0.improvement > $1.improvement }

        let whatIfResult = WhatIfResult(
            input: input,
            target: .defectRate,
            baseline: baseline,
            suggestions: suggestions,
            allScenarios: evaluatedScenarios
        )

        return FoundationAdvisorAnalysis(
            result: whatIfResult,
            advisories: advisories,
            summary: report.summary,
            englishSummary: report.englishSummary
        )
    }
    #endif
}

enum FoundationAdvisorError: LocalizedError {
    case unsupportedPlatform
    case modelUnavailable

    var errorDescription: String? {
        switch self {
        case .unsupportedPlatform:
            return "Foundation Models membutuhkan iOS 26.0 atau lebih baru."
        case .modelUnavailable:
            return "Model on-device Apple Intelligence belum siap atau tidak tersedia."
        }
    }
}
