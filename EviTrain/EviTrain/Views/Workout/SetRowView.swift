import SwiftUI

/// 1セット分の入力行。完了チェックを押すと休憩タイマーが始まる。
struct SetRowView: View {
    @Bindable var set: SetRecord
    let number: Int
    let tracking: TrackingType
    let previous: SetRecord?
    let onToggle: (SetRecord) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text("\(number)")
                .font(.subheadline.bold())
                .frame(width: 22)
                .foregroundStyle(.secondary)

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
        .listRowBackground(set.isDone ? Color.green.opacity(0.08) : nil)
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
