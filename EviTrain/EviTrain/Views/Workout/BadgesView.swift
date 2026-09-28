import SwiftData
import SwiftUI

/// バッジ1つ（六角形のオリジナルデザイン）。未達成は灰色で、進み具合の輪を表示。
struct BadgeMedal: View {
    let badge: Badge
    var size: CGFloat = 64
    @Environment(\.appTheme) private var theme

    var body: some View {
        ZStack {
            Hexagon()
                .fill(badge.earned
                      ? AnyShapeStyle(LinearGradient(colors: [theme.accent, theme.accent.opacity(0.55)],
                                                     startPoint: .top, endPoint: .bottom))
                      : AnyShapeStyle(Color.secondary.opacity(0.18)))
            Hexagon()
                .stroke(badge.earned ? Color.white.opacity(0.5) : Color.secondary.opacity(0.3), lineWidth: 2)
                .padding(4)
            Image(systemName: badge.symbol)
                .font(.system(size: size * 0.36, weight: .bold))
                .foregroundStyle(badge.earned ? Color.white : Color.secondary)
        }
        .frame(width: size, height: size * 1.1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(badge.title)、\(badge.earned ? "達成" : "未達成")")
    }
}

/// 縦長の六角形
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let w = rect.width, h = rect.height
        var path = Path()
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.25))
        path.addLine(to: CGPoint(x: w, y: h * 0.75))
        path.addLine(to: CGPoint(x: w / 2, y: h))
        path.addLine(to: CGPoint(x: 0, y: h * 0.75))
        path.addLine(to: CGPoint(x: 0, y: h * 0.25))
        path.closeSubpath()
        return path.offsetBy(dx: rect.minX, dy: rect.minY)
    }
}

/// バッジの一覧。
struct BadgesView: View {
    let badges: [Badge]

    var body: some View {
        let columns = [GridItem(.adaptive(minimum: 100), spacing: 16)]
        ScrollView {
            LazyVGrid(columns: columns, spacing: 20) {
                ForEach(badges) { badge in
                    VStack(spacing: 6) {
                        BadgeMedal(badge: badge)
                        Text(badge.title).font(.subheadline.bold()).multilineTextAlignment(.center)
                        Text(badge.detail).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        if !badge.earned {
                            ProgressView(value: badge.progress).frame(width: 70)
                        }
                    }
                }
            }
            .padding()
        }
        .themedBackground()
        .navigationTitle("バッジ \(badges.filter(\.earned).count) / \(badges.count)")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 記録タブに出す、バッジの小さな行。
struct BadgeStrip: View {
    @Environment(\.appTheme) private var theme
    let badges: [Badge]

    var body: some View {
        NavigationLink {
            BadgesView(badges: badges)
        } label: {
            HStack(spacing: 10) {
                let earned = badges.filter(\.earned)
                HStack(spacing: -10) {
                    ForEach(earned.suffix(4)) { BadgeMedal(badge: $0, size: 30) }
                    if earned.isEmpty, let next = badges.first { BadgeMedal(badge: next, size: 30) }
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("バッジ \(earned.count) / \(badges.count)").font(.subheadline.bold())
                    if let next = badges.first(where: { !$0.earned }) {
                        Text("次: \(next.title)（\(next.detail)）").font(.caption).foregroundStyle(.secondary).lineLimit(1)
                    }
                }
                Spacer()
                Image(systemName: "chevron.right").foregroundStyle(.tertiary)
            }
            .padding()
            .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }
}
