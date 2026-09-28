import SwiftData
import SwiftUI

@main
struct EviTrainApp: App {
    private let container: ModelContainer
    @State private var studyStore = StudyStore()
    @State private var restTimer = RestTimer()

    init() {
        do {
            container = try ModelContainer(for: Exercise.self, Workout.self, WorkoutEntry.self, SetRecord.self)
        } catch {
            fatalError("データベースを開けませんでした: \(error)")
        }
        ExerciseCatalog.seedIfNeeded(container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(studyStore)
                .environment(restTimer)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system

    var body: some View {
        TabView {
            WorkoutHomeView()
                .tabItem { Label("記録", systemImage: "figure.strengthtraining.traditional") }
            HistoryView()
                .tabItem { Label("履歴", systemImage: "chart.xyaxis.line") }
            StudiesView()
                .tabItem { Label("論文", systemImage: "doc.text.magnifyingglass") }
            SettingsView()
                .tabItem { Label("設定", systemImage: "gearshape") }
        }
        .preferredColorScheme(appearance.colorScheme)
    }
}
