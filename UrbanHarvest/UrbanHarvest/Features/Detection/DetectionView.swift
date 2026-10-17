import PhotosUI
import SwiftData
import SwiftUI

/// Deteksi tab in the FruitGrade style: a home screen with Live, Photo and
/// Sample entry points, plus the latest saved sessions.
struct DetectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model: DetectionViewModel
    @Query(sort: \HarvestSession.date, order: .reverse) private var sessions: [HarvestSession]

    @State private var showCamera = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var showResult = false
    /// Set by "Ulangi" so the picker opens only after the result cover has dismissed.
    @State private var reopenPickerAfterResult = false
    @State private var showNoFruitAlert = false

    init(detector: FruitDetecting, config: CountingConfig) {
        _model = StateObject(wrappedValue: DetectionViewModel(detector: detector, config: config))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Deteksi Buah")
                            .font(.title2.weight(.bold))
                        Text("Hitung buah baik dan cacat dengan kamera atau foto.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    VStack(spacing: 12) {
                        FruitGradeModeCard(
                            icon: "camera.fill",
                            tint: .good,
                            title: "Kamera Langsung",
                            subtitle: "Hitung buah secara langsung saat melewati kamera."
                        ) {
                            showCamera = true
                        }
                        FruitGradeModeCard(
                            icon: "photo.fill",
                            tint: .blue,
                            title: "Foto",
                            subtitle: "Deteksi buah dari foto di galeri."
                        ) {
                            showPicker = true
                        }
                        FruitGradeModeCard(
                            icon: "leaf.fill",
                            tint: .teal,
                            title: "Gambar Contoh",
                            subtitle: "Coba deteksi tanpa kamera dengan gambar bawaan."
                        ) {
                            Task { await analyze(SampleImage.load()) }
                        }
                    }

                    Text("Sesi Terbaru")
                        .font(.headline)

                    recentSessions
                }
                .padding()
            }
            .toolbar(.hidden, for: .navigationBar)
            .overlay {
                if model.isAnalyzingPhoto {
                    ProgressView("Mendeteksi…")
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            pickerItem = nil
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await analyze(image)
                } else {
                    model.errorMessage = "Foto tidak dapat dimuat."
                }
            }
        }
        .onChange(of: settings.counting) { _, newValue in model.update(config: newValue) }
        .fullScreenCover(isPresented: $showCamera) {
            LiveCountingView(model: model)
        }
        .fullScreenCover(isPresented: $showResult, onDismiss: {
            model.reset()
            if reopenPickerAfterResult {
                reopenPickerAfterResult = false
                showPicker = true
            }
        }) {
            PhotoResultView(
                model: model,
                onRetake: {
                    reopenPickerAfterResult = true
                    showResult = false
                },
                onClose: { showResult = false }
            )
        }
        .alert("Tidak ada buah terdeteksi", isPresented: $showNoFruitAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("Model tidak menemukan buah pada gambar ini. Coba foto lain dengan buah di atas permukaan polos.")
        }
        .alert(
            "Terjadi kesalahan",
            isPresented: Binding(get: { model.errorMessage != nil }, set: { if !$0 { model.errorMessage = nil } })
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Label("UrbanHarvest", systemImage: "leaf.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(Color.good)
            if model.isDemo {
                DemoBadge()
            }
            Spacer()
        }
    }

    @ViewBuilder
    private var recentSessions: some View {
        if sessions.isEmpty {
            Text("Belum ada sesi. Gunakan Kamera Langsung atau Foto, lalu ketuk Simpan Sesi.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 12) {
                    ForEach(sessions.prefix(4)) { session in
                        RecentSessionCard(session: session)
                    }
                }
            }
        }
    }

    private func analyze(_ image: UIImage) async {
        model.source = .photo
        await model.analyze(photo: image)
        guard model.errorMessage == nil else { return }
        if model.photoDetections.isEmpty {
            model.reset()
            showNoFruitAlert = true
        } else {
            showResult = true
        }
    }
}

/// Small card for one saved session in the "Sesi Terbaru" row.
private struct RecentSessionCard: View {
    let session: HarvestSession

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(session.fruitDisplayName)
                .font(.subheadline.weight(.semibold))
            Text(session.date.formatted(.relative(presentation: .named)))
                .font(.caption2)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                Label("\(session.goodCount)", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.good)
                Label("\(session.defectCount)", systemImage: "xmark.octagon.fill")
                    .foregroundStyle(.defect)
            }
            .font(.caption.monospacedDigit())
        }
        .frame(width: 120, alignment: .leading)
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        .accessibilityElement(children: .combine)
    }
}

/// Good / Defect / Total / Defect % tiles.
struct CountersBar: View {
    let counts: FruitCounts
    let language: SpeechLanguage

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatTile(title: "Baik", value: "\(counts.good)", color: .good)
                StatTile(title: "Cacat", value: "\(counts.defect)", color: .defect)
                StatTile(title: "Total", value: "\(counts.total)")
                StatTile(title: "Cacat %", value: SpokenText.displayPercent(counts.defectPercent), color: .defect)
            }
            HStack {
                Spacer()
                ListenButton(id: "live-counts", text: SpokenText.countsSpoken(counts, language: language))
            }
        }
    }
}

#Preview("Detection") {
    DetectionView(detector: MockFruitDetector(), config: .default)
        .previewEnvironment()
}

#Preview("Counters bar") {
    CountersBar(counts: FruitCounts(good: 128, defect: 14), language: .indonesian)
        .padding()
        .previewEnvironment()
}
