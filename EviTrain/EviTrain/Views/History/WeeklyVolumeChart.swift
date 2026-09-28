import Charts
import SwiftUI

/// 過去8週の、部位ごとの週のセット数（部位の色で積み上げ）。鍛え方の偏りが見える。
struct WeeklyVolumeChart: View {
    @Environment(\.appTheme) private var theme
    let workouts: [Workout]

    struct Bar: Identifiable {
        let id = UUID()
        let weekStart: Date
        let group: MuscleGroup
        let sets: Int
    }

    private var bars: [Bar] {
        let calendar = Calendar.current
        guard let thisWeek = calendar.dateInterval(of: .weekOfYear, for: .now)?.start else { return [] }
        var result: [Bar] = []
        for offset in (0..<8).reversed() {
            guard let start = calendar.date(byAdding: .weekOfYear, value: -offset, to: thisWeek),
                  let end = calendar.date(byAdding: .weekOfYear, value: 1, to: start) else { continue }
            var counts: [MuscleGroup: Int] = [:]
            for workout in workouts where workout.startedAt >= start && workout.startedAt < end {
                for entry in workout.entries {
                    guard let group = entry.exercise?.group else { continue }
                    counts[group, default: 0] += entry.sets.filter(\.isDone).count
                }
            }
            for group in MuscleGroup.allCases {
                if let sets = counts[group], sets > 0 { result.append(Bar(weekStart: start, group: group, sets: sets)) }
            }
        }
        return result
    }

    var body: some View {
        let data = bars
        VStack(alignment: .leading, spacing: 10) {
            Text("部位ごとの週のセット数（8週間）").font(.headline)
            if data.isEmpty {
                Text("トレーニングを記録すると表示されます。").font(.footnote).foregroundStyle(.secondary)
            } else {
                Chart(data) { bar in
                    BarMark(x: .value("週", bar.weekStart, unit: .weekOfYear), y: .value("セット", bar.sets))
                        .foregroundStyle(by: .value("部位", bar.group.rawValue))
                }
                .chartForegroundStyleScale(domain: MuscleGroup.allCases.map(\.rawValue),
                                           range: MuscleGroup.allCases.map(\.color))
                .chartXAxis {
                    AxisMarks(values: .stride(by: .weekOfYear)) { _ in
                        AxisValueLabel(format: .dateTime.month(.defaultDigits).day(), centered: true)
                    }
                }
                .frame(height: 200)
            }
        }
        .padding()
        .background(theme.card, in: RoundedRectangle(cornerRadius: 16))
    }
}
