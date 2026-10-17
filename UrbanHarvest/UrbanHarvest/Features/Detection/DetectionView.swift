import PhotosUI
import SwiftUI

struct DetectionView: View {
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model: DetectionViewModel
    @State private var pickerItem: PhotosPickerItem?
    @State private var showingSaveSheet = false

    init(detector: FruitDetecting? = nil, config: CountingConfig) {
        _model = StateObject(wrappedValue: DetectionViewModel(detector: detector, config: config))
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Sumber", selection: $model.source) {
                    ForEach(DetectionViewModel.Source.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)
                .padding(.bottom, 8)

                ZStack {
                    Color.black
                    switch model.source {
                    case .live: liveView
                    case .photo: photoView
                    }
                }
                .clipped()

                CountersBar(counts: model.displayedCounts, language: settings.speechLanguage)
                    .padding(.horizontal)
                    .padding(.top, 10)

                controls
                    .padding()
            }
            .navigationTitle("Deteksi Buah")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if model.isDemo {
                    ToolbarItem(placement: .topBarTrailing) { DemoBadge() }
                }
            }
            .sheet(isPresented: $showingSaveSheet) {
                SaveSessionSheet(counts: model.displayedCounts) {
                    model.didSaveSession()
                }
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
        .onAppear { model.onAppear() }
        .onDisappear { model.onDisappear() }
        .onChange(of: model.source) { model.sourceChanged() }
        .onChange(of: settings.counting) { _, newValue in model.update(config: newValue) }
        .onChange(of: pickerItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self), let image = UIImage(data: data) {
                    await model.analyze(photo: image)
                } else {
                    model.errorMessage = "Foto tidak dapat dimuat."
                }
                pickerItem = nil
            }
        }
    }

    // MARK: Live

    @ViewBuilder
    private var liveView: some View {
        switch model.liveFeed {
        case .camera:
            switch model.cameraStatus {
            case .denied:
                messageView(
                    icon: "video.slash",
                    text: "Akses kamera ditolak. Izinkan di Pengaturan iOS, atau gunakan Foto uji."
                )
            case .unavailable:
                messageView(icon: "video.slash", text: "Kamera tidak dapat dibuka. Gunakan Foto uji.")
            case .idle, .running:
                GeometryReader { geo in
                    ZStack {
                        CameraPreviewView(previewLayer: model.camera.previewLayer)
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        liveOverlay
                    }
                }
            }
        case .simulated:
            messageView(
                icon: "video.slash",
                text: "Kamera tidak tersedia di perangkat ini. Gunakan Foto uji untuk mencoba deteksi."
            )
        case .unavailable:
            messageView(
                icon: "video.slash",
                text: "Kamera tidak tersedia di perangkat ini. Gunakan Foto uji untuk mencoba deteksi."
            )
        }
    }

    private var liveOverlay: some View {
        DetectionOverlay(
            boxes: model.overlayBoxesForLive(),
            imageSize: model.frameSize,
            mode: .fill,
            linePosition: settings.counting.method == .lineCrossing ? settings.counting.linePosition : nil
        )
        .overlay(alignment: .topLeading) {
            if !model.isRunning {
                Label("Dijeda", systemImage: "pause.circle.fill")
                    .font(.caption.weight(.semibold))
                    .padding(6)
                    .background(.ultraThinMaterial, in: Capsule())
                    .padding(8)
            }
        }
    }

    // MARK: Photo

    @ViewBuilder
    private var photoView: some View {
        if let photo = model.photo {
            Image(uiImage: photo)
                .resizable()
                .scaledToFit()
                .overlay {
                    DetectionOverlay(boxes: model.overlayBoxesForPhoto(), imageSize: photo.size, mode: .fit)
                }
                .overlay {
                    if model.isAnalyzingPhoto {
                        ProgressView("Mendeteksi…")
                            .padding()
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    }
                }
        } else {
            VStack(spacing: 16) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundStyle(.white.opacity(0.7))
                Text("Uji deteksi dengan foto buah di atas permukaan polos.")
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(.horizontal)
                photoButtons
            }
        }
    }

    private var photoButtons: some View {
        HStack {
            PhotosPicker(selection: $pickerItem, matching: .images) {
                Label("Pilih Foto", systemImage: "photo")
            }
            Button {
                Task { await model.analyze(photo: SampleImage.load()) }
            } label: {
                Label("Gambar Contoh", systemImage: "leaf")
            }
        }
        .buttonStyle(.borderedProminent)
    }

    // MARK: Controls

    private var controls: some View {
        HStack(spacing: 12) {
            if model.source == .live {
                Button {
                    model.toggleRunning()
                } label: {
                    Label(model.isRunning ? "Jeda" : "Mulai", systemImage: model.isRunning ? "pause.fill" : "play.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(model.isRunning ? .orange : .green)
                .disabled(model.liveFeed == .unavailable)
            } else {
                PhotosPicker(selection: $pickerItem, matching: .images) {
                    Label("Foto Lain", systemImage: "photo")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            Button(role: .destructive) {
                model.reset()
            } label: {
                Label("Reset", systemImage: "arrow.counterclockwise")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                model.pause()
                showingSaveSheet = true
            } label: {
                Label("Simpan", systemImage: "square.and.arrow.down")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(model.displayedCounts.total == 0)
        }
        .labelStyle(.titleAndIcon)
        .controlSize(.large)
    }

    private func messageView(icon: String, text: String) -> some View {
        VStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 40))
            Text(text)
                .multilineTextAlignment(.center)
            Button("Gunakan Foto uji") { model.source = .photo }
                .buttonStyle(.borderedProminent)
        }
        .foregroundStyle(.white)
        .padding()
    }

    private func boundingBoxOverlay(in size: CGSize) -> some View {
        ForEach(model.detections) { detection in
            BoundingBoxView(detection: detection, canvasSize: size)
        }
    }
}

/// Good / Defect / Total / Defect % tiles.
struct CountersBar: View {
    let counts: FruitCounts
    let language: SpeechLanguage

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                StatTile(title: "Baik", value: "\(counts.good)", color: .green)
                StatTile(title: "Cacat", value: "\(counts.defect)", color: .red)
                StatTile(title: "Total", value: "\(counts.total)")
                StatTile(title: "Cacat %", value: SpokenText.displayPercent(counts.defectPercent), color: .red)
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
