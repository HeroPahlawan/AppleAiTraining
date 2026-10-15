import CoreGraphics
import Foundation

/// Running totals.
struct FruitCounts: Equatable {
    var good = 0
    var defect = 0

    var total: Int { good + defect }

    /// Defect share in percent (0 when nothing has been counted).
    var defectPercent: Double {
        total == 0 ? 0 : Double(defect) / Double(total) * 100
    }

    mutating func add(_ bucket: FruitBucket) {
        switch bucket {
        case .good: good += 1
        case .defect: defect += 1
        }
    }
}

/// Counts each tracked fruit at most once, using the configured method.
struct FruitCounter {
    var config: CountingConfig
    private(set) var counts = FruitCounts()
    private(set) var countedIDs: Set<Int> = []

    init(config: CountingConfig = .default) {
        self.config = config
    }

    /// Inspects the visible tracks of one frame and counts any that qualify.
    /// Returns the IDs counted in this frame.
    @discardableResult
    mutating func process(_ tracks: [TrackedFruit]) -> [Int] {
        var newlyCounted: [Int] = []
        for track in tracks where !countedIDs.contains(track.id) && shouldCount(track) {
            countedIDs.insert(track.id)
            counts.add(track.bucket)
            newlyCounted.append(track.id)
        }
        return newlyCounted
    }

    func isCounted(_ id: Int) -> Bool {
        countedIDs.contains(id)
    }

    mutating func reset() {
        counts = FruitCounts()
        countedIDs.removeAll()
    }

    private func shouldCount(_ track: TrackedFruit) -> Bool {
        switch config.method {
        case .lineCrossing:
            guard let previous = track.previousCenter else { return false }
            return Self.crossesLine(from: previous.y, to: track.center.y, line: CGFloat(config.linePosition))
        case .stableFrames:
            return track.framesSeen >= config.stableFrames
        }
    }

    /// True when the segment from `a` to `b` crosses (or lands on) the line, in either direction.
    static func crossesLine(from a: CGFloat, to b: CGFloat, line: CGFloat) -> Bool {
        (a < line && b >= line) || (a > line && b <= line)
    }
}
