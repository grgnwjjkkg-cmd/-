import SwiftUI

/// 画面下に出る休憩タイマー。終わった直後は「休憩終了」を数秒表示する。
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer
    @Environment(\.appTheme) private var theme

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            if timer.isRunning(at: context.date) {
                let remaining = timer.remaining(at: context.date)
                HStack(spacing: 12) {
                    ZStack {
                        Circle().stroke(.fill.tertiary, lineWidth: 4)
                        Circle()
                            .trim(from: 0, to: remaining / max(timer.total, remaining))
                            .stroke(theme.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        Image(systemName: "timer").font(.caption)
                    }
                    .frame(width: 36, height: 36)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("休憩").font(.caption).foregroundStyle(.secondary)
                        Text(remaining.clock)
                            .font(.title3.bold())
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                    }
                    Spacer()
                    Button("-15秒") { timer.add(-15) }
                    Button("+15秒") { timer.add(15) }
                    Button {
                        timer.stop()
                    } label: {
                        Image(systemName: "forward.end.fill")
                    }
                    .accessibilityLabel("休憩をスキップ")
                }
                .buttonStyle(.bordered)
                .padding()
                .background(.regularMaterial)
            } else if timer.justFinished {
                Label("休憩終了！次のセットへ", systemImage: "checkmark.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
                    .foregroundStyle(theme.onAccent)
                    .background(theme.accent)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(duration: 0.35), value: timer.justFinished)
    }
}
