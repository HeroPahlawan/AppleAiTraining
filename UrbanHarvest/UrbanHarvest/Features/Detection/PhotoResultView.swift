import SwiftUI

/// FruitGrade-style result card for an analyzed photo: boxes, confidence ring and counts.
struct PhotoResultView: View {
    @ObservedObject var model: DetectionViewModel
    var onRetake: () -> Void
    var onClose: () -> Void

    @EnvironmentObject private var settings: AppSettings
    @State private var showingSaveSheet = false
    @State private var didSave = false

    /// Highest-confidence detection drives the ring and the headline.
    private var top: FruitDetection? {
        model.photoDetections.max(by: { $0.confidence < $1.confidence })
    }

    private var fruit: FruitKind {
        top.map { FruitKind(label: $0.label) } ?? .unknown
    }

    private var bucket: FruitBucket { top?.bucket ?? .good }

    private var bucketColor: Color { bucket == .defect ? .defect : .good }

    private var counts: FruitCounts { model.displayedCounts }

    var body: some View {
        VStack(spacing: 0) {
            photo
                .frame(height: 360)
                .overlay(alignment: .top) { topBar }

            ScrollView {
                resultCard
            }
        }
        .ignoresSafeArea(edges: .top)
        .sheet(isPresented: $showingSaveSheet, onDismiss: {
            if didSave { onClose() }
        }) {
            SaveSessionSheet(counts: counts, suggestedFruit: model.dominantPhotoFruit.fruitType) {
                didSave = true
            }
        }
    }

    private var photo: some View {
        FruitGradePhotoBackground(image: model.photo, emoji: fruit.emoji, contentMode: .fit)
            .overlay {
                if let image = model.photo {
                    DetectionOverlay(boxes: model.overlayBoxesForPhoto(), imageSize: image.size, mode: .fit)
                }
            }
    }

    private var topBar: some View {
        HStack {
            Button(action: onClose) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
            .accessibilityLabel("Kembali")
            if model.isDemo {
                DemoBadge()
            }
            Spacer()
            if let image = model.photo {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(fruit.displayName, image: Image(uiImage: image))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.35), in: Circle())
                }
                .accessibilityLabel("Bagikan")
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
    }

    private var resultCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                FruitGradeProgressRing(
                    progress: Double(top?.confidence ?? 0),
                    color: bucketColor,
                    label: "\(Int(((top?.confidence ?? 0) * 100).rounded()))%"
                )
                .frame(width: 70, height: 70)
                .accessibilityLabel("Keyakinan \(Int(((top?.confidence ?? 0) * 100).rounded())) persen")

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(fruit.emoji) \(fruit.displayName)")
                        .font(.title3.weight(.bold))
                    Text(bucket.displayName)
                        .font(.headline)
                        .foregroundStyle(bucketColor)
                }
                Spacer()
                EstimateTag()
            }

            Text(bucket.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                resultStat(title: "Baik", value: "\(counts.good)", dot: .good)
                Spacer()
                resultStat(title: "Cacat", value: "\(counts.defect)", dot: .defect)
                Spacer()
                resultStat(title: "Terdeteksi", value: "\(counts.total)")
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            HStack {
                Spacer()
                ListenButton(id: "photo-result", text: SpokenText.countsSpoken(counts, language: settings.speechLanguage))
            }

            Button {
                showingSaveSheet = true
            } label: {
                Text("Simpan Sesi")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.good, in: RoundedRectangle(cornerRadius: 14))
            }

            Button("Ulangi", action: onRetake)
                .font(.subheadline.weight(.medium))
        }
        .padding(20)
    }

    private func resultStat(title: String, value: String, dot: Color? = nil) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let dot {
                    Circle().fill(dot).frame(width: 6, height: 6)
                }
                Text(value).font(.subheadline.weight(.semibold).monospacedDigit())
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    let model = DetectionViewModel(detector: MockFruitDetector(), config: .default)
    return PhotoResultView(model: model, onRetake: {}, onClose: {})
        .task {
            model.source = .photo
            await model.analyze(photo: SampleImage.load())
        }
        .previewEnvironment()
}
