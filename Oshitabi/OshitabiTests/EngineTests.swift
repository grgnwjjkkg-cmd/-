import XCTest
@testable import Oshitabi

final class EngineTests: XCTestCase {
    func testCatalogIsConsistent() {
        for character in Catalog.characters {
            for id in character.starterDeck + character.rewardPool {
                let card = Catalog.card(id)
                XCTAssertNotNil(card, "カードがない: \(id)")
                XCTAssertEqual(card?.owner, character.id, "持ち主が違う: \(id)")
            }
            XCTAssertEqual(character.starterDeck.count, 4)
            XCTAssertFalse(character.lines.isEmpty)
        }
        for id in Catalog.starters { XCTAssertNotNil(Catalog.character(id)) }
        XCTAssertFalse(Catalog.enemies(.boss).isEmpty)
        XCTAssertFalse(Catalog.enemies(.elite).isEmpty)
    }

    func testLevelUp() {
        var p = CharacterProgress()
        let ups = p.gain(CharacterProgress.expToNext(1) + 5)
        XCTAssertEqual(ups, 1)
        XCTAssertEqual(p.level, 2)
        XCTAssertEqual(p.exp, 5)
        p.gain(100_000)
        XCTAssertEqual(p.level, CharacterProgress.maxLevel)
        XCTAssertEqual(p.awakening, 2)
    }

    func testIdleGrowthIsCapped() {
        let start = Date(timeIntervalSince1970: 0)
        XCTAssertEqual(IdleGrowth.pendingExp(since: start, now: start.addingTimeInterval(90 * 60)), 90)
        XCTAssertEqual(IdleGrowth.pendingExp(since: start, now: start.addingTimeInterval(48 * 3600)), Int(IdleGrowth.capMinutes))
        XCTAssertEqual(IdleGrowth.pendingExp(since: start, now: start.addingTimeInterval(-60)), 0)
    }

    private func makeBattle(enemy: String = "minion", deck: [String]) -> Battle {
        Battle(enemy: Catalog.enemy(enemy)!, floor: 0, deck: deck, playerHP: 60, playerMaxHP: 60,
               levels: ["kai": 1, "sena": 1, "mio": 1], rng: SeededRNG(seed: 1))
    }

    func testChainBoostsDamage() {
        var battle = makeBattle(deck: ["kai_slash", "sena_frost", "kai_slash", "mio_kick", "kai_guard"])
        let kai = battle.hand.first { $0.defID == "kai_slash" }!
        let sena = battle.hand.first { $0.defID == "sena_frost" }!
        battle.play(kai)
        XCTAssertEqual(battle.chain, 0)
        let hpBefore = battle.enemyHP
        battle.play(sena)
        XCTAssertEqual(battle.chain, 1)
        // 氷刃 5 × 1.2 = 6
        XCTAssertEqual(hpBefore - battle.enemyHP, 6)
    }

    func testSameOwnerResetsChain() {
        var battle = makeBattle(deck: ["kai_slash", "kai_slash", "sena_frost", "kai_guard", "mio_kick"])
        let sena = battle.hand.first { $0.defID == "sena_frost" }!
        battle.play(sena)
        let kai = battle.hand.first { $0.defID == "kai_slash" }!
        battle.play(kai)
        XCTAssertEqual(battle.chain, 1)
        let kai2 = battle.hand.first { $0.defID == "kai_slash" }!
        battle.play(kai2)
        XCTAssertEqual(battle.chain, 0)
    }

    func testBlockAbsorbsEnemyAttack() {
        var battle = makeBattle(deck: ["kai_guard", "kai_guard", "kai_guard", "kai_guard", "kai_guard"])
        battle.play(battle.hand[0])
        let hp = battle.playerHP
        battle.endTurn() // 見習いの攻撃6、ガード5
        XCTAssertEqual(hp - battle.playerHP, 1)
        XCTAssertEqual(battle.playerBlock, 0)
        XCTAssertEqual(battle.energy, Battle.maxEnergy)
        XCTAssertEqual(battle.hand.count, Battle.handSize)
    }

    func testPoisonTicksAndDecays() {
        var battle = makeBattle(deck: ["rin_venom", "kai_guard", "kai_guard", "kai_guard", "kai_guard"])
        let venom = battle.hand.first { $0.defID == "rin_venom" }!
        battle.play(venom)
        XCTAssertEqual(battle.enemyPoison, 9)
        let hp = battle.enemyHP
        battle.endTurn()
        XCTAssertEqual(hp - battle.enemyHP, 9)
        XCTAssertEqual(battle.enemyPoison, 8)
    }

    func testCannotPlayWithoutEnergy() {
        var battle = makeBattle(deck: ["kai_rush", "kai_rush", "kai_rush", "kai_rush", "kai_rush"])
        battle.play(battle.hand[0])
        battle.play(battle.hand[0])
        XCTAssertEqual(battle.energy, 1)
        XCTAssertEqual(battle.hand.count, 4)
        XCTAssertFalse(battle.canPlay(battle.hand[0]))
    }

    /// 単純な操作で最後まで遊んだときの勝利数
    private func simulate(level: Int, runs: Int) -> Int {
        var wins = 0
        for seed in 1...runs {
            let levels = Dictionary(uniqueKeysWithValues: Catalog.starters.map { ($0, level) })
            var run = Run(party: Catalog.starters, levels: levels, recruitable: ["gald", "rin", "leo"], seed: UInt64(seed))
            var steps = 0
            loop: while steps < 3000 {
                steps += 1
                switch run.phase {
                case .choosing:
                    run.choose(run.choices.contains(.rest) && run.hp < run.maxHP / 2 ? .rest : run.choices[0])
                case var .battle(battle):
                    if let card = battle.hand.first(where: { battle.canPlay($0) }) {
                        battle.play(card)
                    } else {
                        battle.endTurn()
                    }
                    run.updateBattle(battle)
                case let .reward(cards, _):
                    run.takeReward(cards.first)
                case let .finished(result):
                    if result.cleared { wins += 1 }
                    XCTAssertGreaterThan(result.expEach, 0)
                    break loop
                }
            }
            XCTAssertLessThan(steps, 3000, "冒険が終わらない seed=\(seed)")
        }
        return wins
    }

    func testDifficultyCurve() {
        // Lv1 ではボスが壁、育てれば勝てる
        XCTAssertLessThan(simulate(level: 1, runs: 40), 5)
        XCTAssertGreaterThan(simulate(level: 10, runs: 40), 30)
    }

    func testSaveDataRoundTrip() throws {
        var run = Run(party: Catalog.starters, levels: [:], recruitable: [], seed: 7)
        run.choose(.battle)
        let data = try JSONEncoder().encode(run)
        let decoded = try JSONDecoder().decode(Run.self, from: data)
        XCTAssertEqual(decoded, run)
    }
}
