import Foundation

/// Fruit types the FruitsQualityDetector model was trained on.
enum FruitKind: String, CaseIterable, Identifiable {
    case apple, banana, guava, lime, orange, pomegranate
    case unknown

    /// Parses the fruit from a model label such as "Apple_Good".
    init(label: String) {
        let prefix = label.split(separator: "_").first.map { String($0).lowercased() } ?? ""
        self = FruitKind(rawValue: prefix) ?? .unknown
    }

    static var detectable: [FruitKind] { allCases.filter { $0 != .unknown } }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .apple: "Apel"
        case .banana: "Pisang"
        case .guava: "Jambu biji"
        case .lime: "Jeruk nipis"
        case .orange: "Jeruk"
        case .pomegranate: "Delima"
        case .unknown: "Buah"
        }
    }

    var emoji: String {
        switch self {
        case .apple: "🍎"
        case .banana: "🍌"
        case .guava: "🍐"
        case .lime: "🍋‍🟩"
        case .orange: "🍊"
        case .pomegranate: "🔴"
        case .unknown: "🍏"
        }
    }

    /// Matching `FruitType` to pre-select when saving a session, if the advisor schema has one.
    var fruitType: FruitType? {
        switch self {
        case .apple: .apple
        case .banana: .banana
        case .orange: .orange
        case .guava, .lime, .pomegranate, .unknown: nil
        }
    }
}

extension FruitBucket {
    /// One-line explanation shown under the verdict on the result card.
    var summary: String {
        self == .defect
            ? "Buah terlihat kurang baik. Mungkin belum matang atau rusak."
            : "Buah terlihat baik dan siap dipanen."
    }
}
