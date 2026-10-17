import Combine
import CoreVideo
import SwiftUI

@MainActor
final class DetectionViewModel: ObservableObject {
    enum Source: String, CaseIterable, Identifiable {
        case live
        case photo

        var id: String { rawValue }

        var displayName: String {
            switch self {
            case .live: return "Kamera"
            case .photo: return "Foto uji"
            }
        }
    }

    enum LiveFeed: Equatable {
        case camera
        /// No camera (simulator) but the demo detector needs no pixels.
        case simulated
        case unavailable
    }

    @Published var source: Source = .live
    @Published private(set) var isRunning = false
    @Published private(set) var liveFeed: LiveFeed = .unavailable
    @Published private(set) var cameraStatus: CameraManager.Status = .idle
    @Published private(set) var detections: [Detection] = []

    // Live
    @Published private(set) var liveCounts = FruitCounts()
    @Published private(set) var visibleFruit: [TrackedFruit] = []
    @Published private(set) var countedIDs: Set<Int> = []
    @Published private(set) var frameSize = CGSize(width: 720, height: 1280)

    // Photo
    @Published private(set) var photo: UIImage?
    @Published private(set) var photoDetections: [FruitDetection] = []
    @Published private(set) var isAnalyzingPhoto = false
    @Published var errorMessage: String?

    let camera: CameraManager
    let mapping: ClassMapping
    private(set) var config: CountingConfig

    init(detector: FruitDetecting? = nil, config: CountingConfig, mapping: ClassMapping = .load()) {
        self.config = config
        self.mapping = mapping
        let camera = CameraManager(config: config, mapping: mapping)
        self.camera = camera

        camera.$status
            .receive(on: DispatchQueue.main)
            .assign(to: &$cameraStatus)

        camera.$detections
            .receive(on: DispatchQueue.main)
            .assign(to: &$detections)

        camera.$counts
            .receive(on: DispatchQueue.main)
            .assign(to: &$liveCounts)

        camera.$visibleFruit
            .receive(on: DispatchQueue.main)
            .assign(to: &$visibleFruit)

        camera.$countedIDs
            .receive(on: DispatchQueue.main)
            .assign(to: &$countedIDs)

        camera.$frameSize
            .receive(on: DispatchQueue.main)
            .assign(to: &$frameSize)
    }

    var isDemo: Bool { false }

    /// Counters for whatever is on screen.
    var displayedCounts: FruitCounts {
        switch source {
        case .live:
            return liveCounts
        case .photo:
            var counts = FruitCounts()
            photoDetections.forEach { counts.add($0.bucket) }
            return counts
        }
    }

    // MARK: Lifecycle

    func onAppear() {
        guard source == .live else { return }
        if CameraManager.isCameraAvailable {
            liveFeed = .camera
            camera.start()
        } else {
            liveFeed = .unavailable
        }
    }

    func onDisappear() {
        pause()
        camera.stop()
    }

    func sourceChanged() {
        if source == .live {
            onAppear()
        } else {
            onDisappear()
        }
    }

    // MARK: Controls

    func toggleRunning() {
        if isRunning {
            pause()
        } else {
            start()
        }
    }

    func start() {
        camera.startCounting()
        isRunning = true
    }

    func pause() {
        camera.pauseCounting()
        isRunning = false
    }

    func reset() {
        switch source {
        case .live:
            camera.reset()
            liveCounts = FruitCounts()
            visibleFruit = []
            countedIDs = []
            detections = []
        case .photo:
            photo = nil
            photoDetections = []
        }
    }

    func update(config: CountingConfig) {
        self.config = config
        camera.update(config: config)
    }

    /// Counts were saved to a session; start fresh.
    func didSaveSession() {
        reset()
    }

    // MARK: Photo test mode

    func analyze(photo image: UIImage) async {
        photo = image
        photoDetections = []
        errorMessage = nil
        guard let input = image.visionInput else {
            errorMessage = "Gambar tidak dapat dibaca."
            return
        }
        isAnalyzingPhoto = true
        defer { isAnalyzingPhoto = false }

        let camera = self.camera
        let cgImage = input.image
        let orientation = input.orientation
        do {
            photoDetections = try await Task.detached(priority: .userInitiated) {
                try camera.detect(image: cgImage, orientation: orientation)
            }.value
        } catch {
            errorMessage = "Deteksi gagal: \(error.localizedDescription)"
        }
    }

    func overlayBoxesForPhoto() -> [OverlayBox] {
        photoDetections.enumerated().map { index, detection in
            OverlayBox(
                id: "photo-\(index)",
                rect: detection.boundingBox,
                bucket: detection.bucket,
                title: mapping.displayName(for: detection.label),
                confidence: detection.confidence,
                counted: true
            )
        }
    }

    func overlayBoxesForLive() -> [OverlayBox] {
        visibleFruit.map { fruit in
            OverlayBox(
                id: "track-\(fruit.id)",
                rect: fruit.boundingBox,
                bucket: fruit.bucket,
                title: "#\(fruit.id) \(mapping.displayName(for: fruit.label))",
                confidence: fruit.confidence,
                counted: countedIDs.contains(fruit.id)
            )
        }
    }
}
