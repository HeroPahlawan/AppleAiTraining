import Foundation

/// The two buckets every detector label is folded into.
enum FruitBucket: String, Codable, CaseIterable, Hashable {
    case good
    case defect

    var displayName: String {
        switch self {
        case .good: return "Baik"
        case .defect: return "Cacat"
        }
    }
}

/// Runtime configuration loaded from `Resources/ClassMapping.json`.
///
/// It holds the model names and the mapping from *your* Create ML labels to
/// `good` / `defect`. Editing the JSON is all that is needed to adapt the app
/// to a new model; nothing here is tied to a specific label set.
struct ClassMapping: Equatable {
    enum UnknownPolicy: String, Codable, Equatable {
        case ignore
        case good
        case defect
    }

    enum CropAndScale: String, Codable, Equatable {
        case scaleFill
        case scaleFit
        case centerCrop
    }

    var detectorModelName: String
    var advisorModelName: String
    var minimumConfidence: Float
    var cropAndScale: CropAndScale
    /// `nil` means "auto": read it from the model's output feature name.
    var advisorTarget: PredictionTarget?
    var goodLabels: Set<String>
    var defectLabels: Set<String>
    var goodKeywords: Set<String>
    var defectKeywords: Set<String>
    var unknownPolicy: UnknownPolicy
    var displayNames: [String: String]

    static let fileName = "ClassMapping"

    /// Used when the JSON file is missing or unreadable.
    static let fallback = ClassMapping(
        detectorModelName: "FruitsQualityDetector TL 1500",
        advisorModelName: "YieldAdvisor",
        minimumConfidence: 0.5,
        cropAndScale: .scaleFill,
        advisorTarget: nil,
        goodLabels: [
            "fresh", "good", "ripe", "segar", "baik",
            "apple_good", "banana_good", "guava_good", "lime_good", "orange_good", "pomegranate_good"
        ],
        defectLabels: [
            "rotten", "defect", "bad", "busuk", "cacat", "rusak",
            "apple_bad", "banana_bad", "guava_bad", "lime_bad", "orange_bad", "pomegranate_bad"
        ],
        goodKeywords: ["fresh", "good", "ripe", "segar", "baik", "matang"],
        defectKeywords: ["rotten", "rot", "defect", "defective", "bruised", "damaged", "busuk", "cacat", "rusak", "overripe", "unripe", "bad"],
        unknownPolicy: .ignore,
        displayNames: [:]
    )

    // MARK: Mapping

    /// Maps a raw detector label to a bucket, or `nil` when it should be ignored.
    func bucket(for rawLabel: String) -> FruitBucket? {
        let label = Self.normalize(rawLabel)
        guard !label.isEmpty else { return nil }

        if defectLabels.contains(label) { return .defect }
        if goodLabels.contains(label) { return .good }

        let words = Set(label.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).map(String.init))
        if !words.isDisjoint(with: defectKeywords) { return .defect }
        if !words.isDisjoint(with: goodKeywords) { return .good }

        switch unknownPolicy {
        case .ignore: return nil
        case .good: return .good
        case .defect: return .defect
        }
    }

    func displayName(for rawLabel: String) -> String {
        displayNames[Self.normalize(rawLabel)] ?? rawLabel
    }

    static func normalize(_ label: String) -> String {
        label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    // MARK: Loading

    static func load(from bundle: Bundle = .main) -> ClassMapping {
        guard let url = bundle.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url) else {
            return .fallback
        }
        return (try? decode(data)) ?? .fallback
    }

    static func decode(_ data: Data) throws -> ClassMapping {
        let file = try JSONDecoder().decode(File.self, from: data)
        let fallback = ClassMapping.fallback

        let targetString = file.advisor?.target.map(normalize) ?? "auto"

        return ClassMapping(
            detectorModelName: file.models?.detector ?? fallback.detectorModelName,
            advisorModelName: file.models?.advisor ?? fallback.advisorModelName,
            minimumConfidence: file.detection?.minimumConfidence ?? fallback.minimumConfidence,
            cropAndScale: file.detection?.imageCropAndScale ?? fallback.cropAndScale,
            advisorTarget: PredictionTarget(rawValue: targetString),
            goodLabels: Set((file.labels?.good ?? Array(fallback.goodLabels)).map(normalize)),
            defectLabels: Set((file.labels?.defect ?? Array(fallback.defectLabels)).map(normalize)),
            goodKeywords: Set((file.keywords?.good ?? Array(fallback.goodKeywords)).map(normalize)),
            defectKeywords: Set((file.keywords?.defect ?? Array(fallback.defectKeywords)).map(normalize)),
            unknownPolicy: file.unknownLabel?.policy ?? fallback.unknownPolicy,
            displayNames: Dictionary(
                (file.displayNames ?? [:])
                    .filter { !$0.key.hasPrefix("_") }
                    .map { (normalize($0.key), $0.value) },
                uniquingKeysWith: { first, _ in first }
            )
        )
    }

    /// Mirrors the JSON layout. Every field is optional so a partial file still works.
    private struct File: Decodable {
        struct Models: Decodable { var detector: String?; var advisor: String? }
        struct Detection: Decodable { var minimumConfidence: Float?; var imageCropAndScale: CropAndScale? }
        struct Advisor: Decodable { var target: String? }
        struct Buckets: Decodable { var good: [String]?; var defect: [String]? }
        struct Unknown: Decodable { var policy: UnknownPolicy? }

        var models: Models?
        var detection: Detection?
        var advisor: Advisor?
        var labels: Buckets?
        var keywords: Buckets?
        var unknownLabel: Unknown?
        var displayNames: [String: String]?
    }
}
