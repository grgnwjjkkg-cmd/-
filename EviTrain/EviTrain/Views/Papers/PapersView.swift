import SwiftUI

/// 「論文」タブ。要約サイトの記事を一覧・検索・カテゴリ別に読める。
struct PapersView: View {
    @Environment(PaperStore.self) private var store
    @State private var searchText = ""
    @State private var category: String?
    @State private var bookmarksOnly = false

    private var filtered: [Paper] {
        store.papers.filter { paper in
            (category == nil || paper.category == category)
                && (!bookmarksOnly || store.isBookmarked(paper))
                && (searchText.isEmpty
                    || paper.title.localizedStandardContains(searchText)
                    || paper.summary.localizedStandardContains(searchText)
                    || paper.tags.contains { $0.localizedStandardContains(searchText) })
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack {
                            CategoryChip(title: "すべて", isSelected: category == nil && !bookmarksOnly) {
                                category = nil
                                bookmarksOnly = false
                            }
                            CategoryChip(title: "★ 保存", isSelected: bookmarksOnly) { bookmarksOnly.toggle() }
                            ForEach(store.categories, id: \.self) { item in
                                CategoryChip(title: item, isSelected: category == item) {
                                    category = category == item ? nil : item
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    .listRowInsets(EdgeInsets())
                    .listRowBackground(Color.clear)
                }

                if let error = store.lastError {
                    Label(error, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                ForEach(filtered) { paper in
                    NavigationLink {
                        PaperDetailView(paper: paper)
                    } label: {
                        PaperRow(paper: paper)
                    }
                }

                Section {
                    Text("データ: \(store.source.rawValue)（\(store.papers.count)件）")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                } footer: {
                    Text("このタブの内容は研究の要約であり、医学的な助言ではありません。持病やケガがある場合は専門家に相談してください。")
                }
            }
            .overlay {
                if filtered.isEmpty {
                    ContentUnavailableView.search(text: searchText)
                }
            }
            .searchable(text: $searchText, prompt: "キーワード（例: 休憩、スプリント）")
            .refreshable { await store.refresh() }
            .navigationTitle("論文")
        }
    }
}

private struct CategoryChip: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(title, action: action)
            .font(.subheadline)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.fill.tertiary), in: Capsule())
            .foregroundStyle(isSelected ? .white : .primary)
            .buttonStyle(.plain)
    }
}

struct PaperRow: View {
    @Environment(PaperStore.self) private var store
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(paper.category)
                    .font(.caption2.bold())
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(.tint.opacity(0.15), in: Capsule())
                if let studyType = paper.studyType {
                    Text(studyType).font(.caption2).foregroundStyle(.secondary)
                }
                Spacer()
                if store.isBookmarked(paper) {
                    Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(.tint)
                }
            }
            Text(paper.title)
                .font(.subheadline.bold())
                .lineLimit(3)
            Text(paper.citation)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.vertical, 2)
    }
}

/// 種目から開く「関連する論文」一覧。
struct RelatedPapersView: View {
    @Environment(PaperStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    var body: some View {
        let papers = store.related(to: exercise, limit: 20)
        List(papers) { paper in
            NavigationLink {
                PaperDetailView(paper: paper)
            } label: {
                PaperRow(paper: paper)
            }
        }
        .overlay {
            if papers.isEmpty {
                ContentUnavailableView("関連する論文はまだありません", systemImage: "doc.text.magnifyingglass")
            }
        }
        .navigationTitle(exercise.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button("閉じる") { dismiss() }
            }
        }
    }
}
