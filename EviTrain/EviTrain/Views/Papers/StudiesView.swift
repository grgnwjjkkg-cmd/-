import SwiftUI

/// 「論文」タブ。知りたいこと（質問）で選ぶ一覧。
struct StudiesView: View {
    enum StarFilter: Int, CaseIterable, Identifiable {
        case all = 0, three = 3, four = 4
        var id: Int { rawValue }
        var title: String { self == .all ? "★すべて" : "★\(rawValue)以上" }
    }

    @Environment(StudyStore.self) private var store
    @State private var searchText = ""
    @State private var field: String?
    @State private var starFilter: StarFilter = .all
    @State private var bookmarksOnly = false
    @State private var menusOnly = false
    /// 選んだコースの論文だけ（コースを選んでいるときは、最初からオン）
    @State private var courseOnly = true
    @AppStorage(Course.storageKey) private var courseRaw = ""

    private var course: Course? { Course.stored(courseRaw) }
    private var courseActive: Bool { courseOnly && course != nil }

    var body: some View {
        NavigationStack {
            Group {
                if store.visibleStudies.isEmpty {
                    emptyState
                } else if !searchText.isEmpty || bookmarksOnly || menusOnly || courseActive {
                    studyList
                } else {
                    themeList
                }
            }
            .searchable(text: $searchText, prompt: "キーワード（例: ダッシュ、ジャンプ）")
            .themedBackground()
            .navigationTitle("論文")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    NavigationLink {
                        StarGuideView()
                    } label: {
                        Label("★と答えの見かた", systemImage: "info.circle")
                    }
                }
                #if DEBUG
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink {
                        ReviewView()
                    } label: {
                        Label("確認", systemImage: "checkmark.seal")
                    }
                }
                #endif
            }
        }
    }

    private var filters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let course {
                    Button { courseOnly.toggle() } label: {
                        FilterChip(title: "\(course.title)の論文", isSelected: courseOnly)
                    }
                }
                Menu {
                    Picker("★", selection: $starFilter) {
                        ForEach(StarFilter.allCases) { Text($0.title).tag($0) }
                    }
                } label: {
                    FilterChip(title: starFilter.title + " ▾", isSelected: starFilter != .all)
                }
                Button { bookmarksOnly.toggle() } label: {
                    FilterChip(title: "保存した論文", isSelected: bookmarksOnly)
                }
                Button { menusOnly.toggle() } label: {
                    FilterChip(title: "練習メニューあり", isSelected: menusOnly)
                }
                Button { field = nil } label: {
                    FilterChip(title: "すべて", isSelected: field == nil)
                }
                ForEach(store.visibleFields, id: \.self) { item in
                    Button { field = field == item ? nil : item } label: {
                        FilterChip(title: item, isSelected: field == item)
                    }
                }
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
        }
        .listRowInsets(EdgeInsets(top: 6, leading: 0, bottom: 6, trailing: 0))
        .listRowBackground(Color.clear)
    }

    private var themeList: some View {
        let summaries = store.themeSummaries(minStars: starFilter.rawValue, field: field)
        let fields = store.fieldOrder.filter { name in summaries.contains { $0.field == name } }
        return List {
            filters
            ForEach(fields, id: \.self) { name in
                Section(name) {
                    ForEach(summaries.filter { $0.field == name }) { summary in
                        NavigationLink {
                            ThemeView(summary: summary)
                        } label: {
                            ThemeRow(summary: summary)
                        }
                    }
                }
            }
        }
        .overlay {
            if summaries.isEmpty {
                ContentUnavailableView("条件に合う論文がありません", systemImage: "line.3.horizontal.decrease.circle")
            }
        }
    }

    private var studyList: some View {
        let studies = filteredStudies()
        return List {
            filters
            ForEach(studies) { study in
                NavigationLink {
                    StudyDetailView(study: study)
                } label: {
                    StudyRow(study: study)
                }
            }
        }
        .overlay {
            if studies.isEmpty {
                ContentUnavailableView.search(text: searchText)
            }
        }
    }

    private func filteredStudies() -> [Study] {
        let minStars = starFilter.rawValue
        var result: [Study] = []
        // コースの論文は、コースの優先順位のまま。それ以外は★の多い順
        let base: [Study]
        if let course, courseActive {
            base = store.studies(for: course, limit: 10_000)
        } else {
            base = store.visibleStudies
        }
        for study in base {
            if study.stars < minStars { continue }
            if let field, study.field != field { continue }
            if bookmarksOnly && !store.isBookmarked(study) { continue }
            if menusOnly && store.menu(for: study) == nil { continue }
            if !searchText.isEmpty && !study.contains(searchText) { continue }
            result.append(study)
        }
        return courseActive ? result : result.sorted { $0.stars > $1.stars }
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("準備中です", systemImage: "doc.text.magnifyingglass")
        } description: {
            Text("研究の要約は、人が内容を確認してから順番に公開します。")
        } actions: {
            #if DEBUG
            NavigationLink("確認画面を開く（開発用）") { ReviewView() }
            #endif
        }
    }
}

private struct FilterChip: View {
    @Environment(\.appTheme) private var theme
    let title: String
    let isSelected: Bool

    var body: some View {
        Text(title)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .foregroundStyle(isSelected ? theme.onAccent : Color.primary)
            .background(isSelected ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.fill.tertiary), in: Capsule())
    }
}

/// 質問1つ分の行：質問 / 研究の答え / ★ / 本数。
private struct ThemeRow: View {
    let summary: StudyStore.ThemeSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(summary.question)
                .font(.body.bold())
            HStack(spacing: 8) {
                ThemeAnswerChip(answer: summary.answer)
                StarsView(stars: summary.maxStars, font: .caption2)
                Text("論文 \(summary.studies.count)本")
                    .font(.caption)
                    .foregroundStyle(Palette.subText)
            }
        }
        .padding(.vertical, 4)
    }
}

/// テーマの答え：質問 → 答え → わかったこと（1本ずつ）→ 注意。
struct ThemeView: View {
    let summary: StudyStore.ThemeSummary

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 12) {
                    Text(summary.question)
                        .font(.title2.bold())
                    let answer = summary.answer
                    ThemeAnswerChip(answer: answer, large: true)
                    if let lead = answer.lead {
                        Text(lead.oneLine)
                            .font(.title3)
                    } else {
                        Text("「はい」の研究と「そうでもない」研究があります。下の研究を1本ずつ見て、自分に近い条件のものを参考にしてください。")
                            .font(.subheadline)
                    }
                    Text(answer.basis)
                        .font(.caption)
                        .foregroundStyle(Palette.subText)
                    VerdictBar(summary: summary)
                    verdictBreakdown
                }
                .padding(.vertical, 6)
            }

            Section("研究でわかったこと（1本ずつの答え）") {
                ForEach(orderedStudies) { study in
                    NavigationLink {
                        StudyDetailView(study: study)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(study.oneLine)
                            HStack(spacing: 6) {
                                VerdictChip(verdict: study.verdictKind, prefix: false)
                                StarsView(stars: study.stars, font: .caption2)
                                Text("\(study.design)")
                            }
                            .font(.caption)
                            .foregroundStyle(Palette.subText)
                            Text("\(study.citation.firstAuthor)（\(study.citation.year)）\(study.citation.titleEn)")
                                .font(.caption2)
                                .foregroundStyle(Palette.subText)
                                .lineLimit(1)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }

            Section {
                CalloutBox(title: "注意", items: ["痛いときはやめる", "ケガや体の不安があるときは、医師・専門家に相談する"],
                           style: .warning)
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
            } footer: {
                Text("公開中の論文 \(summary.studies.count)本")
            }
        }
        .themedBackground()
        .navigationTitle(summary.theme)
        .navigationBarTitleDisplayMode(.inline)
    }

    /// 答えの代表の研究を先頭に、あとは★の多い順。
    private var orderedStudies: [Study] {
        guard let lead = summary.answer.lead else { return summary.studies }
        return [lead] + summary.studies.filter { $0.pmid != lead.pmid }
    }

    /// 研究ごとの答えの内訳（例: はい 1本・たぶん はい 3本）。
    private var verdictBreakdown: some View {
        let parts = Verdict.allCases.compactMap { verdict -> String? in
            let count = summary.count(of: verdict)
            return count > 0 ? "\(verdict.rawValue) \(count)本" : nil
        }
        return Text("研究ごとの答え：" + parts.joined(separator: "・"))
            .font(.footnote)
            .foregroundStyle(Palette.subText)
    }
}

/// テーマの答えのチップ。研究で分かれるときは紫系で「研究で分かれる」。
struct ThemeAnswerChip: View {
    let answer: ThemeAnswer
    var large = false

    var body: some View {
        if let verdict = answer.verdict {
            VerdictChip(verdict: verdict, prefix: large, large: large)
        } else {
            Text(large ? "研究の答え：研究で分かれる" : "研究で分かれる")
                .font(large ? .headline : .caption.bold())
                .padding(.horizontal, large ? 12 : 8)
                .padding(.vertical, large ? 6 : 3)
                .foregroundStyle(Color(light: 0x6B4FA0, dark: 0xC4B0F0))
                .background(Color(light: 0xEEE8F8, dark: 0x2C2440), in: Capsule())
        }
    }
}

/// 研究ごとの答えの割合を色の帯で見せる（★の重みつき）。
private struct VerdictBar: View {
    let summary: StudyStore.ThemeSummary

    var body: some View {
        let parts = Verdict.allCases.map { verdict in
            (verdict, summary.studies.filter { $0.verdictKind == verdict }.map(\.stars).reduce(0, +))
        }.filter { $0.1 > 0 }
        let total = max(parts.map(\.1).reduce(0, +), 1)
        GeometryReader { proxy in
            HStack(spacing: 2) {
                ForEach(parts, id: \.0) { verdict, weight in
                    Palette.verdict(verdict).text
                        .frame(width: max(4, proxy.size.width * CGFloat(weight) / CGFloat(total) - 2))
                }
            }
        }
        .frame(height: 8)
        .clipShape(Capsule())
        .accessibilityHidden(true)
    }
}
