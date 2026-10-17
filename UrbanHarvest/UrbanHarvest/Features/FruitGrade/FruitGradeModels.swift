import SwiftUI
import UIKit

/// Two-level ripeness derived from the detector's `<Fruit>_Good` / `<Fruit>_Bad` labels.
enum FruitGradeRipeness: String, CaseIterable, Identifiable {
    case ripe = "Ripe"
    case unripe = "Unripe"

    init(bucket: FruitBucket) {
        self = bucket == .good ? .ripe : .unripe
    }

    var id: String { rawValue }

    var quality: String {
        switch self {
        case .ripe: "Good"
        case .unripe: "Bad"
        }
    }

    var color: Color {
        switch self {
        case .ripe: .green
        case .unripe: .red
        }
    }

    var icon: String {
        switch self {
        case .ripe: "checkmark.seal.fill"
        case .unripe: "xmark.seal.fill"
        }
    }

    var subtitle: String {
        switch self {
        case .ripe: "Ready to eat"
        case .unripe: "Not good to eat"
        }
    }

    var summary: String {
        switch self {
        case .ripe: "The fruit looks good and is ready to eat."
        case .unripe: "The fruit doesn't look good. It may be unripe or damaged."
        }
    }
}

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
        self == .unknown ? "Fruit" : rawValue.capitalized
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
}

enum FruitGradeMode: String, CaseIterable, Identifiable {
    case live = "Live"
    case snapshot = "Snapshot"

    var id: String { rawValue }
}

struct FruitGradeDetection: Identifiable {
    let id = UUID()
    let fruit: FruitKind
    let ripeness: FruitGradeRipeness
    let confidence: Double
    let date: Date
    let mode: FruitGradeMode
    let image: UIImage?
    /// Normalized (0...1) rectangle with a top-left origin, in the upright image.
    let boundingBox: CGRect?
    let detectedCount: Int
    let modelName: String

    init(
        fruit: FruitKind,
        ripeness: FruitGradeRipeness,
        confidence: Double,
        date: Date = .now,
        mode: FruitGradeMode,
        image: UIImage?,
        boundingBox: CGRect?,
        detectedCount: Int,
        modelName: String
    ) {
        self.fruit = fruit
        self.ripeness = ripeness
        self.confidence = confidence
        self.date = date
        self.mode = mode
        self.image = image
        self.boundingBox = boundingBox
        self.detectedCount = detectedCount
        self.modelName = modelName
    }

    init(top: FruitDetection, detectedCount: Int, image: UIImage?, mode: FruitGradeMode, modelName: String) {
        self.init(
            fruit: FruitKind(label: top.label),
            ripeness: FruitGradeRipeness(bucket: top.bucket),
            confidence: Double(top.confidence),
            mode: mode,
            image: image,
            boundingBox: top.boundingBox,
            detectedCount: detectedCount,
            modelName: modelName
        )
    }

    var confidencePercentText: String {
        "\(Int((confidence * 100).rounded()))%"
    }
}

extension FruitGradeDetection {
    static let preview = FruitGradeDetection(
        fruit: .apple,
        ripeness: .ripe,
        confidence: 0.92,
        mode: .live,
        image: nil,
        boundingBox: CGRect(x: 0.25, y: 0.3, width: 0.5, height: 0.4),
        detectedCount: 1,
        modelName: "FruitsQualityDetector TL 1500"
    )

    static func timeAgo(from date: Date, reference: Date = .now) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: reference)
    }
}
