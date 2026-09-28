import SwiftData
import SwiftUI

/// トレーニングの編集画面。進行中（isActive）なら経過時間・休憩タイマー・完了ボタンを出す。
/// 過去の記録の修正（日付・重量の直し）にも同じ画面を使う。
struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(RestTimer.self) private var restTimer
    @AppStorage(RestTimer.defaultSecondsKey) private var defaultRestSeconds = 90.0

    @Bindable var workout: Workout
    let isActive: Bool
    /// 完了時に呼ばれる（更新した自己ベストを渡す）。完了後はこの画面が閉じるため、結果の表示は呼び出し元で行う。
    var onFinish: ([Stats.Record]) -> Void = { _ in }

    @State private var showingPicker = false
    @State private var papersFor: Exercise?
    @State private var confirmingDiscard = false

    var body: some View {
        List {
            Section {
                DatePicker("日時", selection: $workout.startedAt)
                if isActive {
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        LabeledContent("経過時間", value: context.date.timeIntervalSince(workout.startedAt).clock)
                            .monospacedDigit()
                    }
                }
            }

            ForEach(workout.sortedEntries) { entry in
                EntrySection(entry: entry, workoutDate: workout.startedAt) { set in
                    if isActive, set.isDone { restTimer.start(seconds: defaultRestSeconds) }
                } onShowPapers: {
                    papersFor = entry.exercise
                } onDelete: {
                    delete(entry)
                }
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("種目を追加", systemImage: "plus.circle.fill")
                }
                TextField("メモ（体調・気づきなど）", text: $workout.note, axis: .vertical)
            }

            if isActive {
                Section {
                    Button("このトレーニングを破棄", role: .destructive) { confirmingDiscard = true }
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(isActive ? "トレーニング中" : "記録の編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isActive {
                ToolbarItem(placement: .confirmationAction) {
                    Button("完了", action: finish).bold()
                }
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("閉じる") { hideKeyboard() }
            }
        }
        .safeAreaInset(edge: .bottom) {
            if isActive { RestTimerBar() }
        }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { add($0) }
        }
        .sheet(item: $papersFor) { exercise in
            NavigationStack { RelatedPapersView(exercise: exercise) }
        }
        .confirmationDialog("記録を破棄しますか？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("破棄する", role: .destructive) {
                restTimer.stop()
                context.delete(workout)
                try? context.save()
            }
        }
    }

    private func add(_ exercise: Exercise) {
        let entry = WorkoutEntry(order: (workout.entries.map(\.order).max() ?? -1) + 1, exercise: exercise)
        context.insert(entry)
        entry.workout = workout
        // 前回の1セット目を初期値にして入力の手間を減らす
        let previous = Stats.previousEntry(for: exercise, before: workout.startedAt)?.sortedSets.first
        let set = SetRecord(order: 0, weight: previous?.weight ?? 0, reps: previous?.reps ?? 0,
                            seconds: previous?.seconds ?? 0, meters: previous?.meters ?? defaultMeters(for: exercise))
        context.insert(set)
        set.entry = entry
    }

    /// 「30mダッシュ」のような名前から距離を読み取る。
    private func defaultMeters(for exercise: Exercise) -> Double {
        guard exercise.tracking == .distanceTime,
              let match = exercise.name.firstMatch(of: #/(\d+)m/#) else { return 0 }
        return Double(match.1) ?? 0
    }

    private func delete(_ entry: WorkoutEntry) {
        context.delete(entry)
        for (index, remaining) in workout.sortedEntries.filter({ $0 !== entry }).enumerated() {
            remaining.order = index
        }
    }

    private func finish() {
        hideKeyboard()
        // 何も完了していないセットは保存しない
        for entry in workout.entries {
            for set in entry.sets where !set.isDone { context.delete(set) }
        }
        for entry in workout.entries where !entry.sets.contains(where: \.isDone) { context.delete(entry) }
        workout.finishedAt = .now
        restTimer.stop()
        try? context.save()
        onFinish(Stats.newRecords(in: workout))
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// 1種目分のセクション（前回の記録・セット一覧・セット追加）。
private struct EntrySection: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: WorkoutEntry
    let workoutDate: Date
    let onToggle: (SetRecord) -> Void
    let onShowPapers: () -> Void
    let onDelete: () -> Void

    var body: some View {
        let previous = entry.exercise.flatMap { Stats.previousEntry(for: $0, before: workoutDate) }
        Section {
            ForEach(Array(entry.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRowView(set: set, number: index + 1, tracking: entry.tracking,
                           previous: previous?.sortedSets[safe: index], onToggle: onToggle)
            }
            .onDelete { offsets in
                let sets = entry.sortedSets
                for index in offsets { context.delete(sets[index]) }
            }

            Button {
                addSet()
            } label: {
                Label("セットを追加", systemImage: "plus")
                    .font(.subheadline)
            }
        } header: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(entry.exercise?.name ?? "削除された種目")
                        .font(.headline)
                        .foregroundStyle(.primary)
                    if let previous {
                        Text("前回: " + previous.sortedSets.filter(\.isDone).map { $0.summary(for: entry.tracking) }.joined(separator: ", "))
                            .font(.caption)
                            .lineLimit(1)
                    }
                }
                Spacer()
                Menu {
                    Button("関連する論文", systemImage: "doc.text.magnifyingglass", action: onShowPapers)
                    Button("種目を削除", systemImage: "trash", role: .destructive, action: onDelete)
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                }
            }
            .textCase(nil)
        }
    }

    /// 直前のセットと同じ値で1セット追加する。
    private func addSet() {
        let last = entry.sortedSets.last
        let set = SetRecord(order: (last?.order ?? -1) + 1, weight: last?.weight ?? 0, reps: last?.reps ?? 0,
                            seconds: last?.seconds ?? 0, meters: last?.meters ?? 0)
        context.insert(set)
        set.entry = entry
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
