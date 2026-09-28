import Charts
import SwiftData
import SwiftUI

/// 体重の記録。推定1RM を体重で割った「体重あたりの強さ」にも使う。
struct BodyWeightView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme) private var theme
    @Query(sort: \BodyWeight.date, order: .reverse) private var records: [BodyWeight]
    @State private var input: Double?
    @FocusState private var focused: Bool

    var body: some View {
        List {
            Section {
                HStack {
                    TextField("今日の体重", value: $input, format: .number)
                        .keyboardType(.decimalPad)
                        .focused($focused)
                        .font(.title3.monospacedDigit())
                    Text("kg").foregroundStyle(.secondary)
                    Button("記録") { save() }
                        .buttonStyle(.borderedProminent)
                        .disabled((input ?? 0) <= 0)
                }
            } footer: {
                Text("同じ日に入れ直すと上書きされます。種目のグラフ画面に「体重あたりの強さ」（推定1RM ÷ 体重）が出ます。")
            }
            .themedRow()

            if records.count >= 2 {
                Section("推移") {
                    Chart(records) { record in
                        LineMark(x: .value("日付", record.date), y: .value("体重", record.kilograms))
                            .foregroundStyle(theme.accent)
                        PointMark(x: .value("日付", record.date), y: .value("体重", record.kilograms))
                            .foregroundStyle(theme.accent)
                    }
                    .chartYScale(domain: .automatic(includesZero: false))
                    .frame(height: 200)
                    .padding(.vertical)
                }
                .themedRow()
            }

            Section("記録") {
                ForEach(records) { record in
                    LabeledContent {
                        Text("\(record.kilograms.short) kg").monospacedDigit()
                    } label: {
                        Text(record.date, format: .dateTime.year().month().day().weekday())
                    }
                }
                .onDelete { offsets in
                    for index in offsets { context.delete(records[index]) }
                }
            }
            .themedRow()
        }
        .overlay {
            if records.isEmpty && !focused {
                ContentUnavailableView("体重の記録はまだありません", systemImage: "scalemass",
                                       description: Text("上の欄に今日の体重を入れて「記録」を押します"))
                    .allowsHitTesting(false)
                    .padding(.top, 120)
            }
        }
        .scrollDismissesKeyboard(.interactively)
    }

    private func save() {
        guard let value = input, value > 0 else { return }
        let calendar = Calendar.current
        if let today = records.first(where: { calendar.isDateInToday($0.date) }) {
            today.kilograms = value
            today.date = .now
        } else {
            context.insert(BodyWeight(kilograms: value))
        }
        try? context.save()
        input = nil
        focused = false
    }
}
