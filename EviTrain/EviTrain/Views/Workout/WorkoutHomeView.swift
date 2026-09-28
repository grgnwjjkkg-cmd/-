import SwiftData
import SwiftUI

/// 「記録」タブ。進行中のトレーニングがあればそれを表示し、なければ開始画面を出す。
struct WorkoutHomeView: View {
    @Query(filter: #Predicate<Workout> { $0.finishedAt == nil }, sort: \Workout.startedAt)
    private var activeWorkouts: [Workout]
    @State private var finishSummary: FinishSummary?

    var body: some View {
        NavigationStack {
            if let workout = activeWorkouts.first {
                WorkoutEditorView(workout: workout, isActive: true) { finishSummary = $0 }
            } else {
                StartScreen()
            }
        }
        .fullScreenCover(item: $finishSummary) { summary in
            FinishCelebrationView(summary: summary)
        }
    }
}

/// トレーニング開始画面：前回のメニュー → マイメニュー → 空で始める → 今日の研究。
private struct StartScreen: View {
    @Environment(\.modelContext) private var context
    @Environment(StudyStore.self) private var studyStore
    @Environment(\.appTheme) private var theme
    @AppStorage(AppSettings.weeklySetTargetKey) private var weeklySetTarget = 0

    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var finishedWorkouts: [Workout]
    @Query(sort: \MenuTemplate.createdAt, order: .reverse) private var menus: [MenuTemplate]

    private var sortedMenus: [MenuTemplate] {
        menus.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return (a.lastUsedAt ?? a.createdAt) > (b.lastUsedAt ?? b.createdAt)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                Text(Date.now, format: .dateTime.month().day().weekday(.wide))
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)

                HStack(spacing: 10) {
                    StatTile(title: "連続日数", value: "\(Stats.streakDays(finishedWorkouts))日", systemImage: "flame.fill", tint: .orange)
                    StatTile(title: "今週", value: "\(Stats.countThisWeek(finishedWorkouts))回", systemImage: "calendar", tint: theme.accent)
                }

                if let last = finishedWorkouts.first {
                    LastWorkoutCard(workout: last) { MenuBuilder.startWorkout(copying: last, in: context) }
                }

                myMenus

                Button {
                    let workout = Workout()
                    context.insert(workout)
                    try? context.save()
                } label: {
                    Label("空のトレーニングで始める", systemImage: "plus")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
                        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(.tint.opacity(0.5)))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)

                if let study = studyStore.studyOfTheDay() {
                    DailyStudyCard(study: study)
                }

                if weeklySetTarget > 0 {
                    WeeklySetsCard(counts: Stats.weeklySets(finishedWorkouts), target: weeklySetTarget)
                }
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle("トレーニング")
    }

    private var myMenus: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("マイメニュー").font(.title3.bold())
                Spacer()
                NavigationLink {
                    MyMenusView()
                } label: {
                    Text(menus.isEmpty ? "作る" : "すべて見る・編集")
                        .font(.subheadline)
                }
            }
            if menus.isEmpty {
                Text("よく使うメニューを保存すると、ここから1タップで始められます。論文の「このメニューで練習する」からも追加できます。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(sortedMenus.prefix(8)) { menu in
                            MenuCard(menu: menu) { MenuBuilder.startWorkout(from: menu, in: context) }
                        }
                    }
                }
            }
        }
    }
}

/// 前回のトレーニングを、そのまま今日のメニューにするカード。
private struct LastWorkoutCard: View {
    @Environment(\.appTheme) private var theme
    let workout: Workout
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("前回のメニュー", systemImage: "arrow.counterclockwise")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                Spacer()
                Text(workout.startedAt, format: .dateTime.month().day().weekday())
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if let name = workout.menuName {
                Text(name).font(.headline)
            }
            VStack(alignment: .leading, spacing: 6) {
                ForEach(workout.sortedEntries.prefix(5)) { entry in
                    let sets = entry.sortedSets.filter(\.isDone)
                    HStack(spacing: 8) {
                        ExerciseIcon(exercise: entry.exercise, size: 24)
                        Text(entry.exercise?.name ?? "")
                            .lineLimit(1)
                        Spacer()
                        if let last = sets.last {
                            Text("\(last.summary(for: entry.tracking)) × \(sets.count)セット")
                                .font(.subheadline.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                }
                if workout.entries.count > 5 {
                    Text("ほか \(workout.entries.count - 5) 種目").font(.caption).foregroundStyle(.secondary)
                }
            }
            Button(action: onStart) {
                Label("このメニューで今日を始める", systemImage: "play.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 12)
                    .foregroundStyle(theme.onAccent)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            Text("前回の重さと回数が入った状態で始まります")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding()
        .background(theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}

/// マイメニューの小さなカード（横スクロール）。
private struct MenuCard: View {
    @Environment(\.appTheme) private var theme
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }) private var finished: [Workout]
    let menu: MenuTemplate
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                if menu.isFavorite {
                    Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption)
                }
                if menu.sourcePMID != nil {
                    Image(systemName: "doc.text").foregroundStyle(.tint).font(.caption)
                }
                Spacer()
            }
            Text(menu.name)
                .font(.subheadline.bold())
                .lineLimit(2)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, minHeight: 40, alignment: .topLeading)
            Text(menu.sortedItems.compactMap(\.exercise?.name).joined(separator: "・"))
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .topLeading)
            if menu.weeks != nil || menu.perWeek != nil {
                MenuProgressView(menu: menu, sessions: finished.filter { $0.menuName == menu.name }, compact: true)
            }
            Button(action: onStart) {
                Label("開始", systemImage: "play.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 8)
                    .foregroundStyle(theme.onAccent)
                    .background(theme.accent, in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(12)
        .frame(width: 170)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}

struct StatTile: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let value: String
    let systemImage: String
    let tint: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label(title, systemImage: systemImage)
                .font(.caption)
                .foregroundStyle(tint)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
    }
}
