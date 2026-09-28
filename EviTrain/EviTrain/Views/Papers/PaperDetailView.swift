import SwiftUI

struct PaperDetailView: View {
    @Environment(PaperStore.self) private var store
    let paper: Paper

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text(paper.category + (paper.studyType.map { " ・ \($0)" } ?? ""))
                        .font(.caption.bold())
                        .foregroundStyle(.tint)
                    Text(paper.title)
                        .font(.title2.bold())
                    if let originalTitle = paper.originalTitle {
                        Text(originalTitle)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    Text(paper.citation)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                block("要約") {
                    Text(paper.summary)
                }

                if !paper.keyPoints.isEmpty {
                    block("ポイント") {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(paper.keyPoints, id: \.self) { point in
                                Label(point, systemImage: "checkmark.seal")
                            }
                        }
                    }
                }

                if let practical = paper.practical {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("トレーニングへの活かし方", systemImage: "figure.run")
                            .font(.headline)
                        Text(practical)
                    }
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.tint.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                }

                if let action = paper.action {
                    PaperActionButton(action: action)
                }

                VStack(alignment: .leading, spacing: 12) {
                    if let url = paper.articleURL {
                        Link(destination: url) {
                            Label("サイトで詳しく読む", systemImage: "safari")
                        }
                    }
                    if let url = paper.doiURL {
                        Link(destination: url) {
                            Label("原著論文を見る（DOI）", systemImage: "doc.text")
                        }
                    }
                }

                if !paper.tags.isEmpty {
                    Text(paper.tags.map { "#\($0)" }.joined(separator: " "))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.toggleBookmark(paper)
                } label: {
                    Image(systemName: store.isBookmarked(paper) ? "bookmark.fill" : "bookmark")
                }
            }
            if let url = paper.articleURL ?? paper.doiURL {
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: url)
                }
            }
        }
    }

    private func block(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.headline)
            content()
        }
    }
}
