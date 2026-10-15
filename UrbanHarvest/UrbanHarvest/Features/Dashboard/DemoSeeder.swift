import Foundation
import SwiftData

/// Fills the dashboard with example sessions in demo mode.
enum DemoSeeder {
    static func seedIfEmpty(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<HarvestSession>())) ?? 0
        guard count == 0 else { return }
        seed(context)
    }

    static func seed(_ context: ModelContext, days: Int = 28, now: Date = .now) {
        var rng = SeededGenerator(seed: 2024)
        let fruits: [FruitType] = [.tomato, .tomato, .apple, .orange, .mango, .strawberry]
        let calendar = Calendar.current
        let areas: [Double] = [500, 1_000, 2_500]

        for dayOffset in stride(from: days - 1, through: 0, by: -1) {
            // Roughly two harvest days out of three.
            guard Double.random(in: 0...1, using: &rng) < 0.66,
                  let day = calendar.date(byAdding: .day, value: -dayOffset, to: now),
                  let date = calendar.date(bySettingHour: Int.random(in: 6...10, using: &rng), minute: 0, second: 0, of: day)
            else { continue }

            let fruit = fruits[Int.random(in: 0..<fruits.count, using: &rng)]
            let total = Int.random(in: 120...480, using: &rng)
            let defectRate = Double.random(in: 0.05...0.22, using: &rng)
            let defect = Int(Double(total) * defectRate)

            context.insert(HarvestSession(
                date: date,
                fruitType: fruit.rawValue,
                goodCount: total - defect,
                defectCount: defect,
                fieldArea: areas[Int.random(in: 0..<areas.count, using: &rng)],
                notes: "Data contoh (mode demo)",
                isDemo: true
            ))
        }
        try? context.save()
    }

    static func removeDemoSessions(_ context: ModelContext) {
        try? context.delete(model: HarvestSession.self, where: #Predicate<HarvestSession> { $0.isDemo })
        try? context.save()
    }
}
