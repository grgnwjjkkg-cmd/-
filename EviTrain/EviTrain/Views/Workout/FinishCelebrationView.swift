import SwiftUI

/// トレーニング終了時の振り返り。伸びた種目を1つずつアニメーションで見せ、自己ベストは紙吹雪で祝う。
struct FinishCelebrationView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.appTheme) private var theme
    let summary: FinishSummary

    /// いま何件目まで表示したか（1件ずつ増やしてアニメーションさせる）
    @State private var shown = 0
    @State private var headerVisible = false
    @State private var confetti = false
    @State private var shareImage: Image?

    var body: some View {
        ZStack {
            LinearGradient(colors: [theme.accent.opacity(0.35), theme.background], startPoint: .top, endPoint: .center)
                .ignoresSafeArea()
            theme.background.opacity(0.0001).ignoresSafeArea()

            ScrollView {
                VStack(spacing: 18) {
                    header
                        .opacity(headerVisible ? 1 : 0)
                        .scaleEffect(headerVisible ? 1 : 0.8)

                    statsRow
                        .opacity(headerVisible ? 1 : 0)

                    VStack(spacing: 10) {
                        ForEach(Array(summary.results.enumerated()), id: \.element.id) { index, result in
                            if index < shown {
                                ResultCard(result: result)
                                    .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .opacity))
                            }
                        }
                    }

                    if shown >= summary.results.count {
                        Text("重さ×回数の種目は「推定1RM」（その重さと回数から計算した、1回だけ持ち上げられる重さの目安）で前回と比べています。自重は回数、時間は秒、ダッシュはタイムで比べます。")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .transition(.opacity)
                    }
                }
                .padding()
                .padding(.bottom, 90)
            }

            if confetti { ConfettiView().allowsHitTesting(false).ignoresSafeArea() }
        }
        .safeAreaInset(edge: .bottom) {
            HStack(spacing: 10) {
                if let shareImage {
                    ShareLink(item: shareImage, preview: SharePreview("エビトレの記録", image: shareImage)) {
                        Label("画像でシェア", systemImage: "square.and.arrow.up")
                            .font(.headline)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 14)
                            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .foregroundStyle(.tint)
                }
                Button {
                    dismiss()
                } label: {
                    Text("閉じる")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 14)
                        .foregroundStyle(theme.onAccent)
                        .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(.ultraThinMaterial)
        }
        .sensoryFeedback(.increase, trigger: shown)
        .task { await play() }
    }

    private var header: some View {
        VStack(spacing: 6) {
            Text(summary.recordCount > 0 ? "🏆" : "💪")
                .font(.system(size: 56))
            Text("お疲れさまでした！")
                .font(.title.bold())
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 24)
    }

    private var message: String {
        if summary.recordCount > 0 { return "自己ベスト更新 \(summary.recordCount)種目！" }
        if summary.improvedCount > 0 { return "前回より伸びた種目 \(summary.improvedCount)つ" }
        if summary.results.isEmpty { return "記録を保存しました" }
        return "今日も積み上げました。続けることがいちばんの近道です"
    }

    private var statsRow: some View {
        HStack(spacing: 10) {
            StatTile(title: "時間", value: summary.duration.clock, systemImage: "clock", tint: theme.accent)
            StatTile(title: "セット", value: "\(summary.setCount)", systemImage: "checkmark.circle", tint: theme.accent)
            if summary.volume > 0 {
                StatTile(title: "総挙上量", value: "\(Int(summary.volume))kg", systemImage: "scalemass", tint: theme.accent)
            }
        }
    }

    /// 見出し → 種目を0.45秒ごとに1つずつ表示。自己ベストがあれば紙吹雪。
    @MainActor
    private func play() async {
        withAnimation(.spring(duration: 0.5, bounce: 0.35)) { headerVisible = true }
        try? await Task.sleep(for: .milliseconds(500))
        for _ in summary.results {
            withAnimation(.spring(duration: 0.45, bounce: 0.3)) { shown += 1 }
            try? await Task.sleep(for: .milliseconds(450))
        }
        withAnimation { shown = summary.results.count + 1 }
        if summary.recordCount > 0 { confetti = true }
        if !summary.results.isEmpty { shareImage = ShareImage.render(summary: summary, theme: theme) }
    }
}

/// 種目1つ分の結果。伸びた量をカウントアップで見せる。
private struct ResultCard: View {
    @Environment(\.appTheme) private var theme
    let result: FinishSummary.Result
    @State private var progress: Double = 0

    var body: some View {
        HStack(spacing: 12) {
            ExerciseIcon(exercise: result.exercise, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(result.name).font(.subheadline.bold()).lineLimit(1)
                    if result.isRecord {
                        Text("自己ベスト")
                            .font(.caption2.bold())
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(.yellow.opacity(0.3), in: Capsule())
                    }
                }
                Text("\(result.metricName) \(result.current.short)\(result.unit)")
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Spacer()
            deltaView
        }
        .padding(12)
        .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        .overlay {
            if result.isRecord {
                RoundedRectangle(cornerRadius: 14).strokeBorder(.yellow.opacity(0.8), lineWidth: 2)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.8)) { progress = 1 }
        }
    }

    @ViewBuilder
    private var deltaView: some View {
        if let delta = result.delta {
            let shownDelta = delta * progress
            let sign = shownDelta > 0 ? "+" : ""
            VStack(alignment: .trailing, spacing: 2) {
                HStack(spacing: 3) {
                    Image(systemName: result.improved ? "arrow.up.right" : (abs(delta) < 0.0001 ? "equal" : "arrow.down.right"))
                    Text("\(sign)\(shownDelta.short)\(result.unit)")
                        .contentTransition(.numericText(value: shownDelta))
                }
                .font(.headline.monospacedDigit())
                .foregroundStyle(result.improved ? Color.green : Color.secondary)
                Text("前回比").font(.caption2).foregroundStyle(.secondary)
            }
        } else {
            Text("はじめての記録")
                .font(.caption.bold())
                .foregroundStyle(.tint)
        }
    }
}

/// 自己ベストのときに降らせる紙吹雪（コードで描いた四角と丸）。
private struct ConfettiView: View {
    @State private var start = Date.now
    private let pieces: [(x: Double, speed: Double, spin: Double, size: Double, hue: Double, delay: Double)] =
        (0..<70).map { _ in (Double.random(in: 0...1), Double.random(in: 180...320), Double.random(in: -4...4),
                             Double.random(in: 6...11), Double.random(in: 0...1), Double.random(in: 0...0.8)) }

    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                let elapsed = timeline.date.timeIntervalSince(start)
                for piece in pieces {
                    let t = elapsed - piece.delay
                    guard t > 0 else { continue }
                    let y = -20 + t * piece.speed
                    guard y < size.height + 20 else { continue }
                    let x = piece.x * size.width + sin(t * 3 + piece.hue * 6) * 18
                    var copy = context
                    copy.translateBy(x: x, y: y)
                    copy.rotate(by: .radians(t * piece.spin))
                    let rect = CGRect(x: -piece.size / 2, y: -piece.size / 4, width: piece.size, height: piece.size / 2)
                    copy.fill(Path(roundedRect: rect, cornerRadius: 1.5),
                              with: .color(Color(hue: piece.hue, saturation: 0.75, brightness: 0.95)))
                }
            }
        }
    }
}
