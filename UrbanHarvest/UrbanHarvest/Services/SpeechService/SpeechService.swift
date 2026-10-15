import AVFoundation
import Foundation

enum SpeechLanguage: String, CaseIterable, Identifiable, Codable {
    case indonesian = "id-ID"
    case english = "en-US"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .indonesian: return "Bahasa Indonesia"
        case .english: return "English"
        }
    }
}

/// Thin wrapper around AVSpeechSynthesizer with speak / pause / continue / stop.
/// Tracks which item is speaking so each "Dengarkan" button can show its own state.
@MainActor
final class SpeechService: NSObject, ObservableObject {
    enum State: Equatable {
        case idle
        case speaking
        case paused
    }

    @Published private(set) var state: State = .idle
    /// ID passed to `speak(_:id:)` for the utterance currently playing.
    @Published private(set) var activeID: String?

    var language: SpeechLanguage = .indonesian
    /// AVSpeechUtterance rate (0...1). Slightly slow suits outdoor listening.
    var rate: Float = 0.45

    private let synthesizer = AVSpeechSynthesizer()
    private var audioSessionConfigured = false

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func speak(_ text: String, id: String? = nil) {
        configureAudioSessionIfNeeded()
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: language.rawValue)
            ?? AVSpeechSynthesisVoice(language: AVSpeechSynthesisVoice.currentLanguageCode())
        utterance.rate = min(max(rate, AVSpeechUtteranceMinimumSpeechRate), AVSpeechUtteranceMaximumSpeechRate)
        utterance.postUtteranceDelay = 0.1

        activeID = id
        state = .speaking
        synthesizer.speak(utterance)
    }

    func pause() {
        guard synthesizer.isSpeaking else { return }
        if synthesizer.pauseSpeaking(at: .word) {
            state = .paused
        }
    }

    func continueSpeaking() {
        guard synthesizer.isPaused else { return }
        if synthesizer.continueSpeaking() {
            state = .speaking
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
        state = .idle
        activeID = nil
    }

    /// One-button behaviour: start, pause or resume the item with this ID.
    func toggle(_ text: String, id: String) {
        if activeID == id {
            switch state {
            case .speaking: pause()
            case .paused: continueSpeaking()
            case .idle: speak(text, id: id)
            }
        } else {
            speak(text, id: id)
        }
    }

    func playbackState(for id: String) -> State {
        activeID == id ? state : .idle
    }

    /// `.playback` routes speech to the loud speaker (not the earpiece) and
    /// plays even with the silent switch on — useful in a noisy field.
    private func configureAudioSessionIfNeeded() {
        guard !audioSessionConfigured else { return }
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .spokenAudio, options: [.duckOthers])
            try session.setActive(true)
            audioSessionConfigured = true
        } catch {
            // Speech still works with the default session.
        }
    }

    private func finish() {
        state = .idle
        activeID = nil
        try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        audioSessionConfigured = false
    }
}

extension SpeechService: AVSpeechSynthesizerDelegate {
    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking else { return }
            self.finish()
        }
    }

    nonisolated func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        Task { @MainActor in
            guard !self.synthesizer.isSpeaking else { return }
            self.state = .idle
            self.activeID = nil
        }
    }
}
