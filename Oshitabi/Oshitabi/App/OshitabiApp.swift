import SwiftUI

@main
struct OshitabiApp: App {
    @State private var store = GameStore()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(store)
                .preferredColorScheme(.dark)
        }
    }
}

struct RootView: View {
    @Environment(GameStore.self) private var store
    @State private var tab = 0

    var body: some View {
        if store.hasChosenOshi {
            TabView(selection: $tab) {
                HomeView()
                    .tabItem { Label("推し", systemImage: "heart.fill") }
                    .tag(0)
                AdventureView()
                    .tabItem { Label("冒険", systemImage: "map.fill") }
                    .tag(1)
                PartyView()
                    .tabItem { Label("仲間", systemImage: "person.3.fill") }
                    .tag(2)
            }
            .tint(Palette.gold)
        } else {
            OshiPickView()
        }
    }
}

/// はじめて開いたとき：推しを選ぶ
struct OshiPickView: View {
    @Environment(GameStore.self) private var store
    @State private var selected = Catalog.starters[0]

    var body: some View {
        let def = Catalog.character(selected)!
        ZStack {
            GameBackground(color: def.tint)
            VStack(spacing: 14) {
                VStack(spacing: 6) {
                    Text("あなたの推しを選んでください")
                        .font(.title3.weight(.heavy))
                    Text("推しはアプリを閉じている間も育ちます。あとから変えられます。")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.7))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 24)

                AnimatedSprite(id: selected)
                    .frame(maxHeight: .infinity)
                    .id(selected)
                    .transition(.opacity.combined(with: .scale(scale: 0.95)))

                VStack(spacing: 4) {
                    Stars(count: def.rarity)
                    Text(def.name).font(.largeTitle.weight(.black))
                    Text(def.title).font(.subheadline.weight(.bold)).foregroundStyle(def.tint2)
                    Text(def.profile)
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                HStack(spacing: 18) {
                    ForEach(Catalog.starters, id: \.self) { id in
                        Button {
                            withAnimation(.spring(duration: 0.35)) { selected = id }
                        } label: {
                            FaceIcon(id: id, size: selected == id ? 68 : 54)
                                .shadow(color: selected == id ? .white.opacity(0.6) : .clear, radius: 8)
                        }
                        .accessibilityLabel(Catalog.character(id)?.name ?? id)
                    }
                }
                .sensoryFeedback(.selection, trigger: selected)

                Button("\(def.name)を推しにする") {
                    store.start(withOshi: selected)
                    store.requestNotifications()
                }
                .buttonStyle(PrimaryButtonStyle(color: def.tint))
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
            }
        }
    }
}
