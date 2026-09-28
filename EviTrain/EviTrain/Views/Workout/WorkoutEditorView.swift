import SwiftData
import SwiftUI

/// トレーニングの編集画面。進行中（isActive）なら経過時間・休憩タイマー・終了ボタンを出す。
/// 過去の記録の修正（日付・重量の直し）にも同じ画面を使う。
struct WorkoutEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(RestTimer.self) private var restTimer
    @AppStorage(RestTimer.defaultSecondsKey) private var defaultRestSeconds = 90.0

    @Bindable var workout: Workout
    let isActive: Bool
    /// 終了したときに呼ばれる（振り返りの内容を渡す）。終了後はこの画面が閉じるため、結果の表示は呼び出し元で行う。
    var onFinish: (FinishSummary) -> Void = { _ in }

    @State private var showingPicker = false
    @State private var papersFor: Exercise?
    @State private var confirmingDiscard = false
    @State private var confirmingUnfinished = false
    @State private var savingMenu = false
    @State private var menuName = ""
    @State private var savedMenuName: String?

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
            .themedRow()

            ForEach(workout.sortedEntries) { entry in
                EntrySection(entry: entry, workoutDate: workout.startedAt, isActive: isActive,
                             restSeconds: restSeconds(for: entry)) { set in
                    if isActive, set.isDone { restTimer.start(seconds: restSeconds(for: entry)) }
                } onRestChange: { seconds in
                    // この種目の休憩時間として記憶し、次からも使う
                    entry.restSeconds = seconds
                    entry.exercise?.restSeconds = seconds
                } onStartRest: {
                    restTimer.start(seconds: restSeconds(for: entry))
                } onShowPapers: {
                    papersFor = entry.exercise
                } onDelete: {
                    delete(entry)
                } onMove: { direction in
                    move(entry, by: direction)
                }
            }

            Section {
                Button {
                    showingPicker = true
                } label: {
                    Label("種目を追加（まとめて選べます）", systemImage: "plus.circle.fill")
                }
                TextField("メモ（体調・気づきなど）", text: $workout.note, axis: .vertical)
            }
            .themedRow()

            if isActive {
                Section {
                    HoldToFinishButton {
                        if hasUnfinishedSets { confirmingUnfinished = true } else { finish() }
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                } footer: {
                    Text("押し間違いで終わらないよう、1秒長押しで終了します。")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .scrollDismissesKeyboard(.interactively)
        .themedBackground()
        .navigationTitle(isActive ? (workout.menuName ?? "トレーニング中") : "記録の編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Menu {
                    Button {
                        menuName = workout.menuName ?? workout.startedAt.formatted(.dateTime.month().day()) + "のメニュー"
                        savingMenu = true
                    } label: {
                        Label("マイメニューに保存", systemImage: "star.square.on.square")
                    }
                    .disabled(workout.entries.isEmpty)
                    if isActive {
                        Button(role: .destructive) {
                            confirmingDiscard = true
                        } label: {
                            Label("このトレーニングを破棄", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
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
            ExercisePickerView { exercises in exercises.forEach(add) }
        }
        .sheet(item: $papersFor) { exercise in
            NavigationStack { RelatedStudiesView(exercise: exercise) }
        }
        .alert("マイメニューに保存", isPresented: $savingMenu) {
            TextField("メニュー名", text: $menuName)
            Button("保存") {
                let name = menuName.trimmingCharacters(in: .whitespaces)
                MenuBuilder.saveAsMenu(workout, name: name.isEmpty ? "マイメニュー" : name, in: context)
                savedMenuName = name
            }
            Button("キャンセル", role: .cancel) {}
        } message: {
            Text("種目・セット数・重さと回数・休憩時間を、次から1タップで使えるメニューとして保存します。")
        }
        .alert("保存しました", isPresented: Binding(get: { savedMenuName != nil }, set: { if !$0 { savedMenuName = nil } })) {
            Button("OK") { savedMenuName = nil }
        } message: {
            Text("記録タブの「マイメニュー」から始められます。")
        }
        .confirmationDialog("記録を破棄しますか？", isPresented: $confirmingDiscard, titleVisibility: .visible) {
            Button("破棄する", role: .destructive) {
                restTimer.stop()
                context.delete(workout)
                try? context.save()
            }
        }
        .confirmationDialog("チェックしていないセットがあります", isPresented: $confirmingUnfinished, titleVisibility: .visible) {
            Button("チェックしたセットだけ保存して終了") { finish() }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("✓ を付けていないセットは記録されません。")
        }
    }

    private var hasUnfinishedSets: Bool {
        workout.entries.contains { entry in entry.sets.contains { !$0.isDone } }
    }

    /// 種目の休憩時間：このトレーニングで選んだ時間 → 種目に記憶した時間 → 設定の休憩時間
    private func restSeconds(for entry: WorkoutEntry) -> Double {
        entry.restSeconds ?? entry.exercise?.restSeconds ?? defaultRestSeconds
    }

    private func add(_ exercise: Exercise) {
        let entry = WorkoutEntry(order: (workout.entries.map(\.order).max() ?? -1) + 1, exercise: exercise)
        entry.restSeconds = exercise.restSeconds
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

    /// 種目の順番を1つ上（-1）または下（+1）に動かす。
    private func move(_ entry: WorkoutEntry, by direction: Int) {
        var entries = workout.sortedEntries
        guard let index = entries.firstIndex(where: { $0 === entry }) else { return }
        let target = index + direction
        guard entries.indices.contains(target) else { return }
        entries.swapAt(index, target)
        for (order, item) in entries.enumerated() { item.order = order }
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
        onFinish(Stats.finishSummary(for: workout))
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

/// 1種目分のセクション（休憩時間・前回の記録・セット一覧・セット追加）。
private struct EntrySection: View {
    @Environment(\.modelContext) private var context
    @Bindable var entry: WorkoutEntry
    let workoutDate: Date
    let isActive: Bool
    let restSeconds: Double
    let onToggle: (SetRecord) -> Void
    let onRestChange: (Double) -> Void
    let onStartRest: () -> Void
    let onShowPapers: () -> Void
    let onDelete: () -> Void
    var onMove: ((Int) -> Void)?

    var body: some View {
        let previous = entry.exercise.flatMap { Stats.previousEntry(for: $0, before: workoutDate) }
        Section {
            ForEach(Array(entry.sortedSets.enumerated()), id: \.element.id) { index, set in
                SetRowView(set: set, number: index + 1, tracking: entry.tracking,
                           previous: previous?.sortedSets[safe: index], onToggle: onToggle,
                           onDuplicate: { duplicate(set) }, onApplyToFollowing: { applyToFollowing(set) },
                           onWarmup: { addWarmups(before: set) })
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
            .themedRow()
        } header: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 10) {
                    ExerciseIcon(exercise: entry.exercise, size: 40)
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
                        if let onMove {
                            Button("上へ移動", systemImage: "arrow.up") { onMove(-1) }
                            Button("下へ移動", systemImage: "arrow.down") { onMove(1) }
                        }
                        Button("関係する研究", systemImage: "doc.text.magnifyingglass", action: onShowPapers)
                        Button("種目を削除", systemImage: "trash", role: .destructive, action: onDelete)
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .font(.title3)
                    }
                }
                HStack(spacing: 8) {
                    RestPicker(seconds: restSeconds, onChange: onRestChange)
                    if isActive {
                        Button(action: onStartRest) {
                            Label("休憩スタート", systemImage: "play.fill")
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(.tint.opacity(0.14), in: Capsule())
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.tint)
                    }
                    Spacer()
                }
            }
            .textCase(nil)
            .padding(.bottom, 2)
        }
    }

    /// そのセットのすぐ後ろに同じ値のセットを入れる。
    private func duplicate(_ source: SetRecord) {
        for set in entry.sets where set.order > source.order { set.order += 1 }
        let copy = SetRecord(order: source.order + 1, weight: source.weight, reps: source.reps,
                             seconds: source.seconds, meters: source.meters)
        context.insert(copy)
        copy.entry = entry
    }

    /// 本番の重さの 40%・60%・80% のウォームアップを、そのセットの前に入れる。
    private func addWarmups(before working: SetRecord) {
        let warmups = PlateMath.warmups(for: working.weight)
        guard !warmups.isEmpty else { return }
        for set in entry.sets where set.order >= working.order { set.order += warmups.count }
        for (index, warmup) in warmups.enumerated() {
            let set = SetRecord(order: working.order - warmups.count + index, weight: warmup.weight, reps: warmup.reps)
            context.insert(set)
            set.entry = entry
        }
    }

    /// まだ ✓ していない以降のセットを、同じ重さ・回数などにそろえる。
    private func applyToFollowing(_ source: SetRecord) {
        for set in entry.sets where set.order > source.order && !set.isDone {
            set.weight = source.weight
            set.reps = source.reps
            set.seconds = source.seconds
            set.meters = source.meters
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

/// 休憩時間を選ぶチップ（よく使う時間から1タップで選べる）。
struct RestPicker: View {
    static let presets: [Double] = [30, 45, 60, 75, 90, 120, 150, 180, 240, 300]

    let seconds: Double
    let onChange: (Double) -> Void

    var body: some View {
        Menu {
            ForEach(Self.presets, id: \.self) { value in
                Button {
                    onChange(value)
                } label: {
                    if value == seconds {
                        Label(value.clock, systemImage: "checkmark")
                    } else {
                        Text(value.clock)
                    }
                }
            }
        } label: {
            Label("休憩 \(seconds.clock)", systemImage: "timer")
                .font(.caption.bold().monospacedDigit())
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(.fill.tertiary, in: Capsule())
                .foregroundStyle(.primary)
        }
        .accessibilityLabel("休憩時間 \(Int(seconds))秒。タップして変更")
    }
}

/// 1秒長押しで終了するボタン（押している間ゲージがたまる）。
struct HoldToFinishButton: View {
    @Environment(\.appTheme) private var theme
    let action: () -> Void
    @State private var pressing = false
    @State private var done = false

    var body: some View {
        ZStack(alignment: .leading) {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(theme.card)
            GeometryReader { proxy in
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(theme.accent)
                    .frame(width: pressing || done ? proxy.size.width : 0)
                    .animation(pressing ? .linear(duration: 1) : .easeOut(duration: 0.2), value: pressing)
            }
            HStack {
                Spacer()
                Label(pressing ? "そのまま押し続けて…" : "長押しでトレーニングを終える",
                      systemImage: "flag.checkered")
                    .font(.headline)
                    .foregroundStyle(pressing ? theme.onAccent : theme.accent)
                Spacer()
            }
        }
        .frame(height: 58)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(theme.accent.opacity(0.6), lineWidth: 1.5))
        .contentShape(Rectangle())
        .onLongPressGesture(minimumDuration: 1.0, perform: {
            done = true
            action()
        }, onPressingChanged: { isPressing in
            pressing = isPressing
        })
        .sensoryFeedback(.impact(weight: .medium), trigger: pressing) { _, now in now }
        .sensoryFeedback(.success, trigger: done) { _, now in now }
        .accessibilityAddTraits(.isButton)
        .accessibilityAction { action() }
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
