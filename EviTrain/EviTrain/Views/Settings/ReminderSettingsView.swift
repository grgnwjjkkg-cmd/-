import SwiftUI

/// リマインダーの設定（曜日と時刻）。
struct ReminderSettingsView: View {
    @AppStorage(TrainingReminder.enabledKey) private var enabled = false
    @AppStorage(TrainingReminder.weekdaysKey) private var storedWeekdays = "2,4,6"
    @AppStorage(TrainingReminder.hourKey) private var hour = 19
    @AppStorage(TrainingReminder.minuteKey) private var minute = 0
    @Environment(\.appTheme) private var theme

    private let symbols = Calendar.current.veryShortWeekdaySymbols // 日 月 火 …

    private var time: Binding<Date> {
        Binding {
            Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now) ?? .now
        } set: { date in
            hour = Calendar.current.component(.hour, from: date)
            minute = Calendar.current.component(.minute, from: date)
        }
    }

    var body: some View {
        let selected = TrainingReminder.weekdays(from: storedWeekdays)
        Toggle(isOn: $enabled) {
            Label("トレーニングのリマインダー", systemImage: "bell.badge")
        }
        if enabled {
            HStack(spacing: 6) {
                ForEach(1...7, id: \.self) { weekday in
                    let isOn = selected.contains(weekday)
                    Button {
                        var next = selected
                        if isOn { next.remove(weekday) } else { next.insert(weekday) }
                        storedWeekdays = TrainingReminder.store(next)
                    } label: {
                        Text(symbols[weekday - 1])
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity, minHeight: 36)
                            .foregroundStyle(isOn ? theme.onAccent : Color.primary)
                            .background(isOn ? AnyShapeStyle(theme.accent) : AnyShapeStyle(.fill.tertiary), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("\(symbols[weekday - 1])曜日 \(isOn ? "オン" : "オフ")")
                }
            }
            DatePicker("時刻", selection: time, displayedComponents: .hourAndMinute)
        }
    }

    /// 設定が変わったら通知を入れ直す（設定画面から呼ぶ）。
    static func apply() {
        let defaults = UserDefaults.standard
        let enabled = defaults.bool(forKey: TrainingReminder.enabledKey)
        let weekdays = TrainingReminder.weekdays(from: defaults.string(forKey: TrainingReminder.weekdaysKey) ?? "2,4,6")
        let hour = defaults.object(forKey: TrainingReminder.hourKey) as? Int ?? 19
        let minute = defaults.object(forKey: TrainingReminder.minuteKey) as? Int ?? 0
        Task { await TrainingReminder.reschedule(enabled: enabled, weekdays: weekdays, hour: hour, minute: minute) }
    }
}
