import SwiftUI

/// トレーニングした日を色の濃さで見せる月のカレンダー（セット数が多い日ほど濃い）。
/// 日をタップすると、その日の記録だけに絞り込む。
struct TrainingCalendarView: View {
    @Environment(\.appTheme) private var theme
    let workouts: [Workout]
    @Binding var selectedDay: Date?
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)?.start ?? .now

    private let calendar = Calendar.current

    /// 日ごとのセット数
    private var setsByDay: [Date: Int] {
        var result: [Date: Int] = [:]
        for workout in workouts {
            result[calendar.startOfDay(for: workout.startedAt), default: 0] += max(workout.completedSetCount, 1)
        }
        return result
    }

    /// 月のマス（前月の空きマスは nil）
    private var cells: [Date?] {
        guard let range = calendar.range(of: .day, in: .month, for: month) else { return [] }
        let firstWeekday = calendar.component(.weekday, from: month)
        let leading = (firstWeekday - calendar.firstWeekday + 7) % 7
        let days = range.compactMap { calendar.date(byAdding: .day, value: $0 - 1, to: month) }
        return Array(repeating: nil, count: leading) + days
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortWeekdaySymbols
        let start = calendar.firstWeekday - 1
        return Array(symbols[start...] + symbols[..<start])
    }

    var body: some View {
        let counts = setsByDay
        let maxSets = max(counts.values.max() ?? 1, 1)
        let monthDays = counts.keys.filter { calendar.isDate($0, equalTo: month, toGranularity: .month) }
        VStack(spacing: 10) {
            HStack {
                Button { shiftMonth(-1) } label: { Image(systemName: "chevron.left") }
                Spacer()
                VStack(spacing: 2) {
                    Text(month, format: .dateTime.year().month(.wide)).font(.headline)
                    Text("\(monthDays.count)日トレーニング").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Button { shiftMonth(1) } label: { Image(systemName: "chevron.right") }
                    .disabled(calendar.isDate(month, equalTo: .now, toGranularity: .month))
            }
            .buttonStyle(.plain)
            .foregroundStyle(.tint)

            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(weekdaySymbols.indices, id: \.self) { index in
                    Text(weekdaySymbols[index]).font(.caption2).foregroundStyle(.secondary)
                }
                ForEach(Array(cells.enumerated()), id: \.offset) { _, day in
                    if let day {
                        dayCell(day, sets: counts[calendar.startOfDay(for: day)] ?? 0, maxSets: maxSets)
                    } else {
                        Color.clear.frame(height: 34)
                    }
                }
            }
        }
        .padding()
        .background(theme.card, in: RoundedRectangle(cornerRadius: 16))
    }

    private func dayCell(_ day: Date, sets: Int, maxSets: Int) -> some View {
        let isToday = calendar.isDateInToday(day)
        let isSelected = selectedDay.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        // 1セットでも薄く色がつき、多い日ほど濃くなる
        let strength: Double = sets == 0 ? 0 : 0.3 + 0.7 * Double(sets) / Double(maxSets)
        let border: Color = isSelected ? .primary : (isToday ? theme.accent : .clear)
        let borderWidth: CGFloat = isSelected ? 2 : 1.5
        let textColor: Color = strength > 0.6 ? theme.onAccent : .primary
        return Button {
            guard sets > 0 else { return }
            selectedDay = isSelected ? nil : day
        } label: {
            Text("\(calendar.component(.day, from: day))")
                .font(.caption.monospacedDigit().weight(sets > 0 ? .bold : .regular))
                .frame(maxWidth: .infinity, minHeight: 34)
                .foregroundStyle(textColor)
                .background(Circle().fill(theme.accent.opacity(strength)))
                .overlay(Circle().strokeBorder(border, lineWidth: borderWidth))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(day.formatted(.dateTime.month().day()))、\(sets > 0 ? "\(sets)セット" : "記録なし")")
    }

    private func shiftMonth(_ value: Int) {
        if let next = calendar.date(byAdding: .month, value: value, to: month) { month = next }
        selectedDay = nil
    }
}
