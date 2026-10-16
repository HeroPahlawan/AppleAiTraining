#if DEBUG
import SwiftData
import SwiftUI

/// Shared setup for Xcode Previews: the same environment objects the app
/// injects, an in-memory SwiftData store and the Indonesian locale.
@MainActor
enum PreviewSupport {
    /// In-memory container, optionally filled with the demo sessions.
    static func container(seeded: Bool = true) -> ModelContainer {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: true)
        // An in-memory store for a single known model cannot realistically fail.
        let container = try! ModelContainer(for: HarvestSession.self, configurations: configuration)
        if seeded {
            DemoSeeder.seed(container.mainContext)
        }
        return container
    }

    /// Settings backed by a throwaway suite so previews never touch the app's real preferences.
    static func settings() -> AppSettings {
        AppSettings(defaults: UserDefaults(suiteName: "UrbanHarvest.previews") ?? .standard)
    }
}

extension View {
    /// Injects everything the app's views expect from `UrbanHarvestApp`.
    @MainActor
    func previewEnvironment(seeded: Bool = true) -> some View {
        self
            .environmentObject(ModelProvider.live())
            .environmentObject(PreviewSupport.settings())
            .environmentObject(SpeechService())
            .environment(\.locale, Locale(identifier: "id_ID"))
            .modelContainer(PreviewSupport.container(seeded: seeded))
    }
}
#endif
