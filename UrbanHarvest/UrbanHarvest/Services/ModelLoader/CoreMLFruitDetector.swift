import CoreML
import Vision

/// Runs a Create ML Object Detection model through Vision.
final class CoreMLFruitDetector: FruitDetecting, @unchecked Sendable {
    let isDemo = false

    private let visionModel: VNCoreMLModel
    private let mapping: ClassMapping

    init(model: MLModel, mapping: ClassMapping) throws {
        self.visionModel = try VNCoreMLModel(for: model)
        self.mapping = mapping
    }

    func detect(pixelBuffer: CVPixelBuffer, orientation: CGImagePropertyOrientation) throws -> [FruitDetection] {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: orientation, options: [:])
        return try run(handler)
    }

    func detect(image: CGImage, orientation: CGImagePropertyOrientation) throws -> [FruitDetection] {
        let handler = VNImageRequestHandler(cgImage: image, orientation: orientation, options: [:])
        return try run(handler)
    }

    private func run(_ handler: VNImageRequestHandler) throws -> [FruitDetection] {
        // A new request per call keeps this safe if two callers overlap.
        let request = VNCoreMLRequest(model: visionModel)
        request.imageCropAndScaleOption = cropOption
        try handler.perform([request])

        let observations = request.results as? [VNRecognizedObjectObservation] ?? []
        return observations.compactMap(makeDetection)
    }

    private func makeDetection(_ observation: VNRecognizedObjectObservation) -> FruitDetection? {
        guard let top = observation.labels.first,
              top.confidence >= mapping.minimumConfidence,
              let bucket = mapping.bucket(for: top.identifier) else {
            return nil
        }
        // Vision boxes are normalized with the origin at the bottom-left; flip to top-left.
        let box = observation.boundingBox
        let flipped = CGRect(x: box.minX, y: 1 - box.maxY, width: box.width, height: box.height)
        return FruitDetection(label: top.identifier, bucket: bucket, confidence: top.confidence, boundingBox: flipped)
    }

    private var cropOption: VNImageCropAndScaleOption {
        switch mapping.cropAndScale {
        case .scaleFill: return .scaleFill
        case .scaleFit: return .scaleFit
        case .centerCrop: return .centerCrop
        }
    }
}
