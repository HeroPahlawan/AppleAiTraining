import PhotosUI
import SwiftUI

struct FruitGradeLiveCameraView: View {
    var onClose: () -> Void

    @Environment(FruitGradeDetectionService.self) private var service
    @Environment(FruitGradeHistoryStore.self) private var store

    @State private var mode: FruitGradeMode = .live
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var result: FruitGradeDetection?
    @State private var isAnalyzing = false
    @State private var alertMessage: String?

    var body: some View {
        ZStack {
            feed.ignoresSafeArea()

            if let top = service.liveTop {
                let ripeness = FruitGradeRipeness(bucket: top.bucket)
                FruitGradeBoxOverlay(
                    rect: top.boundingBox,
                    imageSize: service.frameSize,
                    mode: .fill,
                    title: FruitKind(label: top.label).displayName,
                    subtitle: "Ripeness: \(ripeness.rawValue)\nConfidence: \(Int((top.confidence * 100).rounded()))%",
                    color: ripeness.color
                )
                .ignoresSafeArea()
            }

            VStack {
                topBar
                Spacer()
                statusMessage
                Spacer()
                modeToggle
                bottomControls
            }
            .padding(.vertical, 12)

            if isAnalyzing {
                ProgressView("Analyzing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .onAppear { service.startLive() }
        .onDisappear { service.stopLive() }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) {
            guard let item = pickerItem else { return }
            pickerItem = nil
            Task { await analyze(item) }
        }
        .onChange(of: showPicker) {
            if !showPicker { mode = .live }
        }
        .fullScreenCover(item: $result) { detection in
            FruitGradeResultView(
                detection: detection,
                onRetake: { result = nil },
                onSave: {
                    store.add(detection)
                    result = nil
                    onClose()
                }
            )
        }
        .alert("No fruit detected", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    @ViewBuilder
    private var feed: some View {
        switch service.liveFeed {
        case .camera:
            CameraPreview(session: service.camera.session)
        case .simulated:
            FruitGradePhotoBackground(emoji: "🍏", dark: true)
        case .unavailable:
            FruitGradePhotoBackground(emoji: "📷", dark: true)
        }
    }

    @ViewBuilder
    private var statusMessage: some View {
        switch service.liveFeed {
        case .unavailable:
            HintPill(text: "Camera isn't available on this device. Use Snapshot to detect from a photo.")
        case .camera:
            CameraStatusHint(camera: service.camera, hasDetection: service.liveTop != nil)
        case .simulated:
            EmptyView()
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "xmark")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
            if service.isDemo {
                DemoBadge()
            }
            Spacer()
            Image(systemName: "bolt.fill")
                .foregroundStyle(.white)
                .padding(10)
                .background(.black.opacity(0.35), in: Circle())
        }
        .padding(.horizontal, 16)
    }

    private var modeToggle: some View {
        HStack(spacing: 0) {
            ForEach(FruitGradeMode.allCases) { value in
                Button {
                    mode = value
                    if value == .snapshot { showPicker = true }
                } label: {
                    Text(value.rawValue)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(mode == value ? .black : .white)
                        .frame(width: 100)
                        .padding(.vertical, 8)
                        .background(mode == value ? Color.white : .clear, in: Capsule())
                }
            }
        }
        .padding(4)
        .background(.black.opacity(0.35), in: Capsule())
        .padding(.bottom, 20)
    }

    private var bottomControls: some View {
        HStack {
            Button {
                showPicker = true
            } label: {
                Image(systemName: "photo.on.rectangle")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 48, height: 48)
                    .background(.black.opacity(0.35), in: Circle())
            }

            Spacer()

            Button {
                Task { await captureAndAnalyze() }
            } label: {
                Circle()
                    .fill(.white)
                    .frame(width: 70, height: 70)
                    .overlay(Circle().stroke(.white.opacity(0.6), lineWidth: 3).frame(width: 80, height: 80))
            }
            .disabled(service.liveFeed == .unavailable || isAnalyzing)
            .opacity(service.liveFeed == .unavailable ? 0.4 : 1)

            Spacer()

            Image(systemName: "arrow.triangle.2.circlepath.camera")
                .font(.title2)
                .foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.black.opacity(0.35), in: Circle())
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 8)
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
    }

    private func captureAndAnalyze() async {
        guard let image = service.captureFrame() else {
            alertMessage = "No camera frame is available yet. Try again in a moment."
            return
        }
        await run { try await service.analyze(image: image, mode: .live) }
    }

    private func analyze(_ item: PhotosPickerItem) async {
        await run {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                throw FruitGradeDetectionService.AnalysisError.unreadableImage
            }
            return try await service.analyze(image: image, mode: .snapshot)
        }
    }

    private func run(_ work: () async throws -> FruitGradeDetection?) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            if let detection = try await work() {
                result = detection
            } else {
                alertMessage = FruitGradeDetectionService.noFruitMessage
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

/// Observes the camera's permission/availability status and shows a matching hint.
private struct CameraStatusHint: View {
    @ObservedObject var camera: CameraManager
    let hasDetection: Bool

    var body: some View {
        if let text {
            HintPill(text: text)
        }
    }

    private var text: String? {
        switch camera.status {
        case .denied: "Camera access is off. Enable it in Settings to use Live mode."
        case .unavailable: "The camera couldn't be started."
        case .idle, .running: hasDetection ? nil : "Point the camera at a fruit"
        }
    }
}

private struct HintPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45), in: Capsule())
            .padding(.horizontal, 24)
    }
}

#Preview {
    FruitGradeLiveCameraView(onClose: {})
        .fruitGradePreviewEnvironment()
}
