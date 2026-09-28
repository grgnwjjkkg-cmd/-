import Charts
import CoreTransferable
import SwiftUI
import UniformTypeIdentifiers

/// 仕様書（画面とグラフの仕様.md）の色。ライト／ダークで切り替わる。
enum Palette {
    static let main = Color(light: 0x1F4F93, dark: 0x79A6E6)
    static let mainBackground = Color(light: 0xE6EEF8, dark: 0x1C3149)
    static let subText = Color(light: 0x5A6B7A, dark: 0xA3B1BE)
    static let line = Color(light: 0xDCE4EB, dark: 0x2B3B48)
    static let star = Color(light: 0xC07F10, dark: 0xE8B75C)
    static let starEmpty = Color(light: 0xD9DEE3, dark: 0x3A4855)
    static let chartGray = Color(light: 0xB7C2CC, dark: 0x4A5A68)
    static let warningText = Color(light: 0x5E4600, dark: 0xEDD591)
    static let warningBackground = Color(light: 0xFFF6DC, dark: 0x2F2812)

    static func verdict(_ verdict: Verdict) -> (text: Color, background: Color) {
        switch verdict {
        case .yes: (Color(light: 0x1E7A4C, dark: 0x72CF9C), Color(light: 0xE2F3E9, dark: 0x173427))
        case .probably: (Color(light: 0x8F5B00, dark: 0xEBBB5E), Color(light: 0xFCEFD4, dark: 0x3A2E14))
        case .unknown: (Color(light: 0x56636F, dark: 0xB3BFCA), Color(light: 0xECEFF2, dark: 0x26323C))
        case .no: (Color(light: 0x9B2C2C, dark: 0xF09A9A), Color(light: 0xF8E4E4, dark: 0x3B1E1E))
        }
    }
}

extension Color {
    init(light: UInt32, dark: UInt32) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt32) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// 「研究の答え：たぶん はい」のチップ。
struct VerdictChip: View {
    let verdict: Verdict
    var prefix = true
    var large = false

    var body: some View {
        let colors = Palette.verdict(verdict)
        Text(prefix ? "研究の答え：\(verdict.rawValue)" : verdict.rawValue)
            .font(large ? .headline : .caption.bold())
            .padding(.horizontal, large ? 12 : 8)
            .padding(.vertical, large ? 6 : 3)
            .foregroundStyle(colors.text)
            .background(colors.background, in: Capsule())
    }
}

/// ★の表示（読み上げでは「★3つ」）。
struct StarsView: View {
    let stars: Int
    var font: Font = .subheadline

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<5, id: \.self) { index in
                Image(systemName: "star.fill")
                    .foregroundStyle(index < stars ? Palette.star : Palette.starEmpty)
            }
        }
        .font(font)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("研究の確かさ ★\(stars)つ")
    }
}

/// 仕様どおりの横向き棒グラフ。棒の上にラベル、棒の右に数字。目盛りは 0 から。
struct StudyChartView: View {
    let chart: StudyChart

    private var domain: ClosedRange<Double> {
        let values = chart.bars.map(\.value)
        let low = min(0, values.min() ?? 0), high = max(0, values.max() ?? 0)
        let pad = max(high - low, 1) * 0.3 // 右側に数字を置く余白
        return low...(high + pad)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text(chart.chartTitle).font(.headline)
                if chart.lowerIsBetter {
                    Text("小さいほど良い").font(.caption).foregroundStyle(Palette.subText)
                }
            }
            Chart(chart.bars) { bar in
                BarMark(x: .value(chart.unit, bar.value), y: .value("グループ", bar.label), height: .fixed(26))
                    .foregroundStyle(bar.isMain ? Palette.main : Palette.chartGray)
                    .annotation(position: .top, alignment: .leading, spacing: 4) {
                        Text(bar.label).font(.caption).foregroundStyle(.primary)
                    }
                    .annotation(position: .trailing, alignment: .leading, spacing: 6) {
                        Text(formatted(bar.value)).font(.subheadline.bold().monospacedDigit())
                    }
            }
            .chartXScale(domain: domain)
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks(values: [0.0]) { _ in
                    AxisGridLine()
                    AxisValueLabel()
                }
            }
            .frame(height: CGFloat(chart.bars.count) * 58 + 12)

            Text(chart.note + "\n出典の論文の要旨より作図")
                .font(.caption)
                .foregroundStyle(Palette.subText)
        }
        .accessibilityElement(children: .combine)
    }

    private func formatted(_ value: Double) -> String {
        let number = value.formatted(.number.precision(.fractionLength(0...2)))
        return (chart.unit == "%" && value > 0 ? "+" : "") + number + chart.unit
    }
}

/// 色つきの枠（練習にどう使う？＝青、気をつけたい点＝黄色）。
struct CalloutBox: View {
    enum Style { case info, warning }

    let title: String
    let items: [String]
    let style: Style
    var footer: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: style == .info ? "figure.run" : "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(style == .info ? Palette.main : Palette.warningText)
            ForEach(items, id: \.self) { item in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("・")
                    Text(item)
                }
                .foregroundStyle(style == .info ? Color.primary : Palette.warningText)
            }
            if let footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(style == .info ? Palette.subText : Palette.warningText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
        .background(style == .info ? Palette.mainBackground : Palette.warningBackground,
                    in: RoundedRectangle(cornerRadius: 14))
    }
}

/// 論文の一覧の1行。
struct StudyRow: View {
    @Environment(StudyStore.self) private var store
    let study: Study

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                VerdictChip(verdict: study.verdictKind, prefix: false)
                StarsView(stars: study.stars, font: .caption2)
                Spacer()
                if store.isBookmarked(study) {
                    Image(systemName: "bookmark.fill").font(.caption).foregroundStyle(Palette.main)
                }
                if store.showPending && !store.isPublished(study) {
                    Text("確認待ち").font(.caption2.bold()).foregroundStyle(.orange)
                }
            }
            Text(study.headline)
                .font(.body.bold())
            Text("\(study.design) ・ \(study.citation.firstAuthor)（\(study.citation.year)）")
                .font(.caption)
                .foregroundStyle(Palette.subText)
                .lineLimit(1)
        }
        .padding(.vertical, 4)
    }
}

/// ★の意味（仕様で「アプリ内のどこかに必ず載せる」）。
struct StarGuideView: View {
    private let rows: [(Int, String)] = [
        (5, "たくさんの研究をまとめて、同じ結果"),
        (4, "人数の多いくじ引き実験 / まとめ研究だが結果にばらつき"),
        (3, "比べる実験はあるが、まだ数が少ない"),
        (2, "比べる群がない・観察しただけ"),
        (1, "専門家の意見だけ"),
    ]

    var body: some View {
        List {
            Section {
                ForEach(rows, id: \.0) { stars, text in
                    VStack(alignment: .leading, spacing: 4) {
                        StarsView(stars: stars)
                        Text(text)
                    }
                    .padding(.vertical, 2)
                }
            } footer: {
                Text("★は「研究の確かさ」です。効果の大きさではありません。")
            }
            Section("研究の答え") {
                ForEach(Verdict.allCases, id: \.self) { verdict in
                    VerdictChip(verdict: verdict, prefix: false)
                }
            }
            Section {
                Text("要約は論文の要旨（アブストラクト）をもとにAIが下書きし、別のAIが要旨と照合して点検したうえで、人が確認して「公開OK」にしたものだけを表示しています。医療・治療についての助言ではありません。")
                    .font(.footnote)
                    .foregroundStyle(Palette.subText)
            }
        }
        .navigationTitle("★と答えの見かた")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// approvals.json として共有・保存するためのファイル。
struct ApprovalsFile: Transferable {
    let data: Data

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .json) { $0.data }
            .suggestedFileName("approvals.json")
    }
}
