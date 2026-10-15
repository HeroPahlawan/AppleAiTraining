import Foundation

/// How fruit is counted. Editable in Settings (persisted in UserDefaults).
struct CountingConfig: Equatable, Codable {
    enum Method: String, CaseIterable, Codable, Identifiable {
        /// Count when a tracked fruit's center crosses the horizontal line.
        case lineCrossing
        /// Count once a fruit has been tracked for `stableFrames` frames.
        case stableFrames

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .lineCrossing: return "Melewati garis"
            case .stableFrames: return "Stabil N frame"
            }
        }
    }

    var method: Method = .lineCrossing
    /// Vertical position of the counting line, 0 (top) ... 1 (bottom).
    var linePosition: Double = 0.5
    /// Frames a fruit must be seen before it is counted (stableFrames method).
    var stableFrames: Int = 8
    /// Largest centroid jump (normalized screen units) still treated as the same fruit.
    var maxMatchDistance: Double = 0.12
    /// Frames a fruit may be missing before its track is dropped.
    var maxMissedFrames: Int = 10

    static let `default` = CountingConfig()

    static let linePositionRange: ClosedRange<Double> = 0.1...0.9
    static let stableFramesRange: ClosedRange<Int> = 2...60
    static let maxMatchDistanceRange: ClosedRange<Double> = 0.02...0.4
    static let maxMissedFramesRange: ClosedRange<Int> = 1...60

    /// Returns a copy with every value clamped to its allowed range.
    func clamped() -> CountingConfig {
        var copy = self
        copy.linePosition = min(max(linePosition, Self.linePositionRange.lowerBound), Self.linePositionRange.upperBound)
        copy.stableFrames = min(max(stableFrames, Self.stableFramesRange.lowerBound), Self.stableFramesRange.upperBound)
        copy.maxMatchDistance = min(max(maxMatchDistance, Self.maxMatchDistanceRange.lowerBound), Self.maxMatchDistanceRange.upperBound)
        copy.maxMissedFrames = min(max(maxMissedFrames, Self.maxMissedFramesRange.lowerBound), Self.maxMissedFramesRange.upperBound)
        return copy
    }
}
