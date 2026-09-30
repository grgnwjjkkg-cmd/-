import SwiftData
import SwiftUI

/// コースを選ぶ画面（初回と、あとから変更するとき）。
struct CoursePickerView: View {
    @AppStorage(Course.storageKey) private var courseRaw = ""
    @Environment(\.dismiss) private var dismiss
    /// 初回は「あとで決める」を出す
    var showsSkip = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("目的を選ぼう")
                    .font(.largeTitle.bold())
                Text("選んだコースで、記録画面・おすすめメニュー・研究の根拠が変わります。あとから変えられます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(Course.allCases) { course in
                    Button {
                        courseRaw = course.rawValue
                        dismiss()
                    } label: {
                        CourseCard(course: course, isSelected: courseRaw == course.rawValue)
                    }
                    .buttonStyle(.plain)
                }

                if showsSkip {
                    Button("あとで決める") {
                        courseRaw = "none"
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }
            }
            .padding()
        }
        .themedBackground()
    }
}

private struct CourseCard: View {
    let course: Course
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: course.symbol)
                .font(.system(size: 34, weight: .bold))
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title).font(.title3.bold())
                Text(course.tagline)
                    .font(.footnote)
                    .opacity(0.9)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark.circle.fill").font(.title2)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: course.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

/// 記録タブの先頭に出す、コースのカード。
struct CourseHeaderCard: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme) private var theme
    let course: Course
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: course.symbol)
                    .font(.system(size: 28, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("いまのコース").font(.caption).opacity(0.85)
                    Text(course.title).font(.title3.bold())
                }
                Spacer()
                Button("変える") { showingPicker = true }
                    .buttonStyle(.plain)
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.22), in: Capsule())
            }

            HStack(spacing: 10) {
                Button {
                    _ = CourseStarter.startWorkout(course: course, in: context)
                } label: {
                    Label("このコースで始める", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(course.colors[0])
                }
                if course.usesStopwatch {
                    NavigationLink {
                        SprintTimerView(course: course)
                    } label: {
                        Label("タイム計測", systemImage: "stopwatch.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            LinearGradient(colors: course.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .sheet(isPresented: $showingPicker) {
            CoursePickerView()
                .presentationDetents([.large])
        }
    }
}

/// コースのおすすめ種目でトレーニングを作る。
enum CourseStarter {
    @MainActor
    static func startWorkout(course: Course, in context: ModelContext) -> Workout {
        let workout = Workout()
        workout.menuName = "\(course.title)コース"
        context.insert(workout)
        let names = course.starterExercises
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { names.contains($0.name) })
        let found = (try? context.fetch(descriptor)) ?? []
        var order = 0
        for name in names {
            guard let exercise = found.first(where: { $0.name == name }) else { continue }
            let entry = WorkoutEntry(order: order, exercise: exercise)
            entry.restSeconds = exercise.restSeconds
            context.insert(entry)
            entry.workout = workout
            order += 1
            let previous = Stats.previousEntry(for: exercise, before: workout.startedAt)?.sortedSets
            let meters = exercise.tracking == .distanceTime ? distance(of: name, fallback: course.defaultDistance) : 0
            for setIndex in 0..<3 {
                let last = previous?[safe: setIndex] ?? previous?.last
                let set = SetRecord(order: setIndex,
                                    weight: last?.weight ?? 0,
                                    reps: last?.reps ?? 0,
                                    seconds: 0,
                                    meters: meters)
                context.insert(set)
                set.entry = entry
            }
        }
        try? context.save()
        return workout
    }

    /// 「30mダッシュ」のように名前が数字で始まるときはその距離、なければ fallback。
    private static func distance(of name: String, fallback: Double) -> Double {
        Double(name.prefix(while: \.isNumber)) ?? fallback
    }
}

// MARK: - コースのメニュー

/// コースのメニュー一覧：基本メニュー（目安）と、論文にもとづくメニュー。
struct CourseMenusView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme) private var theme
    @Environment(StudyStore.self) private var store
    @Query private var templates: [MenuTemplate]
    let course: Course

    /// このコースに関係する論文のメニュー（★の多い順）
    private struct PaperMenu: Identifiable {
        let study: Study
        let menu: StudyMenu
        var id: String { study.pmid }
    }

    private var paperMenus: [PaperMenu] {
        store.studies(for: course, limit: 1000)
            .compactMap { study in store.menu(for: study).map { PaperMenu(study: study, menu: $0) } }
            .sorted { $0.study.stars > $1.study.stars }
    }

    var body: some View {
        List {
            Section {
                ForEach(course.presets) { preset in
                    PresetRow(preset: preset) { start(preset) }
                        .listRowBackground(theme.card)
                }
            } header: {
                Text("基本メニュー")
            } footer: {
                Text("よくある組み立ての目安です。重さや回数は、やりながら自分に合わせて変えてください。")
            }

            if !paperMenus.isEmpty {
                Section {
                    ForEach(paperMenus) { item in
                        PaperMenuRow(study: item.study, menu: item.menu) { start(item.menu) }
                            .listRowBackground(theme.card)
                    }
                } header: {
                    Text("論文にもとづくメニュー（\(paperMenus.count)本）")
                } footer: {
                    Text("研究でやった練習をそのまま再現します。対象の人（年齢・競技レベル）は、各研究の説明で確認してください。")
                }
            }
        }
        .themedBackground()
        .navigationTitle("\(course.title)のメニュー")
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 基本メニューで始める（同じ名前のマイメニューがあればそれを使う）
    private func start(_ preset: CoursePreset) {
        let name = "\(course.title)：\(preset.name)"
        let template: MenuTemplate
        if let found = templates.first(where: { $0.name == name && $0.sourcePMID == nil }) {
            template = found
        } else {
            template = MenuTemplate(name: name, note: preset.summary)
            context.insert(template)
            for (index, source) in preset.items.enumerated() {
                let exerciseName = source.exercise
                var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == exerciseName })
                descriptor.fetchLimit = 1
                guard let exercise = try? context.fetch(descriptor).first else { continue }
                let item = MenuItem(order: index, exercise: exercise, sets: source.sets, reps: source.reps,
                                    seconds: source.seconds, meters: source.meters, restSeconds: source.rest)
                context.insert(item)
                item.template = template
            }
            try? context.save()
        }
        _ = MenuBuilder.startWorkout(from: template, in: context)
    }

    /// 論文のメニューで始める（先にマイメニューに追加する）
    private func start(_ menu: StudyMenu) {
        let template = templates.first(where: { $0.sourcePMID == menu.pmid && $0.name == menu.name })
            ?? MenuBuilder.addMenu(menu, in: context)
        _ = MenuBuilder.startWorkout(from: template, in: context)
    }
}

private struct PresetRow: View {
    let preset: CoursePreset
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(preset.name).font(.headline)
            Text(preset.summary).font(.footnote).foregroundStyle(.secondary)
            Text(preset.exerciseNames).font(.caption).foregroundStyle(.tertiary).lineLimit(2)
            Button(action: onStart) {
                Label("このメニューで始める", systemImage: "play.fill")
                    .font(.subheadline.bold())
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

private struct PaperMenuRow: View {
    let study: Study
    let menu: StudyMenu
    let onStart: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                StarsView(stars: study.stars, font: .caption2)
                if let schedule = menu.scheduleText {
                    Text(schedule).font(.caption2.bold()).foregroundStyle(.tint)
                }
            }
            Text(menu.name).font(.headline)
            Text(menu.items.map(\.exercise).joined(separator: "・")).font(.caption).foregroundStyle(.secondary).lineLimit(2)
            Text("\(study.citation.firstAuthor)（\(study.citation.year)）・ \(study.design)")
                .font(.caption2).foregroundStyle(.tertiary).lineLimit(1)
            HStack {
                Button(action: onStart) {
                    Label("この研究のメニューで始める", systemImage: "play.fill")
                        .font(.subheadline.bold())
                }
                .buttonStyle(.borderedProminent)
                NavigationLink {
                    StudyDetailView(study: study)
                } label: {
                    Text("研究を読む").font(.subheadline)
                }
                .buttonStyle(.bordered)
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 4)
    }
}

// MARK: - コースの論文

/// このコースに関係する論文を、テーマごとに並べる。
struct CourseStudiesView: View {
    @Environment(StudyStore.self) private var store
    let course: Course
    @State private var query = ""

    private struct ThemeGroup: Identifiable {
        let id: String
        let items: [Study]
    }

    private var groups: [ThemeGroup] {
        let studies = store.studies(for: course, limit: 1000).filter {
            query.isEmpty || $0.headline.contains(query) || $0.theme.contains(query) || $0.oneLine.contains(query)
        }
        return Dictionary(grouping: studies, by: \.theme)
            .map { ThemeGroup(id: $0.key, items: $0.value.sorted { $0.stars > $1.stars }) }
            .sorted { $0.items.count > $1.items.count }
    }

    var body: some View {
        List {
            ForEach(groups) { group in
                Section("\(group.id)（\(group.items.count)本）") {
                    ForEach(group.items) { study in
                        NavigationLink {
                            StudyDetailView(study: study)
                        } label: {
                            StudyRow(study: study)
                        }
                        .themedRow()
                    }
                }
            }
        }
        .themedBackground()
        .navigationTitle("\(course.title)の研究")
        .navigationBarTitleDisplayMode(.inline)
        .searchable(text: $query, prompt: "研究をさがす")
    }
}

/// 記録タブに出す、メニューと研究への入り口。
struct CourseLinks: View {
    @Environment(\.appTheme) private var theme
    @Environment(StudyStore.self) private var store
    let course: Course

    var body: some View {
        VStack(spacing: 10) {
            link(title: "\(course.title)のメニュー", detail: "基本メニューと、論文にもとづくメニュー", symbol: "list.bullet.rectangle") {
                CourseMenusView(course: course)
            }
            link(title: "\(course.title)の研究", detail: "\(store.studies(for: course, limit: 1000).count)本の研究を読む", symbol: "doc.text.magnifyingglass") {
                CourseStudiesView(course: course)
            }
        }
    }

    private func link<Destination: View>(title: String, detail: String, symbol: String,
                                         @ViewBuilder destination: () -> Destination) -> some View {
        NavigationLink {
            destination()
        } label: {
            HStack(spacing: 12) {
                Image(systemName: symbol).font(.title3).frame(width: 30).foregroundStyle(.tint)
                VStack(alignment: .leading, spacing: 2) {
                    Text(title).font(.headline).foregroundStyle(.primary)
                    Text(detail).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "chevron.right").font(.caption.bold()).foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
