import SwiftUI

struct AdvisorView: View {
    @EnvironmentObject private var models: ModelProvider
    @EnvironmentObject private var settings: AppSettings
    @StateObject private var model = AdvisorViewModel()

    var body: some View {
        NavigationStack {
            Form {
                inputSections

                Section {
                    Button {
                        Task {
                            await model.analyze(using: models.predictor)
                        }
                    } label: {
                        if model.isAnalyzing {
                            HStack(spacing: 8) {
                                ProgressView()
                                    .tint(.white)
                                Text("Menganalisis dengan Apple Intelligence...")
                            }
                            .frame(maxWidth: .infinity)
                        } else {
                            Label("Analisis", systemImage: "wand.and.stars")
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(model.validationError != nil || model.isAnalyzing)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
                }

                if let errorMessage = model.errorMessage {
                    Section {
                        Text(errorMessage).foregroundStyle(.red)
                    }
                }

                if let result = model.result {
                    resultSections(result)
                }

                advisorySection
            }
            .navigationTitle("Penasihat Panen")
            .toolbar {
                if models.isPredictorDemo {
                    ToolbarItem(placement: .topBarTrailing) { DemoBadge() }
                } else {
                    ToolbarItem(placement: .topBarTrailing) {
                        Label("Apple Intelligence", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.accentColor.opacity(0.15), in: Capsule())
                            .foregroundStyle(Color.accentColor)
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Reset") { model.resetInput() }
                        .disabled(model.isAnalyzing)
                }
            }
        }
    }

    // MARK: Inputs

    @ViewBuilder
    private var inputSections: some View {
        Section {
            Picker("Jenis buah", selection: $model.input.fruitType) {
                ForEach(FruitType.allCases) { Text($0.displayName).tag($0) }
            }
            HStack {
                Text("Luas lahan")
                Spacer()
                TextField("1000", value: $model.input.fieldAreaM2, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 140)
                Text("m²").foregroundStyle(.secondary)
            }
            if let error = model.validationError {
                Text(error).font(.caption).foregroundStyle(.red)
            }
        } header: {
            Text("Buah dan lahan")
        }

        Section {
            OptionPicker(title: "Curah hujan", selection: $model.input.rainfall)
            OptionPicker(title: "Suhu", selection: $model.input.temperature)
            OptionPicker(title: "Langit", selection: $model.input.sky)
        } header: {
            Text("Cuaca")
        } footer: {
            Text("Cuaca dan luas lahan dianggap tetap saat mencari saran.")
        }

        Section {
            OptionPicker(title: "Irigasi", selection: $model.input.irrigation)
            OptionPicker(title: "Waktu panen", selection: $model.input.harvestTiming)
        } header: {
            Text("Yang bisa Anda atur")
        }
    }

    // MARK: Results

    @ViewBuilder
    private func resultSections(_ result: WhatIfResult) -> some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                if let summary = model.aiSummary {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Analisis Apple Intelligence", systemImage: "sparkles")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color.accentColor)
                        Text(summary)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding(.bottom, 4)
                    Divider()
                }

                HStack {
                    Text("Perkiraan \(result.target.displayName.lowercased())")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    EstimateTag()
                }
                Text(SpokenText.displayValue(result.baseline, target: result.target))
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(result.target == .defectRate ? Color.defect : Color.good)
                ListenButton(
                    id: "analysis-summary",
                    text: SpokenText.analysisSpoken(
                        result,
                        advisories: model.advisories,
                        summary: settings.speechLanguage == .english ? model.aiEnglishSummary : model.aiSummary,
                        language: settings.speechLanguage
                    )
                )
            }
            .padding(.vertical, 4)
        } header: {
            Text("Hasil analisis")
        }

        Section {
            if result.suggestions.isEmpty {
                Label("Pengaturan Anda sudah baik. Tidak ada perubahan yang jelas lebih baik.", systemImage: "checkmark.seal")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(result.suggestions.enumerated()), id: \.element.id) { index, suggestion in
                    SuggestionCard(rank: index + 1, suggestion: suggestion, language: settings.speechLanguage)
                }
            }
        } header: {
            Text("Saran perubahan")
        } footer: {
            Text("Semua angka adalah perkiraan model, bukan jaminan. Setiap saran hanya mengubah satu hal.")
        }
    }

    private var advisorySection: some View {
        Section {
            if model.advisories.isEmpty {
                Label("Tidak ada peringatan untuk kondisi ini.", systemImage: "checkmark.circle")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(model.advisories) { advisory in
                    AdvisoryCard(advisory: advisory, language: settings.speechLanguage)
                }
            }
        } header: {
            Text("Peringatan dan tips")
        } footer: {
            Text(model.isUsingFoundationModel
                ? "Dihasilkan langsung oleh model kecerdasan buatan Apple Intelligence pada perangkat."
                : "Berdasarkan aturan sederhana, tetap berlaku tanpa model.")
        }
    }
}

/// Segmented picker with a caption, for any `FeatureOption` enum.
private struct OptionPicker<Option: FeatureOption>: View where Option.AllCases: RandomAccessCollection {
    let title: String
    @Binding var selection: Option

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.subheadline)
            Picker(title, selection: $selection) {
                ForEach(Option.allCases) { option in
                    Text(option.displayName).tag(option)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
        .padding(.vertical, 2)
    }
}

private struct SuggestionCard: View {
    let rank: Int
    let suggestion: WhatIfSuggestion
    let language: SpeechLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text("\(rank)")
                    .font(.caption.weight(.bold))
                    .frame(width: 22, height: 22)
                    .background(Color.accentColor.opacity(0.2), in: Circle())
                Text(SpokenText.title(for: suggestion.change))
                    .font(.headline)
                Spacer()
                EstimateTag()
            }
            Text(SpokenText.suggestionDisplay(suggestion))
                .font(.subheadline)
            HStack(spacing: 6) {
                Text(SpokenText.displayValue(suggestion.baseline, target: suggestion.target))
                    .foregroundStyle(.secondary)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
                Text(SpokenText.displayValue(suggestion.predicted, target: suggestion.target))
                    .fontWeight(.semibold)
                    .foregroundStyle(.good)
            }
            .font(.subheadline.monospacedDigit())
            ListenButton(
                id: "suggestion-\(rank)-\(suggestion.change.hashValue)",
                text: SpokenText.suggestionSpoken(suggestion, language: language)
            )
        }
        .padding(.vertical, 4)
    }
}

private struct AdvisoryCard: View {
    let advisory: Advisory
    let language: SpeechLanguage

    private var color: Color {
        switch advisory.severity {
        case .critical: return .red
        case .warning: return .orange
        case .info: return .blue
        }
    }

    private var icon: String {
        switch advisory.severity {
        case .critical: return "exclamationmark.octagon.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .info: return "info.circle.fill"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(advisory.title, systemImage: icon)
                .font(.headline)
                .foregroundStyle(color)
            Text(advisory.message)
                .font(.subheadline)
            ListenButton(id: "advisory-\(advisory.id)", text: SpokenText.advisorySpoken(advisory, language: language))
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    AdvisorView()
        .previewEnvironment()
}
