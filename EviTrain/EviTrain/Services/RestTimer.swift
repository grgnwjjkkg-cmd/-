import Foundation
import Observation
import UIKit
import UserNotifications

/// セット間の休憩タイマー。
/// アプリを閉じていても通知で、開いているときは通知のバナー＋振動と画面の表示で、終わりを知らせる。
@MainActor
@Observable
final class RestTimer {
    static let defaultSecondsKey = "defaultRestSeconds"
    private static let notificationID = "rest-timer"

    private(set) var endDate: Date?
    private(set) var total: TimeInterval = 0
    /// 休憩が終わった直後（数秒だけ true）。画面に「休憩終了」を出すのに使う
    private(set) var justFinished = false

    private var finishTask: Task<Void, Never>?
    private var flashTask: Task<Void, Never>?

    func remaining(at date: Date = .now) -> TimeInterval {
        max(0, (endDate ?? date).timeIntervalSince(date))
    }

    func isRunning(at date: Date = .now) -> Bool { remaining(at: date) > 0 }

    func start(seconds: TimeInterval) {
        guard seconds > 0 else { return }
        endDate = .now.addingTimeInterval(seconds)
        total = seconds
        justFinished = false
        scheduleNotification()
        scheduleFinish()
    }

    func add(_ seconds: TimeInterval) {
        guard let endDate else { return }
        let newEnd = endDate.addingTimeInterval(seconds)
        guard newEnd > .now else { return stop() }
        self.endDate = newEnd
        total = max(total + seconds, 1)
        scheduleNotification()
        scheduleFinish()
    }

    func stop() {
        endDate = nil
        finishTask?.cancel()
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [Self.notificationID])
    }

    /// 終了時刻になったら、振動して「休憩終了」を数秒表示する（アプリを開いているとき用）。
    private func scheduleFinish() {
        finishTask?.cancel()
        guard let target = endDate else { return }
        finishTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(max(0, target.timeIntervalSinceNow)))
            guard !Task.isCancelled, let self, self.endDate == target else { return }
            self.finish()
        }
    }

    private func finish() {
        endDate = nil
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        justFinished = true
        flashTask?.cancel()
        flashTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(4))
            guard !Task.isCancelled else { return }
            self?.justFinished = false
        }
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

/// アプリを開いているときも、休憩終了の通知をバナーと音で出す。
final class ForegroundNotificationPresenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = ForegroundNotificationPresenter()

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification,
                                withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        completionHandler([.banner, .sound, .list])
    }
}
