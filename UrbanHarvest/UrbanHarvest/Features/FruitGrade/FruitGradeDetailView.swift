import SwiftUI

struct FruitGradeDetailView: View {
    let detection: FruitGradeDetection

    @Environment(FruitGradeHistoryStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                ripenessCard
                detailsSection
            }
        }
        .navigationBarBackButtonHidden()
        .ignoresSafeArea(edges: .top)
    }

    private var header: some View {
        FruitGradePhotoBackground(image: detection.image, emoji: detection.fruit.emoji, dark: false)
            .frame(height: 300)
            .overlay(alignment: .top) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                    Spacer()
                    Button {
                        store.remove(id: detection.id)
                        dismiss()
                    } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.white)
                            .padding(10)
                            .background(.black.opacity(0.35), in: Circle())
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)
            }
            .overlay(alignment: .bottom) {
                HStack(alignment: .bottom) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(detection.fruit.displayName)
                            .font(.title3.weight(.bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 4)
                        FruitGradeStatusChip(ripeness: detection.ripeness)
                    }
                    Spacer()
                    Text(detection.confidencePercentText)
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(.black.opacity(0.35), in: Capsule())
                        .foregroundStyle(.white)
                }
                .padding(16)
            }
    }

    private var ripenessCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: detection.ripeness.icon)
                    .font(.title2)
                    .foregroundStyle(detection.ripeness.color)
                    .padding(8)
                    .background(detection.ripeness.color.opacity(0.15), in: Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(detection.ripeness.rawValue).font(.headline)
                    Text(detection.ripeness.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }

            ProgressView(value: detection.confidence)
                .tint(detection.ripeness.color)
        }
        .padding(16)
    }

    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Detection Details")
                .font(.headline)
                .padding(.bottom, 8)

            detailRow("Ripeness Level", detection.ripeness.rawValue)
            detailRow("Quality", detection.ripeness.quality)
            detailRow("Confidence", detection.confidencePercentText)
            detailRow("Detected At", detection.date.formatted(date: .abbreviated, time: .shortened))
            detailRow("Mode", detection.mode.rawValue)
            detailRow("Fruits Detected", "\(detection.detectedCount)")
            detailRow("Model", detection.modelName, showDivider: false)
        }
        .padding(16)
    }

    private func detailRow(_ title: String, _ value: String, showDivider: Bool = true) -> some View {
        VStack(spacing: 0) {
            HStack {
                Text(title).foregroundStyle(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline.weight(.medium))
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 10)
            if showDivider { Divider() }
        }
    }
}

#Preview {
    NavigationStack { FruitGradeDetailView(detection: .preview) }
        .fruitGradePreviewEnvironment()
}
