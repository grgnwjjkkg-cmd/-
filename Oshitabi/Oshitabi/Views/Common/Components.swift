import SwiftUI
import UIKit

// MARK: - 色

extension Color {
    init(hex: String) {
        var value: UInt64 = 0
        Scanner(string: hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))).scanHexInt64(&value)
        self.init(red: Double((value >> 16) & 0xFF) / 255, green: Double((value >> 8) & 0xFF) / 255, blue: Double(value & 0xFF) / 255)
    }
}

enum Palette {
    static let night = Color(hex: "#15121F")
    static let panel = Color(hex: "#221D33")
    static let panel2 = Color(hex: "#2E2745")
    static let gold = Color(hex: "#FFD36B")
    static let hp = Color(hex: "#FF5A7A")
    static let guardBlue = Color(hex: "#6FC3FF")
    static let exp = Color(hex: "#8CF0B4")
    static let energy = Color(hex: "#FFC94D")
}

extension CharacterDef {
    var tint: Color { Color(hex: color) }
    var tint2: Color { Color(hex: color2) }
}

// MARK: - 画像

/// Resources/Sprites/<id>/ に入っている、3Dモデルから作った画像
enum Sprites {
    private static let cache = NSCache<NSString, UIImage>()

    static func image(_ id: String, _ name: String) -> UIImage? {
        let key = "\(id)/\(name)" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        guard let url = Bundle.main.url(forResource: name, withExtension: "webp", subdirectory: "Sprites/\(id)"),
              let image = UIImage(contentsOfFile: url.path) else { return nil }
        cache.setObject(image, forKey: key)
        return image
    }

    static func idleFrames(_ id: String) -> [UIImage] {
        (0..<24).compactMap { image(id, String(format: "idle_%02d", $0)) }
    }
}

/// 待機アニメーション（コマ送り）
struct AnimatedSprite: View {
    let id: String
    var fps = 12.0
    @State private var frames: [UIImage] = []

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / fps)) { context in
            if frames.isEmpty {
                Color.clear
            } else {
                let index = Int(context.date.timeIntervalSinceReferenceDate * fps) % frames.count
                Image(uiImage: frames[index]).resizable().scaledToFit()
            }
        }
        .onAppear { if frames.isEmpty { frames = Sprites.idleFrames(id) } }
        .onChange(of: id) { frames = Sprites.idleFrames(id) }
    }
}

struct SpriteImage: View {
    let id: String
    let name: String

    var body: some View {
        if let image = Sprites.image(id, name) {
            Image(uiImage: image).resizable().scaledToFit()
        } else {
            Color.clear
        }
    }
}

/// 丸い顔アイコン
struct FaceIcon: View {
    let id: String
    var size: CGFloat = 44
    var locked = false

    var body: some View {
        let def = Catalog.character(id)
        ZStack {
            Circle().fill(LinearGradient(colors: [def?.tint2 ?? .gray, def?.tint ?? .gray], startPoint: .top, endPoint: .bottom))
            SpriteImage(id: id, name: "face")
                .clipShape(Circle())
                .brightness(locked ? -1 : 0)
                .opacity(locked ? 0.55 : 1)
            if locked {
                Text("？").font(.system(size: size * 0.45, weight: .black, design: .rounded)).foregroundStyle(.white.opacity(0.8))
            }
        }
        .frame(width: size, height: size)
        .overlay(Circle().strokeBorder(.white.opacity(0.7), lineWidth: max(1.5, size / 28)))
    }
}

struct Stars: View {
    let count: Int
    var awakening = 0
    var size: CGFloat = 11

    var body: some View {
        HStack(spacing: 1) {
            ForEach(0..<count, id: \.self) { _ in
                Image(systemName: "star.fill").foregroundStyle(Palette.gold)
            }
            ForEach(0..<awakening, id: \.self) { _ in
                Image(systemName: "star.fill").foregroundStyle(Color(hex: "#FF8AE2"))
            }
        }
        .font(.system(size: size))
        .accessibilityLabel("レア度\(count)、覚醒\(awakening)")
    }
}

/// HPやEXPのバー
struct MeterBar: View {
    let value: Double
    var color: Color
    var height: CGFloat = 10
    var extra: Double = 0
    var extraColor: Color = Palette.guardBlue

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.12))
                Capsule().fill(color.gradient)
                    .frame(width: geo.size.width * min(1, max(0, value)))
                    .shadow(color: color.opacity(0.6), radius: 4)
                if extra > 0 {
                    Capsule().strokeBorder(extraColor, lineWidth: 2)
                        .frame(width: geo.size.width * min(1, max(0, value)))
                }
            }
        }
        .frame(height: height)
        .animation(.spring(duration: 0.4), value: value)
    }
}

// MARK: - カード

struct CardView: View {
    let card: CardDef
    let level: Int
    var battle: Battle?
    var playable = true
    var width: CGFloat = 72

    var body: some View {
        let owner = Catalog.character(card.owner)!
        let height = width * 1.5
        VStack(spacing: 2) {
            ZStack(alignment: .topLeading) {
                SpriteImage(id: card.owner, name: "face")
                    .frame(width: width - 10, height: width * 0.55)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .background(RoundedRectangle(cornerRadius: 8).fill(owner.tint.opacity(0.35)))
                Text("\(card.cost)")
                    .font(.system(size: width * 0.2, weight: .black, design: .rounded))
                    .foregroundStyle(.black)
                    .frame(width: width * 0.28, height: width * 0.28)
                    .background(Circle().fill(Palette.energy))
                    .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                    .offset(x: -5, y: -5)
            }
            Text(card.name)
                .font(.system(size: width * 0.15, weight: .heavy))
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            Text(CardText.describe(card, level: level, battle: battle))
                .font(.system(size: width * 0.125, weight: .semibold))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.85))
                .lineLimit(3)
                .minimumScaleFactor(0.6)
            Spacer(minLength: 0)
        }
        .padding(5)
        .frame(width: width, height: height)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(LinearGradient(colors: [owner.tint.opacity(0.9), Palette.panel], startPoint: .top, endPoint: .bottom))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(card.isRare ? Palette.gold : .white.opacity(0.5), lineWidth: card.isRare ? 2 : 1)
        )
        .foregroundStyle(.white)
        .opacity(playable ? 1 : 0.45)
        .accessibilityElement(children: .combine)
    }
}

/// 暗い背景＋推しの色のグラデーション
struct GameBackground: View {
    var color: Color = Color(hex: "#6E5AE6")

    var body: some View {
        ZStack {
            Palette.night
            RadialGradient(colors: [color.opacity(0.55), .clear], center: .top, startRadius: 10, endRadius: 520)
            RadialGradient(colors: [color.opacity(0.25), .clear], center: .bottom, startRadius: 10, endRadius: 400)
        }
        .ignoresSafeArea()
    }
}

struct PrimaryButtonStyle: ButtonStyle {
    var color: Color = Palette.gold

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.headline.weight(.heavy))
            .foregroundStyle(.black)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(RoundedRectangle(cornerRadius: 16).fill(color.gradient))
            .shadow(color: color.opacity(0.5), radius: 10, y: 4)
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .animation(.spring(duration: 0.2), value: configuration.isPressed)
    }
}
