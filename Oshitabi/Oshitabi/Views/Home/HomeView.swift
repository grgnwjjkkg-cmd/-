import SwiftUI

/// 推しのホーム：放置で育つ推しを眺める・話しかける・経験値を受け取る
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @State private var line: String?
    @State private var bounce = false
    @State private var talkCount = 0
    @State private var report: GrowthReport?
    @State private var showPicker = false

    var body: some View {
        let def = store.oshi
        let progress = store.progress(def.id)
        ZStack {
            GameBackground(color: def.tint)
            VStack(spacing: 0) {
                header(def, progress)
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                ZStack(alignment: .top) {
                    AnimatedSprite(id: def.id)
                        .scaleEffect(bounce ? 1.04 : 1, anchor: .bottom)
                        .id(def.id)
                        .contentShape(Rectangle())
                        .onTapGesture { talk() }
                        .accessibilityLabel("\(def.name)に話しかける")
                        .accessibilityAddTraits(.isButton)
                    if let line {
                        SpeechBubble(text: line, color: def.tint)
                            .padding(.top, 12)
                            .transition(.scale(scale: 0.6, anchor: .bottom).combined(with: .opacity))
                            .id(line)
                    }
                }
                .frame(maxHeight: .infinity)
                .sensoryFeedback(.impact(weight: .light), trigger: talkCount)

                IdlePanel(onClaim: claim)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
            }

            if let report {
                LevelUpOverlay(report: report) { withAnimation { self.report = nil } }
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showPicker) {
            OshiChangeSheet { id in
                if let r = store.setOshi(id), r.levelsGained > 0 { report = r }
                line = nil
                showPicker = false
            }
            .presentationDetents([.medium])
        }
    }

    private func header(_ def: CharacterDef, _ progress: CharacterProgress) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 4) {
                Stars(count: def.rarity, awakening: progress.awakening)
                Text(def.name).font(.largeTitle.weight(.black))
                Text(def.title).font(.subheadline.weight(.bold)).foregroundStyle(def.tint2)
                HStack(spacing: 8) {
                    Text("Lv.\(progress.level)").font(.headline.weight(.heavy).monospacedDigit())
                    MeterBar(value: progress.isMaxLevel ? 1 : Double(progress.exp) / Double(CharacterProgress.expToNext(progress.level)),
                             color: Palette.exp, height: 8)
                        .frame(width: 120)
                }
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill").foregroundStyle(Color(hex: "#FF7AB6"))
                    Text("なかよし \(progress.affection)").font(.caption.weight(.bold))
                }
            }
            Spacer()
            Button {
                showPicker = true
            } label: {
                Label("推しを変える", systemImage: "arrow.triangle.2.circlepath")
                    .font(.caption.weight(.bold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Capsule().fill(.white.opacity(0.12)))
            }
            .foregroundStyle(.white)
        }
    }

    private func talk() {
        talkCount += 1
        withAnimation(.spring(duration: 0.25, bounce: 0.6)) {
            line = store.talk()
            bounce = true
        }
        Task {
            try? await Task.sleep(for: .milliseconds(180))
            withAnimation(.spring(duration: 0.3)) { bounce = false }
        }
    }

    private func claim() {
        if let r = store.claimIdle() {
            withAnimation(.spring(duration: 0.4)) { report = r }
        }
    }
}

struct SpeechBubble: View {
    let text: String
    let color: Color

    var body: some View {
        Text(text)
            .font(.subheadline.weight(.bold))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(RoundedRectangle(cornerRadius: 18).fill(.white))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(color, lineWidth: 2))
            .shadow(color: .black.opacity(0.3), radius: 8, y: 4)
            .padding(.horizontal, 40)
    }
}

/// 放置でたまった経験値
struct IdlePanel: View {
    @Environment(GameStore.self) private var store
    let onClaim: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let pending = store.pendingIdleExp(now: context.date)
            let cap = Int(IdleGrowth.capMinutes * IdleGrowth.expPerMinute)
            let remaining = store.idleCapDate.timeIntervalSince(context.date)
            VStack(spacing: 10) {
                HStack {
                    Label("放置でたまった経験値", systemImage: "hourglass")
                        .font(.subheadline.weight(.bold))
                    Spacer()
                    Text("+\(pending) EXP")
                        .font(.headline.weight(.heavy).monospacedDigit())
                        .foregroundStyle(Palette.exp)
                        .contentTransition(.numericText(value: Double(pending)))
                }
                MeterBar(value: Double(pending) / Double(cap), color: Palette.exp, height: 8)
                Text(remaining > 0 ? "満タンまで あと\(Self.format(remaining))（閉じていても増えます）" : "満タンです！ 受け取らないとこれ以上たまりません")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, alignment: .leading)
                Button("受け取る", action: onClaim)
                    .buttonStyle(PrimaryButtonStyle(color: Palette.exp))
                    .disabled(pending == 0)
                    .opacity(pending == 0 ? 0.5 : 1)
            }
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 22).fill(.ultraThinMaterial))
        }
    }

    static func format(_ seconds: TimeInterval) -> String {
        let minutes = Int(seconds / 60)
        return minutes >= 60 ? "\(minutes / 60)時間\(minutes % 60)分" : "\(max(1, minutes))分"
    }
}

struct LevelUpOverlay: View {
    let report: GrowthReport
    let onClose: () -> Void
    @State private var appear = false

    var body: some View {
        let def = Catalog.character(report.character)!
        ZStack {
            Color.black.opacity(0.6).ignoresSafeArea().onTapGesture(perform: onClose)
            VStack(spacing: 10) {
                Text(report.levelsGained > 0 ? "レベルアップ！" : "経験値を受け取った")
                    .font(.title.weight(.black))
                    .foregroundStyle(Palette.gold)
                SpriteImage(id: def.id, name: "attack")
                    .frame(height: 260)
                    .scaleEffect(appear ? 1 : 0.7)
                Text("\(def.name)  +\(report.exp) EXP").font(.headline.weight(.bold))
                if report.levelsGained > 0 {
                    Text("Lv.\(report.newLevel - report.levelsGained) → Lv.\(report.newLevel)")
                        .font(.title2.weight(.heavy).monospacedDigit())
                    if let awakening = Self.awakeningCrossed(report) {
                        Text("覚醒！ ★+\(awakening)　カードがさらに強くなった")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(Color(hex: "#FF8AE2"))
                    }
                }
                Button("OK", action: onClose)
                    .buttonStyle(PrimaryButtonStyle(color: def.tint))
                    .padding(.horizontal, 40)
                    .padding(.top, 6)
            }
            .padding(24)
        }
        .onAppear { withAnimation(.spring(duration: 0.5, bounce: 0.5)) { appear = true } }
        .sensoryFeedback(.success, trigger: appear)
    }

    static func awakeningCrossed(_ r: GrowthReport) -> Int? {
        let before = r.newLevel - r.levelsGained
        if before < 20, r.newLevel >= 20 { return 2 }
        if before < 10, r.newLevel >= 10 { return 1 }
        return nil
    }
}

struct OshiChangeSheet: View {
    @Environment(GameStore.self) private var store
    let onPick: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("推しを変える").font(.title3.weight(.heavy))
            Text("今までの放置ぶんは、いまの推しが受け取ります。")
                .font(.footnote).foregroundStyle(.secondary)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 90))], spacing: 14) {
                    ForEach(store.ownedCharacters) { def in
                        Button {
                            onPick(def.id)
                        } label: {
                            VStack(spacing: 4) {
                                FaceIcon(id: def.id, size: 64)
                                    .overlay(alignment: .topTrailing) {
                                        if def.id == store.oshiID {
                                            Image(systemName: "heart.circle.fill").foregroundStyle(Color(hex: "#FF7AB6")).font(.title3)
                                        }
                                    }
                                Text(def.name).font(.subheadline.weight(.bold))
                                Text("Lv.\(store.level(def.id))").font(.caption.monospacedDigit()).foregroundStyle(.secondary)
                            }
                        }
                        .foregroundStyle(.primary)
                    }
                }
            }
        }
        .padding(20)
    }
}
