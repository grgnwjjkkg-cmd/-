import Foundation

/// 手札・山札の1枚（同じカードが複数あっても区別できるよう番号を持つ）
struct CardInstance: Codable, Hashable, Identifiable {
    let id: Int
    let defID: String

    var def: CardDef { Catalog.card(defID)! }
}

/// 画面の演出に使う出来事
enum BattleEvent: Hashable {
    case played(owner: String, cardName: String)
    case enemyHit(damage: Int, blocked: Int)
    case playerHit(damage: Int, blocked: Int)
    case playerBlock(Int)
    case enemyBlock(Int)
    case heal(Int)
    case poisonTick(Int)
    case status(String)
    case chain(Int)
    case enemyDefeated
    case playerDefeated
}

enum BattleOutcome: String, Codable {
    case ongoing, won, lost
}

/// 1回の戦闘。画面から play / endTurn を呼んで進める。
struct Battle: Codable, Hashable {
    static let handSize = 5
    static let maxEnergy = 3
    static let maxChain = 5

    let enemyID: String
    var enemyHP: Int
    let enemyMaxHP: Int
    var enemyBlock = 0
    var enemyStrength: Int
    var enemyWeak = 0
    var enemyVulnerable = 0
    var enemyPoison = 0
    var intentIndex = 0

    var playerHP: Int
    let playerMaxHP: Int
    var playerBlock = 0
    var playerStrength = 0
    var playerWeak = 0

    var energy = Battle.maxEnergy
    var drawPile: [CardInstance]
    var hand: [CardInstance] = []
    var discard: [CardInstance] = []

    /// 連携：違うキャラのカードを続けて使うと上がる。同じキャラが続くと0に戻る
    var chain = 0
    var lastOwner: String?
    var turn = 1

    /// キャラごとのレベル（カードの強さに反映）
    let levels: [String: Int]
    var rng: SeededRNG
    var outcome: BattleOutcome = .ongoing

    var enemy: EnemyDef { Catalog.enemy(enemyID)! }
    var intent: Intent { enemy.intents[intentIndex % enemy.intents.count] }

    init(enemy: EnemyDef, floor: Int, deck: [String], playerHP: Int, playerMaxHP: Int, levels: [String: Int], rng: SeededRNG) {
        enemyID = enemy.id
        let hp = Int((Double(enemy.hp) * (1 + 0.1 * Double(floor))).rounded())
        enemyHP = hp
        enemyMaxHP = hp
        enemyStrength = floor / 2
        self.playerHP = playerHP
        self.playerMaxHP = playerMaxHP
        self.levels = levels
        self.rng = rng
        var pile = deck.enumerated().map { CardInstance(id: $0.offset, defID: $0.element) }
        self.rng.shuffle(&pile)
        drawPile = pile
        draw(Battle.handSize)
    }

    // MARK: 表示用の計算

    var chainMultiplier: Double { 1 + 0.2 * Double(min(chain, Battle.maxChain)) }

    /// 次にこのカードを使ったときの連携段階
    func chainIfPlayed(_ card: CardDef) -> Int {
        guard let lastOwner else { return 0 }
        return lastOwner == card.owner ? 0 : min(chain + 1, Battle.maxChain)
    }

    func level(of owner: String) -> Int { levels[owner] ?? 1 }

    /// 1ヒットあたりのダメージ（敵のブロック前）
    func hitDamage(base: Int, owner: String, chain: Int) -> Int {
        var value = Double(Scaling.scaled(base, level: level(of: owner)) + playerStrength)
        value *= 1 + 0.2 * Double(chain)
        if playerWeak > 0 { value *= 0.75 }
        if enemyVulnerable > 0 { value *= 1.5 }
        return max(0, Int(value))
    }

    /// 敵の次の攻撃1ヒットぶん（プレイヤーのブロック前）
    func enemyHitDamage(_ base: Int) -> Int {
        var value = Double(base + enemyStrength)
        if enemyWeak > 0 { value *= 0.75 }
        return max(0, Int(value))
    }

    func canPlay(_ card: CardInstance) -> Bool {
        outcome == .ongoing && card.def.cost <= energy && hand.contains(card)
    }

    // MARK: 行動

    @discardableResult
    mutating func play(_ card: CardInstance) -> [BattleEvent] {
        guard canPlay(card), let index = hand.firstIndex(of: card) else { return [] }
        let def = card.def
        var events: [BattleEvent] = [.played(owner: def.owner, cardName: def.name)]
        energy -= def.cost
        hand.remove(at: index)

        chain = chainIfPlayed(def)
        lastOwner = def.owner
        if chain > 0 { events.append(.chain(chain)) }

        let lv = level(of: def.owner)
        for effect in def.effects {
            switch effect {
            case let .damage(base, hits):
                for _ in 0..<hits where enemyHP > 0 {
                    events.append(hitEnemy(hitDamage(base: base, owner: def.owner, chain: chain)))
                }
            case let .block(base):
                let amount = Scaling.scaled(base, level: lv)
                playerBlock += amount
                events.append(.playerBlock(amount))
            case let .heal(base):
                let amount = min(Scaling.scaled(base, level: lv), playerMaxHP - playerHP)
                playerHP += amount
                events.append(.heal(amount))
            case let .draw(n):
                draw(n)
            case let .energy(n):
                energy += n
            case let .strength(n):
                playerStrength += n
                events.append(.status("攻撃力 +\(n)"))
            case let .weak(n):
                enemyWeak += n
                events.append(.status("弱体 \(n)"))
            case let .vulnerable(n):
                enemyVulnerable += n
                events.append(.status("脆弱 \(n)"))
            case let .poison(base):
                let amount = Scaling.scaled(base, level: lv)
                enemyPoison += amount
                events.append(.status("毒 +\(amount)"))
            case let .chainUp(n):
                chain = min(chain + n, Battle.maxChain)
                events.append(.chain(chain))
            }
        }
        discard.append(card)
        if enemyHP <= 0 {
            outcome = .won
            events.append(.enemyDefeated)
        }
        return events
    }

    @discardableResult
    mutating func endTurn() -> [BattleEvent] {
        guard outcome == .ongoing else { return [] }
        var events: [BattleEvent] = []
        discard += hand
        hand = []
        if playerWeak > 0 { playerWeak -= 1 }

        // 敵のターン
        if enemyPoison > 0 {
            enemyHP -= enemyPoison
            events.append(.poisonTick(enemyPoison))
            enemyPoison -= 1
            if enemyHP <= 0 {
                enemyHP = 0
                outcome = .won
                return events + [.enemyDefeated]
            }
        }
        enemyBlock = 0
        switch intent {
        case let .attack(n):
            events.append(hitPlayer(enemyHitDamage(n)))
        case let .multi(n, times):
            for _ in 0..<times where playerHP > 0 { events.append(hitPlayer(enemyHitDamage(n))) }
        case let .defend(n):
            enemyBlock += n
            events.append(.enemyBlock(n))
        case let .attackDefend(a, d):
            events.append(hitPlayer(enemyHitDamage(a)))
            enemyBlock += d
            events.append(.enemyBlock(d))
        case let .buff(n):
            enemyStrength += n
            events.append(.status("敵の攻撃力 +\(n)"))
        case let .debuff(weak):
            playerWeak += weak
            events.append(.status("弱体にされた"))
        }
        if enemyWeak > 0 { enemyWeak -= 1 }
        if enemyVulnerable > 0 { enemyVulnerable -= 1 }
        intentIndex += 1

        if playerHP <= 0 {
            playerHP = 0
            outcome = .lost
            return events + [.playerDefeated]
        }

        // 自分のターン開始
        turn += 1
        playerBlock = 0
        energy = Battle.maxEnergy
        chain = 0
        lastOwner = nil
        draw(Battle.handSize)
        return events
    }

    // MARK: 内部

    private mutating func hitEnemy(_ damage: Int) -> BattleEvent {
        let blocked = min(enemyBlock, damage)
        enemyBlock -= blocked
        enemyHP = max(0, enemyHP - (damage - blocked))
        return .enemyHit(damage: damage - blocked, blocked: blocked)
    }

    private mutating func hitPlayer(_ damage: Int) -> BattleEvent {
        let blocked = min(playerBlock, damage)
        playerBlock -= blocked
        playerHP = max(0, playerHP - (damage - blocked))
        return .playerHit(damage: damage - blocked, blocked: blocked)
    }

    mutating func draw(_ n: Int) {
        for _ in 0..<n {
            if drawPile.isEmpty {
                guard !discard.isEmpty else { return }
                drawPile = discard
                discard = []
                rng.shuffle(&drawPile)
            }
            hand.append(drawPile.removeLast())
        }
    }
}
