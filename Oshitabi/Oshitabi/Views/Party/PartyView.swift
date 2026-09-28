import SwiftUI

/// 仲間（図鑑）：集めたキャラの一覧と詳細
struct PartyView: View {
    @Environment(GameStore.self) private var store
    @State private var detail: CharacterDef?

    var body: some View {
        NavigationStack {
            ZStack {
                GameBackground(color: Color(hex: "#FF7AB6"))
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text("\(store.ownedCharacters.count) / \(Catalog.characters.count) 人")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                            ForEach(Catalog.characters) { def in
                                let owned = store.owns(def.id)
                                Button {
                                    if owned { detail = def }
                                } label: {
                                    MemberCard(def: def, owned: owned, progress: store.progress(def.id), isOshi: store.oshiID == def.id)
                                }
                                .buttonStyle(.plain)
                                .disabled(!owned)
                            }
                        }
                        Text("まだ会っていない仲間は、冒険で強敵や影の王を倒すと加わります。")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                }
            }
            .navigationTitle("仲間")
            #if DEBUG
            .toolbar {
                Menu {
                    Button("放置 +8時間") { store.debugAddIdleHours(8) }
                    Button("データを消す", role: .destructive) { store.debugReset() }
                } label: { Image(systemName: "ladybug") }
            }
            #endif
        }
        .sheet(item: $detail) { def in
            MemberDetail(def: def).presentationDetents([.large])
        }
    }
}

private struct MemberCard: View {
    let def: CharacterDef
    let owned: Bool
    let progress: CharacterProgress
    let isOshi: Bool

    var body: some View {
        VStack(spacing: 4) {
            SpriteImage(id: def.id, name: "idle_00")
                .frame(height: 150)
                .brightness(owned ? 0 : -1)
                .opacity(owned ? 1 : 0.5)
            if owned {
                Stars(count: def.rarity, awakening: progress.awakening)
                Text(def.name).font(.headline.weight(.heavy))
                Text("Lv.\(progress.level)  \(def.title)").font(.caption).foregroundStyle(.secondary)
            } else {
                Text("？？？").font(.headline.weight(.heavy))
                Text("まだ出会っていない").font(.caption).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 20).fill(owned ? def.tint.opacity(0.22) : Palette.panel))
        .overlay(RoundedRectangle(cornerRadius: 20).strokeBorder(owned ? def.tint.opacity(0.7) : .white.opacity(0.1), lineWidth: 1.5))
        .overlay(alignment: .topTrailing) {
            if isOshi {
                Label("推し", systemImage: "heart.fill")
                    .font(.caption2.weight(.heavy))
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(Capsule().fill(Color(hex: "#FF7AB6")))
                    .padding(8)
            }
        }
    }
}

private struct MemberDetail: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss
    let def: CharacterDef

    var body: some View {
        let p = store.progress(def.id)
        ZStack {
            GameBackground(color: def.tint)
            ScrollView {
                VStack(spacing: 12) {
                    AnimatedSprite(id: def.id).frame(height: 320)
                    Stars(count: def.rarity, awakening: p.awakening, size: 14)
                    Text(def.name).font(.largeTitle.weight(.black))
                    Text(def.title).font(.subheadline.weight(.bold)).foregroundStyle(def.tint2)
                    Text(def.profile).font(.footnote).foregroundStyle(.white.opacity(0.8)).multilineTextAlignment(.center)

                    HStack(spacing: 10) {
                        info("レベル", "\(p.level)")
                        info("HP", "\(Scaling.maxHP(def, level: p.level))")
                        info("カード威力", "×\(String(format: "%.2f", Scaling.power(level: p.level)))")
                        info("なかよし", "\(p.affection)")
                    }

                    if store.oshiID != def.id {
                        Button("推しにする") {
                            store.setOshi(def.id)
                            dismiss()
                        }
                        .buttonStyle(PrimaryButtonStyle(color: def.tint))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("最初から持っているカード").font(.headline.weight(.heavy))
                        cards(Array(Set(def.starterDeck)).sorted(), level: p.level)
                        Text("冒険で手に入るカード").font(.headline.weight(.heavy)).padding(.top, 6)
                        cards(def.rewardPool, level: p.level)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .padding(20)
            }
        }
    }

    private func cards(_ ids: [String], level: Int) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ids, id: \.self) { id in
                    if let card = Catalog.card(id) { CardView(card: card, level: level, width: 92) }
                }
            }
        }
    }

    private func info(_ title: String, _ value: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(.headline.weight(.heavy).monospacedDigit())
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.08)))
    }
}
