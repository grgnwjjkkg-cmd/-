import SwiftUI

/// プレート計算：目標の重さにするには、バーの片側にどのプレートを付けるか。
enum PlateMath {
    static let plates: [Double] = [25, 20, 15, 10, 5, 2.5, 1.25]

    /// 片側に付けるプレート（重い順）。ぴったりにならないときは残りも返す。
    static func perSide(target: Double, bar: Double) -> (plates: [Double], remainder: Double) {
        var rest = max(0, (target - bar) / 2)
        var result: [Double] = []
        for plate in plates {
            while rest + 0.0001 >= plate {
                result.append(plate)
                rest -= plate
            }
        }
        return (result, rest < 0.0001 ? 0 : rest)
    }

    /// ウォームアップの重さ（本番の重さの 40%・60%・80%。2.5kg 単位に丸める。バーより軽くしない）
    static func warmups(for working: Double, bar: Double = 20) -> [(weight: Double, reps: Int)] {
        guard working > bar else { return [] }
        let steps: [(Double, Int)] = [(0.4, 8), (0.6, 5), (0.8, 3)]
        var result: [(weight: Double, reps: Int)] = []
        for (ratio, reps) in steps {
            let weight = max(bar, (working * ratio / 2.5).rounded() * 2.5)
            if weight < working, !result.contains(where: { $0.weight == weight }) {
                result.append((weight, reps))
            }
        }
        return result
    }
}

struct PlateCalculatorView: View {
    @Environment(\.dismiss) private var dismiss
    @State var target: Double
    @AppStorage("barWeight") private var bar = 20.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $target, in: 0...400, step: 2.5) {
                        LabeledContent("目標の重さ", value: "\(target.short) kg")
                    }
                    Picker("バーの重さ", selection: $bar) {
                        ForEach([20.0, 15.0, 10.0, 7.0], id: \.self) { Text("\($0.short) kg").tag($0) }
                    }
                }
                Section("片側に付けるプレート") {
                    let result = PlateMath.perSide(target: target, bar: bar)
                    if target <= bar {
                        Text("プレートなし（バーだけ）")
                    } else {
                        PlateStackView(plates: result.plates)
                            .frame(height: 90)
                            .listRowInsets(EdgeInsets(top: 12, leading: 12, bottom: 12, trailing: 12))
                        Text(result.plates.map { "\($0.short)kg" }.joined(separator: " + "))
                            .font(.subheadline.monospacedDigit())
                        if result.remainder > 0 {
                            Text("あと片側 \(result.remainder.short)kg はプレートで作れません")
                                .font(.caption)
                                .foregroundStyle(.orange)
                        }
                    }
                }
            }
            .navigationTitle("プレート計算")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("閉じる") { dismiss() } }
            }
        }
        .presentationDetents([.medium, .large])
    }
}

/// バーとプレートを横から見た図（重いプレートほど高く太い）。
private struct PlateStackView: View {
    let plates: [Double]

    private func color(for plate: Double) -> Color {
        switch plate {
        case 25: Color(light: 0xD64545, dark: 0xF06A6A)
        case 20: Color(light: 0x2F6FD1, dark: 0x6D9EF0)
        case 15: Color(light: 0xD9A400, dark: 0xF2C94C)
        case 10: Color(light: 0x2E9E5B, dark: 0x5BCB88)
        default: Color(light: 0x6B7280, dark: 0x9CA3AF)
        }
    }

    private func plateView(_ plate: Double, maxHeight: CGFloat) -> some View {
        let ratio: CGFloat = 0.35 + 0.65 * CGFloat(min(plate, 25)) / 25
        let width: CGFloat = plate >= 10 ? 14 : 9
        return RoundedRectangle(cornerRadius: 3)
            .fill(color(for: plate))
            .frame(width: width, height: maxHeight * ratio)
    }

    var body: some View {
        GeometryReader { proxy in
            let height = proxy.size.height
            HStack(spacing: 2) {
                RoundedRectangle(cornerRadius: 2).fill(.gray.opacity(0.6)).frame(width: 36, height: 10)
                RoundedRectangle(cornerRadius: 2).fill(.gray).frame(width: 8, height: 26)
                ForEach(Array(plates.enumerated()), id: \.offset) { _, plate in
                    plateView(plate, maxHeight: height)
                }
                RoundedRectangle(cornerRadius: 2).fill(.gray.opacity(0.6)).frame(width: 30, height: 10)
                Spacer(minLength: 0)
            }
            .frame(maxHeight: .infinity)
        }
        .accessibilityHidden(true)
    }
}
