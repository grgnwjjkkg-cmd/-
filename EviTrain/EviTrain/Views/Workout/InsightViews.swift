import SwiftUI

enum AppSettings {
    /// 部位ごとの週の目標セット数（0 のときは表示しない）
    static let weeklySetTargetKey = "weeklySetTarget"
    static let appearanceKey = "appearance"
}

enum Appearance: String, CaseIterable, Identifiable {
    case dark = "ダーク"
    case light = "ライト"
    case system = "端末に合わせる"

    var id: String { rawValue }

    var colorScheme: ColorScheme? {
        switch self {
        case .dark: .dark
        case .light: .light
        case .system: nil
        }
    }
}

/// ホームに出す「今日の研究」カード。読むだけでなく、その場で設定に反映できる。
struct DailyPaperCard: View {
    let paper: Paper

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("今日の研究", systemImage: "lightbulb.max.fill")
                .font(.caption.bold())
                .foregroundStyle(.tint)
            NavigationLink {
                PaperDetailView(paper: paper)
            } label: {
                VStack(alignment: .leading, spacing: 6) {
                    Text(paper.title)
                        .font(.headline)
                        .multilineTextAlignment(.leading)
                    if let practical = paper.practical {
                        Text(practical)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                            .multilineTextAlignment(.leading)
                    }
                    Text(paper.citation)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            if let action = paper.action {
                PaperActionButton(action: action)
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(.tint.opacity(0.35)))
    }
}

/// 論文の内容を設定に反映するボタン。反映済みならチェックを表示する。
struct PaperActionButton: View {
    @AppStorage(RestTimer.defaultSecondsKey) private var restSeconds = 90.0
    @AppStorage(AppSettings.weeklySetTargetKey) private var weeklySetTarget = 0
    let action: PaperAction

    private var isApplied: Bool {
        switch action.knownKind {
        case .restTimer: restSeconds == action.value
        case .weeklySets: weeklySetTarget == Int(action.value)
        case nil: false
        }
    }

    var body: some View {
        if action.knownKind != nil {
            Button {
                switch action.knownKind {
                case .restTimer: restSeconds = action.value
                case .weeklySets: weeklySetTarget = Int(action.value)
                case nil: break
                }
            } label: {
                Label(isApplied ? "設定済み" : action.label,
                      systemImage: isApplied ? "checkmark.circle.fill" : "bolt.fill")
                    .font(.subheadline.bold())
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isApplied)
            .sensoryFeedback(.success, trigger: isApplied)
        }
    }
}

/// 部位ごとの今週のセット数と目標（論文から設定した値）。
struct WeeklySetsCard: View {
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
                    Text("\(item.sets)/\(target)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(item.sets >= target ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
                        .frame(width: 44, alignment: .trailing)
                }
            }
        }
        .padding()
        .background(.background.secondary, in: RoundedRectangle(cornerRadius: 16))
    }
}
