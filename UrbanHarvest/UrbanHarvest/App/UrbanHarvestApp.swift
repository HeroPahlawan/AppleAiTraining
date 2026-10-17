import SwiftData
import SwiftUI

@main
struct UrbanHarvestApp: App {
    @StateObject private var models = ModelProvider.live()
    @StateObject private var settings = AppSettings()
    @StateObject private var speech = SpeechService()

    var body: some Scene {
        WindowGroup {
            FruitGradeRootView()
                .environmentObject(models)
                .environmentObject(settings)
                .environmentObject(speech)
                .environment(\.locale, Locale(identifier: "id_ID"))
        }
        .modelContainer(for: HarvestSession.self)
    }
}
