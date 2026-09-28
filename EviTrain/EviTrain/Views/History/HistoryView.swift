import Charts
import SwiftData
import SwiftUI

/// 「履歴」タブ。日付ごとの記録と、種目ごとの伸びを切り替えて見る。
struct HistoryView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case workouts = "日付"
        case exercises = "種目"
        case bodyWeight = "体重"
        var id: String { rawValue }
    }

    @State private var mode: Mode = .workouts

    var body: some View {
        NavigationStack {
            Group {
                switch mode {
                case .workouts: WorkoutHistoryList()
                case .exercises: ExerciseHistoryList()
                case .bodyWeight: BodyWeightView()
                }
            }
            .themedBackground()
            .navigationTitle("履歴")
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Picker("表示", selection: $mode) {
                        ForEach(Mode.allCases) { Text($0.rawValue).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
    }
}

private struct WorkoutHistoryList: View {
    @Environment(\.modelContext) private var context
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt, order: .reverse)
    private var workouts: [Workout]
    @State private var selectedDay: Date?

    private var shownWorkouts: [Workout] {
        guard let selectedDay else { return workouts }
        return workouts.filter { Calendar.current.isDate($0.startedAt, inSameDayAs: selectedDay) }
    }

    var body: some View {
        if workouts.isEmpty {
            ContentUnavailableView("まだ記録がありません", systemImage: "list.bullet.clipboard",
                                   description: Text("「記録」タブからトレーニングを始めましょう"))
        } else {
            List {
                Section {
                    TrainingCalendarView(workouts: workouts, selectedDay: $selectedDay)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                    WeeklyVolumeChart(workouts: workouts)
                        .listRowInsets(EdgeInsets(top: 12, leading: 0, bottom: 0, trailing: 0))
                        .listRowBackground(Color.clear)
                }
                Section {
                    ForEach(shownWorkouts) { workout in
                        NavigationLink {
                            WorkoutEditorView(workout: workout, isActive: false)
                        } label: {
                            WorkoutRow(workout: workout)
                        }
                        .themedRow()
                    }
                    .onDelete { offsets in
                        let list = shownWorkouts
                        for index in offsets { context.delete(list[index]) }
                        try? context.save()
                    }
                } header: {
                    if let selectedDay {
                        HStack {
                            Text(selectedDay, format: .dateTime.month().day().weekday())
                            Spacer()
                            Button("すべて表示") { self.selectedDay = nil }
                        }
                    }
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
            if let menuName = workout.menuName {
                Label(menuName, systemImage: "star.square.on.square")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
            }
            HStack(spacing: -6) {
                ForEach(workout.sortedEntries.prefix(6)) { entry in
                    ExerciseIcon(exercise: entry.exercise, size: 22)
                        .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(.background, lineWidth: 1.5))
                }
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
            List {
                if trained.count >= 2 {
                    Section {
                        CompareProgressView(exercises: trained)
                            .listRowInsets(EdgeInsets())
                            .listRowBackground(Color.clear)
                    }
                }
                Section {
                    ForEach(trained) { exercise in
                        NavigationLink {
                            ExerciseProgressView(exercise: exercise)
                        } label: {
                            HStack(spacing: 12) {
                                ExerciseIcon(exercise: exercise, size: 34)
                                Text(exercise.name)
                                Spacer()
                                if let best = Stats.personalBest(for: exercise) {
                                    Text("自己ベスト \(best.short)")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .themedRow()
                    }
                }
            }
        }
    }
}

/// 種目ごとの伸び（グラフ）と、関連する論文。
struct ExerciseProgressView: View {
    @Environment(StudyStore.self) private var studyStore
    @Query(sort: \BodyWeight.date, order: .reverse) private var bodyWeights: [BodyWeight]
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
                    if exercise.tracking == .weightReps, let weight = bodyWeights.first?.kilograms, weight > 0 {
                        LabeledContent("体重あたり", value: "体重の\((best / weight).formatted(.number.precision(.fractionLength(2))))倍")
                    }
                }
                LabeledContent("記録回数", value: "\(points.count)回")
                if exercise.tracking == .distanceTime, let fastest = fastestSpeed {
                    LabeledContent("最高平均速度", value: "\(fastest.short) km/h")
                }
                if !exercise.tracking.higherIsBetter {
                    Text("タイムは小さいほど速い記録です")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                TextField("フォームの注意、使う器具の設定など", text: noteBinding, axis: .vertical)
            } header: {
                Text("メモ")
            } footer: {
                Text("トレーニング中、この種目の名前の下に表示されます。")
            }

            let studies = studyStore.related(to: exercise)
            if !studies.isEmpty {
                Section("この種目に関係する研究") {
                    ForEach(studies) { study in
                        NavigationLink {
                            StudyDetailView(study: study)
                        } label: {
                            StudyRow(study: study)
                        }
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle(exercise.name)
    }

    private var noteBinding: Binding<String> {
        Binding(get: { exercise.note ?? "" }, set: { exercise.note = $0.isEmpty ? nil : $0 })
    }

    private var fastestSpeed: Double? {
        exercise.entries
            .filter { $0.workout?.finishedAt != nil }
            .flatMap(\.sets)
            .filter(\.isDone)
            .compactMap(\.speedKmh)
            .max()
    }
}
