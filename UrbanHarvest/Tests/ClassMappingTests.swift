import XCTest
@testable import UrbanHarvest

final class ClassMappingTests: XCTestCase {
    private func mapping(_ json: String) throws -> ClassMapping {
        try ClassMapping.decode(Data(json.utf8))
    }

    func testBundledFileLoadsAndMapsCommonLabels() {
        guard Bundle.main.url(forResource: ClassMapping.fileName, withExtension: "json") != nil else {
            return XCTFail("ClassMapping.json is not in the app bundle")
        }
        let mapping = ClassMapping.load()
        XCTAssertEqual(mapping.detectorModelName, "FruitDetector")
        XCTAssertEqual(mapping.advisorModelName, "YieldAdvisor")
        XCTAssertEqual(mapping.bucket(for: "fresh"), .good)
        XCTAssertEqual(mapping.bucket(for: "rotten"), .defect)
        XCTAssertEqual(mapping.bucket(for: "fresh_apple"), .good)
        XCTAssertEqual(mapping.bucket(for: "rotten_apple"), .defect)
    }

    func testExactLabelsAreCaseInsensitive() throws {
        let m = try mapping(#"{"labels": {"good": ["Fresh_Apple"], "defect": ["ROTTEN_APPLE"]}}"#)
        XCTAssertEqual(m.bucket(for: "fresh_apple"), .good)
        XCTAssertEqual(m.bucket(for: " Rotten_Apple "), .defect)
    }

    func testKeywordFallback() throws {
        let m = try mapping(#"{"labels": {"good": [], "defect": []}, "keywords": {"good": ["fresh"], "defect": ["rotten"]}}"#)
        XCTAssertEqual(m.bucket(for: "fresh_pear"), .good)
        XCTAssertEqual(m.bucket(for: "pear-rotten"), .defect)
        XCTAssertNil(m.bucket(for: "freshly"), "keywords match whole words only")
    }

    func testDefectKeywordWinsOverGood() throws {
        let m = try mapping(#"{"labels": {"good": [], "defect": []}, "keywords": {"good": ["fresh"], "defect": ["rotten"]}}"#)
        XCTAssertEqual(m.bucket(for: "fresh_but_rotten"), .defect)
    }

    func testUnknownLabelPolicy() throws {
        let base = #""labels": {"good": ["a"], "defect": ["b"]}, "keywords": {"good": [], "defect": []}"#
        XCTAssertNil(try mapping("{\(base), \"unknownLabel\": {\"policy\": \"ignore\"}}").bucket(for: "zzz"))
        XCTAssertEqual(try mapping("{\(base), \"unknownLabel\": {\"policy\": \"good\"}}").bucket(for: "zzz"), .good)
        XCTAssertEqual(try mapping("{\(base), \"unknownLabel\": {\"policy\": \"defect\"}}").bucket(for: "zzz"), .defect)
    }

    func testExactListTakesPriorityOverKeywords() throws {
        // "fresh_rotten_cut" contains a defect keyword, but is explicitly listed as good.
        let m = try mapping(#"{"labels": {"good": ["fresh_rotten_cut"], "defect": []}, "keywords": {"good": [], "defect": ["rotten"]}}"#)
        XCTAssertEqual(m.bucket(for: "fresh_rotten_cut"), .good)
    }

    func testModelNamesTargetAndConfidence() throws {
        let m = try mapping(#"""
        {
          "_comment": "ignored",
          "models": {"detector": "MyDetector", "advisor": "MyAdvisor"},
          "detection": {"minimumConfidence": 0.7, "imageCropAndScale": "centerCrop"},
          "advisor": {"target": "yield_kg_per_m2"},
          "displayNames": {"_comment": "x", "Fresh": "Segar"}
        }
        """#)
        XCTAssertEqual(m.detectorModelName, "MyDetector")
        XCTAssertEqual(m.advisorModelName, "MyAdvisor")
        XCTAssertEqual(m.minimumConfidence, 0.7, accuracy: 0.0001)
        XCTAssertEqual(m.cropAndScale, .centerCrop)
        XCTAssertEqual(m.advisorTarget, .yieldPerArea)
        XCTAssertEqual(m.displayName(for: "FRESH"), "Segar")
        XCTAssertEqual(m.displayName(for: "unknown"), "unknown")
        XCTAssertNil(m.displayNames["_comment"])
    }

    func testAutoTargetAndEmptyFileUseDefaults() throws {
        let m = try mapping("{}")
        XCTAssertNil(m.advisorTarget)
        XCTAssertEqual(m.detectorModelName, ClassMapping.fallback.detectorModelName)
        XCTAssertEqual(m.bucket(for: "rotten"), .defect)
    }

    func testInvalidJSONThrows() {
        XCTAssertThrowsError(try mapping("not json"))
    }
}
