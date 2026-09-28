import SwiftUI

/// はじめて開いたときに1回だけ出す説明（3枚）。
struct OnboardingView: View {
    static let seenKey = "onboardingSeen"
    @AppStorage(OnboardingView.seenKey) private var seen = false
    @Environment(\.appTheme) private var theme
    @State private var page = 0

    private struct Page {
        let symbol: String
        let title: String
        let text: String
    }

    private let pages: [Page] = [
        Page(symbol: "figure.strengthtraining.traditional", title: "記録はすばやく",
             text: "前回のメニューを1タップでセット。重さと回数は前回の値が入ります。休憩タイマーは種目ごとに覚えます。"),
        Page(symbol: "doc.text.magnifyingglass", title: "研究で確かめる",
             text: "スポーツ科学の論文714本を、答え・★・グラフで1画面にまとめました。「筋トレで足は速くなる？」のような質問で探せます。"),
        Page(symbol: "star.square.on.square", title: "研究をそのまま練習に",
             text: "論文の「このメニューで練習する」で、研究でやった練習をマイメニューに追加。期間と週の回数の進み具合も見られます。"),
    ]

    var body: some View {
        VStack(spacing: 24) {
            TabView(selection: $page) {
                ForEach(pages.indices, id: \.self) { index in
                    VStack(spacing: 20) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 36, style: .continuous)
                                .fill(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.6)],
                                                     startPoint: .topLeading, endPoint: .bottomTrailing))
                            Image(systemName: pages[index].symbol)
                                .font(.system(size: 64, weight: .semibold))
                                .foregroundStyle(.white)
                        }
                        .frame(width: 150, height: 150)
                        Text(pages[index].title).font(.title.bold())
                        Text(pages[index].text)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 28)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .always))
            .indexViewStyle(.page(backgroundDisplayMode: .always))

            Button {
                if page < pages.count - 1 {
                    withAnimation { page += 1 }
                } else {
                    seen = true
                }
            } label: {
                Text(page < pages.count - 1 ? "次へ" : "はじめる")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 14)
                    .foregroundStyle(theme.onAccent)
                    .background(theme.accent, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 24)

            Button("スキップ") { seen = true }
                .font(.subheadline)
                .padding(.bottom, 12)
        }
        .padding(.top, 40)
        .background(theme.background.ignoresSafeArea())
    }
}
