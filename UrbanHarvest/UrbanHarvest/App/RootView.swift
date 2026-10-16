import SwiftData
import SwiftUI

struct RootView: View {
    @EnvironmentObject private var models: ModelProvider
    @EnvironmentObject private var settings: AppSettings
    @EnvironmentObject private var speech: SpeechService
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        TabView {
            DetectionView(detector: models.detector, config: settings.counting)
                .tabItem { Label("Deteksi", systemImage: "camera.viewfinder") }

            DashboardView()
                .tabItem { Label("Dasbor", systemImage: "chart.bar.xaxis") }

            AdvisorView()
                .tabItem { Label("Penasihat", systemImage: "lightbulb") }

            SettingsView()
                .tabItem { Label("Pengaturan", systemImage: "gearshape") }
        }
        .tint(.green)
        .onAppear(perform: applySpeechSettings)
        .onChange(of: settings.speechLanguage) { applySpeechSettings() }
        .onChange(of: settings.speechRate) { applySpeechSettings() }
        .task {
            if models.isAnyDemo && !settings.demoSeeded {
                DemoSeeder.seedIfEmpty(modelContext)
                settings.demoSeeded = true
            }
        }
    }

    private func applySpeechSettings() {
        speech.language = settings.speechLanguage
        speech.rate = Float(settings.speechRate)
    }
}

#Preview {
    RootView()
        .previewEnvironment()
}
