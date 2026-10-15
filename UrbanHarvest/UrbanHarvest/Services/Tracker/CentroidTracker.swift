import CoreGraphics
import Foundation

/// A fruit followed across frames.
struct TrackedFruit: Identifiable, Equatable {
    let id: Int
    var boundingBox: CGRect
    var center: CGPoint
    /// Center in the frame before the latest match (nil on the first frame).
    var previousCenter: CGPoint?
    var label: String
    var confidence: Float
    /// Frames in which this fruit was matched.
    var framesSeen: Int
    /// Consecutive frames in which it was not matched.
    var missedFrames: Int
    var goodVotes: Int
    var defectVotes: Int

    /// Majority vote over all frames, so one bad frame does not flip the class.
    var bucket: FruitBucket {
        defectVotes > goodVotes ? .defect : .good
    }

    var isVisible: Bool { missedFrames == 0 }
}

/// Simple centroid tracker: matches each detection to the nearest existing
/// track (greedy, closest pairs first) and assigns stable integer IDs.
struct CentroidTracker {
    var maxMatchDistance: CGFloat
    var maxMissedFrames: Int

    private(set) var tracks: [TrackedFruit] = []
    private var nextID = 1

    init(maxMatchDistance: CGFloat = 0.12, maxMissedFrames: Int = 10) {
        self.maxMatchDistance = maxMatchDistance
        self.maxMissedFrames = maxMissedFrames
    }

    init(config: CountingConfig) {
        self.init(maxMatchDistance: CGFloat(config.maxMatchDistance), maxMissedFrames: config.maxMissedFrames)
    }

    /// Feeds one frame of detections and returns the fruit visible in it.
    @discardableResult
    mutating func update(with detections: [FruitDetection]) -> [TrackedFruit] {
        // All (track, detection) pairs close enough to match, nearest first.
        var candidates: [(track: Int, detection: Int, distance: CGFloat)] = []
        for (t, track) in tracks.enumerated() {
            for (d, detection) in detections.enumerated() {
                let distance = Self.distance(track.center, detection.center)
                if distance <= maxMatchDistance {
                    candidates.append((t, d, distance))
                }
            }
        }
        candidates.sort { $0.distance < $1.distance }

        var matchedTracks = Set<Int>()
        var matchedDetections = Set<Int>()
        for candidate in candidates
        where !matchedTracks.contains(candidate.track) && !matchedDetections.contains(candidate.detection) {
            matchedTracks.insert(candidate.track)
            matchedDetections.insert(candidate.detection)
            Self.apply(detections[candidate.detection], to: &tracks[candidate.track])
        }

        // Unmatched tracks age; drop the ones gone too long.
        for index in tracks.indices where !matchedTracks.contains(index) {
            tracks[index].missedFrames += 1
        }
        tracks.removeAll { $0.missedFrames > maxMissedFrames }

        // Unmatched detections start new tracks.
        for (d, detection) in detections.enumerated() where !matchedDetections.contains(d) {
            tracks.append(
                TrackedFruit(
                    id: nextID,
                    boundingBox: detection.boundingBox,
                    center: detection.center,
                    previousCenter: nil,
                    label: detection.label,
                    confidence: detection.confidence,
                    framesSeen: 1,
                    missedFrames: 0,
                    goodVotes: detection.bucket == .good ? 1 : 0,
                    defectVotes: detection.bucket == .defect ? 1 : 0
                )
            )
            nextID += 1
        }

        return tracks.filter(\.isVisible)
    }

    mutating func reset() {
        tracks.removeAll()
        nextID = 1
    }

    private static func apply(_ detection: FruitDetection, to track: inout TrackedFruit) {
        track.previousCenter = track.center
        track.center = detection.center
        track.boundingBox = detection.boundingBox
        track.label = detection.label
        track.confidence = detection.confidence
        track.framesSeen += 1
        track.missedFrames = 0
        switch detection.bucket {
        case .good: track.goodVotes += 1
        case .defect: track.defectVotes += 1
        }
    }

    static func distance(_ a: CGPoint, _ b: CGPoint) -> CGFloat {
        hypot(a.x - b.x, a.y - b.y)
    }
}
