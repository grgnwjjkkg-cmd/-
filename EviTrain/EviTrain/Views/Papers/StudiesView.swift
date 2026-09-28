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

    var body: some View {
        NavigationStack {
            Group {
                if store.visibleStudies.isEmpty {
                    emptyState
                } else if !searchText.isEmpty || bookmarksOnly {
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
        for study in store.visibleStudies {
            if study.stars < minStars { continue }
            if let field, study.field != field { continue }
            if bookmarksOnly && !store.isBookmarked(study) { continue }
            if !searchText.isEmpty && !study.contains(searchText) { continue }
            result.append(study)
        }
        return result.sorted { $0.stars > $1.stars }
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
                if let lead = summary.lead {
                    VerdictChip(verdict: lead.verdictKind, prefix: false)
                }
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
                    if let lead = summary.lead {
                        VerdictChip(verdict: lead.verdictKind, large: true)
                        Text(lead.oneLine)
                            .font(.title3)
                        Text("いちばん確かな研究（★\(lead.stars)）の答えです")
                            .font(.caption)
                            .foregroundStyle(Palette.subText)
                    }
                    verdictBreakdown
                }
                .padding(.vertical, 6)
            }

            Section("研究でわかったこと") {
                ForEach(summary.studies) { study in
                    NavigationLink {
                        StudyDetailView(study: study)
                    } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(study.oneLine)
                            HStack(spacing: 6) {
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
