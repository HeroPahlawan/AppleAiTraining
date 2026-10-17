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

/// Circular ring used on the result screen to show confidence.
struct FruitGradeProgressRing: View {
    var progress: Double
    var color: Color = .good
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
                .lineLimit(1)
                .minimumScaleFactor(0.6)
                .padding(lineWidth + 2)
        }
    }
}

/// Large tappable card that starts a detection mode from the home screen.
struct FruitGradeModeCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle().fill(tint).frame(width: 44, height: 44)
                    Image(systemName: icon).foregroundStyle(.white)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(14)
            .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

/// White text on a translucent black capsule, for hints over the camera feed.
struct FruitGradeHintPill: View {
    let text: String

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.medium))
            .multilineTextAlignment(.center)
            .foregroundStyle(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(.black.opacity(0.45), in: Capsule())
            .padding(.horizontal, 24)
    }
}

#Preview("Shared components") {
    VStack(spacing: 20) {
        FruitGradeModeCard(icon: "camera.fill", tint: .good, title: "Kamera Langsung", subtitle: "Hitung buah secara langsung.") {}
        FruitGradeProgressRing(progress: 0.92, label: "92%")
            .frame(width: 70, height: 70)
        FruitGradeHintPill(text: "Tekan Mulai untuk menghitung buah")
            .padding()
            .background(.gray)
    }
    .padding()
}
