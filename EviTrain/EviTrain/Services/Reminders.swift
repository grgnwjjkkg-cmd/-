import Foundation
import UserNotifications

/// 決めた曜日・時刻に「トレーニングの日です」と知らせる。
enum TrainingReminder {
    static let enabledKey = "reminderEnabled"
    static let weekdaysKey = "reminderWeekdays"   // "2,4,6" のように保存（1=日曜 … 7=土曜）
    static let hourKey = "reminderHour"
    static let minuteKey = "reminderMinute"
    private static let idPrefix = "training-reminder-"

    static func weekdays(from stored: String) -> Set<Int> {
        Set(stored.split(separator: ",").compactMap { Int($0) }.filter { (1...7).contains($0) })
    }

    static func store(_ weekdays: Set<Int>) -> String {
        weekdays.sorted().map(String.init).joined(separator: ",")
    }

    /// 設定に合わせて通知を入れ直す。オフなら全部消す。
    static func reschedule(enabled: Bool, weekdays: Set<Int>, hour: Int, minute: Int) async {
        let center = UNUserNotificationCenter.current()
        let ids = (1...7).map { idPrefix + String($0) }
        center.removePendingNotificationRequests(withIdentifiers: ids)
        guard enabled, !weekdays.isEmpty else { return }
        guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
        for weekday in weekdays {
            let content = UNMutableNotificationContent()
            content.title = "今日はトレーニングの日"
            content.body = "前回のメニューなら1タップで始められます 💪"
            content.sound = .default
            var components = DateComponents()
            components.weekday = weekday
            components.hour = hour
            components.minute = minute
            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: true)
            try? await center.add(UNNotificationRequest(identifier: idPrefix + String(weekday), content: content, trigger: trigger))
        }
    }
}
