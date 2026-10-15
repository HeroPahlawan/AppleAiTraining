import Charts
import SwiftData
import SwiftUI

struct DashboardView: View {
    @EnvironmentObject private var models: ModelProvider
    @EnvironmentObject private var settings: AppSettings
    @Environment(\.modelContext) private var modelContext

    @Query(sort: \HarvestSession.date, order: .reverse) private var sessions: [HarvestSession]
    @State private var granularity: DashboardStats.Granularity = .day

    var body: some View {
        NavigationStack {
            Group {
                if sessions.isEmpty {
                    ContentUnavailableView(
                        "Belum ada sesi",
                        systemImage: "basket",
                        description: Text("Hitung buah di tab Deteksi, lalu tekan Simpan Sesi.")
                    )
                } else {
                    content
                }
            }
            .navigationTitle("Dasbor")
            .toolbar {
                if sessions.contains(where: \.isDemo) {
                    ToolbarItem(placement: .topBarTrailing) { DemoBadge() }
                }
            }
        }
    }

    private var content: some View {
        let entries = sessions.map(\.statsEntry)
        let stats = DashboardStats(entries: entries)
        let points = DashboardStats.series(entries, granularity: granularity)

        return List {
            Section {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                    StatTile(title: "Total buah", value: "\(stats.total)")
                    StatTile(title: "Sesi", value: "\(stats.sessionCount)")
                    StatTile(title: "Baik", value: SpokenText.displayPercent(stats.goodPercent), color: .green)
                    StatTile(title: "Cacat", value: SpokenText.displayPercent(stats.defectPercent), color: .red)
                }
                .padding(.vertical, 4)

                ListenButton(
                    id: "dashboard-summary",
                    text: SpokenText.dashboardSpoken(
                        totalGood: stats.totalGood,
                        totalDefect: stats.totalDefect,
                        sessions: stats.sessionCount,
                        language: settings.speechLanguage
                    )
                )
            } header: {
                Text("Ringkasan")
            }

            Section {
                Picker("Periode", selection: $granularity) {
                    ForEach(DashboardStats.Granularity.allCases) { Text($0.displayName).tag($0) }
                }
                .pickerStyle(.segmented)

                if points.isEmpty {
                    Text("Tidak ada data pada periode ini.")
                        .foregroundStyle(.secondary)
                } else {
                    Chart(points) { point in
                        BarMark(
                            x: .value("Periode", point.period, unit: granularity.calendarComponent),
                            y: .value("Jumlah", point.count)
                        )
                        .foregroundStyle(by: .value("Kategori", point.bucket.displayName))
                    }
                    .chartForegroundStyleScale([
                        FruitBucket.good.displayName: Color.green,
                        FruitBucket.defect.displayName: Color.red,
                    ])
                    .frame(height: 220)
                    .padding(.vertical, 4)
                }
            } header: {
                Text("Produksi")
            }

            Section {
                ForEach(sessions) { session in
                    SessionRow(session: session)
                }
                .onDelete(perform: delete)
            } header: {
                Text("Riwayat sesi")
            }
        }
    }

    private func delete(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(sessions[index])
        }
        try? modelContext.save()
    }
}

private struct SessionRow: View {
    let session: HarvestSession

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(session.fruitDisplayName).font(.headline)
                Spacer()
                Text(session.date.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            HStack(spacing: 12) {
                Label("\(session.goodCount)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                Label("\(session.defectCount)", systemImage: "xmark.octagon.fill").foregroundStyle(.red)
                Text("Cacat \(SpokenText.displayPercent(session.defectPercent))")
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(session.fieldArea)) m²")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            if !session.notes.isEmpty {
                Text(session.notes)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.vertical, 2)
    }
}
