import SwiftData
import SwiftUI
import UserNotifications

@main
struct EviTrainApp: App {
    private let container: ModelContainer
    @State private var studyStore = StudyStore()
    @State private var restTimer = RestTimer()

    init() {
        do {
            container = try ModelContainer(for: Exercise.self, Workout.self, WorkoutEntry.self, SetRecord.self,
                                           MenuTemplate.self, MenuItem.self, BodyWeight.self)
        } catch {
            fatalError("データベースを開けませんでした: \(error)")
        }
        ExerciseCatalog.seedIfNeeded(container.mainContext)
        // アプリを開いているときも休憩終了の通知を出す
        UNUserNotificationCenter.current().delegate = ForegroundNotificationPresenter.shared
    }

    var body: some Scene {
        WindowGroup {
            ThemeProvider {
                RootView()
            }
            .environment(studyStore)
            .environment(restTimer)
        }
        .modelContainer(container)
    }
}

struct RootView: View {
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(OnboardingView.seenKey) private var onboardingSeen = false

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
        .fullScreenCover(isPresented: Binding(get: { !onboardingSeen }, set: { if !$0 { onboardingSeen = true } })) {
            OnboardingView()
        }
    }
}
