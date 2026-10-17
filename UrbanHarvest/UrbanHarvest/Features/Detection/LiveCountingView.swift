import SwiftUI

/// Full-screen FruitGrade-style camera that counts fruit with the tracker.
struct LiveCountingView: View {
    @ObservedObject var model: DetectionViewModel

    @EnvironmentObject private var settings: AppSettings
    @Environment(\.dismiss) private var dismiss
    @State private var showingSaveSheet = false

    var body: some View {
        ZStack {
            feed.ignoresSafeArea()

            VStack(spacing: 12) {
                topBar
                Spacer()
                if let hint {
                    FruitGradeHintPill(text: hint)
                }
                Spacer()
                CountersBar(counts: model.liveCounts, language: settings.speechLanguage)
                    .padding(10)
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal, 12)
                bottomControls
            }
            .padding(.vertical, 12)
        }
        .onAppear {
            model.source = .live
            model.onAppear()
        }
        .onDisappear { model.onDisappear() }
        .sheet(isPresented: $showingSaveSheet) {
            SaveSessionSheet(counts: model.liveCounts, suggestedFruit: model.dominantLiveFruit.fruitType) {
                model.didSaveSession()
            }
        }
    }

    // MARK: Feed

    @ViewBuilder
    private var feed: some View {
        switch model.liveFeed {
        case .camera:
            switch model.cameraStatus {
            case .idle, .running:
                CameraPreview(session: model.camera.session)
                    .overlay { overlay }
            case .denied, .unavailable:
                Color.black
            }
        case .simulated:
            FruitGradePhotoBackground(emoji: "🍏")
                .overlay { overlay }
        case .unavailable:
            FruitGradePhotoBackground(emoji: "📷")
        }
    }

    private var overlay: some View {
        DetectionOverlay(
            boxes: model.overlayBoxesForLive(),
            imageSize: model.frameSize,
            mode: .fill,
            linePosition: settings.counting.method == .lineCrossing ? settings.counting.linePosition : nil
        )
    }

    private var hint: String? {
        switch model.liveFeed {
        case .unavailable:
            return "Kamera tidak tersedia di perangkat ini. Gunakan Foto untuk mencoba deteksi."
        case .camera where model.cameraStatus == .denied:
            return "Akses kamera ditolak. Izinkan di Pengaturan iOS."
        case .camera where model.cameraStatus == .unavailable:
            return "Kamera tidak dapat dibuka."
        case .camera, .simulated:
            if !model.isRunning { return "Tekan Mulai untuk menghitung buah" }
            return model.liveFeed == .simulated ? "Umpan simulasi — tidak ada kamera" : nil
        }
    }

    // MARK: Controls

    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Tutup")
            if model.isDemo {
                DemoBadge()
            }
            Spacer()
        }
        .padding(.horizontal, 16)
    }

    private var bottomControls: some View {
        HStack {
            circleButton(icon: "arrow.counterclockwise", label: "Reset") {
                model.reset()
            }

            Spacer()

            // Shutter-style start/pause button.
            Button {
                model.toggleRunning()
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 70, height: 70)
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 3).frame(width: 80, height: 80))
                    .overlay {
                        Image(systemName: model.isRunning ? "pause.fill" : "play.fill")
                            .font(.title)
                            .foregroundStyle(model.isRunning ? Color.orange : Color.black)
                    }
            }
            .accessibilityLabel(model.isRunning ? "Jeda" : "Mulai")
            .disabled(isFeedBlocked)
            .opacity(isFeedBlocked ? 0.4 : 1)

            Spacer()

            circleButton(icon: "square.and.arrow.down", label: "Simpan") {
                model.pause()
                showingSaveSheet = true
            }
            .disabled(model.liveCounts.total == 0)
            .opacity(model.liveCounts.total == 0 ? 0.4 : 1)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }

    private var isFeedBlocked: Bool {
        model.liveFeed == .unavailable || model.cameraStatus == .denied || model.cameraStatus == .unavailable
    }

    private func circleButton(icon: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.35), in: Circle())
        }
        .accessibilityLabel(label)
    }
}

#Preview {
    LiveCountingView(model: DetectionViewModel(detector: MockFruitDetector(), config: .default))
        .previewEnvironment()
}
