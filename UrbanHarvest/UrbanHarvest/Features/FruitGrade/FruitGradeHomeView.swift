import PhotosUI
import SwiftUI

struct FruitGradeHomeView: View {
    @Environment(FruitGradeHistoryStore.self) private var store
    @Environment(FruitGradeDetectionService.self) private var service

    @State private var showCamera = false
    @State private var showPicker = false
    @State private var pickerItem: PhotosPickerItem?
    @State private var result: FruitGradeDetection?
    @State private var isAnalyzing = false
    @State private var alertMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                header

                VStack(alignment: .leading, spacing: 4) {
                    Text("Hello, Naufan 👋")
                        .font(.title2.weight(.bold))
                    Text("Detect fruit ripeness easily with camera or photo.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 12) {
                    ModeCard(
                        icon: "camera.fill",
                        tint: .green,
                        title: "Live",
                        subtitle: "Detect fruit in real time using your camera."
                    ) {
                        showCamera = true
                    }
                    ModeCard(
                        icon: "photo.fill",
                        tint: .blue,
                        title: "Snapshot",
                        subtitle: "Detect from your photo or gallery."
                    ) {
                        showPicker = true
                    }
                }

                HStack {
                    Text("Recent Activity")
                        .font(.headline)
                    Spacer()
                    NavigationLink("View all") {
                        FruitGradeHistoryView()
                    }
                    .font(.subheadline)
                }

                recentActivity
            }
            .padding()
        }
        .overlay {
            if isAnalyzing {
                ProgressView("Analyzing…")
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .photosPicker(isPresented: $showPicker, selection: $pickerItem, matching: .images)
        .onChange(of: pickerItem) {
            guard let item = pickerItem else { return }
            pickerItem = nil
            Task { await analyze(item) }
        }
        .fullScreenCover(isPresented: $showCamera) {
            FruitGradeLiveCameraView(onClose: { showCamera = false })
        }
        .fullScreenCover(item: $result) { detection in
            FruitGradeResultView(
                detection: detection,
                onRetake: {
                    result = nil
                    showPicker = true
                },
                onSave: {
                    store.add(detection)
                    result = nil
                }
            )
        }
        .alert("No fruit detected", isPresented: alertBinding) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage ?? "")
        }
    }

    private var header: some View {
        HStack {
            Label("FruitGrade", systemImage: "leaf.fill")
                .font(.title3.weight(.bold))
                .foregroundStyle(.green)
            if service.isDemo {
                DemoBadge()
            }
            Spacer()
            Button {
                // Placeholder: no settings destination yet.
            } label: {
                Image(systemName: "gearshape")
                    .foregroundStyle(.primary)
            }
        }
    }

    @ViewBuilder
    private var recentActivity: some View {
        if store.items.isEmpty {
            Text("No detections yet. Use Live or Snapshot, then tap Save to History.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        } else {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(alignment: .top, spacing: 14) {
                    ForEach(store.items.prefix(4)) { detection in
                        NavigationLink {
                            FruitGradeDetailView(detection: detection)
                        } label: {
                            RecentActivityCard(detection: detection)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private var alertBinding: Binding<Bool> {
        Binding(get: { alertMessage != nil }, set: { if !$0 { alertMessage = nil } })
    }

    private func analyze(_ item: PhotosPickerItem) async {
        isAnalyzing = true
        defer { isAnalyzing = false }
        do {
            guard let data = try await item.loadTransferable(type: Data.self), let image = UIImage(data: data) else {
                throw FruitGradeDetectionService.AnalysisError.unreadableImage
            }
            if let detection = try await service.analyze(image: image, mode: .snapshot) {
                result = detection
            } else {
                alertMessage = FruitGradeDetectionService.noFruitMessage
            }
        } catch {
            alertMessage = error.localizedDescription
        }
    }
}

private struct ModeCard: View {
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

private struct RecentActivityCard: View {
    let detection: FruitGradeDetection

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            FruitGradeThumbnail(detection: detection)
                .frame(width: 84, height: 84)

            Text(detection.fruit.displayName)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
            Text(FruitGradeDetection.timeAgo(from: detection.date))
                .font(.caption2)
                .foregroundStyle(.secondary)
            FruitGradeStatusChip(ripeness: detection.ripeness)
        }
        .frame(width: 84)
    }
}

#Preview {
    NavigationStack { FruitGradeHomeView() }
        .fruitGradePreviewEnvironment()
}
