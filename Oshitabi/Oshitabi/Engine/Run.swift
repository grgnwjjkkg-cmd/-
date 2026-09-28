import Foundation

enum NodeKind: String, Codable, CaseIterable {
    case battle, elite, rest, treasure, boss

    var label: String {
        switch self {
        case .battle: "戦闘"
        case .elite: "強敵"
        case .rest: "休憩"
        case .treasure: "宝箱"
        case .boss: "ボス"
        }
    }

    var detail: String {
        switch self {
        case .battle: "影と戦う。勝てばカードがもらえる"
        case .elite: "手ごわい影。仲間が増えるかも"
        case .rest: "HPを30%回復する"
        case .treasure: "レアカードを1枚もらえる"
        case .boss: "この道の主。倒せば新しい仲間が"
        }
    }
}

enum RunPhase: Codable, Hashable {
    /// 次に進む道を選ぶ
    case choosing
    case battle(Battle)
    /// 戦闘や宝箱の報酬（カード3枚から1枚）
    case reward(cards: [String], fromElite: Bool)
    case finished(RunResult)
}

struct RunResult: Codable, Hashable {
    var cleared: Bool
    var floorsCleared: Int
    var expEach: Int
    var recruited: String?
}

/// 1回の冒険（ローグライク）。全8階、最後にボス。
struct Run: Codable, Hashable {
    static let floorCount = 8

    let party: [String]
    var deck: [String]
    var hp: Int
    let maxHP: Int
    /// 今いる階（0始まり）。choosing のときはこれから進む階
    var floor = 0
    var choices: [NodeKind] = []
    var phase: RunPhase = .choosing
    var elitesDefeated = 0
    let levels: [String: Int]
    /// まだ仲間にいないキャラ（勧誘の候補）
    let recruitable: [String]
    var rng: SeededRNG

    init(party: [String], levels: [String: Int], recruitable: [String], seed: UInt64) {
        self.party = party
        self.levels = levels
        self.recruitable = recruitable
        deck = party.flatMap { Catalog.character($0)?.starterDeck ?? [] }
        maxHP = party.reduce(0) { total, id in
            guard let def = Catalog.character(id) else { return total }
            return total + Scaling.maxHP(def, level: levels[id] ?? 1)
        }
        hp = maxHP
        rng = SeededRNG(seed: seed)
        choices = makeChoices()
    }

    var isBossFloor: Bool { floor == Run.floorCount - 1 }

    // MARK: 道を選ぶ

    mutating func choose(_ kind: NodeKind) {
        guard case .choosing = phase, choices.contains(kind) else { return }
        switch kind {
        case .battle, .elite, .boss:
            let tier: EnemyTier = kind == .boss ? .boss : kind == .elite ? .elite : .normal
            let enemy = rng.pick(Catalog.enemies(tier))!
            phase = .battle(Battle(enemy: enemy, floor: floor, deck: deck, playerHP: hp, playerMaxHP: maxHP,
                                   levels: levels, rng: SeededRNG(seed: rng.next())))
        case .rest:
            hp = min(maxHP, hp + Int(Double(maxHP) * 0.3))
            advance()
        case .treasure:
            phase = .reward(cards: rewardCards(rareOnly: true), fromElite: false)
        }
    }

    // MARK: 戦闘

    mutating func updateBattle(_ battle: Battle) {
        guard case .battle = phase else { return }
        switch battle.outcome {
        case .ongoing:
            phase = .battle(battle)
        case .won:
            hp = battle.playerHP
            let tier = battle.enemy.tier
            if tier == .elite { elitesDefeated += 1 }
            if tier == .boss {
                finish(cleared: true)
            } else {
                phase = .reward(cards: rewardCards(rareOnly: tier == .elite), fromElite: tier == .elite)
            }
        case .lost:
            hp = 0
            finish(cleared: false)
        }
    }

    // MARK: 報酬

    mutating func takeReward(_ card: String?) {
        guard case .reward = phase else { return }
        if let card { deck.append(card) }
        advance()
    }

    /// 仲間のカードから3枚。レアは強敵・宝箱で出やすい
    private mutating func rewardCards(rareOnly: Bool) -> [String] {
        let pool = party.flatMap { id -> [String] in
            guard let def = Catalog.character(id) else { return [] }
            return rareOnly ? def.rewardPool : def.rewardPool + def.starterDeck
        }
        var unique = Array(Set(pool)).sorted()
        rng.shuffle(&unique)
        return Array(unique.prefix(3))
    }

    // MARK: 進行

    private mutating func advance() {
        floor += 1
        if floor >= Run.floorCount {
            finish(cleared: true)
            return
        }
        choices = makeChoices()
        phase = .choosing
    }

    private mutating func makeChoices() -> [NodeKind] {
        if isBossFloor { return [.boss] }
        if floor == 0 { return [.battle] }
        var picks: [NodeKind] = []
        while picks.count < 2 {
            let roll = rng.unit()
            let kind: NodeKind
            if roll < 0.5 { kind = .battle }
            else if roll < 0.68 { kind = floor >= 2 ? .elite : .battle }
            else if roll < 0.86 { kind = .rest }
            else { kind = .treasure }
            if !picks.contains(kind) { picks.append(kind) }
        }
        return picks
    }

    private mutating func finish(cleared: Bool) {
        let floors = cleared ? Run.floorCount : floor
        var exp = floors * 12 + elitesDefeated * 15
        if cleared { exp += 60 }
        // ボスを倒せば必ず、強敵を倒していれば確率で新しい仲間
        var recruited: String?
        let chance = cleared ? 1.0 : min(0.6, Double(elitesDefeated) * 0.3)
        if !recruitable.isEmpty, rng.chance(chance) {
            recruited = rng.pick(recruitable)
        }
        phase = .finished(RunResult(cleared: cleared, floorsCleared: floors, expEach: exp, recruited: recruited))
    }
}
