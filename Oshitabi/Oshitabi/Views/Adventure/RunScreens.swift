import SwiftUI

extension NodeKind {
    var icon: String {
        switch self {
        case .battle: "figure.fencing"
        case .elite: "flame.fill"
        case .rest: "bed.double.fill"
        case .treasure: "gift.fill"
        case .boss: "crown.fill"
        }
    }

    var color: Color {
        switch self {
        case .battle: Color(hex: "#FF6A8A")
        case .elite: Color(hex: "#FFA24A")
        case .rest: Color(hex: "#6FE3A8")
        case .treasure: Color(hex: "#FFD36B")
        case .boss: Color(hex: "#C45CFF")
        }
    }
}

/// 冒険中の上部：階の進み具合・HP・デッキ枚数
struct RunHeader: View {
    let run: Run

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 6) {
                ForEach(0..<Run.floorCount, id: \.self) { i in
                    Capsule()
                        .fill(i < run.floor ? Palette.gold : i == run.floor ? .white : .white.opacity(0.2))
                        .frame(height: 6)
                }
            }
            HStack {
                Text("\(run.floor + 1)階 / \(Run.floorCount)").font(.subheadline.weight(.heavy).monospacedDigit())
                Spacer()
                Label("\(run.deck.count)", systemImage: "rectangle.stack.fill").font(.caption.weight(.bold))
            }
            HStack(spacing: 8) {
                Image(systemName: "heart.fill").foregroundStyle(Palette.hp)
                MeterBar(value: Double(run.hp) / Double(run.maxHP), color: Palette.hp, height: 10)
                Text("\(run.hp)/\(run.maxHP)").font(.caption.weight(.bold).monospacedDigit())
            }
        }
    }
}

struct MapView: View {
    @Environment(GameStore.self) private var store
    let run: Run
    @State private var confirmQuit = false

    var body: some View {
        ZStack {
            GameBackground(color: Color(hex: "#5A4ACF"))
            VStack(spacing: 18) {
                RunHeader(run: run)
                HStack(spacing: -10) {
                    ForEach(run.party, id: \.self) { id in
                        SpriteImage(id: id, name: "idle_00").frame(height: 150)
                    }
                }
                Text(run.isBossFloor ? "最後の階。影の王が待っている" : "どちらへ進む？")
                    .font(.title3.weight(.heavy))
                VStack(spacing: 12) {
                    ForEach(run.choices, id: \.self) { kind in
                        Button {
                            var next = run
                            next.choose(kind)
                            withAnimation(.easeInOut(duration: 0.3)) { store.updateRun(next) }
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: kind.icon)
                                    .font(.title2)
                                    .frame(width: 54, height: 54)
                                    .background(Circle().fill(kind.color.opacity(0.25)))
                                    .foregroundStyle(kind.color)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(kind.label).font(.headline.weight(.heavy))
                                    Text(kind.detail).font(.caption).foregroundStyle(.white.opacity(0.7))
                                }
                                Spacer()
                                Image(systemName: "chevron.right").foregroundStyle(.secondary)
                            }
                            .padding(14)
                            .background(RoundedRectangle(cornerRadius: 18).fill(Palette.panel))
                            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(kind.color.opacity(0.6), lineWidth: 1.5))
                        }
                        .foregroundStyle(.white)
                    }
                }
                Spacer()
                Button("冒険をやめる") { confirmQuit = true }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
        .alert("冒険をやめますか？", isPresented: $confirmQuit) {
            Button("やめる", role: .destructive) { store.abandonRun() }
            Button("続ける", role: .cancel) {}
        } message: {
            Text("ここまで進んだ階のぶんの経験値はもらえます。")
        }
    }
}

struct RewardView: View {
    @Environment(GameStore.self) private var store
    let run: Run
    let cards: [String]
    let fromElite: Bool
    @State private var selected: String?

    var body: some View {
        ZStack {
            GameBackground(color: Palette.gold)
            VStack(spacing: 18) {
                RunHeader(run: run)
                Text(fromElite ? "強敵を倒した！" : "報酬").font(.title.weight(.black)).foregroundStyle(Palette.gold)
                Text("デッキに加えるカードを1枚えらぶ").font(.subheadline).foregroundStyle(.white.opacity(0.75))
                HStack(spacing: 10) {
                    ForEach(cards, id: \.self) { id in
                        let card = Catalog.card(id)!
                        Button {
                            withAnimation(.spring(duration: 0.3)) { selected = id }
                        } label: {
                            CardView(card: card, level: run.levels[card.owner] ?? 1, width: 104)
                                .scaleEffect(selected == id ? 1.08 : 1)
                                .shadow(color: selected == id ? Palette.gold.opacity(0.8) : .clear, radius: 12)
                        }
                    }
                }
                .sensoryFeedback(.selection, trigger: selected)
                if let selected, let card = Catalog.card(selected), let owner = Catalog.character(card.owner) {
                    Text("\(owner.name)のカード「\(card.name)」").font(.footnote.weight(.bold))
                }
                Spacer()
                Button("デッキに加える") { take(selected) }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(selected == nil)
                    .opacity(selected == nil ? 0.5 : 1)
                Button("何ももらわない") { take(nil) }
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
        }
    }

    private func take(_ card: String?) {
        var next = run
        next.takeReward(card)
        withAnimation { store.updateRun(next) }
    }
}

struct ResultView: View {
    let run: Run
    let result: RunResult
    let onCollect: () -> Void

    var body: some View {
        ZStack {
            GameBackground(color: result.cleared ? Palette.gold : Color(hex: "#5A5A7A"))
            VStack(spacing: 16) {
                Spacer()
                Text(result.cleared ? "影の王を倒した！" : "力尽きた…")
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(result.cleared ? Palette.gold : .white)
                Text("\(result.floorsCleared)階まで到達").font(.headline)
                HStack(spacing: -16) {
                    ForEach(run.party, id: \.self) { id in
                        SpriteImage(id: id, name: result.cleared ? "attack" : "idle_00").frame(height: 190)
                    }
                }
                Text("全員に +\(result.expEach) EXP").font(.title3.weight(.heavy)).foregroundStyle(Palette.exp)
                if result.recruited != nil {
                    Label("新しい仲間の気配が…！", systemImage: "sparkles")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(Color(hex: "#FF8AE2"))
                }
                Spacer()
                Button("受け取る", action: onCollect)
                    .buttonStyle(PrimaryButtonStyle(color: Palette.exp))
            }
            .padding(20)
        }
    }
}

struct RunSummary: Equatable {
    let result: RunResult
    let reports: [GrowthReport]
}

/// 結果を受け取ったあと：レベルアップと新しい仲間
struct RunSummaryOverlay: View {
    let summary: RunSummary
    let onClose: () -> Void
    @State private var appear = false

    var body: some View {
        ZStack {
            Color.black.opacity(0.75).ignoresSafeArea()
            VStack(spacing: 16) {
                if let id = summary.result.recruited, let def = Catalog.character(id) {
                    Text("新しい仲間！").font(.title.weight(.black)).foregroundStyle(Color(hex: "#FF8AE2"))
                    AnimatedSprite(id: id)
                        .frame(height: 280)
                        .scaleEffect(appear ? 1 : 0.6)
                        .opacity(appear ? 1 : 0)
                    Stars(count: def.rarity, size: 14)
                    Text("\(def.name)（\(def.title)）が仲間になった").font(.headline.weight(.heavy))
                } else {
                    Text("冒険の成果").font(.title.weight(.black)).foregroundStyle(Palette.gold)
                }
                VStack(spacing: 8) {
                    ForEach(summary.reports) { r in
                        HStack {
                            FaceIcon(id: r.character, size: 40)
                            Text(Catalog.character(r.character)?.name ?? "").font(.subheadline.weight(.bold))
                            Spacer()
                            Text(r.levelsGained > 0 ? "Lv.\(r.newLevel - r.levelsGained) → \(r.newLevel)" : "Lv.\(r.newLevel)")
                                .font(.subheadline.weight(.heavy).monospacedDigit())
                                .foregroundStyle(r.levelsGained > 0 ? Palette.gold : .white)
                        }
                    }
                }
                .padding(14)
                .background(RoundedRectangle(cornerRadius: 18).fill(Palette.panel))
                Button("OK", action: onClose)
                    .buttonStyle(PrimaryButtonStyle())
            }
            .padding(24)
        }
        .onAppear { withAnimation(.spring(duration: 0.7, bounce: 0.45).delay(0.2)) { appear = true } }
        .sensoryFeedback(.success, trigger: appear)
    }
}
