import Foundation

/// ゲームに登場するキャラ・カード・敵の一覧。
enum Catalog {
    static let characters: [CharacterDef] = [
        CharacterDef(
            id: "kai", name: "カイ", title: "旅の剣士", rarity: 3, color: "#F08A4B", color2: "#FFD8A8",
            baseHP: 26, hpPerLevel: 3,
            starterDeck: ["kai_slash", "kai_slash", "kai_guard", "kai_rush"],
            rewardPool: ["kai_whirl", "kai_second", "kai_brave"],
            profile: "まっすぐで世話焼きな剣士。困っている人を見ると放っておけない。",
            lines: ["今日も一緒に行こうか", "鍛えた分だけ強くなれる。お前もな", "無理はするなよ。…俺もしないから", "腹、減ってないか？", "次はどこへ行く？"]
        ),
        CharacterDef(
            id: "sena", name: "セナ", title: "氷の魔法剣士", rarity: 4, color: "#6FA8FF", color2: "#D6E8FF",
            baseHP: 22, hpPerLevel: 2,
            starterDeck: ["sena_frost", "sena_frost", "sena_barrier", "sena_lance"],
            rewardPool: ["sena_blizzard", "sena_focus", "sena_mirror"],
            profile: "無口でクールな魔法剣士。実は甘いものに目がない。",
            lines: ["……何か用？", "別に、待ってたわけじゃない", "寒くない？ 私の近くは冷えるから", "甘いもの、持ってない？", "あなたといると、少しだけ静かになれる"]
        ),
        CharacterDef(
            id: "mio", name: "ミオ", title: "旅の踊り子", rarity: 5, color: "#FF7AB6", color2: "#FFD6EA",
            baseHP: 20, hpPerLevel: 2,
            starterDeck: ["mio_step", "mio_step", "mio_heal", "mio_kick"],
            rewardPool: ["mio_encore", "mio_finale", "mio_blessing"],
            profile: "どこでも踊り出すムードメーカー。仲間の連携を盛り上げる。",
            lines: ["見て見て！ 新しいステップ！", "元気ないの？ 一緒に踊ろ！", "あなたが見てくれると、もっと上手に踊れるの", "ねえ、次のステージはどこ？", "えへへ、今日も会えたね"]
        ),
        CharacterDef(
            id: "gald", name: "ガルド", title: "鍛冶師", rarity: 3, color: "#8BC47A", color2: "#DDF0D2",
            baseHP: 32, hpPerLevel: 4,
            starterDeck: ["gald_hammer", "gald_shield", "gald_shield", "gald_temper"],
            rewardPool: ["gald_fortress", "gald_anvil", "gald_repair"],
            profile: "頑固だが腕は確かな鍛冶師。仲間の盾になるのが誇り。",
            lines: ["おう、来たか", "道具は手入れが命だ。体もな", "後ろは任せろ", "ガハハ！ 今日もいい火が入ってる", "無茶する前に俺を呼べ"]
        ),
        CharacterDef(
            id: "rin", name: "リン", title: "影の斥候", rarity: 4, color: "#7C8AA0", color2: "#D5DCE6",
            baseHP: 21, hpPerLevel: 2,
            starterDeck: ["rin_dagger", "rin_poison", "rin_poison", "rin_dodge"],
            rewardPool: ["rin_venom", "rin_flurry", "rin_shadow"],
            profile: "フードで顔を隠した斥候。毒と素早さで敵を追い詰める。",
            lines: ["……気づいてたの？", "影の中なら、どこへでも行ける", "油断しないで。見られてる", "フードは取らない。…今はまだ", "あなたの背中は、私が見てる"]
        ),
        CharacterDef(
            id: "leo", name: "レオ", title: "拳闘士", rarity: 4, color: "#FF8A5B", color2: "#FFDCCB",
            baseHP: 24, hpPerLevel: 3,
            starterDeck: ["leo_jab", "leo_jab", "leo_straight", "leo_guard"],
            rewardPool: ["leo_combo", "leo_upper", "leo_spirit"],
            profile: "拳ひとつで旅をする格闘家。連携がつながるほど燃える。",
            lines: ["よっしゃ、今日も一発いくか！", "つなげてつなげて、最後に決める！", "拳は嘘をつかないぜ", "トレーニング付き合えよ", "お前の応援、ちゃんと届いてる"]
        ),
    ]

    static let cards: [CardDef] = [
        // カイ：バランス型の剣士
        CardDef("kai_slash", "斬りつけ", owner: "kai", cost: 1, .attack, [.damage(6)]),
        CardDef("kai_guard", "受け流し", owner: "kai", cost: 1, .skill, [.block(5)]),
        CardDef("kai_rush", "突進", owner: "kai", cost: 2, .attack, [.damage(12)]),
        CardDef("kai_whirl", "旋風斬り", owner: "kai", cost: 2, .attack, [.damage(5, hits: 3)], rare: true),
        CardDef("kai_second", "二の太刀", owner: "kai", cost: 0, .attack, [.damage(4), .chainUp(1)], rare: true),
        CardDef("kai_brave", "勇気", owner: "kai", cost: 1, .skill, [.strength(2)], rare: true),
        // セナ：氷で弱らせる
        CardDef("sena_frost", "氷刃", owner: "sena", cost: 1, .attack, [.damage(5), .weak(1)]),
        CardDef("sena_barrier", "氷壁", owner: "sena", cost: 1, .skill, [.block(7)]),
        CardDef("sena_lance", "氷槍", owner: "sena", cost: 2, .attack, [.damage(10), .vulnerable(2)]),
        CardDef("sena_blizzard", "吹雪", owner: "sena", cost: 2, .attack, [.damage(4, hits: 3), .weak(2)], rare: true),
        CardDef("sena_focus", "集中", owner: "sena", cost: 0, .skill, [.draw(2)], rare: true),
        CardDef("sena_mirror", "氷の鏡", owner: "sena", cost: 1, .skill, [.block(11)], rare: true),
        // ミオ：回復とドロー、連携を盛り上げる
        CardDef("mio_step", "ステップ", owner: "mio", cost: 0, .skill, [.draw(1), .chainUp(1)]),
        CardDef("mio_heal", "癒しの舞", owner: "mio", cost: 1, .skill, [.heal(5)]),
        CardDef("mio_kick", "回し蹴り", owner: "mio", cost: 1, .attack, [.damage(5)]),
        CardDef("mio_encore", "アンコール", owner: "mio", cost: 1, .skill, [.energy(2)], rare: true),
        CardDef("mio_finale", "フィナーレ", owner: "mio", cost: 2, .attack, [.damage(8), .chainUp(2)], rare: true),
        CardDef("mio_blessing", "祝福の舞", owner: "mio", cost: 2, .skill, [.heal(9), .block(5)], rare: true),
        // ガルド：守りの要
        CardDef("gald_hammer", "鉄槌", owner: "gald", cost: 2, .attack, [.damage(11)]),
        CardDef("gald_shield", "盾打ち", owner: "gald", cost: 1, .skill, [.block(8)]),
        CardDef("gald_temper", "焼き入れ", owner: "gald", cost: 1, .skill, [.block(4), .strength(1)]),
        CardDef("gald_fortress", "鉄壁", owner: "gald", cost: 2, .skill, [.block(16)], rare: true),
        CardDef("gald_anvil", "金床落とし", owner: "gald", cost: 3, .attack, [.damage(26)], rare: true),
        CardDef("gald_repair", "応急修理", owner: "gald", cost: 1, .skill, [.heal(6), .block(4)], rare: true),
        // リン：毒と手数
        CardDef("rin_dagger", "投げナイフ", owner: "rin", cost: 1, .attack, [.damage(3, hits: 2)]),
        CardDef("rin_poison", "毒刃", owner: "rin", cost: 1, .attack, [.damage(3), .poison(4)]),
        CardDef("rin_dodge", "身かわし", owner: "rin", cost: 1, .skill, [.block(5), .draw(1)]),
        CardDef("rin_venom", "猛毒", owner: "rin", cost: 1, .skill, [.poison(9)], rare: true),
        CardDef("rin_flurry", "乱れ投げ", owner: "rin", cost: 2, .attack, [.damage(2, hits: 6)], rare: true),
        CardDef("rin_shadow", "影縫い", owner: "rin", cost: 1, .skill, [.weak(2), .vulnerable(2)], rare: true),
        // レオ：連携でつなぐ
        CardDef("leo_jab", "ジャブ", owner: "leo", cost: 0, .attack, [.damage(3)]),
        CardDef("leo_straight", "ストレート", owner: "leo", cost: 1, .attack, [.damage(7)]),
        CardDef("leo_guard", "ガード", owner: "leo", cost: 1, .skill, [.block(6)]),
        CardDef("leo_combo", "連打", owner: "leo", cost: 1, .attack, [.damage(2, hits: 4)], rare: true),
        CardDef("leo_upper", "アッパー", owner: "leo", cost: 2, .attack, [.damage(9), .vulnerable(2)], rare: true),
        CardDef("leo_spirit", "気合", owner: "leo", cost: 1, .skill, [.strength(2), .chainUp(1)], rare: true),
    ]

    static let enemies: [EnemyDef] = [
        EnemyDef(id: "minion", name: "影の見習い", tier: .normal, hp: 26,
                 intents: [.attack(6), .attack(7), .defend(5)], sprite: "e_minion"),
        EnemyDef(id: "scout", name: "影の斥候", tier: .normal, hp: 22,
                 intents: [.multi(3, times: 2), .debuff(weak: 1), .attack(8)], sprite: "e_scout"),
        EnemyDef(id: "dancer", name: "影の踊り子", tier: .normal, hp: 30,
                 intents: [.buff(2), .attack(6), .attackDefend(5, 5)], sprite: "e_dancer"),
        EnemyDef(id: "smith", name: "影の鍛冶師", tier: .elite, hp: 58,
                 intents: [.defend(10), .attack(14), .attackDefend(8, 6)], sprite: "e_smith"),
        EnemyDef(id: "blade", name: "影の剣豪", tier: .elite, hp: 52,
                 intents: [.multi(5, times: 3), .buff(3), .attack(12)], sprite: "e_blade"),
        EnemyDef(id: "king", name: "影の王", tier: .boss, hp: 115,
                 intents: [.attack(10), .multi(4, times: 4), .attackDefend(8, 12), .buff(3), .attack(20)], sprite: "e_king"),
    ]

    private static let characterIndex = Dictionary(uniqueKeysWithValues: characters.map { ($0.id, $0) })
    private static let cardIndex = Dictionary(uniqueKeysWithValues: cards.map { ($0.id, $0) })
    private static let enemyIndex = Dictionary(uniqueKeysWithValues: enemies.map { ($0.id, $0) })

    static func character(_ id: String) -> CharacterDef? { characterIndex[id] }
    static func card(_ id: String) -> CardDef? { cardIndex[id] }
    static func enemy(_ id: String) -> EnemyDef? { enemyIndex[id] }

    static func enemies(_ tier: EnemyTier) -> [EnemyDef] { enemies.filter { $0.tier == tier } }

    /// 最初から仲間にいるキャラ
    static let starters = ["kai", "sena", "mio"]
}
