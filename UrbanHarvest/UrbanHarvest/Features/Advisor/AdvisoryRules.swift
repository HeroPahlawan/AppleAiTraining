import Foundation

/// A plain-language warning or tip. Produced by `AdvisoryRules` without any ML.
struct Advisory: Identifiable, Equatable {
    enum Severity: Int, Comparable {
        case info = 0
        case warning = 1
        case critical = 2

        static func < (lhs: Severity, rhs: Severity) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    let id: String
    let severity: Severity
    let title: String
    /// Indonesian text, written to read well aloud too.
    let message: String
    let englishTitle: String
    let englishMessage: String
}

/// Small rule layer that works even when no model is installed.
enum AdvisoryRules {
    static func evaluate(_ input: AdvisorInput) -> [Advisory] {
        var result: [Advisory] = []

        if input.rainfall == .high {
            result.append(Advisory(
                id: "rain-rot",
                severity: .critical,
                title: "Risiko busuk tinggi",
                message: "Curah hujan tinggi membuat buah mudah busuk. Pastikan saluran air lancar. Keringkan buah segera setelah dipanen.",
                englishTitle: "High risk of rot",
                englishMessage: "Heavy rain makes fruit rot easily. Keep the drains clear. Dry the fruit right after picking."
            ))
        }

        if input.sky == .rainy {
            result.append(Advisory(
                id: "rainy-harvest",
                severity: .warning,
                title: "Hindari panen saat hujan",
                message: "Buah yang basah lebih cepat busuk. Tunggu sampai buah kering sebelum dipetik.",
                englishTitle: "Avoid picking in the rain",
                englishMessage: "Wet fruit rots faster. Wait until the fruit is dry before picking."
            ))
        }

        if input.rainfall == .high && input.irrigation == .high {
            result.append(Advisory(
                id: "over-water",
                severity: .warning,
                title: "Terlalu banyak air",
                message: "Hujan sudah banyak. Kurangi irigasi agar akar tidak tergenang.",
                englishTitle: "Too much water",
                englishMessage: "It is already raining a lot. Reduce irrigation so the roots do not drown."
            ))
        }

        if input.rainfall == .low && input.irrigation == .low {
            result.append(Advisory(
                id: "water-stress",
                severity: .warning,
                title: "Tanaman kekurangan air",
                message: "Hujan sedikit dan irigasi juga sedikit. Buah bisa kecil dan mudah retak. Tambah irigasi.",
                englishTitle: "Plants lack water",
                englishMessage: "There is little rain and little irrigation. Fruit may stay small and crack. Irrigate more."
            ))
        }

        if input.temperature == .hot && input.harvestTiming == .late {
            result.append(Advisory(
                id: "hot-late",
                severity: .warning,
                title: "Buah cepat terlalu matang",
                message: "Cuaca panas dan panen terlambat membuat buah cepat terlalu matang. Panen lebih awal, sebaiknya pagi hari.",
                englishTitle: "Fruit will overripen",
                englishMessage: "Hot weather and a late harvest overripen the fruit quickly. Harvest earlier, ideally in the morning."
            ))
        } else if input.harvestTiming == .late {
            result.append(Advisory(
                id: "late",
                severity: .info,
                title: "Panen terlambat",
                message: "Buah yang terlalu lama di pohon lebih mudah cacat. Pertimbangkan panen tepat waktu.",
                englishTitle: "Late harvest",
                englishMessage: "Fruit left too long on the plant is more likely to be damaged. Consider harvesting on time."
            ))
        } else if input.temperature == .hot {
            result.append(Advisory(
                id: "hot",
                severity: .info,
                title: "Panen pagi hari",
                message: "Saat cuaca panas, panen pada pagi hari. Simpan buah di tempat teduh.",
                englishTitle: "Pick in the morning",
                englishMessage: "In hot weather, pick in the morning. Keep the fruit in the shade."
            ))
        }

        if input.fruitType == .strawberry && input.rainfall != .low {
            result.append(Advisory(
                id: "strawberry-humid",
                severity: .info,
                title: "Stroberi mudah rusak",
                message: "Stroberi cepat rusak saat lembap. Pakai wadah dangkal agar buah tidak tertekan.",
                englishTitle: "Strawberries bruise easily",
                englishMessage: "Strawberries spoil quickly when it is damp. Use shallow trays so the fruit is not crushed."
            ))
        }

        // Most severe first; keep rule order within a severity.
        return result.enumerated()
            .sorted { lhs, rhs in
                lhs.element.severity != rhs.element.severity
                    ? lhs.element.severity > rhs.element.severity
                    : lhs.offset < rhs.offset
            }
            .map(\.element)
    }
}
