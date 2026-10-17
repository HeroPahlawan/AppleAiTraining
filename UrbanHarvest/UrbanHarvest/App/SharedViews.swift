import SwiftUI

/// Orange "Mode Demo" pill shown wherever a mock replaces a real model.
struct DemoBadge: View {
    var body: some View {
        Label("Mode Demo", systemImage: "sparkles")
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.demo.opacity(0.2), in: Capsule())
            .foregroundStyle(Color.demo)
            .accessibilityLabel("Mode demo: model belum dipasang, hasil adalah contoh")
    }
}

/// Small "Perkiraan" (estimate) tag.
struct EstimateTag: View {
    var body: some View {
        Text("Perkiraan")
            .font(.caption2.weight(.semibold))
            .textCase(.uppercase)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Color.secondary.opacity(0.15), in: Capsule())
            .foregroundStyle(.secondary)
    }
}

/// "Dengarkan" button: speak, pause, continue, plus a stop button while active.
struct ListenButton: View {
    let id: String
    let text: String

    @EnvironmentObject private var speech: SpeechService

    var body: some View {
        let state = speech.playbackState(for: id)
        HStack(spacing: 8) {
            Button {
                speech.toggle(text, id: id)
            } label: {
                switch state {
                case .idle: Label("Dengarkan", systemImage: "speaker.wave.2.fill")
                case .speaking: Label("Jeda", systemImage: "pause.fill")
                case .paused: Label("Lanjutkan", systemImage: "play.fill")
                }
            }
            if state != .idle {
                Button {
                    speech.stop()
                } label: {
                    Label("Berhenti", systemImage: "stop.fill")
                        .labelStyle(.iconOnly)
                }
                .accessibilityLabel("Berhenti")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }
}

/// A rounded number tile used by the counters and the dashboard.
struct StatTile: View {
    let title: String
    let value: String
    var color: Color = .primary

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

#Preview("Shared components") {
    VStack(spacing: 16) {
        DemoBadge()
        EstimateTag()
        ListenButton(id: "preview", text: "Contoh teks untuk didengarkan")
        HStack(spacing: 8) {
            StatTile(title: "Baik", value: "128", color: .good)
            StatTile(title: "Cacat", value: "14", color: .defect)
            StatTile(title: "Total", value: "142")
        }
    }
    .padding()
    .previewEnvironment()
}
