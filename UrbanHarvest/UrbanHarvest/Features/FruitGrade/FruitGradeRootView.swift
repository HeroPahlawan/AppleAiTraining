import SwiftUI

/// Entry point for FruitGrade: splash, then a tabbed Home/History/Profile flow driven by
/// the detector from `ModelProvider` (FruitsQualityDetector, or the demo mock if missing).
struct FruitGradeRootView: View {
    @EnvironmentObject private var models: ModelProvider

    @State private var showSplash = true
    @State private var store = FruitGradeHistoryStore()
    @State private var service: FruitGradeDetectionService?

    var body: some View {
        Group {
            if showSplash {
                FruitGradeSplashView(onGetStarted: { withAnimation { showSplash = false } })
            } else if let service {
                FruitGradeMainTabView()
                    .environment(service)
                    .environment(store)
            }
        }
        .onAppear {
            if service == nil {
                service = FruitGradeDetectionService(detector: models.detector, modelName: models.mapping.detectorModelName)
            }
        }
    }
}

struct FruitGradeMainTabView: View {
    var body: some View {
        TabView {
            NavigationStack { FruitGradeHomeView() }
                .tabItem { Label("Home", systemImage: "house.fill") }

            NavigationStack { FruitGradeHistoryView() }
                .tabItem { Label("History", systemImage: "clock") }

            NavigationStack { FruitGradeProfileView() }
                .tabItem { Label("Profile", systemImage: "person.fill") }
        }
        .tint(.green)
    }
}

private struct FruitGradeProfileView: View {
    var body: some View {
        List {
            Section {
                HStack(spacing: 14) {
                    Circle()
                        .fill(Color.green.opacity(0.15))
                        .frame(width: 56, height: 56)
                        .overlay(Image(systemName: "person.fill").foregroundStyle(.green))
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Naufan").font(.headline)
                        Text("naufan@example.com")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }
        }
        .navigationTitle("Profile")
    }
}

#Preview {
    FruitGradeRootView()
        .previewEnvironment()
}
