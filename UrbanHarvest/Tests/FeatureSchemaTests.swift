import XCTest
@testable import UrbanHarvest

final class FeatureSchemaTests: XCTestCase {
    /// The CSV in Resources must have exactly the schema's columns and only allowed values.
    func testBundledCSVMatchesSchema() throws {
        let url = try XCTUnwrap(
            Bundle.main.url(forResource: FeatureSchema.sampleCSVFileName, withExtension: "csv"),
            "sample_training_data.csv is not in the app bundle"
        )
        let lines = try String(contentsOf: url, encoding: .utf8)
            .split(whereSeparator: \.isNewline)
            .map(String.init)

        let header = try XCTUnwrap(lines.first).split(separator: ",").map(String.init)
        XCTAssertEqual(header, FeatureSchema.csvColumns, "regenerate with scripts/generate_sample_csv.py")

        let rows = lines.dropFirst()
        XCTAssertGreaterThanOrEqual(rows.count, 150)

        for (lineNumber, line) in rows.enumerated() {
            let values = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            XCTAssertEqual(values.count, header.count, "row \(lineNumber + 2)")
            for (column, value) in zip(header, values) {
                if let allowed = FeatureSchema.allowedValues[column] {
                    XCTAssertTrue(allowed.contains(value), "\(column)=\(value) in row \(lineNumber + 2)")
                } else {
                    let number = try XCTUnwrap(Double(value), "\(column) must be numeric in row \(lineNumber + 2)")
                    if column == FeatureSchema.Column.fieldArea {
                        XCTAssertTrue(FeatureSchema.fieldAreaRange.contains(number))
                    }
                }
            }
        }
    }

    func testFeatureDictionaryHasEveryColumn() {
        let features = FeatureSchema.features(from: .default)
        XCTAssertEqual(Set(features.keys), Set(FeatureSchema.featureColumns))
        for column in FeatureSchema.featureColumns {
            if FeatureSchema.numericColumns.contains(column) {
                XCTAssertTrue(features[column] is Double, column)
            } else {
                let value = features[column] as? String
                XCTAssertNotNil(value, column)
                XCTAssertTrue(FeatureSchema.allowedValues[column]?.contains(value ?? "") == true, column)
            }
        }
    }

    func testContextAndControllableColumnsAreDisjoint() {
        XCTAssertTrue(Set(FeatureSchema.contextColumns).isDisjoint(with: FeatureSchema.controllableColumns))
        XCTAssertEqual(FeatureSchema.controllableColumns.count, ControllableFactor.allCases.count)
    }

    func testFieldAreaValidation() {
        var input = AdvisorInput()
        XCTAssertNil(FeatureSchema.validationError(for: input))
        input.fieldAreaM2 = 5
        XCTAssertNotNil(FeatureSchema.validationError(for: input))
        input.fieldAreaM2 = 2_000_000
        XCTAssertNotNil(FeatureSchema.validationError(for: input))
        input.fieldAreaM2 = .nan
        XCTAssertNotNil(FeatureSchema.validationError(for: input))
    }

    func testAdvisoryRulesWorkWithoutModel() {
        var input = AdvisorInput()
        input.rainfall = .high
        input.irrigation = .high
        let advisories = AdvisoryRules.evaluate(input)
        XCTAssertEqual(advisories.first?.id, "rain-rot")
        XCTAssertTrue(advisories.contains { $0.id == "over-water" })
        XCTAssertTrue(AdvisoryRules.evaluate(AdvisorInput()).isEmpty)
    }

    func testDashboardSeriesGroupsByDay() throws {
        let calendar = DashboardStats.calendar
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 10, day: 15, hour: 12)))
        let yesterday = try XCTUnwrap(calendar.date(byAdding: .day, value: -1, to: now))
        let entries = [
            DashboardStats.Entry(date: now, good: 10, defect: 2),
            DashboardStats.Entry(date: now.addingTimeInterval(-3_600), good: 5, defect: 1),
            DashboardStats.Entry(date: yesterday, good: 7, defect: 3),
            DashboardStats.Entry(date: try XCTUnwrap(calendar.date(byAdding: .day, value: -60, to: now)), good: 99, defect: 99),
        ]
        let stats = DashboardStats(entries: entries)
        XCTAssertEqual(stats.total, 226)
        XCTAssertEqual(stats.sessionCount, 4)

        let points = DashboardStats.series(entries, granularity: .day, now: now, calendar: calendar)
        XCTAssertEqual(points.count, 4, "two days × two buckets; the old entry is outside the window")
        let today = calendar.startOfDay(for: now)
        XCTAssertEqual(points.first { $0.period == today && $0.bucket == .good }?.count, 15)
        XCTAssertEqual(points.first { $0.period == today && $0.bucket == .defect }?.count, 3)
    }
}
