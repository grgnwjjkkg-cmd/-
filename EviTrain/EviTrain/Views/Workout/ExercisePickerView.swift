import SwiftData
import SwiftUI

/// 種目の選択画面。部位ごとに並べ、検索と自作種目の追加ができる。
struct ExercisePickerView: View {
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \Exercise.name) private var exercises: [Exercise]
    @State private var searchText = ""
    @State private var showingNew = false

    let onSelect: (Exercise) -> Void

    private var filtered: [Exercise] {
        searchText.isEmpty ? exercises : exercises.filter { $0.name.localizedStandardContains(searchText) }
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(MuscleGroup.allCases) { group in
                    let items = filtered.filter { $0.group == group }
                    if !items.isEmpty {
                        Section(group.rawValue) {
                            ForEach(items) { exercise in
                                Button {
                                    onSelect(exercise)
                                    dismiss()
                                } label: {
                                    HStack {
                                        Text(exercise.name)
                                        Spacer()
                                        if exercise.isCustom {
                                            Text("自作").font(.caption).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .tint(.primary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "種目を検索")
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
            .sheet(isPresented: $showingNew) {
                NewExerciseView(initialName: searchText) { exercise in
                    onSelect(exercise)
                    dismiss()
                }
            }
        }
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
            }
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
