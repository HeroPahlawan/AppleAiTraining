import SwiftData
import SwiftUI

/// Asks for the session details and saves a `HarvestSession`.
struct SaveSessionSheet: View {
    let counts: FruitCounts
    /// Fruit detected by the model, pre-selected in the picker when the schema has it.
    var suggestedFruit: FruitType? = nil
    var onSaved: () -> Void = {}

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var fruitType: FruitType = .tomato
    @State private var fieldArea: Double = 1_000
    @State private var notes = ""

    private var areaError: String? {
        var input = AdvisorInput.default
        input.fieldAreaM2 = fieldArea
        return FeatureSchema.validationError(for: input)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Hasil hitung") {
                    LabeledContent("Baik", value: "\(counts.good)")
                    LabeledContent("Cacat", value: "\(counts.defect)")
                    LabeledContent("Total", value: "\(counts.total)")
                    LabeledContent("Cacat %", value: SpokenText.displayPercent(counts.defectPercent))
                }

                Section("Detail") {
                    Picker("Jenis buah", selection: $fruitType) {
                        ForEach(FruitType.allCases) { Text($0.displayName).tag($0) }
                    }
                    HStack {
                        Text("Luas lahan")
                        Spacer()
                        TextField("1000", value: $fieldArea, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .frame(maxWidth: 140)
                        Text("m²").foregroundStyle(.secondary)
                    }
                    if let areaError {
                        Text(areaError).font(.caption).foregroundStyle(.red)
                    }
                    TextField("Catatan (opsional)", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                }
            }
            .onAppear {
                if let suggestedFruit { fruitType = suggestedFruit }
            }
            .navigationTitle("Simpan Sesi")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Batal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Simpan", action: save)
                        .disabled(areaError != nil || counts.total == 0)
                }
            }
        }
    }

    private func save() {
        modelContext.insert(HarvestSession(
            date: .now,
            fruitType: fruitType.rawValue,
            goodCount: counts.good,
            defectCount: counts.defect,
            fieldArea: fieldArea,
            notes: notes.trimmingCharacters(in: .whitespacesAndNewlines)
        ))
        try? modelContext.save()
        onSaved()
        dismiss()
    }
}

#Preview {
    SaveSessionSheet(counts: FruitCounts(good: 128, defect: 14))
        .previewEnvironment()
}
