import Foundation

/// 達成バッジ。記録から毎回計算する（保存はしない）。
struct Badge: Identifiable {
    let id: String
    let title: String
    let detail: String
    let symbol: String
    let earned: Bool
    /// 進み具合（0〜1）。達成していないバッジの目安表示用
    let progress: Double
}

enum Badges {
    struct Input {
        var workouts: [Workout]
        var menus: [MenuTemplate]
        var bookmarkCount: Int
    }

    static func all(_ input: Input) -> [Badge] {
        let finished = input.workouts.filter { $0.finishedAt != nil }
        let count = finished.count
        let longest = longestStreak(finished)
        let records = recordCount(finished)
        let sprintSets = finished.flatMap(\.entries)
            .filter { $0.exercise?.tracking == .distanceTime }
            .reduce(0) { $0 + $1.sets.filter(\.isDone).count }
        let usedStudyMenu = input.menus.contains { $0.sourcePMID != nil && $0.firstUsedAt != nil }
        let volume = finished.reduce(0) { $0 + $1.totalVolume }

        func badge(_ id: String, _ title: String, _ detail: String, _ symbol: String, value: Double, goal: Double) -> Badge {
            Badge(id: id, title: title, detail: detail, symbol: symbol, earned: value >= goal, progress: min(1, value / goal))
        }

        return [
            badge("first", "はじめの一歩", "はじめてトレーニングを記録", "shoeprints.fill", value: Double(count), goal: 1),
            badge("ten", "10回達成", "トレーニングを10回記録", "10.circle.fill", value: Double(count), goal: 10),
            badge("fifty", "50回達成", "トレーニングを50回記録", "50.circle.fill", value: Double(count), goal: 50),
            badge("streak3", "3日連続", "3日続けてトレーニング", "flame.fill", value: Double(longest), goal: 3),
            badge("streak7", "7日連続", "7日続けてトレーニング", "flame.circle.fill", value: Double(longest), goal: 7),
            badge("record1", "自己ベスト", "はじめて自己ベストを更新", "trophy.fill", value: Double(records), goal: 1),
            badge("record10", "自己ベスト10回", "自己ベストを10回更新", "crown.fill", value: Double(records), goal: 10),
            badge("sprint", "スプリンター", "ダッシュを50本記録", "bolt.fill", value: Double(sprintSets), goal: 50),
            badge("ton", "10トン", "総挙上量の合計が10,000kg", "scalemass.fill", value: volume, goal: 10_000),
            badge("study", "研究を練習に", "論文のメニューで練習した", "doc.text.fill", value: usedStudyMenu ? 1 : 0, goal: 1),
            badge("reader", "研究好き", "論文を10本保存", "bookmark.fill", value: Double(input.bookmarkCount), goal: 10),
        ]
    }

    /// これまでで一番長い連続日数。
    static func longestStreak(_ workouts: [Workout], calendar: Calendar = .current) -> Int {
        let days = Set(workouts.map { calendar.startOfDay(for: $0.startedAt) }).sorted()
        var best = 0, current = 0
        var previous: Date?
        for day in days {
            if let previous, calendar.date(byAdding: .day, value: 1, to: previous) == day {
                current += 1
            } else {
                current = 1
            }
            best = max(best, current)
            previous = day
        }
        return best
    }

    /// 自己ベストを更新した回数（種目ごとに、それまでの最高を超えた回数）。
    static func recordCount(_ workouts: [Workout]) -> Int {
        var best: [String: Double] = [:]
        var count = 0
        for workout in workouts.sorted(by: { $0.startedAt < $1.startedAt }) {
            for entry in workout.entries {
                guard let exercise = entry.exercise, let value = entry.bestMetric else { continue }
                if let previous = best[exercise.name] {
                    let better = exercise.tracking.higherIsBetter ? value > previous : value < previous
                    if better {
                        count += 1
                        best[exercise.name] = value
                    }
                } else {
                    best[exercise.name] = value
                }
            }
        }
        return count
    }
}
