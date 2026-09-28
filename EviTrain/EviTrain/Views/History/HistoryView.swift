import Charts
import SwiftData
import SwiftUI

/// 「履歴」タブ。日付ごとの記録と、種目ごとの伸びを切り替えて見る。
struct HistoryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case workouts = "日付"
        case exercises = "種目"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .workouts

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .workouts: WorkoutHistoryList()
                case .exercises: ExerciseHistoryList()
                }
            }
            .navigationTitle("履歴")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("表示", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 180)
                }
            }
        }
    }
}

private struct WorkoutHistoryList: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]

    var body: some View {
        if workouts.isEmpty {
            ContentUnavailableView("まだ記録がありません", systemImage: "list.bullet.clipboard",
                                   description: Text("「記録」タブからトレーニングを始めましょう"))
        } else {
            List {
                ForEach(workouts) { workout in
                    NavigationLink {
                        WorkoutEditorView(workout: workout, isActive: false)
                    } label: {
                        WorkoutRow(workout: workout)
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(workouts[index]) }
                    try? context.save()
                }
            }
        }
    }
}

private struct WorkoutRow: View {
    let workout: Workout

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(workout.startedAt, format: .dateTime.year().month().day().weekday())
                    .font(.headline)
                Spacer()
                Text(workout.duration.clock)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Text(workout.sortedEntries.compactMap(\.exercise?.name).joined(separator: "・"))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(2)
            if workout.totalVolume > 0 {
                Text("総挙上量 \(workout.totalVolume.short)kg ・ \(workout.completedSetCount)セット")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

private struct ExerciseHistoryList: View {
    @Query(sort: \Exercise.name) private var exercises: [Exercise]

    private var trained: [Exercise] {
        exercises.filter { !Stats.history(for: $0).isEmpty }
    }

    var body: some View {
        if trained.isEmpty {
            ContentUnavailableView("まだ記録がありません", systemImage: "chart.xyaxis.line")
        } else {
            List(trained) { exercise in
                NavigationLink {
                    ExerciseProgressView(exercise: exercise)
                } label: {
                    HStack {
                        Text(exercise.name)
                        Spacer()
                        if let best = Stats.personalBest(for: exercise) {
                            Text("自己ベスト \(best.short)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

/// 種目ごとの伸び（グラフ）と、関連する論文。
struct ExerciseProgressView: View {
    @Environment(PaperStore.self) private var paperStore
    let exercise: Exercise

    var body: some View {
        let points = Stats.history(for: exercise)
        List {
            Section(exercise.tracking.metricLabel) {
                Chart(points) { point in
                    LineMark(x: .value("日付", point.date), y: .value("記録", point.value))
                    PointMark(x: .value("日付", point.date), y: .value("記録", point.value))
                }
                .chartYScale(domain: .automatic(includesZero: false))
                .frame(height: 220)
                .padding(.vertical)

                if let best = Stats.personalBest(for: exercise) {
                    LabeledContent("自己ベスト", value: best.short)
                }
                LabeledContent("記録回数", value: "\(points.count)回")
                if !exercise.tracking.higherIsBetter {
                    Text("タイムは小さいほど速い記録です")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            let papers = paperStore.related(to: exercise)
            if !papers.isEmpty {
                Section("この種目に関係する研究") {
                    ForEach(papers) { paper in
                        NavigationLink {
                            PaperDetailView(paper: paper)
                        } label: {
                            PaperRow(paper: paper)
                        }
                    }
                }
            }
        }
        .navigationTitle(exercise.name)
    }
}
