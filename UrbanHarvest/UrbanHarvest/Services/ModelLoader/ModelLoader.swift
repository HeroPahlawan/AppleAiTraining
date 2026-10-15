import CoreML
import Foundation

/// Loads compiled Create ML models (`<name>.mlmodelc`) from the app bundle by
/// name. Never references Xcode's generated model classes, so the app builds
/// and runs whether or not the `.mlmodel` files are present.
enum ModelLoader {
    static func compiledModelURL(named name: String, in bundle: Bundle = .main) -> URL? {
        bundle.url(forResource: name, withExtension: "mlmodelc")
    }

    static func loadModel(named name: String, in bundle: Bundle = .main) -> Result<MLModel, Error>? {
        guard let url = compiledModelURL(named: name, in: bundle) else { return nil }
        let configuration = MLModelConfiguration()
        configuration.computeUnits = .all
        return Result { try MLModel(contentsOf: url, configuration: configuration) }
    }
}

/// Status line shown in Settings for each model.
struct ModelStatus: Equatable {
    var modelName: String
    var isLoaded: Bool
    var detail: String
}

/// Picks the real Core ML implementation when the model is in the bundle,
/// otherwise the demo-mode mock. Created once at app start.
final class ModelProvider: ObservableObject {
    let mapping: ClassMapping
    let detector: FruitDetecting
    let predictor: YieldPredicting
    let detectorStatus: ModelStatus
    let predictorStatus: ModelStatus

    var isDetectorDemo: Bool { detector.isDemo }
    var isPredictorDemo: Bool { predictor.isDemo }
    var isAnyDemo: Bool { detector.isDemo || predictor.isDemo }

    init(
        mapping: ClassMapping,
        detector: FruitDetecting,
        predictor: YieldPredicting,
        detectorStatus: ModelStatus,
        predictorStatus: ModelStatus
    ) {
        self.mapping = mapping
        self.detector = detector
        self.predictor = predictor
        self.detectorStatus = detectorStatus
        self.predictorStatus = predictorStatus
    }

    static func live(bundle: Bundle = .main) -> ModelProvider {
        let mapping = ClassMapping.load(from: bundle)

        // Detector
        let detector: FruitDetecting
        let detectorStatus: ModelStatus
        switch ModelLoader.loadModel(named: mapping.detectorModelName, in: bundle) {
        case .success(let model)?:
            do {
                detector = try CoreMLFruitDetector(model: model, mapping: mapping)
                detectorStatus = ModelStatus(modelName: mapping.detectorModelName, isLoaded: true, detail: "Model Core ML aktif")
            } catch {
                detector = MockFruitDetector()
                detectorStatus = ModelStatus(modelName: mapping.detectorModelName, isLoaded: false, detail: "Bukan model deteksi objek: \(error.localizedDescription)")
            }
        case .failure(let error)?:
            detector = MockFruitDetector()
            detectorStatus = ModelStatus(modelName: mapping.detectorModelName, isLoaded: false, detail: "Gagal dimuat: \(error.localizedDescription)")
        case nil:
            detector = MockFruitDetector()
            detectorStatus = ModelStatus(modelName: mapping.detectorModelName, isLoaded: false, detail: "File tidak ditemukan, memakai detektor demo")
        }

        // Advisor
        let predictor: YieldPredicting
        let predictorStatus: ModelStatus
        switch ModelLoader.loadModel(named: mapping.advisorModelName, in: bundle) {
        case .success(let model)?:
            let real = CoreMLYieldPredictor(model: model, configuredTarget: mapping.advisorTarget)
            predictor = real
            predictorStatus = ModelStatus(modelName: mapping.advisorModelName, isLoaded: true, detail: "Model Core ML aktif (target: \(real.target.rawValue))")
        case .failure(let error)?:
            predictor = MockYieldPredictor(target: mapping.advisorTarget ?? .defectRate)
            predictorStatus = ModelStatus(modelName: mapping.advisorModelName, isLoaded: false, detail: "Gagal dimuat: \(error.localizedDescription)")
        case nil:
            predictor = MockYieldPredictor(target: mapping.advisorTarget ?? .defectRate)
            predictorStatus = ModelStatus(modelName: mapping.advisorModelName, isLoaded: false, detail: "File tidak ditemukan, memakai aturan demo")
        }

        return ModelProvider(
            mapping: mapping,
            detector: detector,
            predictor: predictor,
            detectorStatus: detectorStatus,
            predictorStatus: predictorStatus
        )
    }
}
