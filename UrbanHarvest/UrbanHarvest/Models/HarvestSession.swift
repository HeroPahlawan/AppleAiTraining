import Foundation
import SwiftData

/// One saved counting session.
@Model
final class HarvestSession {
    var date: Date
    /// `FruitType.rawValue` (e.g. "tomato").
    var fruitType: String
    var goodCount: Int
    var defectCount: Int
    /// Field area in square metres.
    var fieldArea: Double
    var notes: String
    /// True for sessions seeded by demo mode, so they can be removed in one tap.
    var isDemo: Bool

    init(
        date: Date = .now,
        fruitType: String,
        goodCount: Int,
        defectCount: Int,
        fieldArea: Double,
        notes: String = "",
        isDemo: Bool = false
    ) {
        self.date = date
        self.fruitType = fruitType
        self.goodCount = goodCount
        self.defectCount = defectCount
        self.fieldArea = fieldArea
        self.notes = notes
        self.isDemo = isDemo
    }

    var totalCount: Int { goodCount + defectCount }

    var defectPercent: Double {
        totalCount == 0 ? 0 : Double(defectCount) / Double(totalCount) * 100
    }

    var fruitDisplayName: String {
        FruitType(flexible: fruitType)?.displayName ?? fruitType
    }
}
