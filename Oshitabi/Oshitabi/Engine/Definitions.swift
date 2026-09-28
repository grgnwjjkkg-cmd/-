import Foundation

// MARK: - カード

/// カードの効果。数値はレベル補正前の基本値。
enum Effect: Codable, Hashable {
    case damage(Int, hits: Int = 1)
    case block(Int)
    case heal(Int)
    case draw(Int)
    case energy(Int)
    /// 攻撃力アップ（この戦闘中ずっと）
    case strength(Int)
    /// 敵を弱体（与ダメージ -25%）にするターン数
    case weak(Int)
    /// 敵を脆弱（被ダメージ +50%）にするターン数
    case vulnerable(Int)
    /// 毒：敵のターン開始時にその数だけダメージ、1ずつ減る
    case poison(Int)
    /// 連携を上げる
    case chainUp(Int)
}

enum CardKind: String, Codable {
    case attack, skill
}

struct CardDef: Identifiable, Hashable {
    let id: String
    let name: String
    let owner: String
    let cost: Int
    let kind: CardKind
    let effects: [Effect]
    /// 報酬でのみ出るカード
    let isRare: Bool

    init(_ id: String, _ name: String, owner: String, cost: Int, _ kind: CardKind, _ effects: [Effect], rare: Bool = false) {
        self.id = id
        self.name = name
        self.owner = owner
        self.cost = cost
        self.kind = kind
        self.effects = effects
        self.isRare = rare
    }
}

// MARK: - キャラ

struct CharacterDef: Identifiable, Hashable {
    let id: String
    let name: String
    let title: String
    /// レア度（★の数）
    let rarity: Int
    /// テーマ色（16進）
    let color: String
    let color2: String
    let baseHP: Int
    let hpPerLevel: Int
    let starterDeck: [String]
    let rewardPool: [String]
    let profile: String
    /// ホームでタップしたときのセリフ
    let lines: [String]
}

// MARK: - 敵

enum Intent: Codable, Hashable {
    case attack(Int)
    case multi(Int, times: Int)
    case defend(Int)
    case attackDefend(Int, Int)
    case buff(Int)
    case debuff(weak: Int)
}

enum EnemyTier: String, Codable {
    case normal, elite, boss
}

struct EnemyDef: Identifiable, Hashable {
    let id: String
    let name: String
    let tier: EnemyTier
    let hp: Int
    let intents: [Intent]
    let sprite: String
}
