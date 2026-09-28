import SwiftUI

/// 論文1本の画面。上から「答え → グラフ → どう使う → 注意」だけで1画面で分かるようにし、
/// 研究の中身・結果の全文・★の理由は「くわしく」にまとめる。
struct StudyDetailView: View {
    @Environment(StudyStore.self) private var store
    let study: Study
    @State private var showDetails = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header

                if let chart = store.chart(for: study) {
                    StudyChartView(chart: chart)
                        .padding()
                        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 14))
                }

                CalloutBox(title: "練習にどう使う？", items: study.howToUse, style: .info)

                CalloutBox(title: "気をつけたい点", items: study.limitations, style: .warning,
                           footer: "痛いときはやめて、医師・専門家に相談してください。")

                DisclosureGroup(isExpanded: $showDetails) {
                    details
                        .padding(.top, 8)
                } label: {
                    Text("くわしく（研究の中身・結果・★の理由）")
                        .font(.headline)
                }
                .tint(Palette.main)

                source
            }
            .padding()
        }
        .navigationTitle(study.theme)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    store.toggleBookmark(study)
                } label: {
                    Image(systemName: store.isBookmarked(study) ? "bookmark.fill" : "bookmark")
                }
                .accessibilityLabel(store.isBookmarked(study) ? "保存を外す" : "保存する")
            }
            if let url = study.pubmedURL {
                ToolbarItem(placement: .secondaryAction) {
                    ShareLink(item: url)
                }
            }
        }
        #if DEBUG
        .safeAreaInset(edge: .bottom) { ReviewBar(study: study) }
        #endif
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(study.design) ・ \(study.citation.year)年")
                .font(.footnote)
                .foregroundStyle(Palette.subText)
            Text(study.headline)
                .font(.title2.bold())
            HStack(spacing: 10) {
                VerdictChip(verdict: study.verdictKind, large: true)
                StarsView(stars: study.stars)
            }
            Text(study.oneLine)
                .font(.title3)
            Label(study.forWhom, systemImage: "person.2")
                .font(.subheadline)
                .foregroundStyle(Palette.subText)
        }
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 6) {
                Text("どんな研究？").font(.headline)
                LabeledText(label: "だれを", text: study.who)
                LabeledText(label: "なにを", text: study.what)
                if let period = study.period, !period.isEmpty {
                    LabeledText(label: "期間", text: period)
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("結果").font(.headline)
                ForEach(study.results, id: \.self) { result in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("・")
                        Text(result)
                    }
                }
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("★の理由").font(.headline)
                StarsView(stars: study.stars)
                Text(study.starsReason)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var source: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("出典").font(.headline)
            Text("\(study.citation.firstAuthor) ほか（\(study.citation.year)）\n\(study.citation.journal)\n\(study.citation.titleEn)")
                .font(.footnote)
                .foregroundStyle(Palette.subText)
            if let url = study.pubmedURL {
                Link("PubMed で見る", destination: url)
                    .font(.subheadline)
            }
            NavigationLink("★と答えの見かた") { StarGuideView() }
                .font(.subheadline)
            Divider().padding(.vertical, 4)
            Text("要旨をもとにAIが下書きし、人が確認しました")
                .font(.caption)
                .foregroundStyle(Palette.subText)
        }
    }
}

private struct LabeledText: View {
    let label: String
    let text: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(label)
                .font(.subheadline)
                .foregroundStyle(Palette.subText)
                .frame(width: 52, alignment: .leading)
            Text(text)
        }
    }
}

/// 種目から開く「関係する研究」。
struct RelatedStudiesView: View {
    @Environment(StudyStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let exercise: Exercise

    var body: some View {
        let studies = store.related(to: exercise, limit: 20)
        List(studies) { study in
            NavigationLink {
                StudyDetailView(study: study)
            } label: {
                StudyRow(study: study)
            }
        }
        .overlay {
            if studies.isEmpty {
                ContentUnavailableView("関係する研究はまだありません", systemImage: "doc.text.magnifyingglass",
                                       description: Text("公開OKになった研究から順に表示されます"))
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
