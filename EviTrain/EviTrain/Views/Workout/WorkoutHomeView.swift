import SwiftData
import SwiftUI

/// 「記録」タブ。進行中のトレーニングがあればそれを表示し、なければ開始画面を出す。
struct WorkoutHomeView: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workout> { $0.finishedAt == nil }, sort: \Workout.startedAt)
    private var activeWorkouts: [Workout]
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var finishedWorkouts: [Workout]
    @State private var finishedRecords: [Stats.Record]?

    var body: some View {
        NavigationStack {
            if let workout = activeWorkouts.first {
                WorkoutEditorView(workout: workout, isActive: true) { finishedRecords = $0 }
            } else {
                startScreen
            }
        }
        .alert("お疲れさまでした！", isPresented: Binding(
            get: { finishedRecords != nil },
            set: { if !$0 { finishedRecords = nil } }
        )) {
            Button("OK") { finishedRecords = nil }
        } message: {
            Text(finishMessage)
        }
    }

    private var finishMessage: String {
        guard let records = finishedRecords, !records.isEmpty else { return "記録を保存しました。" }
        let lines = records.map { "🏆 \($0.exercise.name): \($0.value.short)" }
        return "自己ベスト更新！\n" + lines.joined(separator: "\n")
    }

    private var startScreen: some View {
        List {
            Section {
                HStack(spacing: 12) {
                    StatTile(title: "連続日数", value: "\(Stats.streakDays(finishedWorkouts))日", systemImage: "flame.fill", tint: .orange)
                    StatTile(title: "今週", value: "\(Stats.countThisWeek(finishedWorkouts))回", systemImage: "calendar", tint: .blue)
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            Section {
                Button {
                    start(copying: nil)
                } label: {
                    Label("空のトレーニングを開始", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(.borderedProminent)
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
            }

            if !finishedWorkouts.isEmpty {
                Section("前回と同じメニューで開始") {
                    ForEach(finishedWorkouts.prefix(5)) { workout in
                        Button {
                            start(copying: workout)
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(workout.startedAt, format: .dateTime.month().day().weekday())
                                    .font(.subheadline.bold())
                                Text(workout.sortedEntries.compactMap(\.exercise?.name).joined(separator: "・"))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .tint(.primary)
                    }
                }
            }
        }
        .navigationTitle("トレーニング")
    }

    /// 新しいトレーニングを始める。コピー元があれば種目とセット内容（未完了状態）を引き継ぐ。
    private func start(copying source: Workout?) {
        let workout = Workout()
        context.insert(workout)
        for (index, entry) in (source?.sortedEntries ?? []).enumerated() {
            guard let exercise = entry.exercise else { continue }
            let newEntry = WorkoutEntry(order: index, exercise: exercise)
            context.insert(newEntry)
            newEntry.workout = workout
            for (setIndex, set) in entry.sortedSets.filter(\.isDone).enumerated() {
                let copy = SetRecord(order: setIndex, weight: set.weight, reps: set.reps,
                                     seconds: set.seconds, meters: set.meters)
                context.insert(copy)
                copy.entry = newEntry
            }
        }
        try? context.save()
    }
}

struct StatTile: View {
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
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 12))
    }
}
