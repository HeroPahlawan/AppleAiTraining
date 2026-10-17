//
//  CameraManager.swift
//  UrbanHarvest
//
//  Created by Dinda Ayu Syafitri on 17/10/26.
//

import AVFoundation
import CoreML
import ImageIO
import SimulatorCameraClient
import SwiftUI
import Vision

final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {
    enum Status: Equatable {
        case idle
        case running
        case denied
        /// No camera (e.g. the simulator) or it could not be configured.
        case unavailable
    }

    @Published var detections: [Detection] = []
    @Published var isRunning = false
    @Published var permissionDenied = false
    @Published private(set) var status: Status = .idle

    // Tracking & Counting
    private nonisolated(unsafe) var tracker: CentroidTracker
    private nonisolated(unsafe) var counter: FruitCounter
    private nonisolated(unsafe) var countingConfig: CountingConfig
    private nonisolated(unsafe) var isCountingActive = false
    private nonisolated(unsafe) var mapping: ClassMapping

    @Published var counts = FruitCounts()
    @Published var visibleFruit: [TrackedFruit] = []
    @Published var countedIDs: Set<Int> = []
    @Published var frameSize = CGSize(width: 720, height: 1280)

    let previewLayer = AVCaptureVideoPreviewLayer()

    @Published var previewImage: UIImage?
    private nonisolated let ciContext = CIContext()
    private nonisolated(unsafe) let simulatorOutput = SimulatorCameraOutput()
    private nonisolated(unsafe) var simulatorCaptureStarted = false

    /// Called on the video queue for each frame. Set before calling `start()`.
    var onFrame: (@Sendable (CVPixelBuffer, CGImagePropertyOrientation) -> Void)?

    /// `.up` when the connection rotates buffers to portrait, otherwise `.right`.
    private var bufferOrientation: CGImagePropertyOrientation = .right
    private var isConfigured = false

    // Diakses dari background queue, jadi butuh nonisolated(unsafe).
    nonisolated(unsafe) let session = AVCaptureSession()
    private nonisolated(unsafe) let videoOutput = AVCaptureVideoDataOutput()

    // Antrean terpisah supaya menyalakan kamera dan memproses frame
    // tidak membuat layar membeku.
    private let sessionQueue = DispatchQueue(label: "UrbanHarvest.camera.session")
    private let inferenceQueue = DispatchQueue(label: "camera.inference.queue", qos: .userInitiated)

    private nonisolated(unsafe) var visionModel: VNCoreMLModel?

    private nonisolated(unsafe) var lastInferenceTime = Date.distantPast
    private nonisolated let inferenceInterval: TimeInterval = 0.25

    static let confidenceThreshold = 0.75
    nonisolated static let iouThreshold = 0.75

    static var isCameraAvailable: Bool {
#if targetEnvironment(simulator)
        true
#else
        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
#endif
    }

    init(config: CountingConfig = .default, mapping: ClassMapping = .load()) {
        self.countingConfig = config
        self.mapping = mapping
        self.tracker = CentroidTracker(config: config)
        self.counter = FruitCounter(config: config)
        super.init()
        setupModel()
        setupSession()
    }

    // MARK: - Setup

    private func setupModel() {
        do {
            let config = MLModelConfiguration()
#if targetEnvironment(simulator)
            config.computeUnits = .cpuOnly
#endif
            let mlModel = try FruitsQualityDetector_TL_1500(configuration: config).model
            let vnModel = try VNCoreMLModel(for: mlModel)

            vnModel.featureProvider = try MLDictionaryFeatureProvider(dictionary: [
                "iouThreshold": MLFeatureValue(double: Self.iouThreshold),
                "confidenceThreshold": MLFeatureValue(double: Self.confidenceThreshold)
            ])

            visionModel = vnModel
        } catch {
            print("CameraManager: gagal load model: \(error)")
        }
    }

    private func setupSession() {
        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        } else {
            session.sessionPreset = .medium
        }
        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill
        SimulatorCamera.configure(host: "127.0.0.1", port: 9876)
    }

    @discardableResult
    private func configureInputOutput() -> Bool {
#if targetEnvironment(simulator)
        simulatorOutput.setSampleBufferDelegate(self, queue: inferenceQueue)
        isConfigured = true
        return true
#else
        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device),
              session.canAddInput(input)
        else {
            print("CameraManager: gagal setup input kamera")
            return false
        }

        session.beginConfiguration()
        defer { session.commitConfiguration() }

        if session.canSetSessionPreset(.hd1280x720) {
            session.sessionPreset = .hd1280x720
        }
        session.addInput(input)

        // Frame yang telat dibuang, bukan diantrikan. Tanpa ini antrean
        // menumpuk dan penggunaan memori naik terus.
        videoOutput.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        videoOutput.alwaysDiscardsLateVideoFrames = true

        // Setiap frame dikirim ke captureOutput lewat antrean khusus,
        // bukan main queue, supaya layar tetap responsif.
        videoOutput.setSampleBufferDelegate(self, queue: inferenceQueue)

        if session.canAddOutput(videoOutput) {
            session.addOutput(videoOutput)
        }

        if let connection = videoOutput.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
            connection.videoRotationAngle = 90
            bufferOrientation = .up
        } else {
            bufferOrientation = .right
        }

        isConfigured = true
        return true
#endif
    }

    // MARK: - Control

    func start() {
        startSession()
    }

    func startSession() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            startCapture()
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                if granted {
                    self?.startCapture()
                } else {
                    self?.setStatus(.denied)
                }
            }
        default:
            setStatus(.denied)
        }
    }

    private func startCapture() {
#if targetEnvironment(simulator)
        guard !simulatorCaptureStarted else { return }
        simulatorCaptureStarted = true
        _ = configureInputOutput()
        SimulatorCamera.start()
        setStatus(.running)
#else
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if !self.isConfigured, !self.configureInputOutput() {
                self.setStatus(.unavailable)
                return
            }
            if !self.session.isRunning {
                self.session.startRunning()
            }
            self.setStatus(.running)
        }
#endif
    }

    func stop() {
        stopSession()
        pauseCounting()
    }

    func stopSession() {
#if targetEnvironment(simulator)
        guard simulatorCaptureStarted else { return }
        simulatorCaptureStarted = false
        SimulatorCamera.stop()
        setStatus(.idle)
#else
        sessionQueue.async { [weak self] in
            guard let self else { return }
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            self.setStatus(.idle)
        }
#endif
    }

    // MARK: - Counting & Detection Controls

    func startCounting() {
        inferenceQueue.async { [weak self] in
            self?.isCountingActive = true
        }
    }

    func pauseCounting() {
        inferenceQueue.async { [weak self] in
            self?.isCountingActive = false
        }
    }

    func update(config: CountingConfig) {
        inferenceQueue.async { [weak self] in
            guard let self else { return }
            self.countingConfig = config
            self.tracker.maxMatchDistance = CGFloat(config.maxMatchDistance)
            self.tracker.maxMissedFrames = config.maxMissedFrames
            self.counter.config = config
        }
    }

    func reset() {
        inferenceQueue.async { [weak self] in
            guard let self else { return }
            self.tracker.reset()
            self.counter.reset()
            DispatchQueue.main.async {
                self.counts = FruitCounts()
                self.visibleFruit = []
                self.countedIDs = []
                self.detections = []
            }
        }
    }

    func detect(image: CGImage, orientation: CGImagePropertyOrientation) throws -> [FruitDetection] {
        guard let model = visionModel else { return [] }
        let request = VNCoreMLRequest(model: model)
#if targetEnvironment(simulator)
        request.usesCPUOnly = true
#endif
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        try handler.perform([request])

        guard let observations = request.results as? [VNRecognizedObjectObservation] else { return [] }
        let kept = Self.suppressOverlaps(observations)
        return kept.compactMap { obs in
            guard let top = obs.labels.first else { return nil }
            guard let bucket = self.mapping.bucket(for: top.identifier) ?? (top.identifier.localizedCaseInsensitiveContains("bad") ? .defect : nil) else { return nil }
            let box = obs.boundingBox
            let flipped = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
            return FruitDetection(label: top.identifier, bucket: bucket, confidence: top.confidence, boundingBox: flipped)
        }
    }

    private func setStatus(_ status: Status) {
        DispatchQueue.main.async {
            self.status = status
            switch status {
            case .running:
                self.isRunning = true
                self.permissionDenied = false
            case .denied:
                self.isRunning = false
                self.permissionDenied = true
            case .idle:
                self.isRunning = false
                self.permissionDenied = false
            case .unavailable:
                self.isRunning = false
                self.permissionDenied = false
            }
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated func captureOutput(_ output: AVCaptureOutput,
                                   didOutput sampleBuffer: CMSampleBuffer,
                                   from connection: AVCaptureConnection)
    {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let sideways: [CGImagePropertyOrientation] = [.left, .right, .leftMirrored, .rightMirrored]
        let rotated = sideways.contains(bufferOrientation)
        let currentFrameSize = rotated ? CGSize(width: height, height: width) : CGSize(width: width, height: height)

        // Hand frame to external consumers (e.g. DetectionPipeline)
        onFrame?(pixelBuffer, bufferOrientation)

#if targetEnvironment(simulator)
        let ciImage = CIImage(cvPixelBuffer: pixelBuffer)
        if let cgImage = ciContext.createCGImage(ciImage, from: ciImage.extent) {
            let image = UIImage(cgImage: cgImage, scale: 1, orientation: bufferOrientation == .up ? .up : .right)
            DispatchQueue.main.async { [weak self] in self?.previewImage = image }
        }
#endif

        guard let model = visionModel else { return }

        let now = Date()
        guard now.timeIntervalSince(lastInferenceTime) >= inferenceInterval else { return }
        lastInferenceTime = now

        let request = VNCoreMLRequest(model: model) { [weak self] request, error in
            guard let self = self,
                  error == nil,
                  let observations = request.results as? [VNRecognizedObjectObservation] else { return }

            let kept = Self.suppressOverlaps(observations)

            let detections = kept.map {
                Detection(label: $0.labels.first?.identifier.capitalized ?? "?",
                          confidence: $0.confidence,
                          boundingBox: $0.boundingBox)
            }

            let fruitDetections: [FruitDetection] = kept.compactMap { obs in
                guard let top = obs.labels.first else { return nil }
                let rawLabel = top.identifier
                guard let bucket = self.mapping.bucket(for: rawLabel) ?? (rawLabel.localizedCaseInsensitiveContains("bad") ? .defect : nil) else { return nil }
                let box = obs.boundingBox
                let flipped = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
                return FruitDetection(
                    label: rawLabel,
                    bucket: bucket,
                    confidence: top.confidence,
                    boundingBox: flipped
                )
            }

            let visible = self.tracker.update(with: fruitDetections)
            if self.isCountingActive {
                self.counter.process(visible)
            }
            let currentCounts = self.counter.counts
            let currentCountedIDs = Set(visible.map(\.id).filter { self.counter.isCounted($0) })

            DispatchQueue.main.async {
                self.detections = detections
                self.visibleFruit = visible
                self.counts = currentCounts
                self.countedIDs = currentCountedIDs
                if self.frameSize != currentFrameSize {
                    self.frameSize = currentFrameSize
                }
            }
        }

#if targetEnvironment(simulator)
        request.usesCPUOnly = true
#endif

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer,
                                            orientation: bufferOrientation,
                                            options: [:])
        do {
            try handler.perform([request])
        } catch {
            print("Inference error: \(error)")
        }
    }

    private nonisolated static func suppressOverlaps(_ observations: [VNRecognizedObjectObservation]) -> [VNRecognizedObjectObservation] {
        var kept: [VNRecognizedObjectObservation] = []
        for candidate in observations.sorted(by: { $0.confidence > $1.confidence }) {
            let overlapsKept = kept.contains { keeper in
                iou(keeper.boundingBox, candidate.boundingBox) > iouThreshold
            }
            if !overlapsKept {
                kept.append(candidate)
            }
        }
        return kept
    }

    private nonisolated static func iou(_ a: CGRect, _ b: CGRect) -> Double {
        let intersection = a.intersection(b)
        guard !intersection.isNull else { return 0 }
        let interArea = Double(intersection.width * intersection.height)
        let unionArea = Double(a.width * a.height + b.width * b.height) - interArea
        return interArea / unionArea
    }
}

// MARK: - CameraPreview

/// Live camera preview (portrait, aspect-fill).
struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.previewLayer.session = session
        view.previewLayer.videoGravity = .resizeAspectFill
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {}

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }

        var previewLayer: AVCaptureVideoPreviewLayer {
            layer as! AVCaptureVideoPreviewLayer
        }

        override func layoutSubviews() {
            super.layoutSubviews()
            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
                connection.videoRotationAngle = 90
            }
        }
    }
}
