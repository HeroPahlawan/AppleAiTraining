import SwiftUI

struct FruitGradeResultView: View {
    let detection: FruitGradeDetection
    var onRetake: () -> Void
    var onSave: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            photo
                .frame(height: 360)
                .overlay(alignment: .top) { topBar }

            resultCard
            Spacer(minLength: 0)
        }
        .ignoresSafeArea(edges: .top)
    }

    private var photo: some View {
        FruitGradePhotoBackground(image: detection.image, emoji: detection.fruit.emoji, dark: true, contentMode: .fit)
            .overlay {
                if let image = detection.image, let box = detection.boundingBox {
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
    }

    private var topBar: some View {
        HStack {
            Button(action: onRetake) {
                Image(systemName: "chevron.left")
                    .foregroundStyle(.white)
                    .padding(10)
                    .background(.black.opacity(0.35), in: Circle())
            }
            Spacer()
            if let image = detection.image {
                ShareLink(
                    item: Image(uiImage: image),
                    preview: SharePreview(detection.fruit.displayName, image: Image(uiImage: image))
                ) {
                    Image(systemName: "square.and.arrow.up")
                        .foregroundStyle(.white)
                        .padding(10)
                        .background(.black.opacity(0.35), in: Circle())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 60)
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
        .padding(20)
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

#Preview {
    FruitGradeResultView(detection: .preview, onRetake: {}, onSave: {})
}
