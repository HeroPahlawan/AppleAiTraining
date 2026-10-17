import SwiftUI

struct FruitGradeResultView: View {
    let detection: FruitGradeDetection
    var onRetake: () -> Void
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            topBar
            // Takes whatever height the card leaves, so it adapts to every iPhone size.
            photo
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            resultCard
                .background {
                    UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28)
                        .fill(Color(.systemBackground))
                        .shadow(color: .black.opacity(0.08), radius: 12, y: -4)
                        .ignoresSafeArea(edges: .bottom)
                }
        }
        // Opaque, so the presenting screen never shows through the full-screen cover.
        .background(Color(.secondarySystemBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private var photo: some View {
        if let image = detection.image {
            Color.clear
                .overlay {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .overlay {
                    if let box = detection.boundingBox {
                        FruitGradeBoxOverlay(
                            rect: box,
                            imageSize: image.size,
                            mode: .fit,
                            title: detection.fruit.displayName,
                            subtitle: detection.ripeness.rawValue,
                            color: detection.ripeness.color
                        )
                    }
                }
        } else {
            FruitGradePhotoBackground(emoji: detection.fruit.emoji, dark: true)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        }
    }

    private var topBar: some View {
        HStack {
            Button(action: onRetake) {
                Image(systemName: "chevron.left")
                    .font(.headline)
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(.regularMaterial, in: Circle())
            }
            .accessibilityLabel("Back")
            Spacer()
            Text("Detection Result")
                .font(.headline)
            Spacer()
            if let image = detection.image {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(detection.fruit.displayName, image: Image(uiImage: image))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .frame(width: 40, height: 40)
                        .background(.regularMaterial, in: Circle())
                }
                .accessibilityLabel("Share")
            } else {
                Color.clear.frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
    }

    private var resultCard: some View {
        VStack(spacing: 18) {
            HStack(spacing: 16) {
                FruitGradeProgressRing(
                    progress: detection.confidence,
                    color: detection.ripeness.color,
                    label: detection.confidencePercentText
                )
                .frame(width: 70, height: 70)

                VStack(alignment: .leading, spacing: 2) {
                    Text(detection.fruit.displayName)
                        .font(.title3.weight(.bold))
                    Text(detection.ripeness.rawValue)
                        .font(.headline)
                        .foregroundStyle(detection.ripeness.color)
                }
                Spacer()
            }

            Text(detection.ripeness.summary)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)

            HStack {
                resultStat(title: "Fruit", value: "\(detection.fruit.emoji) \(detection.fruit.displayName)")
                Spacer()
                resultStat(title: "Quality", value: detection.ripeness.quality, dot: detection.ripeness.color)
                Spacer()
                resultStat(title: "Detected", value: "\(detection.detectedCount)")
            }
            .padding(12)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            Button(action: onSave) {
                Text("Save to History")
                    .font(.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(.green, in: RoundedRectangle(cornerRadius: 14))
            }

            Button(action: onRetake) {
                Text("Retake")
                    .font(.subheadline.weight(.medium))
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 24)
        .padding(.bottom, 8)
    }

    private func resultStat(title: String, value: String, dot: Color? = nil) -> some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                if let dot {
                    Circle().fill(dot).frame(width: 6, height: 6)
                }
                Text(value).font(.subheadline.weight(.semibold))
            }
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

#Preview("With photo") {
    FruitGradeResultView(
        detection: FruitGradeDetection(
            fruit: .apple,
            ripeness: .ripe,
            confidence: 0.98,
            mode: .snapshot,
            image: SampleImage.drawn(),
            // Box spanning almost the whole photo, like the real apple test.
            boundingBox: CGRect(x: 0.08, y: 0.02, width: 0.84, height: 0.9),
            detectedCount: 2,
            modelName: "FruitsQualityDetector TL 1500"
        ),
        onRetake: {},
        onSave: {}
    )
}

#Preview("No photo") {
    FruitGradeResultView(detection: .preview, onRetake: {}, onSave: {})
}
