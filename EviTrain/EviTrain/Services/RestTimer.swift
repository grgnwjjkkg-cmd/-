import Foundation
import Observation
import UserNotifications

/// セット間の休憩タイマー。アプリを閉じていても終了時に通知する。
@MainActor
@Observable
final class RestTimer {
    static let defaultSecondsKey = "defaultRestSeconds"
    private static let notificationID = "rest-timer"

    private(set) var endDate: Date?
    private(set) var total: TimeInterval = 0

    func remaining(at date: Date = .now) -> TimeInterval {
        max(0, (endDate ?? date).timeIntervalSince(date))
    }

    func isRunning(at date: Date = .now) -> Bool { remaining(at: date) > 0 }

    func start(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        endDate = .now.addingTimeInterval(seconds)
        total = seconds
        scheduleNotification()
    }

    func add(_ seconds: TimeInterval) {
        guard let endDate else { return }
        let newEnd = endDate.addingTimeInterval(seconds)
        guard newEnd > .now else { return stop() }
        self.endDate = newEnd
        total = max(total + seconds, 1)
        scheduleNotification()
    }

    func stop() {
        endDate = nil
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    private func scheduleNotification() {
        let interval = remaining()
        guard interval >= 1 else { return }
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            let content = UNMutableNotificationContent()
            content.title = "休憩終了"
            content.body = "次のセットを始めましょう 💪"
            content.sound = .default
            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
            try? await center.add(UNNotificationRequest(identifier: Self.notificationID, content: content, trigger: trigger))
        }
    }
}
