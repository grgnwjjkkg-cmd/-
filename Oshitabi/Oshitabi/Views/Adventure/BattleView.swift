import SwiftUI

/// 画面に浮かぶ数字（ダメージ・回復など）
private struct FloatText: Identifiable {
    enum Place { case enemy, player }
    let id = UUID()
    let text: String
    let color: Color
    let place: Place
    let dx: CGFloat
}

struct BattleView: View {
    @State private var battle: Battle
    let floor: Int
    let partyIDs: [String]
    let onUpdate: (Battle) -> Void

    @State private var floats: [FloatText] = []
    @State private var enemyShake = 0
    @State private var playerShake = 0
    @State private var flashOwner: String?
    @State private var busy = false
    @State private var hint: String?
    @State private var showHelp = false
    @State private var hitCount = 0
    @State private var hurtCount = 0

    init(initial: Battle, floor: Int, party: [String], onUpdate: @escaping (Battle) -> Void) {
        _battle = State(initialValue: initial)
        self.floor = floor
        self.partyIDs = party
        self.onUpdate = onUpdate
    }

    var body: some View {
        let enemy = battle.enemy
        ZStack {
            GameBackground(color: enemy.tier == .boss ? Color(hex: "#C43C6A") : enemy.tier == .elite ? Color(hex: "#C47A3C") : Color(hex: "#5A4ACF"))
            VStack(spacing: 8) {
                topBar
                enemyZone(enemy)
                chainRow
                playerRow
                hand
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 6)

            if let flashOwner {
                AttackFlash(owner: flashOwner)
                    .transition(.asymmetric(insertion: .move(edge: .leading).combined(with: .opacity), removal: .opacity))
                    .allowsHitTesting(false)
            }
            if let hint {
                Text(hint)
                    .font(.subheadline.weight(.bold))
                    .padding(.horizontal, 16).padding(.vertical, 10)
                    .background(Capsule().fill(.black.opacity(0.8)))
                    .transition(.opacity)
            }
            if battle.outcome != .ongoing {
                Text(battle.outcome == .won ? "勝利！" : "敗北…")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .foregroundStyle(battle.outcome == .won ? Palette.gold : .white)
                    .shadow(color: .black, radius: 10)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .sensoryFeedback(.impact(weight: .medium), trigger: hitCount)
        .sensoryFeedback(.impact(weight: .heavy), trigger: hurtCount)
        .sheet(isPresented: $showHelp) { HelpSheet().presentationDetents([.medium, .large]) }
    }

    // MARK: 部品

    private var topBar: some View {
        HStack {
            Text("\(floor + 1)階").font(.subheadline.weight(.heavy))
            Text("ターン\(battle.turn)").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Spacer()
            Label("\(battle.drawPile.count)", systemImage: "rectangle.stack").font(.caption.weight(.bold))
            Label("\(battle.discard.count)", systemImage: "tray.full").font(.caption.weight(.bold)).foregroundStyle(.secondary)
            Button { showHelp = true } label: { Image(systemName: "questionmark.circle.fill").font(.title3) }
                .foregroundStyle(.white.opacity(0.8))
                .accessibilityLabel("ルール説明")
        }
    }

    private func enemyZone(_ enemy: EnemyDef) -> some View {
        let intent = CardText.intent(battle.intent, battle: battle)
        return ZStack(alignment: .top) {
            TimelineView(.animation) { context in
                let t = context.date.timeIntervalSinceReferenceDate
                SpriteImage(id: enemy.sprite, name: "idle")
                    .scaleEffect(1 + 0.015 * sin(t * 2.2), anchor: .bottom)
                    .scaleEffect(enemy.tier == .boss ? 1.12 : 1, anchor: .bottom)
            }
            .shadow(color: .black.opacity(0.5), radius: 20)
            .modifier(Shake(amount: 10, shakes: CGFloat(enemyShake)))
            .opacity(battle.enemyHP == 0 ? 0.2 : 1)
            .animation(.easeOut(duration: 0.35), value: enemyShake)

            VStack(spacing: 6) {
                HStack(spacing: 6) {
                    Image(systemName: intent.icon)
                    Text(intent.text).monospacedDigit()
                }
                .font(.subheadline.weight(.heavy))
                .padding(.horizontal, 12).padding(.vertical, 6)
                .background(Capsule().fill(.black.opacity(0.55)))
                .overlay(Capsule().strokeBorder(Palette.hp.opacity(0.8), lineWidth: 1.5))
                .accessibilityLabel("敵の次の行動 \(intent.text)")
                Spacer()
                Text(enemy.name).font(.headline.weight(.heavy))
                HStack(spacing: 8) {
                    MeterBar(value: Double(battle.enemyHP) / Double(battle.enemyMaxHP), color: Palette.hp, height: 12)
                    Text("\(battle.enemyHP)/\(battle.enemyMaxHP)").font(.caption.weight(.bold).monospacedDigit())
                    if battle.enemyBlock > 0 {
                        Label("\(battle.enemyBlock)", systemImage: "shield.fill").font(.caption.weight(.bold)).foregroundStyle(Palette.guardBlue)
                    }
                }
                .padding(.horizontal, 30)
                HStack(spacing: 6) {
                    if battle.enemyWeak > 0 { StatusChip(text: "弱体\(battle.enemyWeak)", color: Color(hex: "#9EA7FF")) }
                    if battle.enemyVulnerable > 0 { StatusChip(text: "脆弱\(battle.enemyVulnerable)", color: Color(hex: "#FF9E6B")) }
                    if battle.enemyPoison > 0 { StatusChip(text: "毒\(battle.enemyPoison)", color: Color(hex: "#8CF06B")) }
                    if battle.enemyStrength > 0 { StatusChip(text: "攻撃+\(battle.enemyStrength)", color: Palette.hp) }
                }
                .frame(height: 20)
            }

            ForEach(floats.filter { $0.place == .enemy }) { f in
                FloatingLabel(text: f.text, color: f.color).offset(x: f.dx, y: 90)
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var chainRow: some View {
        HStack(spacing: 8) {
            ForEach(partyIDs, id: \.self) { id in
                FaceIcon(id: id, size: battle.lastOwner == id ? 40 : 32)
                    .shadow(color: battle.lastOwner == id ? .white : .clear, radius: 6)
                    .animation(.spring(duration: 0.3), value: battle.lastOwner)
            }
            Spacer()
            HStack(spacing: 4) {
                Image(systemName: "link")
                Text(battle.chain > 0 ? "連携\(battle.chain)  ×\(String(format: "%.1f", battle.chainMultiplier))" : "連携なし")
                    .monospacedDigit()
            }
            .font(.subheadline.weight(.heavy))
            .foregroundStyle(battle.chain > 0 ? Palette.gold : .secondary)
            .scaleEffect(battle.chain > 0 ? 1.08 : 1)
            .animation(.spring(duration: 0.3, bounce: 0.6), value: battle.chain)
        }
    }

    private var playerRow: some View {
        ZStack {
            HStack(spacing: 10) {
                Text("\(battle.energy)/\(Battle.maxEnergy)")
                    .font(.headline.weight(.black).monospacedDigit())
                    .foregroundStyle(.black)
                    .frame(width: 50, height: 50)
                    .background(Circle().fill(Palette.energy.gradient))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .accessibilityLabel("エナジー \(battle.energy)")
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("パーティ").font(.caption.weight(.bold))
                        if battle.playerStrength > 0 { StatusChip(text: "攻撃+\(battle.playerStrength)", color: Palette.gold) }
                        if battle.playerWeak > 0 { StatusChip(text: "弱体\(battle.playerWeak)", color: Color(hex: "#9EA7FF")) }
                        Spacer()
                        if battle.playerBlock > 0 {
                            Label("\(battle.playerBlock)", systemImage: "shield.fill").font(.caption.weight(.heavy)).foregroundStyle(Palette.guardBlue)
                        }
                        Text("\(battle.playerHP)/\(battle.playerMaxHP)").font(.caption.weight(.bold).monospacedDigit())
                    }
                    MeterBar(value: Double(battle.playerHP) / Double(battle.playerMaxHP), color: Palette.hp, height: 10, extra: Double(battle.playerBlock))
                }
                Button(action: endTurn) {
                    Text("ターン\n終了").font(.caption.weight(.heavy)).multilineTextAlignment(.center)
                        .foregroundStyle(.black)
                        .frame(width: 58, height: 50)
                        .background(RoundedRectangle(cornerRadius: 14).fill(Palette.gold.gradient))
                }
                .disabled(busy || battle.outcome != .ongoing)
            }
            .modifier(Shake(amount: 8, shakes: CGFloat(playerShake)))
            .animation(.easeOut(duration: 0.35), value: playerShake)

            ForEach(floats.filter { $0.place == .player }) { f in
                FloatingLabel(text: f.text, color: f.color).offset(x: f.dx, y: -30)
            }
        }
    }

    private var hand: some View {
        // 収まるときは中央に並べ、多いときは横にスクロール
        ViewThatFits(in: .horizontal) {
            handRow
            ScrollView(.horizontal, showsIndicators: false) { handRow }
        }
        .frame(height: 118)
        .disabled(busy)
    }

    private var handRow: some View {
        HStack(spacing: 6) {
            ForEach(battle.hand) { card in
                let def = card.def
                Button { play(card) } label: {
                    CardView(card: def, level: battle.level(of: def.owner), battle: battle, playable: battle.canPlay(card), width: 70)
                }
                .buttonStyle(.plain)
                .transition(.asymmetric(insertion: .move(edge: .bottom).combined(with: .opacity), removal: .scale(scale: 0.4).combined(with: .opacity)))
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: 操作

    private func play(_ card: CardInstance) {
        guard !busy else { return }
        guard battle.canPlay(card) else {
            flashHint("エナジーが足りない")
            return
        }
        var events: [BattleEvent] = []
        withAnimation(.spring(duration: 0.3)) { events = battle.play(card) }
        show(events)
        if card.def.kind == .attack {
            withAnimation(.spring(duration: 0.25)) { flashOwner = card.def.owner }
            Task {
                try? await Task.sleep(for: .milliseconds(420))
                withAnimation(.easeOut(duration: 0.2)) { flashOwner = nil }
            }
        }
        commit()
    }

    private func endTurn() {
        guard !busy, battle.outcome == .ongoing else { return }
        busy = true
        Task {
            var events: [BattleEvent] = []
            withAnimation(.spring(duration: 0.3)) { events = battle.endTurn() }
            show(events)
            try? await Task.sleep(for: .milliseconds(450))
            busy = false
            commit()
        }
    }

    /// 戦闘が終わったら少し待ってから結果へ
    private func commit() {
        if battle.outcome == .ongoing {
            onUpdate(battle)
        } else {
            busy = true
            let final = battle
            Task {
                try? await Task.sleep(for: .milliseconds(1100))
                onUpdate(final)
            }
        }
    }

    private func show(_ events: [BattleEvent]) {
        var delay = 0.0
        for event in events {
            var item: FloatText?
            let dx = CGFloat.random(in: -40...40)
            switch event {
            case let .enemyHit(damage, blocked):
                item = FloatText(text: damage > 0 ? "-\(damage)" : "ガード \(blocked)", color: damage > 0 ? .white : Palette.guardBlue, place: .enemy, dx: dx)
                after(delay) { enemyShake += 1; hitCount += 1 }
            case let .playerHit(damage, blocked):
                item = FloatText(text: damage > 0 ? "-\(damage)" : "ガード \(blocked)", color: damage > 0 ? Palette.hp : Palette.guardBlue, place: .player, dx: dx)
                after(delay) { if damage > 0 { playerShake += 1; hurtCount += 1 } }
            case let .playerBlock(n): item = FloatText(text: "ガード+\(n)", color: Palette.guardBlue, place: .player, dx: dx)
            case let .enemyBlock(n): item = FloatText(text: "ガード+\(n)", color: Palette.guardBlue, place: .enemy, dx: dx)
            case let .heal(n): item = FloatText(text: "+\(n)", color: Palette.exp, place: .player, dx: dx)
            case let .poisonTick(n): item = FloatText(text: "毒 -\(n)", color: Color(hex: "#8CF06B"), place: .enemy, dx: dx)
            case let .status(text): item = FloatText(text: text, color: Palette.gold, place: text.hasPrefix("敵") || text.hasPrefix("弱体に") ? .player : .enemy, dx: dx)
            case .played, .chain, .enemyDefeated, .playerDefeated: break
            }
            if let item {
                after(delay) { floats.append(item) }
                after(delay + 1.0) { floats.removeAll { $0.id == item.id } }
                delay += 0.12
            }
        }
    }

    private func after(_ seconds: Double, _ action: @escaping () -> Void) {
        Task {
            try? await Task.sleep(for: .milliseconds(Int(seconds * 1000)))
            action()
        }
    }

    private func flashHint(_ text: String) {
        withAnimation { hint = text }
        after(1.2) { withAnimation { hint = nil } }
    }
}

private struct AttackFlash: View {
    let owner: String

    var body: some View {
        let def = Catalog.character(owner)
        ZStack {
            LinearGradient(colors: [(def?.tint ?? .white).opacity(0.5), .clear], startPoint: .leading, endPoint: .trailing)
                .ignoresSafeArea()
            SpriteImage(id: owner, name: "attack")
                .frame(height: 360)
                .offset(x: -60, y: -60)
        }
    }
}

private struct FloatingLabel: View {
    let text: String
    let color: Color
    @State private var up = false

    var body: some View {
        Text(text)
            .font(.system(size: 28, weight: .black, design: .rounded))
            .foregroundStyle(color)
            .shadow(color: .black, radius: 3)
            .offset(y: up ? -60 : 0)
            .opacity(up ? 0 : 1)
            .onAppear { withAnimation(.easeOut(duration: 0.95)) { up = true } }
    }
}

struct StatusChip: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.heavy))
            .padding(.horizontal, 7).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.25)))
            .overlay(Capsule().strokeBorder(color, lineWidth: 1))
            .foregroundStyle(color)
    }
}

struct Shake: GeometryEffect {
    var amount: CGFloat = 10
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: amount * sin(shakes * .pi * 4), y: 0))
    }
}

struct HelpSheet: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("戦い方").font(.title2.weight(.black))
                Text("毎ターン、エナジー3とカード5枚が配られます。カードをタップして使い、終わったら「ターン終了」。敵の頭の上に、次にしてくる行動が出ています。")
                    .font(.subheadline)
                ForEach(CardText.glossary.indices, id: \.self) { i in
                    let item = CardText.glossary[i]
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.0).font(.headline.weight(.heavy)).foregroundStyle(Palette.gold)
                        Text(item.1).font(.subheadline).foregroundStyle(.secondary)
                    }
                }
            }
            .padding(20)
        }
    }
}
