import AVFoundation
import ImageIO
import SwiftUI

/// Owns the AVCaptureSession and hands every video frame to `onFrame`
/// on a background queue.
//final class CameraManager: NSObject, ObservableObject, @unchecked Sendable {
//    enum Status: Equatable {
//        case idle
//        case running
//        case denied
//        /// No camera (e.g. the simulator) or it could not be configured.
//        case unavailable
//    }
//
//    @Published private(set) var status: Status = .idle
//
//    let session = AVCaptureSession()
//
//    /// Called on the video queue for each frame. Set before calling `start()`.
//    var onFrame: (@Sendable (CVPixelBuffer, CGImagePropertyOrientation) -> Void)?
//
//    private let sessionQueue = DispatchQueue(label: "UrbanHarvest.camera.session")
//    private let videoQueue = DispatchQueue(label: "UrbanHarvest.camera.video", qos: .userInitiated)
//    private let output = AVCaptureVideoDataOutput()
//    private var isConfigured = false
//    /// `.up` when the connection rotates buffers to portrait, otherwise `.right`.
//    private var bufferOrientation: CGImagePropertyOrientation = .right
//
//    static var isCameraAvailable: Bool {
//        AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) != nil
//    }
//
//    func start() {
//        switch AVCaptureDevice.authorizationStatus(for: .video) {
//        case .authorized:
//            startSession()
//        case .notDetermined:
//            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
//                if granted {
//                    self?.startSession()
//                } else {
//                    self?.setStatus(.denied)
//                }
//            }
//        default:
//            setStatus(.denied)
//        }
//    }
//
//    func stop() {
//        sessionQueue.async { [weak self] in
//            guard let self else { return }
//            guard self.session.isRunning else { return }
//            self.session.stopRunning()
//            self.setStatus(.idle)
//        }
//    }
//
//    private func startSession() {
//        sessionQueue.async { [weak self] in
//            guard let self else { return }
//            if !self.isConfigured && !self.configure() {
//                self.setStatus(.unavailable)
//                return
//            }
//            if !self.session.isRunning {
//                self.session.startRunning()
//            }
//            self.setStatus(.running)
//        }
//    }
//
//    private func configure() -> Bool {
//        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
//              let input = try? AVCaptureDeviceInput(device: device) else {
//            return false
//        }
//
//        session.beginConfiguration()
//        defer { session.commitConfiguration() }
//
//        if session.canSetSessionPreset(.hd1280x720) {
//            session.sessionPreset = .hd1280x720
//        }
//        guard session.canAddInput(input) else { return false }
//        session.addInput(input)
//
//        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
//        // Drop frames while Vision is busy instead of queueing them.
//        output.alwaysDiscardsLateVideoFrames = true
//        output.setSampleBufferDelegate(self, queue: videoQueue)
//        guard session.canAddOutput(output) else { return false }
//        session.addOutput(output)
//
//        if let connection = output.connection(with: .video), connection.isVideoRotationAngleSupported(90) {
//            connection.videoRotationAngle = 90
//            bufferOrientation = .up
//        } else {
//            bufferOrientation = .right
//        }
//
//        isConfigured = true
//        return true
//    }
//
//    private func setStatus(_ status: Status) {
//        DispatchQueue.main.async { self.status = status }
//    }
//}
//
//extension CameraManager: AVCaptureVideoDataOutputSampleBufferDelegate {
//    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
//        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
//        onFrame?(pixelBuffer, bufferOrientation)
//    }
//}
//
///// Live camera preview (portrait, aspect-fill).
//struct CameraPreview: UIViewRepresentable {
//    let session: AVCaptureSession
//
//    func makeUIView(context: Context) -> PreviewView {
//        let view = PreviewView()
//        view.previewLayer.session = session
//        view.previewLayer.videoGravity = .resizeAspectFill
//        return view
//    }
//
//    func updateUIView(_ uiView: PreviewView, context: Context) {}
//
//    final class PreviewView: UIView {
//        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
//
//        var previewLayer: AVCaptureVideoPreviewLayer {
//            layer as! AVCaptureVideoPreviewLayer
//        }
//
//        override func layoutSubviews() {
//            super.layoutSubviews()
//            if let connection = previewLayer.connection, connection.isVideoRotationAngleSupported(90) {
//                connection.videoRotationAngle = 90
//            }
//        }
//    }
//}
