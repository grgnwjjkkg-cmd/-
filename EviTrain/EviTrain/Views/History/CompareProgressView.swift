import Charts
import SwiftUI

/// 2つの種目の伸びを、それぞれ「最初の記録からの伸び（%）」にそろえて重ねるグラフ。
/// 例: スクワットの推定1RM と 30mダッシュのタイム（タイムは縮むほどプラス）。
struct CompareProgressView: View {
    @Environment(\.appTheme) private var theme
    let exercises: [Exercise]
    @State private var firstName: String = ""
    @State private var secondName: String = ""

    struct Point: Identifiable {
        let id = UUID()
        let series: String
        let date: Date
        let percent: Double
    }

    private func exercise(named name: String) -> Exercise? { exercises.first { $0.name == name } }

    /// 最初の記録を 0% として、良くなった分をプラスで表す。
    private func points(for exercise: Exercise) -> [Point] {
        let history = Stats.history(for: exercise)
        guard let base = history.first?.value, base > 0 else { return [] }
        return history.map { point in
            let change = exercise.tracking.higherIsBetter ? (point.value - base) / base : (base - point.value) / base
            return Point(series: exercise.name, date: point.date, percent: change * 100)
        }
    }

    var body: some View {
        let first = exercise(named: firstName)
        let second = exercise(named: secondName)
        let data = (first.map(points(for:)) ?? []) + (second.map(points(for:)) ?? [])
        VStack(alignment: .leading, spacing: 12) {
            Text("2つの種目の伸びをくらべる").font(.headline)
            HStack {
                picker(selection: $firstName)
                Text("と").foregroundStyle(.secondary)
                picker(selection: $secondName)
            }
            if data.isEmpty {
                Text("種目を2つ選ぶと、最初の記録からの伸びを重ねて表示します。")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            } else {
                Chart(data) { point in
                    LineMark(x: .value("日付", point.date), y: .value("伸び(%)", point.percent))
                        .foregroundStyle(by: .value("種目", point.series))
                        .symbol(by: .value("種目", point.series))
                }
                .chartForegroundStyleScale(domain: seriesNames(first, second), range: seriesColors(first, second))
                .chartYAxisLabel("最初の記録からの伸び（%）")
                .frame(height: 220)
                Text("重さの種目は推定1RM、ダッシュはタイム（縮むほどプラス）で計算しています。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(theme.card, in: RoundedRectangle(cornerRadius: 16))
        .onAppear(perform: chooseDefaults)
    }

    /// 同じ種目を2回選んだときも、色の対応が重ならないようにする。
    private func seriesNames(_ first: Exercise?, _ second: Exercise?) -> [String] {
        var names: [String] = []
        for exercise in [first, second].compactMap({ $0 }) where !names.contains(exercise.name) { names.append(exercise.name) }
        return names
    }

    private func seriesColors(_ first: Exercise?, _ second: Exercise?) -> [Color] {
        let names = seriesNames(first, second)
        var colors: [Color] = []
        for (index, name) in names.enumerated() {
            let exercise = [first, second].compactMap({ $0 }).first { $0.name == name }
            // 同じ部位の色がかぶったら2本目はテーマ色にする
            let color = exercise?.group.color ?? theme.accent
            colors.append(index == 1 && first?.group == second?.group ? theme.accent : color)
        }
        return colors
    }

    private func picker(selection: Binding<String>) -> some View {
        Picker("種目", selection: selection) {
            Text("選ぶ").tag("")
            ForEach(exercises) { Text($0.name).tag($0.name) }
        }
        .pickerStyle(.menu)
        .lineLimit(1)
    }

    /// 最初は「重さの種目で一番記録が多いもの」と「スプリントで一番記録が多いもの」を選んでおく。
    private func chooseDefaults() {
        guard firstName.isEmpty, secondName.isEmpty else { return }
        func mostRecorded(_ filter: (Exercise) -> Bool) -> Exercise? {
            exercises.filter(filter).max { Stats.history(for: $0).count < Stats.history(for: $1).count }
        }
        let strength = mostRecorded { $0.tracking == .weightReps }
        let speed = mostRecorded { $0.tracking == .distanceTime }
        firstName = strength?.name ?? exercises.first?.name ?? ""
        secondName = speed?.name ?? exercises.dropFirst().first?.name ?? ""
    }
}
