import Foundation
import SwiftData

/// 種目の部位。rawValue は画面表示とデータ保存の両方に使う。
enum MuscleGroup: String, Codable, CaseIterable, Identifiable {
    case chest = "胸"
    case back = "背中"
    case legs = "脚"
    case shoulders = "肩"
    case arms = "腕"
    case core = "体幹"
    case sprint = "スプリント"
    case plyometric = "ジャンプ"
    case cardio = "有酸素"

    var id: String { rawValue }
}

/// 何を記録する種目か。
enum TrackingType: String, Codable, CaseIterable, Identifiable {
    case weightReps = "重量×回数"
    case reps = "回数（自重）"
    case time = "時間"
    case distanceTime = "距離×タイム"

    var id: String { rawValue }

    /// 記録の指標が大きいほど良いか（スプリントはタイムが小さいほど良い）。
    var higherIsBetter: Bool { self != .distanceTime }

    var metricLabel: String {
        switch self {
        case .weightReps: "推定1RM (kg)"
        case .reps: "最高回数"
        case .time: "最長時間 (秒)"
        case .distanceTime: "ベストタイム (秒)"
        }
    }
}

@Model
final class Exercise {
    @Attribute(.unique) var name: String
    var groupRaw: String
    var trackingRaw: String
    /// 論文とのひも付けに使うタグ（例: "筋力", "スプリント"）。
    var tags: [String]
    var isCustom: Bool
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \WorkoutEntry.exercise)
    var entries: [WorkoutEntry] = []

    init(name: String, group: MuscleGroup, tracking: TrackingType, tags: [String] = [], isCustom: Bool = false) {
        self.name = name
        self.groupRaw = group.rawValue
        self.trackingRaw = tracking.rawValue
        self.tags = tags
        self.isCustom = isCustom
        self.createdAt = .now
    }

    var group: MuscleGroup {
        get { MuscleGroup(rawValue: groupRaw) ?? .core }
        set { groupRaw = newValue.rawValue }
    }

    var tracking: TrackingType {
        get { TrackingType(rawValue: trackingRaw) ?? .weightReps }
        set { trackingRaw = newValue.rawValue }
    }

    /// 論文検索に使うキーワード（タグ＋部位名）。
    var paperKeywords: Set<String> { Set(tags).union([group.rawValue]) }
}

@Model
final class Workout {
    var startedAt: Date
    var finishedAt: Date?
    var note: String

    @Relationship(deleteRule: .cascade, inverse: \WorkoutEntry.workout)
    var entries: [WorkoutEntry] = []

    init(startedAt: Date = .now) {
        self.startedAt = startedAt
        self.note = ""
    }

    var sortedEntries: [WorkoutEntry] { entries.sorted { $0.order < $1.order } }

    var totalVolume: Double { entries.reduce(0) { $0 + $1.volume } }

    var completedSetCount: Int { entries.reduce(0) { $0 + $1.sets.filter(\.isDone).count } }

    var duration: TimeInterval { (finishedAt ?? .now).timeIntervalSince(startedAt) }
}

@Model
final class WorkoutEntry {
    var order: Int
    var exercise: Exercise?
    var workout: Workout?

    @Relationship(deleteRule: .cascade, inverse: \SetRecord.entry)
    var sets: [SetRecord] = []

    init(order: Int, exercise: Exercise) {
        self.order = order
        self.exercise = exercise
    }

    var sortedSets: [SetRecord] { sets.sorted { $0.order < $1.order } }

    var tracking: TrackingType { exercise?.tracking ?? .weightReps }

    /// 完了したセットの総挙上量（重量×回数）。
    var volume: Double {
        guard tracking == .weightReps else { return 0 }
        return sets.filter(\.isDone).reduce(0) { $0 + $1.weight * Double($1.reps) }
    }

    /// 完了したセットの中で一番良い指標。
    var bestMetric: Double? {
        let values = sets.filter(\.isDone).compactMap { $0.metric(for: tracking) }
        return tracking.higherIsBetter ? values.max() : values.min()
    }
}

@Model
final class SetRecord {
    var order: Int
    var weight: Double
    var reps: Int
    var seconds: Double
    var meters: Double
    var isDone: Bool
    var completedAt: Date?
    var entry: WorkoutEntry?

    init(order: Int, weight: Double = 0, reps: Int = 0, seconds: Double = 0, meters: Double = 0) {
        self.order = order
        self.weight = weight
        self.reps = reps
        self.seconds = seconds
        self.meters = meters
        self.isDone = false
    }

    /// Epley 式による推定1RM。
    var estimated1RM: Double {
        guard weight > 0, reps > 0 else { return 0 }
        return reps == 1 ? weight : weight * (1 + Double(reps) / 30)
    }

    func metric(for tracking: TrackingType) -> Double? {
        switch tracking {
        case .weightReps: estimated1RM > 0 ? estimated1RM : nil
        case .reps: reps > 0 ? Double(reps) : nil
        case .time: seconds > 0 ? seconds : nil
        case .distanceTime: seconds > 0 ? seconds : nil
        }
    }

    /// 「60kg × 8」のような短い表示。
    func summary(for tracking: TrackingType) -> String {
        switch tracking {
        case .weightReps: "\(weight.formatted())kg × \(reps)"
        case .reps: "\(reps)回"
        case .time: "\(seconds.formatted())秒"
        case .distanceTime: "\(meters.formatted())m \(seconds.formatted())秒"
        }
    }
}
