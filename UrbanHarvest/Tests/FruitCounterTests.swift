import XCTest
@testable import UrbanHarvest

final class FruitCounterTests: XCTestCase {
    private func lineConfig(_ line: Double = 0.5) -> CountingConfig {
        var config = CountingConfig()
        config.method = .lineCrossing
        config.linePosition = line
        config.maxMatchDistance = 0.1
        config.maxMissedFrames = 3
        return config
    }

    /// Runs frames through tracker + counter like the live pipeline does.
    private func run(_ frames: [[FruitDetection]], config: CountingConfig) -> FruitCounter {
        var tracker = CentroidTracker(config: config)
        var counter = FruitCounter(config: config)
        for frame in frames {
            counter.process(tracker.update(with: frame))
        }
        return counter
    }

    func testCrossingLineCountsOnce() {
        let frames = stride(from: 0.2, through: 0.9, by: 0.05).map { [detection(0.5, CGFloat($0))] }
        let counter = run(frames, config: lineConfig())
        XCTAssertEqual(counter.counts, FruitCounts(good: 1, defect: 0))
    }

    func testOscillatingAroundLineStillCountsOnce() {
        let ys: [CGFloat] = [0.45, 0.52, 0.47, 0.53, 0.48, 0.55]
        let counter = run(ys.map { [detection(0.5, $0, .defect)] }, config: lineConfig())
        XCTAssertEqual(counter.counts, FruitCounts(good: 0, defect: 1))
    }

    func testFruitThatNeverCrossesIsNotCounted() {
        let frames = stride(from: 0.1, through: 0.4, by: 0.05).map { [detection(0.5, CGFloat($0))] }
        let counter = run(frames, config: lineConfig())
        XCTAssertEqual(counter.counts.total, 0)
    }

    func testCrossingUpwardsAlsoCounts() {
        let frames = stride(from: 0.8, through: 0.2, by: -0.05).map { [detection(0.5, CGFloat($0))] }
        XCTAssertEqual(run(frames, config: lineConfig()).counts.total, 1)
    }

    func testSeveralFruitCountedByBucket() {
        var frames: [[FruitDetection]] = []
        for step in 0..<12 {
            let y = 0.2 + CGFloat(step) * 0.05
            frames.append([detection(0.2, y, .good), detection(0.5, y, .defect), detection(0.8, y, .good)])
        }
        let counter = run(frames, config: lineConfig())
        XCTAssertEqual(counter.counts, FruitCounts(good: 2, defect: 1))
        XCTAssertEqual(counter.counts.defectPercent, 100.0 / 3.0, accuracy: 0.001)
    }

    func testStableFramesMethod() {
        var config = lineConfig()
        config.method = .stableFrames
        config.stableFrames = 5

        let four = Array(repeating: [detection(0.3, 0.3)], count: 4)
        XCTAssertEqual(run(four, config: config).counts.total, 0)

        let twenty = Array(repeating: [detection(0.3, 0.3)], count: 20)
        XCTAssertEqual(run(twenty, config: config).counts.total, 1, "counted once, not every frame")
    }

    func testResetClearsCounts() {
        let frames = stride(from: 0.2, through: 0.9, by: 0.05).map { [detection(0.5, CGFloat($0))] }
        var counter = run(frames, config: lineConfig())
        counter.reset()
        XCTAssertEqual(counter.counts.total, 0)
        XCTAssertTrue(counter.countedIDs.isEmpty)
    }

    func testCrossesLineEdgeCases() {
        XCTAssertTrue(FruitCounter.crossesLine(from: 0.4, to: 0.5, line: 0.5))
        XCTAssertTrue(FruitCounter.crossesLine(from: 0.6, to: 0.5, line: 0.5))
        XCTAssertFalse(FruitCounter.crossesLine(from: 0.5, to: 0.6, line: 0.5), "already on the line counts on arrival, not departure")
        XCTAssertFalse(FruitCounter.crossesLine(from: 0.1, to: 0.2, line: 0.5))
    }

    func testDefectPercentWithNothingCounted() {
        XCTAssertEqual(FruitCounts().defectPercent, 0)
    }
}
