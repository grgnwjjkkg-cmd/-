import SwiftUI

/// 冒険タブ：パーティを選んで出発 → 道を選ぶ → 戦闘 → 報酬 … → 結果
struct AdventureView: View {
    @Environment(GameStore.self) private var store
    @State private var party: [String] = []
    @State private var summary: RunSummary?

    var body: some View {
        ZStack {
            if let run = store.run {
                RunView(run: run) { result in collect(result) }
            } else {
                startScreen
            }
            if let summary {
                RunSummaryOverlay(summary: summary) { withAnimation { self.summary = nil } }
                    .transition(.opacity)
            }
        }
        .onAppear { if party.isEmpty { party = defaultParty() } }
    }

    private func collect(_ result: RunResult) {
        let reports = store.collectRunResult()
        withAnimation { summary = RunSummary(result: result, reports: reports) }
        party = defaultParty()
    }

    private func defaultParty() -> [String] {
        let others = store.ownedCharacters.map(\.id).filter { $0 != store.oshiID }
        return Array(([store.oshiID] + others).prefix(3))
    }

    private var startScreen: some View {
        ZStack {
            GameBackground(color: Color(hex: "#7A5CFF"))
            ScrollView {
                VStack(spacing: 18) {
                    VStack(spacing: 6) {
                        Text("影の回廊").font(.largeTitle.weight(.black))
                        Text("全8階。最後の階に「影の王」が待っている。\n倒せば新しい仲間が加わります。")
                            .font(.footnote)
                            .foregroundStyle(.white.opacity(0.75))
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 20)

                    HStack(spacing: 10) {
                        stat("挑戦", "\(store.data.runsPlayed)回")
                        stat("最高到達", "\(store.data.bestFloor)階")
                        stat("王を撃破", "\(store.data.bossClears)回")
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("パーティ（3人）").font(.headline.weight(.heavy))
                        HStack(spacing: 10) {
                            ForEach(0..<3, id: \.self) { i in
                                if i < party.count {
                                    PartySlot(id: party[i], level: store.level(party[i]))
                                } else {
                                    RoundedRectangle(cornerRadius: 16).strokeBorder(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1.5, dash: [5]))
                                        .frame(height: 120)
                                        .overlay(Text("空き").font(.caption).foregroundStyle(.secondary))
                                }
                            }
                        }
                        Text("仲間をタップして入れ替え").font(.caption).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 60))], spacing: 10) {
                            ForEach(store.ownedCharacters) { def in
                                Button { toggle(def.id) } label: {
                                    FaceIcon(id: def.id, size: 54)
                                        .overlay(alignment: .bottomTrailing) {
                                            if party.contains(def.id) {
                                                Image(systemName: "checkmark.circle.fill").foregroundStyle(Palette.gold).background(Circle().fill(.black))
                                            }
                                        }
                                        .opacity(party.contains(def.id) ? 1 : 0.6)
                                }
                                .accessibilityLabel("\(def.name)\(party.contains(def.id) ? "、選択中" : "")")
                            }
                        }
                        .sensoryFeedback(.selection, trigger: party)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))

                    VStack(alignment: .leading, spacing: 6) {
                        Label("コツ：連携", systemImage: "link").font(.subheadline.weight(.heavy)).foregroundStyle(Palette.gold)
                        Text("違うキャラのカードを続けて使うと「連携」が上がり、ダメージが1段ごとに+20%。同じキャラが続くと途切れます。")
                            .font(.footnote).foregroundStyle(.white.opacity(0.8))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 18).fill(.white.opacity(0.06)))

                    Button("出発する") {
                        store.startRun(party: party)
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(party.count < min(3, store.ownedCharacters.count))
                    .padding(.bottom, 24)
                }
                .padding(.horizontal, 16)
            }
        }
    }

    private func toggle(_ id: String) {
        withAnimation(.spring(duration: 0.3)) {
            if let i = party.firstIndex(of: id) {
                party.remove(at: i)
            } else if party.count < 3 {
                party.append(id)
            } else {
                party[party.count - 1] = id
            }
        }
    }

    private func stat(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.weight(.heavy).monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.07)))
    }
}

struct PartySlot: View {
    let id: String
    let level: Int

    var body: some View {
        let def = Catalog.character(id)!
        VStack(spacing: 2) {
            SpriteImage(id: id, name: "idle_00")
                .frame(height: 90)
            Text(def.name).font(.caption.weight(.heavy))
            Text("Lv.\(level)").font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 16).fill(def.tint.opacity(0.25)))
        .overlay(RoundedRectangle(cornerRadius: 16).strokeBorder(def.tint.opacity(0.7), lineWidth: 1.5))
    }
}

/// 冒険中の画面の切り替え
struct RunView: View {
    @Environment(GameStore.self) private var store
    let run: Run
    let onCollect: (RunResult) -> Void

    var body: some View {
        switch run.phase {
        case .choosing:
            MapView(run: run)
        case let .battle(battle):
            BattleView(initial: battle, floor: run.floor, party: run.party) { updated in
                var next = run
                next.updateBattle(updated)
                store.updateRun(next)
            }
            .id("battle-\(run.floor)")
        case let .reward(cards, fromElite):
            RewardView(run: run, cards: cards, fromElite: fromElite)
        case let .finished(result):
            ResultView(run: run, result: result) { onCollect(result) }
        }
    }
}
