import SwiftUI

struct FruitGradeHistoryView: View {
    @Environment(FruitGradeHistoryStore.self) private var store

    @State private var searchText = ""
    /// `nil` means "All".
    @State private var selectedFruit: FruitKind?

    private var filteredHistory: [FruitGradeDetection] {
        store.items
            .filter { selectedFruit == nil || $0.fruit == selectedFruit }
            .filter { searchText.isEmpty || $0.fruit.displayName.localizedCaseInsensitiveContains(searchText) }
    }

    var body: some View {
        VStack(spacing: 14) {
            searchField

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    FilterChip(title: "All", isSelected: selectedFruit == nil) {
                        selectedFruit = nil
                    }
                    ForEach(FruitKind.detectable) { fruit in
                        FilterChip(title: fruit.displayName, isSelected: selectedFruit == fruit) {
                            selectedFruit = fruit
                        }
                    }
                }
            }

            if store.items.isEmpty {
                ContentUnavailableView(
                    "No detections yet",
                    systemImage: "clock",
                    description: Text("Detect a fruit with Live or Snapshot, then tap Save to History.")
                )
            } else if filteredHistory.isEmpty {
                ContentUnavailableView("No results", systemImage: "magnifyingglass")
            } else {
                List(filteredHistory) { detection in
                    NavigationLink {
                        FruitGradeDetailView(detection: detection)
                    } label: {
                        HistoryRow(detection: detection)
                    }
                }
                .listStyle(.plain)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .frame(maxHeight: .infinity, alignment: .top)
        .navigationTitle("History")
    }

    private var searchField: some View {
        HStack {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Search fruit...", text: $searchText)
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
    }
}

private struct FilterChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.subheadline.weight(.medium))
                .padding(.horizontal, 14)
                .padding(.vertical, 7)
                .background(isSelected ? Color.green : Color(.secondarySystemBackground), in: Capsule())
                .foregroundStyle(isSelected ? .white : .primary)
        }
        .buttonStyle(.plain)
    }
}

private struct HistoryRow: View {
    let detection: FruitGradeDetection

    var body: some View {
        HStack(spacing: 12) {
            FruitGradeThumbnail(detection: detection, cornerRadius: 10)
                .frame(width: 48, height: 48)

            VStack(alignment: .leading, spacing: 2) {
                Text(detection.fruit.displayName).font(.subheadline.weight(.semibold))
                Text(detection.ripeness.rawValue)
                    .font(.caption)
                    .foregroundStyle(detection.ripeness.color)
                Text(detection.confidencePercentText)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(detection.date.formatted(date: .abbreviated, time: .shortened))
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}

#Preview {
    NavigationStack { FruitGradeHistoryView() }
        .fruitGradePreviewEnvironment()
}
