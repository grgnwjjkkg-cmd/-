import Foundation
import SwiftData

/// マイメニュー（何個でも作れる）。論文のメニュー・過去の記録・自分で作ったものを保存する。
@Model
final class MenuTemplate {
    var name: String
    var note: String
    var createdAt: Date
    var lastUsedAt: Date?
    var isFavorite: Bool
    /// 論文から作ったときの pmid
    var sourcePMID: String?
    /// 研究での期間と週の回数（論文から作ったとき）
    var weeks: Int?
    var perWeek: Int?

    @Relationship(deleteRule: .cascade, inverse: \MenuItem.template)
    var items: [MenuItem] = []

    init(name: String, note: String = "", sourcePMID: String? = nil, weeks: Int? = nil, perWeek: Int? = nil) {
        self.name = name
        self.note = note
        self.createdAt = .now
        self.isFavorite = false
        self.sourcePMID = sourcePMID
        self.weeks = weeks
        self.perWeek = perWeek
    }

    var sortedItems: [MenuItem] { items.sorted { $0.order < $1.order } }

    /// 論文のメニューを使い始めてから何週目か（1始まり）。
    func currentWeek(since start: Date?, now: Date = .now) -> Int? {
        guard let start else { return nil }
        let days = Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0
        return days / 7 + 1
    }
}

@Model
final class MenuItem {
    var order: Int
    var exercise: Exercise?
    var template: MenuTemplate?
    var sets: Int
    var weight: Double
    var reps: Int
    var seconds: Double
    var meters: Double
    var restSeconds: Double?
    /// 重さや強さ、やり方のメモ（例: 最大の80%、下ろす動きを3秒で）
    var note: String

    init(order: Int, exercise: Exercise, sets: Int = 3, weight: Double = 0, reps: Int = 0,
         seconds: Double = 0, meters: Double = 0, restSeconds: Double? = nil, note: String = "") {
        self.order = order
        self.exercise = exercise
        self.sets = sets
        self.weight = weight
        self.reps = reps
        self.seconds = seconds
        self.meters = meters
        self.restSeconds = restSeconds
        self.note = note
    }

    var tracking: TrackingType { exercise?.tracking ?? .weightReps }

    /// 「3セット × 10回」のような短い表示。
    var summary: String {
        let count = reps > 0 ? "\(reps)回" : "回数は自由"
        let body: String = switch tracking {
        case .weightReps: weight > 0 ? "\(weight.short)kg × \(count)" : count
        case .reps: count
        case .time: "\(seconds.short)秒"
        case .distanceTime: meters > 0 ? "\(meters.short)m" : "ダッシュ"
        }
        return "\(sets)セット × \(body)"
    }
}

/// 体重の記録（1日1件。同じ日に入れ直すと上書き）。
@Model
final class BodyWeight {
    var date: Date
    var kilograms: Double

    init(date: Date = .now, kilograms: Double) {
        self.date = date
        self.kilograms = kilograms
    }
}
