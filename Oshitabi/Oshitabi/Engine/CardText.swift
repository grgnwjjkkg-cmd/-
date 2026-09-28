import Foundation

/// カードの説明文。レベルや戦闘中の状態を反映した実際の数値で書く。
enum CardText {
    static func describe(_ card: CardDef, level: Int, battle: Battle? = nil) -> String {
        let chain = battle?.chainIfPlayed(card) ?? 0
        return card.effects.map { effect -> String in
            switch effect {
            case let .damage(base, hits):
                let value = battle?.hitDamage(base: base, owner: card.owner, chain: chain) ?? Scaling.scaled(base, level: level)
                return hits > 1 ? "\(value)ダメージ×\(hits)" : "\(value)ダメージ"
            case let .block(base): return "ガード\(Scaling.scaled(base, level: level))"
            case let .heal(base): return "HP\(Scaling.scaled(base, level: level))回復"
            case let .draw(n): return "\(n)枚引く"
            case let .energy(n): return "エナジー+\(n)"
            case let .strength(n): return "攻撃力+\(n)"
            case let .weak(n): return "弱体\(n)"
            case let .vulnerable(n): return "脆弱\(n)"
            case let .poison(base): return "毒\(Scaling.scaled(base, level: level))"
            case let .chainUp(n): return "連携+\(n)"
            }
        }.joined(separator: "\n")
    }

    static func intent(_ intent: Intent, battle: Battle) -> (icon: String, text: String) {
        switch intent {
        case let .attack(n): ("burst.fill", "\(battle.enemyHitDamage(n))")
        case let .multi(n, times): ("burst.fill", "\(battle.enemyHitDamage(n))×\(times)")
        case let .defend(n): ("shield.fill", "\(n)")
        case let .attackDefend(a, d): ("burst.fill", "\(battle.enemyHitDamage(a)) +守\(d)")
        case let .buff(n): ("arrow.up.circle.fill", "強化+\(n)")
        case .debuff: ("drop.fill", "弱体化")
        }
    }

    static let glossary: [(String, String)] = [
        ("連携", "違うキャラのカードを続けて使うと上がり、ダメージが1段ごとに+20%（最大+100%）。同じキャラが続くと0に戻る。"),
        ("ガード", "次の敵の攻撃を、その数だけ防ぐ。自分のターンが来ると消える。"),
        ("弱体", "与えるダメージが25%減る。ターンごとに1減る。"),
        ("脆弱", "受けるダメージが50%増える。ターンごとに1減る。"),
        ("毒", "敵のターンのはじめにその数だけダメージ。そのあと1減る。"),
    ]
}
