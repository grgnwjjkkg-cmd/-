import SwiftUI

enum AppSettings {
    /// 部位ごとの週の目標セット数（0 のときは表示しない）
    static let weeklySetTargetKey = "weeklySetTarget"
    static let appearanceKey = "appearance"
}

enum Appearance: String, CaseIterable, Identifiable {
    case system = "端末に合わせる"
    case light = "ライト"
    case dark = "ダーク"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

/// ホームに出す「今日の研究」カード。答え・★・ひとことだけで分かるようにする。
struct DailyStudyCard: View {
    @Environment(\.appTheme) private var theme
    let study: Study
    var title = "今日の研究"

    var body: some View {
        NavigationLink {
            StudyDetailView(study: study)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                Label(title, systemImage: "lightbulb.max.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                Text(study.headline)
                    .font(.headline)
                    .multilineTextAlignment(.leading)
                HStack(spacing: 8) {
                    VerdictChip(verdict: study.verdictKind)
                    StarsView(stars: study.stars, font: .caption2)
                }
                Text(study.oneLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
                Text("\(study.citation.firstAuthor)（\(study.citation.year)）・ \(study.design)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(theme.card, in: RoundedRectangle(cornerRadius: 16))
            .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.tint.opacity(0.35)))
        }
        .buttonStyle(.plain)
    }
}

/// 部位ごとの今週のセット数と目標（論文から設定した値）。
struct WeeklySetsCard: View {
    @Environment(\.appTheme) private var theme
    let counts: [Stats.GroupSets]
    let target: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("今週のセット数", systemImage: "chart.bar.fill")
                    .font(.caption.bold())
                    .foregroundStyle(.tint)
                Spacer()
                Text("目標 各\(target)セット")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(counts) { item in
                HStack(spacing: 8) {
                    Text(item.group.rawValue)
                        .font(.subheadline)
                        .frame(width: 40, alignment: .leading)
                    ProgressView(value: Double(min(item.sets, target)), total: Double(max(target, 1)))
                        .tint(item.group.color)
                    Text("\(item.sets)/\(target)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(item.sets >= target ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
