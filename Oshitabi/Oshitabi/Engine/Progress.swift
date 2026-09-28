import Foundation

/// キャラ1人ぶんの育成状況。
struct CharacterProgress: Codable, Hashable {
    var level = 1
    var exp = 0
    /// なかよし度（0〜100）。ホームで話しかけると上がる
    var affection = 0

    static let maxLevel = 30

    static func expToNext(_ level: Int) -> Int { 20 + level * 10 }

    var isMaxLevel: Bool { level >= Self.maxLevel }

    /// 覚醒段階（Lv10 と Lv20 で1段ずつ上がる）
    var awakening: Int { level >= 20 ? 2 : level >= 10 ? 1 : 0 }

    /// 経験値を足す。上がったレベル数を返す
    @discardableResult
    mutating func gain(_ amount: Int) -> Int {
        guard amount > 0, !isMaxLevel else { return 0 }
        let before = level
        exp += amount
        while !isMaxLevel, exp >= Self.expToNext(level) {
            exp -= Self.expToNext(level)
            level += 1
        }
        if isMaxLevel { exp = 0 }
        return level - before
    }
}

/// 放置で推しが育つしくみ。
enum IdleGrowth {
    /// 1分あたりの経験値
    static let expPerMinute = 1.0
    /// ためられる上限（8時間）
    static let capMinutes = 8.0 * 60

    static func pendingExp(since last: Date, now: Date) -> Int {
        let minutes = min(max(0, now.timeIntervalSince(last) / 60), capMinutes)
        return Int(minutes * expPerMinute)
    }

    static func capReached(since last: Date) -> Date {
        last.addingTimeInterval(capMinutes * 60)
    }
}

/// 戦闘でのキャラの強さ（レベル補正）。
enum Scaling {
    /// カードの数値にかける倍率：Lv1で1.0、1レベルごとに+6%、覚醒ごとに+10%
    static func power(level: Int) -> Double {
        let awakening = level >= 20 ? 2 : level >= 10 ? 1 : 0
        return 1.0 + Double(level - 1) * 0.06 + Double(awakening) * 0.1
    }

    static func scaled(_ base: Int, level: Int) -> Int {
        Int((Double(base) * power(level: level)).rounded())
    }

    static func maxHP(_ def: CharacterDef, level: Int) -> Int {
        def.baseHP + def.hpPerLevel * (level - 1)
    }
}
