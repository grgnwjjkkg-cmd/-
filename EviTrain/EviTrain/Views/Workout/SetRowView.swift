import SwiftUI

/// 1セット分の入力行。完了チェックを押すと休憩タイマーが始まる。
struct SetRowView: View {
    @Environment(\.appTheme) private var theme
    @Bindable var set: SetRecord
    let number: Int
    let tracking: TrackingType
    let previous: SetRecord?
    let onToggle: (SetRecord) -> Void
    var onDuplicate: () -> Void = {}
    var onApplyToFollowing: () -> Void = {}
    var onWarmup: () -> Void = {}
    @State private var showingPlates = false

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 2) {
                Text("\(number)")
                    .font(.subheadline.bold())
                    .foregroundStyle(.secondary)
                if let rpe = set.rpe {
                    Text("RPE\(rpe.short)")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.tint)
                        .fixedSize()
                }
            }
            .frame(width: 30)

            fields

            Button {
                set.isDone.toggle()
                set.completedAt = set.isDone ? .now : nil
                onToggle(set)
            } label: {
                Image(systemName: set.isDone ? "checkmark.circle.fill" : "circle")
                    .font(.title2)
                    .foregroundStyle(set.isDone ? .green : .secondary)
            }
            .buttonStyle(.plain)
            .sensoryFeedback(.success, trigger: set.isDone) { _, isDone in isDone }
        }
        .listRowBackground(set.isDone ? Color.green.opacity(0.12) : theme.card)
        .contextMenu { quickActions }
        .sheet(isPresented: $showingPlates) { PlateCalculatorView(target: set.weight) }
    }

    /// RPE の説明（あと何回できそうだったか）
    private func rpeLabel(_ value: Double) -> String {
        let left = 10 - value
        let text: String = left == 0 ? "限界" : "あと\(left.short)回できそう"
        return "RPE \(value.short)（\(text)）"
    }

    /// 長押しで出す、入力を速くするための操作。
    @ViewBuilder
    private var quickActions: some View {
        switch tracking {
        case .weightReps:
            Button("重さ +2.5kg", systemImage: "plus") { set.weight += 2.5 }
            Button("重さ −2.5kg", systemImage: "minus") { set.weight = max(0, set.weight - 2.5) }
            Button("回数 +1", systemImage: "plus") { set.reps += 1 }
            Button("回数 −1", systemImage: "minus") { set.reps = max(0, set.reps - 1) }
        case .reps:
            Button("回数 +1", systemImage: "plus") { set.reps += 1 }
            Button("回数 −1", systemImage: "minus") { set.reps = max(0, set.reps - 1) }
        case .time:
            Button("+5秒", systemImage: "plus") { set.seconds += 5 }
            Button("−5秒", systemImage: "minus") { set.seconds = max(0, set.seconds - 5) }
        case .distanceTime:
            Button("タイム −0.05秒", systemImage: "minus") { set.seconds = max(0, set.seconds - 0.05) }
            Button("タイム +0.05秒", systemImage: "plus") { set.seconds += 0.05 }
        }
        Menu("きつさ（RPE）", systemImage: "gauge.with.dots.needle.67percent") {
            ForEach([10.0, 9.5, 9.0, 8.5, 8.0, 7.0, 6.0], id: \.self) { value in
                Button(rpeLabel(value)) { set.rpe = value }
            }
            if set.rpe != nil {
                Button("消す", role: .destructive) { set.rpe = nil }
            }
        }
        Divider()
        if tracking == .weightReps && set.weight > 20 {
            Button("ウォームアップのセットを前に入れる", systemImage: "flame", action: onWarmup)
            Button("プレート計算", systemImage: "circle.grid.2x1") { showingPlates = true }
        }
        Button("このセットを複製", systemImage: "plus.square.on.square", action: onDuplicate)
        Button("この値を以降のセットにそろえる", systemImage: "arrow.down.to.line", action: onApplyToFollowing)
    }

    @ViewBuilder
    private var fields: some View {
        switch tracking {
        case .weightReps:
            NumberField(value: $set.weight, unit: "kg", placeholder: previous?.weight, decimal: true)
            Text("×").foregroundStyle(.secondary)
            NumberField(value: repsBinding, unit: "回", placeholder: previous.map { Double($0.reps) })
        case .reps:
            NumberField(value: repsBinding, unit: "回", placeholder: previous.map { Double($0.reps) })
        case .time:
            NumberField(value: $set.seconds, unit: "秒", placeholder: previous?.seconds, decimal: true)
        case .distanceTime:
            NumberField(value: $set.meters, unit: "m", placeholder: previous?.meters, decimal: true)
            NumberField(value: $set.seconds, unit: "秒", placeholder: previous?.seconds, decimal: true)
            if let speed = set.speedKmh {
                Text("\(speed.short)\nkm/h")
                    .font(.caption2.monospacedDigit())
                    .multilineTextAlignment(.center)
                    .foregroundStyle(.tint)
            }
        }
    }

    private var repsBinding: Binding<Double> {
        Binding(get: { Double(set.reps) }, set: { set.reps = max(0, Int($0)) })
    }
}

/// 単位つきの数値入力欄。0 のときは前回の値を薄く表示する。
private struct NumberField: View {
    @Binding var value: Double
    let unit: String
    var placeholder: Double?
    var decimal = false

    var body: some View {
        HStack(spacing: 2) {
            TextField(placeholder.map { $0.short } ?? "0", value: optionalValue, format: .number)
                .keyboardType(decimal ? .decimalPad : .numberPad)
                .multilineTextAlignment(.trailing)
                .monospacedDigit()
                .padding(.vertical, 6)
                .padding(.horizontal, 8)
                .background(.fill.tertiary, in: RoundedRectangle(cornerRadius: 8))
            Text(unit)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    /// 0 を空欄として扱い、プレースホルダー（前回値）が見えるようにする。
    private var optionalValue: Binding<Double?> {
        Binding(get: { value == 0 ? nil : value }, set: { value = $0 ?? 0 })
    }
}
