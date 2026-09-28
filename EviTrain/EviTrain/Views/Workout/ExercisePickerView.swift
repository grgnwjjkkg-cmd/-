import SwiftData
import SwiftUI

/// 種目の選択画面。チェックを付けて何種目でもまとめて追加できる（選んだ順に追加）。
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showingNew = false
    /// 選んだ順番を保つため配列で持つ
    @State private var selected: [Exercise] = []

    let onSelect: ([Exercise]) -> Void

    private var filtered: [Exercise] {
        searchText.isEmpty ? exercises : exercises.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MuscleGroup.allCases) { group in
                    let items = filtered.filter { $0.group == group }
                    if !items.isEmpty {
                        Section {
                            ForEach(items) { exercise in
                                row(exercise)
                            }
                        } header: {
                            HStack(spacing: 8) {
                                MuscleMapView(group: group, height: 30)
                                Text(group.rawValue).font(.subheadline.bold()).foregroundStyle(group.color)
                            }
                            .textCase(nil)
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "種目を検索")
            .themedBackground()
            .navigationTitle("種目を選ぶ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button("自作種目", systemImage: "plus") { showingNew = true }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if !selected.isEmpty {
                    Button {
                        onSelect(selected)
                        dismiss()
                    } label: {
                        Text("\(selected.count)種目を追加")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 14)
                            .foregroundStyle(theme.onAccent)
                            .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal)
                    .padding(.bottom, 8)
                }
            }
            .sheet(isPresented: $showingNew) {
                NewExerciseView(initialName: searchText) { exercise in
                    selected.append(exercise)
                }
            }
        }
    }

    private func row(_ exercise: Exercise) -> some View {
        let index = selected.firstIndex { $0 === exercise }
        return Button {
            if let index { selected.remove(at: index) } else { selected.append(exercise) }
        } label: {
            HStack(spacing: 12) {
                ExerciseIcon(exercise: exercise, size: 36)
                Text(exercise.name)
                if exercise.isCustom {
                    Text("自作").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                if let index {
                    // 何番目に選んだかを表示（この順番で追加される）
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(theme.onAccent)
                        .frame(width: 24, height: 24)
                        .background(theme.accent, in: Circle())
                } else {
                    Image(systemName: "circle").foregroundStyle(.tertiary).font(.title3)
                }
            }
            .contentShape(Rectangle())
        }
        .tint(.primary)
        .sensoryFeedback(.selection, trigger: index)
    }
}

/// 自作種目の作成フォーム（個数の上限なし）。
struct NewExerciseView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var exercises: [Exercise]

    @State private var name: String
    @State private var group: MuscleGroup = .chest
    @State private var tracking: TrackingType = .weightReps
    /// 0 は「設定の休憩時間に合わせる」
    @State private var restSeconds: Double = 0
    let onCreate: (Exercise) -> Void

    init(initialName: String = "", onCreate: @escaping (Exercise) -> Void) {
        _name = State(initialValue: initialName)
        self.onCreate = onCreate
    }

    private var trimmedName: String { name.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var isDuplicate: Bool { exercises.contains { $0.name == trimmedName } }

    var body: some View {
        NavigationStack {
            Form {
                TextField("種目名（例: ケーブルクロスオーバー）", text: $name)
                if isDuplicate {
                    Text("同じ名前の種目があります").font(.caption).foregroundStyle(.red)
                }
                Picker("部位", selection: $group) {
                    ForEach(MuscleGroup.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("記録の仕方", selection: $tracking) {
                    ForEach(TrackingType.allCases) { Text($0.rawValue).tag($0) }
                }
                Picker("休憩時間", selection: $restSeconds) {
                    Text("設定に合わせる").tag(0.0)
                    ForEach(RestPicker.presets, id: \.self) { Text($0.clock).tag($0) }
                }
            }
            .themedBackground()
            .navigationTitle("自作種目")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("キャンセル") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("追加") {
                        let exercise = Exercise(name: trimmedName, group: group, tracking: tracking,
                                                tags: defaultTags, isCustom: true)
                        exercise.restSeconds = restSeconds > 0 ? restSeconds : nil
                        context.insert(exercise)
                        try? context.save()
                        dismiss()
                        onCreate(exercise)
                    }
                    .disabled(trimmedName.isEmpty || isDuplicate)
                }
            }
        }
    }

    /// 自作種目にも論文がひも付くよう、記録の仕方からタグを推定する。
    private var defaultTags: [String] {
        switch (group, tracking) {
        case (.sprint, _): ["スプリント"]
        case (.plyometric, _): ["パワー"]
        case (_, .weightReps): ["筋力", "筋肥大"]
        default: []
        }
    }
}
