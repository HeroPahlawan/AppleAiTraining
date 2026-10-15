import Foundation

// SINGLE SOURCE OF TRUTH for the tabular model (YieldAdvisor).
//
// The column names and allowed values below must match the columns you train
// on in Create ML. `Resources/sample_training_data.csv` is generated from this
// schema (see scripts/generate_sample_csv.py) and a unit test fails if the two
// ever drift apart. If you rename or add a column here, regenerate the CSV.

// MARK: - Input value types

/// A categorical feature value: `rawValue` is what the model sees.
protocol FeatureOption: CaseIterable, Hashable, Identifiable, RawRepresentable where RawValue == String {
    var displayName: String { get }
}

extension FeatureOption {
    var id: String { rawValue }
}

enum FruitType: String, FeatureOption, Codable {
    case apple, orange, mango, tomato, banana, strawberry

    var displayName: String {
        switch self {
        case .apple: return "Apel"
        case .orange: return "Jeruk"
        case .mango: return "Mangga"
        case .tomato: return "Tomat"
        case .banana: return "Pisang"
        case .strawberry: return "Stroberi"
        }
    }

    var englishName: String {
        switch self {
        case .apple: return "apple"
        case .orange: return "orange"
        case .mango: return "mango"
        case .tomato: return "tomato"
        case .banana: return "banana"
        case .strawberry: return "strawberry"
        }
    }

    /// Accepts the raw value or an Indonesian display name (used for stored sessions).
    init?(flexible value: String) {
        let v = value.lowercased()
        if let match = FruitType(rawValue: v) {
            self = match
        } else if let match = FruitType.allCases.first(where: { $0.displayName.lowercased() == v }) {
            self = match
        } else {
            return nil
        }
    }
}

enum RainfallLevel: String, FeatureOption {
    case low, medium, high
    var displayName: String {
        switch self {
        case .low: return "Rendah"
        case .medium: return "Sedang"
        case .high: return "Tinggi"
        }
    }
}

enum TemperatureLevel: String, FeatureOption {
    case cool, normal, hot
    var displayName: String {
        switch self {
        case .cool: return "Sejuk"
        case .normal: return "Normal"
        case .hot: return "Panas"
        }
    }
}

enum SkyCondition: String, FeatureOption {
    case sunny, cloudy, rainy
    var displayName: String {
        switch self {
        case .sunny: return "Cerah"
        case .cloudy: return "Berawan"
        case .rainy: return "Hujan"
        }
    }
}

enum IrrigationLevel: String, FeatureOption {
    case low, medium, high
    var displayName: String {
        switch self {
        case .low: return "Sedikit"
        case .medium: return "Sedang"
        case .high: return "Banyak"
        }
    }
}

enum HarvestTiming: String, FeatureOption {
    case early
    case onTime = "on_time"
    case late
    var displayName: String {
        switch self {
        case .early: return "Lebih awal"
        case .onTime: return "Tepat waktu"
        case .late: return "Terlambat"
        }
    }
}

// MARK: - Prediction target

/// What the tabular regressor predicts. Train on ONE of these columns.
enum PredictionTarget: String, CaseIterable, Codable {
    /// Percentage of defective fruit, 0–100. Lower is better.
    case defectRate = "defect_rate"
    /// Kilograms of fruit per square metre. Higher is better.
    case yieldPerArea = "yield_kg_per_m2"

    var higherIsBetter: Bool { self == .yieldPerArea }

    var displayName: String {
        switch self {
        case .defectRate: return "Tingkat cacat"
        case .yieldPerArea: return "Hasil panen"
        }
    }

    var validRange: ClosedRange<Double> {
        switch self {
        case .defectRate: return 0...100
        case .yieldPerArea: return 0...100
        }
    }
}

// MARK: - Advisor input

struct AdvisorInput: Equatable {
    // Context (never changed by the what-if analysis)
    var fruitType: FruitType = .tomato
    var fieldAreaM2: Double = 1_000
    var rainfall: RainfallLevel = .medium
    var temperature: TemperatureLevel = .normal
    var sky: SkyCondition = .sunny
    // Controllable factors (varied one at a time by the what-if analysis)
    var irrigation: IrrigationLevel = .medium
    var harvestTiming: HarvestTiming = .onTime

    static let `default` = AdvisorInput()
}

// MARK: - Schema

enum FeatureSchema {
    enum Column {
        static let fruitType = "fruit_type"
        static let fieldArea = "field_area_m2"
        static let rainfall = "rainfall"
        static let temperature = "temperature"
        static let sky = "sky"
        static let irrigation = "irrigation_level"
        static let harvestTiming = "harvest_timing"
    }

    /// Weather + field context. Fixed during what-if analysis.
    static let contextColumns = [Column.fruitType, Column.fieldArea, Column.rainfall, Column.temperature, Column.sky]
    /// Inputs the farmer can change. Varied one at a time during what-if analysis.
    static let controllableColumns = [Column.irrigation, Column.harvestTiming]
    /// All model input columns, in CSV order.
    static let featureColumns = contextColumns + controllableColumns
    static let targetColumns = PredictionTarget.allCases.map(\.rawValue)
    /// Header row of `sample_training_data.csv`.
    static let csvColumns = featureColumns + targetColumns

    static let numericColumns: Set<String> = [Column.fieldArea]

    /// Allowed values for each categorical column.
    static let allowedValues: [String: [String]] = [
        Column.fruitType: FruitType.allCases.map(\.rawValue),
        Column.rainfall: RainfallLevel.allCases.map(\.rawValue),
        Column.temperature: TemperatureLevel.allCases.map(\.rawValue),
        Column.sky: SkyCondition.allCases.map(\.rawValue),
        Column.irrigation: IrrigationLevel.allCases.map(\.rawValue),
        Column.harvestTiming: HarvestTiming.allCases.map(\.rawValue),
    ]

    static let fieldAreaRange: ClosedRange<Double> = 10...1_000_000

    static let sampleCSVFileName = "sample_training_data"

    /// Model input dictionary. Strings for categorical columns, Double for numeric ones.
    static func features(from input: AdvisorInput) -> [String: Any] {
        [
            Column.fruitType: input.fruitType.rawValue,
            Column.fieldArea: input.fieldAreaM2,
            Column.rainfall: input.rainfall.rawValue,
            Column.temperature: input.temperature.rawValue,
            Column.sky: input.sky.rawValue,
            Column.irrigation: input.irrigation.rawValue,
            Column.harvestTiming: input.harvestTiming.rawValue,
        ]
    }

    /// Returns a user-facing error message, or `nil` when the input is valid.
    static func validationError(for input: AdvisorInput) -> String? {
        guard input.fieldAreaM2.isFinite else {
            return "Luas lahan harus berupa angka."
        }
        guard fieldAreaRange.contains(input.fieldAreaM2) else {
            let lower = Int(fieldAreaRange.lowerBound)
            let upper = Int(fieldAreaRange.upperBound).formatted(.number.locale(Locale(identifier: "id_ID")))
            return "Luas lahan harus antara \(lower) dan \(upper) m²."
        }
        return nil
    }
}
