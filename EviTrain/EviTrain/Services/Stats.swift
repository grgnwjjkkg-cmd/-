import Foundation

/// 記録の集計（連続日数・前回の記録・自己ベスト）。
enum Stats {
    /// 今日（まだなら昨日）から数えて、トレーニングした日が何日続いているか。
    static func streakDays(_ workouts: [Workout], calendar: Calendar = .current, now: Date = .now) -> Int {
        let days = Set(workouts.map { calendar.startOfDay(for: $0.startedAt) })
        var day = calendar.startOfDay(for: now)
        if !days.contains(day) {
            guard let yesterday = calendar.date(byAdding: .day, value: -1, to: day), days.contains(yesterday) else { return 0 }
            day = yesterday
        }
        var count = 0
        while days.contains(day) {
            count += 1
            guard let previous = calendar.date(byAdding: .day, value: -1, to: day) else { break }
            day = previous
        }
        return count
    }

    static func countThisWeek(_ workouts: [Workout], calendar: Calendar = .current, now: Date = .now) -> Int {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return 0 }
        return workouts.filter { week.contains($0.startedAt) }.count
    }

    /// 今週、部位ごとに完了したセット数（スプリント・ジャンプ・有酸素は除く）。
    struct GroupSets: Identifiable {
        let group: MuscleGroup
        let sets: Int
        var id: MuscleGroup { group }
    }

    static func weeklySets(_ workouts: [Workout], calendar: Calendar = .current, now: Date = .now) -> [GroupSets] {
        guard let week = calendar.dateInterval(of: .weekOfYear, for: now) else { return [] }
        var counts: [MuscleGroup: Int] = [:]
        for workout in workouts where week.contains(workout.startedAt) {
            for entry in workout.entries {
                guard let group = entry.exercise?.group else { continue }
                counts[group, default: 0] += entry.sets.filter(\.isDone).count
            }
        }
        let strengthGroups: [MuscleGroup] = [.chest, .back, .legs, .shoulders, .arms, .core]
        return strengthGroups.map { GroupSets(group: $0, sets: counts[$0] ?? 0) }
    }

    /// 完了済みのトレーニングのうち、指定日時より前で一番新しい同じ種目の記録。
    static func previousEntry(for exercise: Exercise, before date: Date) -> WorkoutEntry? {
        exercise.entries
            .filter { entry in
                guard let workout = entry.workout, workout.finishedAt != nil else { return false }
                return workout.startedAt < date && entry.sets.contains(where: \.isDone)
            }
            .max { ($0.workout?.startedAt ?? .distantPast) < ($1.workout?.startedAt ?? .distantPast) }
    }

    /// 指定日時より前の自己ベスト。
    static func personalBest(for exercise: Exercise, before date: Date = .distantFuture) -> Double? {
        let values = exercise.entries
            .filter { ($0.workout?.finishedAt != nil) && ($0.workout?.startedAt ?? .distantFuture) < date }
            .compactMap(\.bestMetric)
        return exercise.tracking.higherIsBetter ? values.max() : values.min()
    }

    struct Record: Identifiable {
        let exercise: Exercise
        let value: Double
        var id: String { exercise.name }
    }

    /// このトレーニングで更新した自己ベスト。
    static func newRecords(in workout: Workout) -> [Record] {
        workout.sortedEntries.compactMap { entry in
            guard let exercise = entry.exercise, let best = entry.bestMetric else { return nil }
            guard let previous = personalBest(for: exercise, before: workout.startedAt) else {
                return nil // 初めての種目は自己ベスト扱いにしない
            }
            let improved = exercise.tracking.higherIsBetter ? best > previous : best < previous
            return improved ? Record(exercise: exercise, value: best) : nil
        }
    }

    struct Point: Identifiable {
        let date: Date
        let value: Double
        var id: Date { date }
    }

    /// 種目ごとの推移（グラフ用）。
    static func history(for exercise: Exercise) -> [Point] {
        exercise.entries
            .compactMap { entry -> Point? in
                guard let workout = entry.workout, workout.finishedAt != nil, let value = entry.bestMetric else { return nil }
                return Point(date: workout.startedAt, value: value)
            }
            .sorted { $0.date < $1.date }
    }
}

extension Double {
    /// 表示用に小数点以下1桁までに丸める。
    var short: String { formatted(.number.precision(.fractionLength(0...1))) }
}

extension TimeInterval {
    /// 「1:05:30」「12:34」形式。
    var clock: String {
        let total = Int(self)
        let h = total / 3600, m = total % 3600 / 60, s = total % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
