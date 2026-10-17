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

    let camera = CameraManager()
    let mapping: ClassMapping
    private(set) var config: CountingConfig
    private let detector: FruitDetecting
    private let pipeline: DetectionPipeline
    private var simulatedTimer: DispatchSourceTimer?

    init(detector: FruitDetecting, config: CountingConfig, mapping: ClassMapping = .load()) {
        self.detector = detector
        self.config = config
        self.mapping = mapping
        let pipeline = DetectionPipeline(detector: detector, config: config)
        self.pipeline = pipeline

        camera.$status
            .receive(on: DispatchQueue.main)
            .assign(to: &$cameraStatus)

        camera.onFrame = { @Sendable [weak self] buffer, orientation in
            guard let snapshot = pipeline.process(pixelBuffer: buffer, orientation: orientation) else { return }
            Task { @MainActor [weak self] in
                self?.apply(snapshot)
            }
        }
    }

    var isDemo: Bool { detector.isDemo }

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

    /// Most common fruit among the tracked boxes, used to pre-fill the save sheet.
    var dominantLiveFruit: FruitKind { Self.dominantFruit(in: visibleFruit.map(\.label)) }

    /// Most common fruit in the analyzed photo.
    var dominantPhotoFruit: FruitKind { Self.dominantFruit(in: photoDetections.map(\.label)) }

    // MARK: Lifecycle

    func onAppear() {
        guard source == .live else { return }
        if CameraManager.isCameraAvailable {
            liveFeed = .camera
            camera.start()
        } else if detector.isDemo {
            liveFeed = .simulated
            startSimulatedFeed()
        } else {
            liveFeed = .unavailable
        }
    }

    func onDisappear() {
        pause()
        camera.stop()
        stopSimulatedFeed()
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
        pipeline.isRunning = true
        isRunning = true
    }

    func pause() {
        pipeline.isRunning = false
        isRunning = false
    }

    func reset() {
        switch source {
        case .live:
            pipeline.reset()
            liveCounts = FruitCounts()
            visibleFruit = []
            countedIDs = []
        case .photo:
            photo = nil
            photoDetections = []
        }
    }

    func update(config: CountingConfig) {
        self.config = config
        pipeline.update(config: config)
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

        let detector = self.detector
        let cgImage = input.image
        let orientation = input.orientation
        do {
            photoDetections = try await Task.detached(priority: .userInitiated) {
                try detector.detect(image: cgImage, orientation: orientation)
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

    // MARK: Private

    private func apply(_ snapshot: DetectionPipeline.Snapshot) {
        guard isRunning else { return }
        visibleFruit = snapshot.visible
        countedIDs = snapshot.countedIDs
        liveCounts = snapshot.counts
        if snapshot.frameSize != frameSize {
            frameSize = snapshot.frameSize
        }
    }

    /// Feeds a blank portrait frame ~15 times a second to the demo detector,
    /// so live counting can be tried in the simulator.
    private func startSimulatedFeed() {
        guard simulatedTimer == nil, let blankBuffer = Self.makeBlankPixelBuffer(width: 72, height: 128) else { return }
        let pipeline = self.pipeline
        // The blank buffer is created once and only ever read on the timer queue.
        nonisolated(unsafe) let buffer = blankBuffer
        let timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "UrbanHarvest.simulatedFeed"))
        timer.schedule(deadline: .now(), repeating: .milliseconds(66))
        timer.setEventHandler { @Sendable [weak self] in
            guard let snapshot = pipeline.process(pixelBuffer: buffer, orientation: .up) else { return }
            Task { @MainActor [weak self] in
                self?.apply(snapshot)
            }
        }
        timer.resume()
        simulatedTimer = timer
    }

    private func stopSimulatedFeed() {
        simulatedTimer?.cancel()
        simulatedTimer = nil
    }

    private static func dominantFruit(in labels: [String]) -> FruitKind {
        let kinds = labels.map(FruitKind.init(label:)).filter { $0 != .unknown }
        let tally = Dictionary(kinds.map { ($0, 1) }, uniquingKeysWith: +)
        return tally.max(by: { $0.value < $1.value })?.key ?? .unknown
    }

    private static func makeBlankPixelBuffer(width: Int, height: Int) -> CVPixelBuffer? {
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, nil, &buffer)
        return status == kCVReturnSuccess ? buffer : nil
    }
}
