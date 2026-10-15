import SwiftUI

/// Maps normalized (0...1, top-left origin) image coordinates onto a view
/// that shows the image with aspect-fill or aspect-fit.
struct NormalizedRectMapper {
    enum Mode { case fill, fit }

    let imageSize: CGSize
    let viewSize: CGSize
    let mode: Mode

    private var displayedRect: CGRect {
        guard imageSize.width > 0, imageSize.height > 0 else {
            return CGRect(origin: .zero, size: viewSize)
        }
        let sx = viewSize.width / imageSize.width
        let sy = viewSize.height / imageSize.height
        let scale = mode == .fill ? max(sx, sy) : min(sx, sy)
        let size = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        return CGRect(
            x: (viewSize.width - size.width) / 2,
            y: (viewSize.height - size.height) / 2,
            width: size.width,
            height: size.height
        )
    }

    func rect(for normalized: CGRect) -> CGRect {
        let d = displayedRect
        return CGRect(
            x: d.minX + normalized.minX * d.width,
            y: d.minY + normalized.minY * d.height,
            width: normalized.width * d.width,
            height: normalized.height * d.height
        )
    }

    func y(forNormalized y: CGFloat) -> CGFloat {
        let d = displayedRect
        return d.minY + y * d.height
    }
}

/// One box to draw.
struct OverlayBox: Identifiable {
    let id: String
    let rect: CGRect
    let bucket: FruitBucket
    let title: String
    let confidence: Float
    /// Already counted (drawn with a check mark).
    var counted = false
}

/// Bounding boxes (green = good, red = defect) and the optional counting line.
struct DetectionOverlay: View {
    let boxes: [OverlayBox]
    let imageSize: CGSize
    let mode: NormalizedRectMapper.Mode
    /// Normalized y of the counting line, or nil to hide it.
    var linePosition: Double?

    var body: some View {
        GeometryReader { geometry in
            let mapper = NormalizedRectMapper(imageSize: imageSize, viewSize: geometry.size, mode: mode)
            ZStack(alignment: .topLeading) {
                if let linePosition {
                    let y = mapper.y(forNormalized: CGFloat(linePosition))
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                    .stroke(Color.yellow, style: StrokeStyle(lineWidth: 2, dash: [8, 6]))
                }

                ForEach(boxes) { box in
                    let rect = mapper.rect(for: box.rect)
                    let color: Color = box.bucket == .good ? .green : .red

                    Rectangle()
                        .stroke(color, lineWidth: box.counted ? 4 : 2)
                        .frame(width: rect.width, height: rect.height)
                        .offset(x: rect.minX, y: rect.minY)

                    HStack(spacing: 3) {
                        if box.counted {
                            Image(systemName: "checkmark.circle.fill")
                        }
                        Text(verbatim: "\(box.title) \(Int((box.confidence * 100).rounded()))%")
                    }
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 2)
                    .background(color)
                    .fixedSize()
                    .offset(x: rect.minX, y: max(rect.minY - 18, 0))
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
    }
}
