import ImageIO
import UIKit

/// Image for photo test mode when no camera is available.
///
/// Uses `Resources/sample_fruits.jpg` (or .png) if you add one; otherwise
/// draws a simple illustration of fruit on a table so the flow still works.
enum SampleImage {
    static let resourceName = "sample_fruits"

    static func load(bundle: Bundle = .main) -> UIImage {
        for ext in ["jpg", "jpeg", "png"] {
            if let url = bundle.url(forResource: resourceName, withExtension: ext),
               let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return drawn()
    }

    static func drawn(size: CGSize = CGSize(width: 900, height: 1200)) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            let cg = context.cgContext
            UIColor(red: 0.93, green: 0.91, blue: 0.86, alpha: 1).setFill()
            cg.fill(CGRect(origin: .zero, size: size))

            let fruits: [(CGPoint, CGFloat, UIColor, Bool)] = [
                (CGPoint(x: 200, y: 220), 95, .systemRed, false),
                (CGPoint(x: 470, y: 260), 105, .systemOrange, false),
                (CGPoint(x: 720, y: 210), 90, .systemRed, true),
                (CGPoint(x: 260, y: 560), 100, .systemGreen, false),
                (CGPoint(x: 560, y: 600), 110, .systemOrange, true),
                (CGPoint(x: 220, y: 920), 95, .systemRed, false),
                (CGPoint(x: 520, y: 950), 100, .systemYellow, false),
                (CGPoint(x: 760, y: 880), 92, .systemRed, false),
            ]

            for (center, radius, color, damaged) in fruits {
                // Shadow
                UIColor.black.withAlphaComponent(0.12).setFill()
                cg.fillEllipse(in: CGRect(x: center.x - radius + 10, y: center.y - radius + 14, width: radius * 2, height: radius * 2))
                // Fruit
                (damaged ? color.withAlphaComponent(0.65) : color).setFill()
                cg.fillEllipse(in: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
                // Highlight
                UIColor.white.withAlphaComponent(0.35).setFill()
                cg.fillEllipse(in: CGRect(x: center.x - radius * 0.55, y: center.y - radius * 0.6, width: radius * 0.45, height: radius * 0.3))
                if damaged {
                    UIColor.brown.withAlphaComponent(0.85).setFill()
                    cg.fillEllipse(in: CGRect(x: center.x - radius * 0.1, y: center.y, width: radius * 0.55, height: radius * 0.45))
                    cg.fillEllipse(in: CGRect(x: center.x - radius * 0.5, y: center.y + radius * 0.2, width: radius * 0.3, height: radius * 0.25))
                }
            }
        }
    }
}

extension UIImage {
    /// A CGImage plus the EXIF orientation Vision needs to read it upright.
    var visionInput: (image: CGImage, orientation: CGImagePropertyOrientation)? {
        if let cgImage {
            return (cgImage, CGImagePropertyOrientation(imageOrientation))
        }
        // e.g. CIImage-backed images: render once to a bitmap.
        let rendered = UIGraphicsImageRenderer(size: size).image { _ in draw(at: .zero) }
        guard let renderedCG = rendered.cgImage else { return nil }
        return (renderedCG, .up)
    }
}

extension CGImagePropertyOrientation {
    init(_ orientation: UIImage.Orientation) {
        switch orientation {
        case .up: self = .up
        case .upMirrored: self = .upMirrored
        case .down: self = .down
        case .downMirrored: self = .downMirrored
        case .left: self = .left
        case .leftMirrored: self = .leftMirrored
        case .right: self = .right
        case .rightMirrored: self = .rightMirrored
        @unknown default: self = .up
        }
    }
}
