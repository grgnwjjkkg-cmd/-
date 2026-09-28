import SwiftUI

/// SNS でシェアする画像のカード（エビトレ独自のデザイン）。ImageRenderer で画像にする。
struct ShareCardView: View {
    let summary: FinishSummary
    let theme: AppTheme
    let date: Date

    private var highlights: [FinishSummary.Result] {
        let improved = summary.results.filter { $0.isRecord || $0.improved }
        return Array((improved.isEmpty ? summary.results : improved).prefix(4))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack {
                Text("エビトレ").font(.system(size: 26, weight: .heavy))
                Spacer()
                Text(date, format: .dateTime.year().month().day()).font(.system(size: 18, weight: .semibold))
            }
            .foregroundStyle(.white.opacity(0.9))

            Text(summary.recordCount > 0 ? "自己ベスト更新 🏆" : (summary.improvedCount > 0 ? "前回より伸びた 💪" : "今日のトレーニング 💪"))
                .font(.system(size: 38, weight: .heavy))
                .foregroundStyle(.white)

            VStack(spacing: 12) {
                ForEach(highlights) { result in
                    HStack(spacing: 14) {
                        PictogramBadge(elements: result.exercise.map(Pictogram.elements(for:)) ?? [],
                                       color: result.exercise?.group.color ?? .gray, size: 56)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.name).font(.system(size: 22, weight: .bold))
                            Text("\(result.metricName) \(result.current.short)\(result.unit)")
                                .font(.system(size: 16, weight: .medium))
                                .opacity(0.8)
                        }
                        Spacer()
                        if let delta = result.delta, result.improved {
                            Text("\(delta > 0 ? "+" : "")\(delta.short)\(result.unit)")
                                .font(.system(size: 26, weight: .heavy).monospacedDigit())
                        }
                    }
                    .foregroundStyle(.white)
                    .padding(14)
                    .background(.white.opacity(0.12), in: RoundedRectangle(cornerRadius: 18))
                }
            }

            Spacer(minLength: 0)

            HStack(spacing: 24) {
                stat("時間", summary.duration.clock)
                stat("セット", "\(summary.setCount)")
                if summary.volume > 0 { stat("総挙上量", "\(Int(summary.volume))kg") }
            }
            .foregroundStyle(.white)
            Text("研究にもとづく筋トレ・スプリント記録")
                .font(.system(size: 15, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
        }
        .padding(40)
        .frame(width: 720, height: 900)
        .background(
            LinearGradient(colors: [theme.accent.resolvedDark, Color(light: 0x0B1117, dark: 0x0B1117)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        )
        .environment(\.colorScheme, .dark)
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.system(size: 15)).opacity(0.7)
            Text(value).font(.system(size: 28, weight: .bold).monospacedDigit())
        }
    }
}

private extension Color {
    /// 画像は常に暗い背景なので、テーマ色の濃い方（ライト用の色）を使う
    var resolvedDark: Color {
        Color(uiColor: UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light)))
    }
}

@MainActor
enum ShareImage {
    static func render(summary: FinishSummary, theme: AppTheme) -> Image? {
        let renderer = ImageRenderer(content: ShareCardView(summary: summary, theme: theme, date: .now))
        renderer.scale = 1.5
        guard let image = renderer.uiImage else { return nil }
        return Image(uiImage: image)
    }
}
