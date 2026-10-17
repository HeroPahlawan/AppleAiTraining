import SwiftUI

/// Shows the captured photo, or a leafy gradient with the fruit emoji when there is none.
struct FruitGradePhotoBackground: View {
    var image: UIImage? = nil
    var emoji: String
    var dark: Bool = true
    var contentMode: ContentMode = .fill

    var body: some View {
        LinearGradient(
            colors: dark
                ? [Color(red: 0.05, green: 0.18, blue: 0.08), Color(red: 0.1, green: 0.3, blue: 0.14)]
                : [Color(red: 0.75, green: 0.88, blue: 0.7), Color(red: 0.55, green: 0.75, blue: 0.5)],
            startPoint: .top, endPoint: .bottom
        )
        .overlay {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: contentMode)
            } else {
                Text(emoji)
                    .font(.system(size: 140))
                    .shadow(radius: 10)
            }
        }
        .clipped()
    }
}

/// Green/red bounding-box rectangle with a label pill, mimicking the detection overlay.
struct FruitGradeBoundingBox: View {
    var title: String
    var subtitle: String?
    var color: Color = .green
    var size = CGSize(width: 180, height: 170)

    var body: some View {
        ZStack(alignment: .topLeading) {
            RoundedRectangle(cornerRadius: 10)
                .stroke(color, lineWidth: 2.5)
                .frame(width: size.width, height: size.height)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.caption.weight(.semibold))
                if let subtitle {
                    Text(subtitle)
                        .font(.caption2)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(color, in: RoundedRectangle(cornerRadius: 6))
            .foregroundStyle(.white)
            .fixedSize()
            .alignmentGuide(.top) { $0[.bottom] - 4 }
        }
    }
}

/// Places a `FruitGradeBoundingBox` over an image shown with aspect-fill or aspect-fit.
struct FruitGradeBoxOverlay: View {
    /// Normalized (0...1) rectangle, top-left origin.
    var rect: CGRect
    var imageSize: CGSize
    var mode: NormalizedRectMapper.Mode
    var title: String
    var subtitle: String?
    var color: Color

    var body: some View {
        GeometryReader { geometry in
            let mapped = NormalizedRectMapper(imageSize: imageSize, viewSize: geometry.size, mode: mode).rect(for: rect)
            FruitGradeBoundingBox(title: title, subtitle: subtitle, color: color, size: mapped.size)
                .offset(x: mapped.minX, y: mapped.minY)
        }
        .allowsHitTesting(false)
    }
}

/// Circular ring used on the Result screen to show confidence.
struct FruitGradeProgressRing: View {
    var progress: Double
    var color: Color = .green
    var lineWidth: CGFloat = 6
    var label: String

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Text(label)
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

/// Square thumbnail: the captured photo, or the fruit emoji.
struct FruitGradeThumbnail: View {
    let detection: FruitGradeDetection
    var cornerRadius: CGFloat = 12

    var body: some View {
        // Color sizes to the proposed frame, so an aspect-filled photo can't grow the thumbnail.
        Color.green.opacity(0.12)
            .overlay {
                if let image = detection.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Text(detection.fruit.emoji).font(.title)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
    }
}

/// Small colored status chip: "Ripe" / "Unripe".
struct FruitGradeStatusChip: View {
    var ripeness: FruitGradeRipeness

    var body: some View {
        Text(ripeness.rawValue)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(ripeness.color.opacity(0.9), in: Capsule())
            .foregroundStyle(.white)
    }
}

#if DEBUG
extension View {
    /// Injects the FruitGrade environment (mock detector + a seeded in-memory history) for previews.
    @MainActor
    func fruitGradePreviewEnvironment() -> some View {
        self
            .environment(FruitGradeHistoryStore(items: [.preview]))
            .environment(FruitGradeDetectionService(detector: MockFruitDetector(), modelName: "Preview"))
    }
}
#endif

#Preview("Shared components") {
    VStack(spacing: 20) {
        FruitGradeBoundingBox(title: "Apple", subtitle: "Ripeness: Ripe · 92%")
            .padding(.top, 30)
        HStack(spacing: 16) {
            FruitGradeProgressRing(progress: 0.92, label: "92%")
                .frame(width: 70, height: 70)
            FruitGradeStatusChip(ripeness: .ripe)
            FruitGradeStatusChip(ripeness: .unripe)
        }
    }
    .padding()
}
