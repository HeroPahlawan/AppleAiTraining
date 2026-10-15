import Foundation

/// User preferences, persisted in UserDefaults.
@MainActor
final class AppSettings: ObservableObject {
    private enum Key {
        static let speechLanguage = "settings.speechLanguage"
        static let speechRate = "settings.speechRate"
        static let counting = "settings.counting"
        static let demoSeeded = "settings.demoSeeded"
    }

    private let defaults: UserDefaults

    @Published var speechLanguage: SpeechLanguage {
        didSet { defaults.set(speechLanguage.rawValue, forKey: Key.speechLanguage) }
    }

    /// AVSpeechUtterance rate, 0.3...0.6 is comfortable.
    @Published var speechRate: Double {
        didSet { defaults.set(speechRate, forKey: Key.speechRate) }
    }

    @Published var counting: CountingConfig {
        didSet {
            if let data = try? JSONEncoder().encode(counting) {
                defaults.set(data, forKey: Key.counting)
            }
        }
    }

    /// Set once demo sessions were seeded, so deleting them does not bring them back.
    var demoSeeded: Bool {
        get { defaults.bool(forKey: Key.demoSeeded) }
        set { defaults.set(newValue, forKey: Key.demoSeeded) }
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        speechLanguage = defaults.string(forKey: Key.speechLanguage).flatMap(SpeechLanguage.init(rawValue:)) ?? .indonesian
        speechRate = defaults.object(forKey: Key.speechRate) as? Double ?? 0.45
        if let data = defaults.data(forKey: Key.counting),
           let saved = try? JSONDecoder().decode(CountingConfig.self, from: data) {
            counting = saved.clamped()
        } else {
            counting = .default
        }
    }
}
