import Foundation

/// Anything that can predict the advisor target from user input. Implemented
/// by the Core ML tabular regressor and by the demo-mode rule-based mock.
protocol YieldPredicting: AnyObject, Sendable {
    /// True for the mock (shows the "Demo mode" badge).
    var isDemo: Bool { get }
    /// What `predict` returns: defect rate in percent, or yield in kg/m².
    var target: PredictionTarget { get }

    func predict(_ input: AdvisorInput) throws -> Double
}

enum PredictionError: LocalizedError {
    case missingOutput(String)
    case invalidValue

    var errorDescription: String? {
        switch self {
        case .missingOutput(let name):
            return "Model tidak menghasilkan kolom '\(name)'."
        case .invalidValue:
            return "Model menghasilkan nilai yang tidak valid."
        }
    }
}
