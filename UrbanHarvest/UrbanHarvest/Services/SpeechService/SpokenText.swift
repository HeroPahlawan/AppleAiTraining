import Foundation

/// Builds the text the app shows and the text it speaks.
///
/// Spoken text is written for the ear: short sentences, whole numbers, and
/// units as words ("14 persen", not "14%").
enum SpokenText {
    private static let displayLocale = Locale(identifier: "id_ID")

    // MARK: Numbers

    /// "14", or "2 koma 5" / "2 point 5" when there is a meaningful decimal.
    static func number(_ value: Double, decimals: Int = 0, language: SpeechLanguage) -> String {
        let factor = pow(10, Double(max(decimals, 0)))
        let rounded = (value * factor).rounded() / factor
        let whole = Int(rounded.rounded(.towardZero))
        let fraction = Int((abs(rounded - Double(whole)) * factor).rounded())
        let sign = rounded < 0 && whole == 0 ? "-" : ""
        guard decimals > 0, fraction > 0 else { return "\(sign)\(whole)" }
        let digits = String(format: "%0\(decimals)ld", fraction)
        switch language {
        case .indonesian: return "\(sign)\(whole) koma \(digits)"
        case .english: return "\(sign)\(whole) point \(digits)"
        }
    }

    static func percent(_ value: Double, language: SpeechLanguage) -> String {
        switch language {
        case .indonesian: return "\(number(value, language: language)) persen"
        case .english: return "\(number(value, language: language)) percent"
        }
    }

    /// Value with its unit, for speech.
    static func value(_ value: Double, target: PredictionTarget, language: SpeechLanguage) -> String {
        switch target {
        case .defectRate:
            return percent(value, language: language)
        case .yieldPerArea:
            let n = number(value, decimals: 1, language: language)
            switch language {
            case .indonesian: return "\(n) kilogram per meter persegi"
            case .english: return "\(n) kilograms per square metre"
            }
        }
    }

    /// Value with its unit, for the screen ("14%", "2,9 kg/m²").
    static func displayValue(_ value: Double, target: PredictionTarget) -> String {
        switch target {
        case .defectRate:
            return value.formatted(.number.precision(.fractionLength(0)).locale(displayLocale)) + "%"
        case .yieldPerArea:
            return value.formatted(.number.precision(.fractionLength(1)).locale(displayLocale)) + " kg/m²"
        }
    }

    static func displayPercent(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)).locale(displayLocale)) + "%"
    }

    // MARK: Changes

    /// "memanen lebih awal" / "harvesting earlier".
    static func action(for change: ControllableChange, language: SpeechLanguage) -> String {
        switch (change, language) {
        case (.harvestTiming(_, .early), .indonesian): return "memanen lebih awal"
        case (.harvestTiming(_, .onTime), .indonesian): return "memanen tepat waktu"
        case (.harvestTiming(_, .late), .indonesian): return "menunda panen"
        case (.harvestTiming(_, .early), .english): return "harvesting earlier"
        case (.harvestTiming(_, .onTime), .english): return "harvesting on time"
        case (.harvestTiming(_, .late), .english): return "delaying the harvest"

        case (.irrigation(let from, let to), .indonesian):
            let more = rank(to) > rank(from)
            switch to {
            case .medium: return more ? "menambah irigasi ke tingkat sedang" : "mengurangi irigasi ke tingkat sedang"
            case .low: return "mengurangi irigasi"
            case .high: return "menambah irigasi"
            }
        case (.irrigation(let from, let to), .english):
            let more = rank(to) > rank(from)
            switch to {
            case .medium: return more ? "increasing irrigation to medium" : "reducing irrigation to medium"
            case .low: return "reducing irrigation"
            case .high: return "increasing irrigation"
            }
        }
    }

    /// Short title for a suggestion card.
    static func title(for change: ControllableChange) -> String {
        switch change {
        case .harvestTiming(_, let to): return "Waktu panen: \(to.displayName.lowercased())"
        case .irrigation(_, let to): return "Irigasi: \(to.displayName.lowercased())"
        }
    }

    // MARK: Suggestions

    /// "Perkiraan tingkat cacat turun dari 14% menjadi 9% jika Anda memanen lebih awal."
    static func suggestionDisplay(_ s: WhatIfSuggestion) -> String {
        let verb = movesUp(s) ? "naik" : "turun"
        return "Perkiraan \(s.target.displayName.lowercased()) \(verb) dari \(displayValue(s.baseline, target: s.target)) menjadi \(displayValue(s.predicted, target: s.target)) jika Anda \(action(for: s.change, language: .indonesian))."
    }

    /// Two short sentences, for the ear.
    static func suggestionSpoken(_ s: WhatIfSuggestion, language: SpeechLanguage) -> String {
        let from = value(s.baseline, target: s.target, language: language)
        let to = value(s.predicted, target: s.target, language: language)
        switch language {
        case .indonesian:
            let verb = movesUp(s) ? "naik" : "turun"
            return "Coba \(action(for: s.change, language: language)). Perkiraan \(s.target.displayName.lowercased()) \(verb) dari \(from), menjadi \(to)."
        case .english:
            let verb = movesUp(s) ? "rises" : "drops"
            let name = s.target == .defectRate ? "defect rate" : "yield"
            return "Try \(action(for: s.change, language: language)). The estimated \(name) \(verb) from \(from), to \(to)."
        }
    }

    private static func movesUp(_ s: WhatIfSuggestion) -> Bool {
        s.predicted > s.baseline
    }

    private static func rank(_ level: IrrigationLevel) -> Int {
        switch level {
        case .low: return 0
        case .medium: return 1
        case .high: return 2
        }
    }

    // MARK: Summaries

    static func analysisSpoken(_ result: WhatIfResult, advisories: [Advisory], language: SpeechLanguage) -> String {
        var sentences: [String] = []
        let predicted = value(result.baseline, target: result.target, language: language)

        switch (language, result.target) {
        case (.indonesian, .defectRate):
            sentences.append("Perkiraan tingkat cacat untuk \(result.input.fruitType.displayName.lowercased()) adalah \(predicted).")
        case (.indonesian, .yieldPerArea):
            sentences.append("Perkiraan hasil panen \(result.input.fruitType.displayName.lowercased()) adalah \(predicted).")
        case (.english, .defectRate):
            sentences.append("The estimated defect rate for \(result.input.fruitType.englishName) is \(predicted).")
        case (.english, .yieldPerArea):
            sentences.append("The estimated \(result.input.fruitType.englishName) yield is \(predicted).")
        }

        if let best = result.suggestions.first {
            sentences.append(suggestionSpoken(best, language: language))
        } else {
            sentences.append(language == .indonesian
                ? "Pengaturan Anda sudah baik. Tidak ada perubahan yang jelas lebih baik."
                : "Your settings already look good. No change is clearly better.")
        }

        if let top = advisories.first {
            sentences.append(language == .indonesian ? "Peringatan. \(top.message)" : "Warning. \(top.englishMessage)")
        }

        sentences.append(language == .indonesian
            ? "Ingat, ini hanya perkiraan."
            : "Remember, these are only estimates.")
        return sentences.joined(separator: " ")
    }

    static func advisorySpoken(_ advisory: Advisory, language: SpeechLanguage) -> String {
        switch language {
        case .indonesian: return "\(advisory.title). \(advisory.message)"
        case .english: return "\(advisory.englishTitle). \(advisory.englishMessage)"
        }
    }

    static func countsSpoken(_ counts: FruitCounts, language: SpeechLanguage) -> String {
        switch language {
        case .indonesian:
            return "Buah baik \(counts.good). Buah cacat \(counts.defect). Total \(counts.total). Buah cacat \(percent(counts.defectPercent, language: language))."
        case .english:
            return "Good fruit, \(counts.good). Defective fruit, \(counts.defect). Total, \(counts.total). Defects are \(percent(counts.defectPercent, language: language))."
        }
    }

    static func dashboardSpoken(totalGood: Int, totalDefect: Int, sessions: Int, language: SpeechLanguage) -> String {
        let counts = FruitCounts(good: totalGood, defect: totalDefect)
        switch language {
        case .indonesian:
            return "Dari \(sessions) sesi panen, ada \(counts.total) buah. \(countsSpoken(counts, language: language))"
        case .english:
            return "Across \(sessions) harvest sessions, you counted \(counts.total) fruit. \(countsSpoken(counts, language: language))"
        }
    }
}
