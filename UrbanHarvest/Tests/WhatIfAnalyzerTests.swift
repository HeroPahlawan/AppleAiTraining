import XCTest
@testable import UrbanHarvest

final class WhatIfAnalyzerTests: XCTestCase {
    func testOnlyControllableInputsAreVaried() throws {
        var input = AdvisorInput()
        input.fruitType = .mango
        input.fieldAreaM2 = 4_321
        input.rainfall = .high
        input.temperature = .hot
        input.sky = .rainy

        let stub = StubPredictor(target: .defectRate) { _ in 10 }
        let result = try WhatIfAnalyzer().analyze(input, using: stub)

        // 1 baseline + 2 alternative irrigation levels + 2 alternative timings.
        XCTAssertEqual(stub.calls.count, 5)
        XCTAssertEqual(result.allScenarios.count, 4)
        for call in stub.calls {
            XCTAssertEqual(call.fruitType, input.fruitType)
            XCTAssertEqual(call.fieldAreaM2, input.fieldAreaM2)
            XCTAssertEqual(call.rainfall, input.rainfall)
            XCTAssertEqual(call.temperature, input.temperature)
            XCTAssertEqual(call.sky, input.sky)
            let changed = (call.irrigation != input.irrigation ? 1 : 0) + (call.harvestTiming != input.harvestTiming ? 1 : 0)
            XCTAssertLessThanOrEqual(changed, 1, "one factor at a time")
        }
    }

    func testRankingForLowerIsBetter() throws {
        let stub = StubPredictor(target: .defectRate) { input in
            var rate = 14.0
            if input.harvestTiming == .early { rate = 9 }      // -5
            if input.harvestTiming == .late { rate = 20 }      // +6
            if input.irrigation == .low { rate -= 2 }          // -2
            if input.irrigation == .high { rate -= 0.2 }       // below threshold
            return rate
        }
        let result = try WhatIfAnalyzer().analyze(AdvisorInput(), using: stub)

        XCTAssertEqual(result.baseline, 14)
        XCTAssertEqual(result.suggestions.map(\.change), [
            .harvestTiming(from: .onTime, to: .early),
            .irrigation(from: .medium, to: .low),
        ])
        XCTAssertEqual(result.suggestions.first?.predicted, 9)
        XCTAssertEqual(result.suggestions.first?.improvement, 5)
        XCTAssertEqual(result.allScenarios.last?.change, .harvestTiming(from: .onTime, to: .late))
    }

    func testRankingForHigherIsBetter() throws {
        let stub = StubPredictor(target: .yieldPerArea) { input in
            var value = 2.0
            if input.irrigation == .high { value += 0.5 }
            if input.harvestTiming == .late { value += 0.2 }
            if input.harvestTiming == .early { value -= 0.3 }
            return value
        }
        let result = try WhatIfAnalyzer().analyze(AdvisorInput(), using: stub)
        XCTAssertEqual(result.suggestions.map(\.change), [
            .irrigation(from: .medium, to: .high),
            .harvestTiming(from: .onTime, to: .late),
        ])
    }

    func testAtMostThreeSuggestions() throws {
        var input = AdvisorInput()
        input.irrigation = .low
        input.harvestTiming = .late
        // Every alternative is better.
        let stub = StubPredictor(target: .defectRate) { candidate in
            candidate == input ? 30 : Double.random(in: 5...20)
        }
        let result = try WhatIfAnalyzer().analyze(input, using: stub)
        XCTAssertEqual(result.allScenarios.count, 4)
        XCTAssertEqual(result.suggestions.count, 3)
        XCTAssertEqual(result.suggestions.map(\.improvement), result.suggestions.map(\.improvement).sorted(by: >))
    }

    func testNoSuggestionsWhenAlreadyOptimal() throws {
        let stub = StubPredictor(target: .defectRate) { input in
            input == AdvisorInput() ? 5 : 12
        }
        XCTAssertTrue(try WhatIfAnalyzer().analyze(AdvisorInput(), using: stub).suggestions.isEmpty)
    }

    func testMockPredictorRecommendsEarlierHarvestInWetLateConditions() throws {
        var input = AdvisorInput()
        input.fruitType = .tomato
        input.rainfall = .high
        input.temperature = .hot
        input.sky = .rainy
        input.irrigation = .high
        input.harvestTiming = .late

        let result = try WhatIfAnalyzer().analyze(input, using: MockYieldPredictor(target: .defectRate))
        XCTAssertFalse(result.suggestions.isEmpty)
        XCTAssertLessThanOrEqual(result.suggestions.count, 3)
        guard case .harvestTiming(_, let to)? = result.suggestions.first?.change else {
            return XCTFail("expected a harvest timing change first, got \(String(describing: result.suggestions.first))")
        }
        XCTAssertEqual(to, .early)
        XCTAssertTrue(result.suggestions.contains { $0.change == .irrigation(from: .high, to: .low) || $0.change == .irrigation(from: .high, to: .medium) })
        for suggestion in result.suggestions {
            XCTAssertLessThan(suggestion.predicted, result.baseline)
        }
    }

    func testMockPredictorStaysInRange() throws {
        let mock = MockYieldPredictor(target: .defectRate)
        let yieldMock = MockYieldPredictor(target: .yieldPerArea)
        for fruit in FruitType.allCases {
            for rain in RainfallLevel.allCases {
                for timing in HarvestTiming.allCases {
                    var input = AdvisorInput()
                    input.fruitType = fruit
                    input.rainfall = rain
                    input.harvestTiming = timing
                    XCTAssertTrue((1...60).contains(try mock.predict(input)))
                    XCTAssertGreaterThan(try yieldMock.predict(input), 0)
                }
            }
        }
    }

    func testSuggestionTextIsWrittenForTheEar() throws {
        let suggestion = WhatIfSuggestion(
            change: .harvestTiming(from: .onTime, to: .early),
            target: .defectRate,
            baseline: 14.2,
            predicted: 8.6
        )
        XCTAssertEqual(
            SpokenText.suggestionDisplay(suggestion),
            "Perkiraan tingkat cacat turun dari 14% menjadi 9% jika Anda memanen lebih awal."
        )
        let spoken = SpokenText.suggestionSpoken(suggestion, language: .indonesian)
        XCTAssertTrue(spoken.contains("14 persen"))
        XCTAssertTrue(spoken.contains("9 persen"))
        XCTAssertFalse(spoken.contains("%"))

        let english = SpokenText.suggestionSpoken(suggestion, language: .english)
        XCTAssertTrue(english.contains("14 percent"))
        XCTAssertTrue(english.contains("harvesting earlier"))
    }

    func testSpokenNumbers() {
        XCTAssertEqual(SpokenText.number(2.94, decimals: 1, language: .indonesian), "2 koma 9")
        XCTAssertEqual(SpokenText.number(2.94, decimals: 1, language: .english), "2 point 9")
        XCTAssertEqual(SpokenText.number(3.0, decimals: 1, language: .indonesian), "3")
        XCTAssertEqual(SpokenText.percent(14.4, language: .indonesian), "14 persen")
    }
}
