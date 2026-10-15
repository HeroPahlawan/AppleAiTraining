import XCTest
@testable import UrbanHarvest

final class CentroidTrackerTests: XCTestCase {
    func testSameFruitMovingKeepsItsID() {
        var tracker = CentroidTracker(maxMatchDistance: 0.1, maxMissedFrames: 3)
        var ids = Set<Int>()
        for step in 0..<10 {
            let visible = tracker.update(with: [detection(0.5, 0.1 + CGFloat(step) * 0.05)])
            XCTAssertEqual(visible.count, 1)
            ids.insert(visible[0].id)
        }
        XCTAssertEqual(ids, [1])
        XCTAssertEqual(tracker.tracks.first?.framesSeen, 10)
    }

    func testTwoFruitGetDistinctIDsAndKeepThem() {
        var tracker = CentroidTracker(maxMatchDistance: 0.1, maxMissedFrames: 3)
        let first = tracker.update(with: [detection(0.2, 0.2), detection(0.8, 0.2)])
        XCTAssertEqual(Set(first.map(\.id)), [1, 2])

        // Detections arrive in the opposite order; IDs must follow position, not order.
        let second = tracker.update(with: [detection(0.82, 0.25), detection(0.22, 0.25)])
        let left = second.first { $0.center.x < 0.5 }
        let right = second.first { $0.center.x > 0.5 }
        XCTAssertEqual(left?.id, 1)
        XCTAssertEqual(right?.id, 2)
    }

    func testFarJumpStartsNewTrack() {
        var tracker = CentroidTracker(maxMatchDistance: 0.1, maxMissedFrames: 3)
        tracker.update(with: [detection(0.1, 0.1)])
        let visible = tracker.update(with: [detection(0.9, 0.9)])
        XCTAssertEqual(visible.map(\.id), [2])
    }

    func testTrackSurvivesShortGapAndIsDroppedAfterLongGap() {
        var tracker = CentroidTracker(maxMatchDistance: 0.1, maxMissedFrames: 2)
        tracker.update(with: [detection(0.5, 0.5)])
        tracker.update(with: [])
        tracker.update(with: [])
        XCTAssertEqual(tracker.tracks.count, 1, "still within maxMissedFrames")

        let back = tracker.update(with: [detection(0.52, 0.5)])
        XCTAssertEqual(back.map(\.id), [1], "re-matched after a short gap")

        tracker.update(with: [])
        tracker.update(with: [])
        tracker.update(with: [])
        XCTAssertTrue(tracker.tracks.isEmpty, "dropped after more than maxMissedFrames")
    }

    func testBucketIsMajorityVote() {
        var tracker = CentroidTracker(maxMatchDistance: 0.1, maxMissedFrames: 3)
        tracker.update(with: [detection(0.5, 0.5, .defect)])
        tracker.update(with: [detection(0.5, 0.5, .defect)])
        let visible = tracker.update(with: [detection(0.5, 0.5, .good)])
        XCTAssertEqual(visible.first?.bucket, .defect)
    }

    func testResetRestartsIDs() {
        var tracker = CentroidTracker()
        tracker.update(with: [detection(0.5, 0.5)])
        tracker.reset()
        XCTAssertEqual(tracker.update(with: [detection(0.1, 0.1)]).map(\.id), [1])
    }
}
