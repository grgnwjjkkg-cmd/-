import Foundation
import Observation
import UserNotifications

/// 端末に保存するデータ
struct SaveData: Codable {
    var owned: [String: CharacterProgress] = [:]
    var oshi: String?
    var lastIdleClaim = Date()
    var run: Run?
    var runsPlayed = 0
    var bestFloor = 0
    var bossClears = 0
}

/// レベルアップなどの結果（画面でお祝いを出すのに使う）
struct GrowthReport: Identifiable, Equatable {
    let id = UUID()
    var character: String
    var exp: Int
    var levelsGained: Int
    var newLevel: Int
}

@MainActor
@Observable
final class GameStore {
    private(set) var data: SaveData
    private let url: URL

    init(fileName: String = "save.json") {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        url = dir.appendingPathComponent(fileName)
        if let raw = try? Data(contentsOf: url), let saved = try? JSONDecoder().decode(SaveData.self, from: raw) {
            data = saved
        } else {
            data = SaveData()
        }
    }

    private func save() {
        if let raw = try? JSONEncoder().encode(data) {
            try? raw.write(to: url, options: .atomic)
        }
    }

    // MARK: 仲間

    var hasChosenOshi: Bool { data.oshi != nil }
    var oshiID: String { data.oshi ?? Catalog.starters[0] }
    var oshi: CharacterDef { Catalog.character(oshiID)! }

    func owns(_ id: String) -> Bool { data.owned[id] != nil }
    func progress(_ id: String) -> CharacterProgress { data.owned[id] ?? CharacterProgress() }
    func level(_ id: String) -> Int { progress(id).level }

    var ownedCharacters: [CharacterDef] { Catalog.characters.filter { owns($0.id) } }

    /// はじめて遊ぶとき：最初の仲間をそろえて推しを決める
    func start(withOshi id: String) {
        for starter in Catalog.starters where data.owned[starter] == nil {
            data.owned[starter] = CharacterProgress()
        }
        data.oshi = id
        data.lastIdleClaim = .now
        save()
    }

    /// 推しを変える（それまでの放置ぶんは今の推しが受け取る）
    @discardableResult
    func setOshi(_ id: String) -> GrowthReport? {
        guard owns(id), id != data.oshi else { return nil }
        let report = claimIdle()
        data.oshi = id
        save()
        return report
    }

    // MARK: 放置

    func pendingIdleExp(now: Date = .now) -> Int {
        guard hasChosenOshi, !progress(oshiID).isMaxLevel else { return 0 }
        return IdleGrowth.pendingExp(since: data.lastIdleClaim, now: now)
    }

    var idleCapDate: Date { IdleGrowth.capReached(since: data.lastIdleClaim) }

    @discardableResult
    func claimIdle(now: Date = .now) -> GrowthReport? {
        let exp = pendingIdleExp(now: now)
        data.lastIdleClaim = now
        defer { save(); scheduleIdleNotification() }
        guard exp > 0 else { return nil }
        return grant(exp, to: oshiID)
    }

    /// 話しかける：なかよし度が上がり、セリフを返す
    func talk() -> String {
        var p = progress(oshiID)
        p.affection = min(100, p.affection + 1)
        data.owned[oshiID] = p
        save()
        let lines = oshi.lines
        return lines[(p.affection + Int(Date.now.timeIntervalSince1970)) % lines.count]
    }

    private func grant(_ exp: Int, to id: String) -> GrowthReport {
        var p = progress(id)
        let gained = p.gain(exp)
        data.owned[id] = p
        return GrowthReport(character: id, exp: exp, levelsGained: gained, newLevel: p.level)
    }

    // MARK: 冒険

    var run: Run? { data.run }

    func startRun(party: [String]) {
        let levels = Dictionary(uniqueKeysWithValues: party.map { ($0, level($0)) })
        let recruitable = Catalog.characters.map(\.id).filter { !owns($0) }
        data.run = Run(party: party, levels: levels, recruitable: recruitable, seed: UInt64.random(in: 1...UInt64.max))
        data.runsPlayed += 1
        save()
    }

    func updateRun(_ run: Run) {
        data.run = run
        save()
    }

    /// 冒険の結果を受け取る：経験値と新しい仲間
    func collectRunResult() -> [GrowthReport] {
        guard let run = data.run, case let .finished(result) = run.phase else { return [] }
        let reports = run.party.map { grant(result.expEach, to: $0) }
        if let recruit = result.recruited, data.owned[recruit] == nil {
            data.owned[recruit] = CharacterProgress()
        }
        data.bestFloor = max(data.bestFloor, result.floorsCleared)
        if result.cleared { data.bossClears += 1 }
        data.run = nil
        save()
        return reports
    }

    func abandonRun() {
        guard var run = data.run else { return }
        // あきらめても、進んだ階ぶんの経験値はもらえる
        if case .finished = run.phase {} else {
            run.phase = .finished(RunResult(cleared: false, floorsCleared: run.floor, expEach: run.floor * 12, recruited: nil))
            data.run = run
        }
        save()
    }

    // MARK: 通知

    func requestNotifications() {
        Task {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
            scheduleIdleNotification()
        }
    }

    /// 放置の経験値がいっぱいになったら知らせる
    func scheduleIdleNotification() {
        let center = UNUserNotificationCenter.current()
        let id = "idle-full"
        center.removePendingNotificationRequests(withIdentifiers: [id])
        guard hasChosenOshi else { return }
        let interval = idleCapDate.timeIntervalSinceNow
        guard interval > 60 else { return }
        let content = UNMutableNotificationContent()
        content.title = "\(oshi.name)が待ってるよ"
        content.body = "放置の経験値がいっぱいになりました。受け取りに行こう！"
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    #if DEBUG
    func debugReset() {
        data = SaveData()
        save()
    }

    func debugAddIdleHours(_ hours: Double) {
        data.lastIdleClaim = data.lastIdleClaim.addingTimeInterval(-hours * 3600)
        save()
    }
    #endif
}
