import SwiftUI

/// 画面下に出る休憩タイマー。
struct RestTimerBar: View {
    @Environment(RestTimer.self) private var timer

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            if timer.isRunning(at: context.date) {
                let remaining = timer.remaining(at: context.date)
                HStack(spacing: 12) {
                    Image(systemName: "timer")
                    VStack(alignment: .leading, spacing: 4) {
                        Text("休憩 \(remaining.clock)")
                            .font(.headline)
                            .monospacedDigit()
                        ProgressView(value: remaining, total: max(timer.total, remaining))
                    }
                    Button("-15秒") { timer.add(-15) }
                    Button("+15秒") { timer.add(15) }
                    Button {
                        timer.stop()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                    }
                }
                .buttonStyle(.bordered)
                .padding()
                .background(.regularMaterial)
            }
        }
    }
}
