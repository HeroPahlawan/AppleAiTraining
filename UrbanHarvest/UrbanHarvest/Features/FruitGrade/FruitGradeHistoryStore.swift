import Observation

/// Saved detections for the current app run only (not persisted).
@MainActor
@Observable
final class FruitGradeHistoryStore {
    private(set) var items: [FruitGradeDetection]

    init(items: [FruitGradeDetection] = []) {
        self.items = items
    }

    func add(_ detection: FruitGradeDetection) {
        items.insert(detection, at: 0)
    }

    func remove(id: FruitGradeDetection.ID) {
        items.removeAll { $0.id == id }
    }
}
