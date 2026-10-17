import SwiftData
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var models: ModelProvider
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var speech: SpeechService
    @Environment(\.modelContext) private var modelContext

    @State private var confirmDeleteDemo = false

    var body: some View {
        NavigationStack {
            Form {
                speechSection
                countingSection
                modelSection
                demoDataSection
            }
            .navigationTitle("Pengaturan")
            .toolbar {
                if models.isAnyDemo {
                    ToolbarItem(placement: .topBarTrailing) { DemoBadge() }
                }
            }
        }
    }

    // MARK: Speech

    private var speechSection: some View {
        Section {
            Picker("Bahasa suara", selection: $settings.speechLanguage) {
                ForEach(SpeechLanguage.allCases) { Text($0.displayName).tag($0) }
            }
            VStack(alignment: .leading) {
                Text("Kecepatan bicara")
                Slider(value: $settings.speechRate, in: 0.3...0.6) {
                    Text("Kecepatan bicara")
                } minimumValueLabel: {
                    Image(systemName: "tortoise")
                } maximumValueLabel: {
                    Image(systemName: "hare")
                }
            }
            Button {
                speech.speak(
                    settings.speechLanguage == .indonesian
                        ? "Halo. Ini suara UrbanHarvest. Selamat memanen."
                        : "Hello. This is UrbanHarvest. Happy harvesting.",
                    id: "settings-test"
                )
            } label: {
                Label("Uji suara", systemImage: "speaker.wave.2")
            }
        } header: {
            Text("Suara")
        } footer: {
            Text("Suara diputar lewat speaker. Jika suara Bahasa Indonesia belum terpasang, unduh di Pengaturan iOS › Aksesibilitas › Konten Lisan.")
        }
    }

    // MARK: Counting

    private var countingSection: some View {
        Section {
            Picker("Metode", selection: $settings.counting.method) {
                ForEach(CountingConfig.Method.allCases) { Text($0.displayName).tag($0) }
            }

            switch settings.counting.method {
            case .lineCrossing:
                VStack(alignment: .leading) {
                    LabeledContent("Posisi garis", value: "\(Int(settings.counting.linePosition * 100))% dari atas")
                    Slider(value: $settings.counting.linePosition, in: CountingConfig.linePositionRange, step: 0.05)
                }
            case .stableFrames:
                Stepper(value: $settings.counting.stableFrames, in: CountingConfig.stableFramesRange) {
                    LabeledContent("Frame stabil", value: "\(settings.counting.stableFrames)")
                }
            }

            VStack(alignment: .leading) {
                LabeledContent("Jarak pencocokan maks.", value: "\(Int(settings.counting.maxMatchDistance * 100))% layar")
                Slider(value: $settings.counting.maxMatchDistance, in: CountingConfig.maxMatchDistanceRange, step: 0.01)
            }

            Stepper(value: $settings.counting.maxMissedFrames, in: CountingConfig.maxMissedFramesRange) {
                LabeledContent("Toleransi hilang", value: "\(settings.counting.maxMissedFrames) frame")
            }

            Button("Kembalikan ke bawaan") {
                settings.counting = .default
            }
        } header: {
            Text("Penghitungan")
        } footer: {
            Text("Setiap buah diberi nomor dan dihitung sekali: saat melewati garis kuning, atau setelah terlihat stabil beberapa frame.")
        }
    }

    // MARK: Models

    private var modelSection: some View {
        Section {
            ModelStatusRow(title: "Detektor buah", status: models.detectorStatus)
            ModelStatusRow(title: "Penasihat hasil", status: models.predictorStatus)
            LabeledContent("Keyakinan minimum", value: "\(Int(models.mapping.minimumConfidence * 100))%")
            LabeledContent("Label baik", value: "\(models.mapping.goodLabels.count)")
            LabeledContent("Label cacat", value: "\(models.mapping.defectLabels.count)")
        } header: {
            Text("Model Create ML")
        } footer: {
            Text("Taruh FruitDetector.mlmodel dan YieldAdvisor.mlmodel di folder Models, ubah label di ClassMapping.json, lalu jalankan xcodegen generate.")
        }
    }

    // MARK: Demo data

    private var demoDataSection: some View {
        Section {
            Button {
                DemoSeeder.seed(modelContext)
            } label: {
                Label("Tambah data contoh", systemImage: "plus.rectangle.on.rectangle")
            }
            Button(role: .destructive) {
                confirmDeleteDemo = true
            } label: {
                Label("Hapus data contoh", systemImage: "trash")
            }
            .confirmationDialog("Hapus semua sesi contoh?", isPresented: $confirmDeleteDemo, titleVisibility: .visible) {
                Button("Hapus", role: .destructive) {
                    DemoSeeder.removeDemoSessions(modelContext)
                }
            }
        } header: {
            Text("Data dasbor")
        } footer: {
            Text("Sesi yang Anda simpan sendiri tidak ikut terhapus.")
        }
    }
}

private struct ModelStatusRow: View {
    let title: String
    let status: ModelStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(title)
                Spacer()
                if status.isLoaded {
                    Label("Aktif", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.good)
                } else {
                    DemoBadge()
                }
            }
            Text("\(status.modelName) — \(status.detail)")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    SettingsView()
        .previewEnvironment()
}
