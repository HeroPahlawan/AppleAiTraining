import XCTest
@testable import UrbanHarvest

final class FoundationModelAdvisorTests: XCTestCase {
    func testFoundationAdvisorAvailability() {
        // Must return a boolean without crashing or hanging
        let isAvailable = FoundationModelAdvisor.shared.isAvailable
        XCTAssertTrue(isAvailable == true || isAvailable == false)
    }

    func testFoundationYieldPredictor() throws {
        let predictor = FoundationYieldPredictor(target: .defectRate)
        XCTAssertEqual(predictor.target, .defectRate)

        let input = AdvisorInput()
        let rate = try predictor.predict(input)
        XCTAssertGreaterThan(rate, 0)
        XCTAssertLessThanOrEqual(rate, 100)
    }

    @MainActor
    func testAdvisorViewModelAsyncAnalysis() async {
        let viewModel = AdvisorViewModel()
        XCTAssertNil(viewModel.result)
        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertFalse(viewModel.advisories.isEmpty)

        let predictor = FoundationYieldPredictor(target: .defectRate)
        await viewModel.analyze(using: predictor)

        XCTAssertFalse(viewModel.isAnalyzing)
        XCTAssertNotNil(viewModel.result)
        XCTAssertFalse(viewModel.advisories.isEmpty)
        XCTAssertNil(viewModel.errorMessage)

        viewModel.resetInput()
        XCTAssertNil(viewModel.result)
        XCTAssertNil(viewModel.aiSummary)
        XCTAssertFalse(viewModel.isUsingFoundationModel)
    }

    @MainActor
    func testAdvisorViewModelValidation() async {
        let viewModel = AdvisorViewModel()
        viewModel.input.fieldAreaM2 = -10
        XCTAssertNotNil(viewModel.validationError)

        let predictor = FoundationYieldPredictor(target: .defectRate)
        await viewModel.analyze(using: predictor)
        XCTAssertNil(viewModel.result)
    }
}
