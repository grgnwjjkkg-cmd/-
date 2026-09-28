import SwiftData
import SwiftUI

/// マイメニューの一覧（お気に入りが上）。ここから開始・編集・新規作成ができる。
struct MyMenusView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query(sort: \MenuTemplate.createdAt, order: .reverse) private var menus: [MenuTemplate]
    @State private var editing: MenuTemplate?

    private var sorted: [MenuTemplate] {
        menus.sorted { a, b in
            if a.isFavorite != b.isFavorite { return a.isFavorite }
            return (a.lastUsedAt ?? a.createdAt) > (b.lastUsedAt ?? b.createdAt)
        }
    }

    var body: some View {
        List {
            if menus.isEmpty {
                ContentUnavailableView {
                    Label("マイメニューはまだありません", systemImage: "star.square.on.square")
                } description: {
                    Text("右上の＋で作るか、トレーニングの画面の「マイメニューに保存」、論文の「このメニューで練習する」から追加できます。何個でも作れます。")
                }
                .listRowBackground(Color.clear)
            }
            ForEach(sorted) { menu in
                NavigationLink {
                    MenuEditorView(menu: menu)
                } label: {
                    MenuRow(menu: menu)
                }
                .themedRow()
                .swipeActions(edge: .leading) {
                    Button {
                        menu.isFavorite.toggle()
                    } label: {
                        Label("お気に入り", systemImage: menu.isFavorite ? "star.slash" : "star")
                    }
                    .tint(.yellow)
                }
                .swipeActions(edge: .trailing) {
                    Button(role: .destructive) {
                        context.delete(menu)
                        try? context.save()
                    } label: {
                        Label("削除", systemImage: "trash")
                    }
                    Button {
                        MenuBuilder.startWorkout(from: menu, in: context)
                        dismiss()
                    } label: {
                        Label("開始", systemImage: "play.fill")
                    }
                    .tint(.green)
                }
            }
        }
        .themedBackground()
        .navigationTitle("マイメニュー")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    let menu = MenuTemplate(name: "新しいメニュー")
                    context.insert(menu)
                    editing = menu
                } label: {
                    Label("新しいメニュー", systemImage: "plus")
                }
            }
        }
        .navigationDestination(item: $editing) { menu in
            MenuEditorView(menu: menu)
        }
    }
}

private struct MenuRow: View {
    let menu: MenuTemplate

    var body: some View {
        HStack(spacing: 12) {
            // 最初の種目のアイコンを重ねて見せる
            ZStack {
                ForEach(Array(menu.sortedItems.prefix(3).enumerated().reversed()), id: \.offset) { index, item in
                    ExerciseIcon(exercise: item.exercise, size: 34)
                        .offset(x: CGFloat(index) * 8, y: CGFloat(index) * -4)
                }
            }
            .frame(width: 54, height: 44, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    if menu.isFavorite { Image(systemName: "star.fill").foregroundStyle(.yellow).font(.caption) }
                    Text(menu.name).font(.headline).lineLimit(1)
                }
                Text(menu.sortedItems.compactMap(\.exercise?.name).joined(separator: "・"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                if menu.sourcePMID != nil {
                    Label("論文のメニュー", systemImage: "doc.text")
                        .font(.caption2)
                        .foregroundStyle(.tint)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// マイメニューの編集。種目の追加（まとめて選べる）・並べ替え・セット数や重さの変更・お気に入り。
struct MenuEditorView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(StudyStore.self) private var studyStore
    @Environment(\.appTheme) private var theme
    @Bindable var menu: MenuTemplate
    @State private var showingPicker = false
    @State private var confirmingDelete = false

    var body: some View {
        List {
            Section {
                TextField("メニュー名", text: $menu.name)
                    .font(.headline)
                Toggle(isOn: $menu.isFavorite) {
                    Label("お気に入り", systemImage: "star.fill")
                }
                .tint(.yellow)
                if let pmid = menu.sourcePMID, let study = studyStore.study(pmid: pmid) {
                    NavigationLink {
                        StudyDetailView(study: study)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("根拠の論文", systemImage: "doc.text").font(.caption).foregroundStyle(.tint)
                            Text(study.headline).font(.subheadline)
                        }
                    }
                }
                if let schedule = scheduleText {
                    Label(schedule, systemImage: "calendar").font(.subheadline)
                }
                if !menu.note.isEmpty {
                    Text(menu.note).font(.footnote).foregroundStyle(.secondary)
                }
            }
            .themedRow()

            Section {
                ForEach(menu.sortedItems) { item in
                    MenuItemRow(item: item)
                }
                .onDelete { offsets in
                    let items = menu.sortedItems
                    for index in offsets { context.delete(items[index]) }
                    renumber(excluding: offsets.map { items[$0] })
                }
                .onMove { source, destination in
                    var items = menu.sortedItems
                    items.move(fromOffsets: source, toOffset: destination)
                    for (index, item) in items.enumerated() { item.order = index }
                }
                Button {
                    showingPicker = true
                } label: {
                    Label("種目を追加（まとめて選べます）", systemImage: "plus.circle.fill")
                }
            } header: {
                Text("種目 \(menu.items.count)")
            } footer: {
                Text("重さが 0 の種目は、開始したときに前回の記録の重さが自動で入ります。")
            }
            .themedRow()

            Section {
                Button {
                    MenuBuilder.startWorkout(from: menu, in: context)
                    dismiss()
                } label: {
                    Label("このメニューで始める", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 6)
                }
                .disabled(menu.items.isEmpty)
                Button("このメニューを削除", role: .destructive) { confirmingDelete = true }
            }
            .themedRow()
        }
        .themedBackground()
        .navigationTitle("メニューの編集")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { EditButton() }
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { exercises in
                var order = (menu.items.map(\.order).max() ?? -1) + 1
                for exercise in exercises {
                    let item = MenuItem(order: order, exercise: exercise, sets: 3)
                    context.insert(item)
                    item.template = menu
                    order += 1
                }
            }
        }
        .confirmationDialog("「\(menu.name)」を削除しますか？", isPresented: $confirmingDelete, titleVisibility: .visible) {
            Button("削除する", role: .destructive) {
                context.delete(menu)
                try? context.save()
                dismiss()
            }
        }
    }

    private var scheduleText: String? {
        let parts = [menu.weeks.map { "研究では\($0)週間" }, menu.perWeek.map { "週\($0)回" }].compactMap { $0 }
        return parts.isEmpty ? nil : parts.joined(separator: " ・ ")
    }

    private func renumber(excluding removed: [MenuItem]) {
        for (index, item) in menu.sortedItems.filter({ item in !removed.contains { $0 === item } }).enumerated() {
            item.order = index
        }
    }
}

/// メニューの1種目：セット数・重さ・回数（または距離・秒）・休憩。
private struct MenuItemRow: View {
    @Bindable var item: MenuItem

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                ExerciseIcon(exercise: item.exercise, size: 34)
                VStack(alignment: .leading, spacing: 2) {
                    Text(item.exercise?.name ?? "削除された種目").font(.subheadline.bold())
                    if let group = item.exercise?.group { MuscleChip(group: group) }
                }
                Spacer()
                Stepper("\(item.sets)セット", value: $item.sets, in: 1...20)
                    .font(.subheadline.monospacedDigit())
                    .fixedSize()
            }
            HStack(spacing: 8) {
                switch item.tracking {
                case .weightReps:
                    field("kg", value: $item.weight)
                    field("回", value: reps)
                case .reps:
                    field("回", value: reps)
                case .time:
                    field("秒", value: $item.seconds)
                case .distanceTime:
                    field("m", value: $item.meters)
                }
                field("休み秒", value: rest)
            }
            if !item.note.isEmpty {
                Text(item.note).font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }

    private var reps: Binding<Double> {
        Binding(get: { Double(item.reps) }, set: { item.reps = max(0, Int($0)) })
    }

    private var rest: Binding<Double> {
        Binding(get: { item.restSeconds ?? 0 }, set: { item.restSeconds = $0 > 0 ? $0 : nil })
    }

    private func field(_ unit: String, value: Binding<Double>) -> some View {
        HStack(spacing: 2) {
            TextField("0", value: Binding<Double?>(get: { value.wrappedValue == 0 ? nil : value.wrappedValue },
                                                   set: { value.wrappedValue = $0 ?? 0 }), format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .padding(.vertical, 5)
                .padding(.horizontal, 7)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 7))
            Text(unit).font(.caption).foregroundStyle(.secondary).fixedSize()
        }
    }
}

/// 論文の「このメニューで練習する」から開く確認画面。
struct StudyMenuSheet: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let menu: StudyMenu
    let study: Study
    @State private var added: MenuTemplate?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(menu.name).font(.title3.bold())
                        if let label = menu.groupLabel, !label.isEmpty {
                            Text("研究の「\(label)」がやった練習です").font(.subheadline).foregroundStyle(.secondary)
                        }
                        if let schedule = menu.scheduleText {
                            Label(schedule, systemImage: "calendar").font(.subheadline)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .themedRow()

                Section("メニュー") {
                    ForEach(Array(menu.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 12) {
                            PictogramBadge(elements: Pictogram.elements(name: item.exercise, group: item.muscleGroup),
                                           color: item.muscleGroup.color, size: 36)
                            VStack(alignment: .leading, spacing: 3) {
                                Text(item.exercise).font(.subheadline.bold())
                                if !item.detail.isEmpty { Text(item.detail).font(.subheadline) }
                                if !item.note.isEmpty {
                                    Text(item.note).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 2)
                    }
                }
                .themedRow()

                Section {
                    CalloutBox(title: "気をつけたい点", items: [menu.caution, "研究でやった内容です。体力に合わせて回数や重さを調整してください"],
                               style: .warning, footer: "痛いときはやめて、医師・専門家に相談してください。")
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                } footer: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("要旨の原文: \(menu.quote)").lineLimit(4)
                        Text("研究の要旨をもとにAIが作り、別のAIが要旨と照らし合わせて点検したメニューです。")
                        #if DEBUG
                        if !menu.isPublished { Text("（開発用: このメニューは確認待ちです）").foregroundStyle(.orange) }
                        #endif
                    }
                }
            }
            .themedBackground()
            .navigationTitle("このメニューで練習する")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("閉じる") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(spacing: 8) {
                    if added == nil {
                        bigButton("マイメニューに追加", systemImage: "star.square.on.square") {
                            added = MenuBuilder.addMenu(menu, in: context)
                        }
                    } else {
                        Label("マイメニューに追加しました", systemImage: "checkmark.circle.fill")
                            .font(.subheadline.bold())
                            .foregroundStyle(.green)
                        bigButton("今すぐこのメニューで始める", systemImage: "play.fill") {
                            if let added { MenuBuilder.startWorkout(from: added, in: context) }
                            dismiss()
                        }
                    }
                }
                .padding()
                .background(.regularMaterial)
            }
        }
    }

    private func bigButton(_ title: String, systemImage: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
                .foregroundStyle(theme.onAccent)
                .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
