import SwiftUI

/// 部位ごとの色（エビトレ独自の配色。ライト／ダークで少し明るさを変える）。
extension MuscleGroup {
    var color: Color {
        switch self {
        case .chest: Color(light: 0xE0475B, dark: 0xFF6B7D)      // 胸: コーラルレッド
        case .back: Color(light: 0x3B5BDB, dark: 0x7C95F5)       // 背中: インディゴ
        case .legs: Color(light: 0x0F9D8A, dark: 0x3FD4BD)       // 脚: ティール
        case .shoulders: Color(light: 0xD98A00, dark: 0xFFB84D)  // 肩: アンバー
        case .arms: Color(light: 0x8B46C9, dark: 0xB889F0)       // 腕: パープル
        case .core: Color(light: 0xE0661B, dark: 0xFF9657)       // 体幹: オレンジ
        case .sprint: Color(light: 0x1A8FD6, dark: 0x5CC2FF)     // スプリント: スカイ
        case .plyometric: Color(light: 0xD4418E, dark: 0xFF7DBE) // ジャンプ: マゼンタ
        case .cardio: Color(light: 0x4F8A1B, dark: 0x9AD65A)     // 有酸素: グリーン
        }
    }

    /// 部位の代表の記号（Apple の SF Symbols）
    var symbol: String {
        switch self {
        case .chest, .back, .shoulders, .arms: "figure.strengthtraining.traditional"
        case .legs: "figure.strengthtraining.functional"
        case .core: "figure.core.training"
        case .sprint: "figure.run"
        case .plyometric: "figure.step.training"
        case .cardio: "figure.run.circle"
        }
    }
}

extension Exercise {
    /// 種目ごとに近い形の記号を選ぶ（名前で判断。なければ部位の記号）。
    var symbol: String {
        let rules: [(String, String)] = [
            ("懸垂", "figure.play"), ("ラット", "figure.play"), ("ロウ", "figure.rower"),
            ("腕立て", "figure.cross.training"), ("ディップス", "figure.cross.training"),
            ("プランク", "figure.core.training"), ("アブローラー", "figure.core.training"),
            ("ジャンプ", "figure.jumprope"), ("跳", "figure.jumprope"), ("バウンディング", "figure.highintensity.intervaltraining"),
            ("そり", "figure.strengthtraining.functional"), ("坂道", "figure.hiking"),
            ("ランニング", "figure.run"), ("ダッシュ", "figure.run"),
            ("クリーン", "figure.highintensity.intervaltraining"), ("メディシン", "figure.handball"),
            ("レイズ", "figure.arms.open"), ("カール", "dumbbell.fill"), ("エクステンション", "dumbbell.fill"),
        ]
        return rules.first { name.contains($0.0) }?.1 ?? group.symbol
    }
}

/// 種目のアイコン：部位の色のグラデーションに、種目の記号をのせる。
struct ExerciseIcon: View {
    let exercise: Exercise?
    var size: CGFloat = 40

    var body: some View {
        let color = exercise?.group.color ?? .gray
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.28, style: .continuous)
                .fill(LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .topLeading, endPoint: .bottomTrailing))
            // 右下に薄い光の輪を重ねて立体感を出す
            Circle()
                .fill(.white.opacity(0.16))
                .frame(width: size * 0.9)
                .offset(x: size * 0.32, y: size * 0.34)
                .clipShape(RoundedRectangle(cornerRadius: size * 0.28, style: .continuous))
            Image(systemName: exercise?.symbol ?? "questionmark")
                .font(.system(size: size * 0.5, weight: .semibold))
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.18), radius: 1, y: 1)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// 鍛える部位だけが光る、ミニ筋肉マップ（コードで描いたオリジナルの人の形）。
struct MuscleMapView: View {
    let group: MuscleGroup
    var height: CGFloat = 44

    var body: some View {
        Canvas { context, size in
            let w = size.width, h = size.height
            let base = Color.secondary.opacity(0.25)
            let hi = group.color
            func fill(_ rect: CGRect, radius: CGFloat, _ color: Color) {
                context.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
            }
            // パーツの位置（幅1 × 高さ2.2 の比率で設計）
            let head = CGRect(x: w * 0.40, y: 0, width: w * 0.20, height: h * 0.10)
            let shoulderL = CGRect(x: w * 0.18, y: h * 0.12, width: w * 0.16, height: h * 0.08)
            let shoulderR = CGRect(x: w * 0.66, y: h * 0.12, width: w * 0.16, height: h * 0.08)
            let chest = CGRect(x: w * 0.32, y: h * 0.12, width: w * 0.36, height: h * 0.14)
            let core = CGRect(x: w * 0.35, y: h * 0.27, width: w * 0.30, height: h * 0.20)
            let armL = CGRect(x: w * 0.12, y: h * 0.21, width: w * 0.12, height: h * 0.30)
            let armR = CGRect(x: w * 0.76, y: h * 0.21, width: w * 0.12, height: h * 0.30)
            let legL = CGRect(x: w * 0.33, y: h * 0.49, width: w * 0.15, height: h * 0.48)
            let legR = CGRect(x: w * 0.52, y: h * 0.49, width: w * 0.15, height: h * 0.48)

            let lit: Set<String> = switch group {
            case .chest: ["chest"]
            case .back: ["chest", "shoulders"] // 背中は胴の上側を光らせ、線で「背面」を示す
            case .legs: ["legs"]
            case .shoulders: ["shoulders"]
            case .arms: ["arms"]
            case .core: ["core"]
            case .sprint, .plyometric: ["legs", "core"]
            case .cardio: ["legs", "chest", "core"]
            }
            func color(_ key: String) -> Color { lit.contains(key) ? hi : base }

            context.fill(Path(ellipseIn: head), with: .color(base))
            fill(shoulderL, radius: h * 0.04, color("shoulders"))
            fill(shoulderR, radius: h * 0.04, color("shoulders"))
            fill(chest, radius: h * 0.04, color("chest"))
            fill(core, radius: h * 0.04, color("core"))
            fill(armL, radius: w * 0.06, color("arms"))
            fill(armR, radius: w * 0.06, color("arms"))
            fill(legL, radius: w * 0.07, color("legs"))
            fill(legR, radius: w * 0.07, color("legs"))

            if group == .back {
                // 背骨の線で「後ろ側」を表す
                var spine = Path()
                spine.move(to: CGPoint(x: w * 0.5, y: h * 0.13))
                spine.addLine(to: CGPoint(x: w * 0.5, y: h * 0.46))
                context.stroke(spine, with: .color(.white.opacity(0.9)), style: StrokeStyle(lineWidth: max(1, w * 0.04), lineCap: .round, dash: [2, 2]))
            }
        }
        .frame(width: height / 2.2, height: height)
        .accessibilityLabel("鍛える部位: \(group.rawValue)")
    }
}

/// 部位の色のチップ（例: ● 脚）
struct MuscleChip: View {
    let group: MuscleGroup

    var body: some View {
        HStack(spacing: 4) {
            Circle().fill(group.color).frame(width: 7, height: 7)
            Text(group.rawValue)
        }
        .font(.caption2.bold())
        .padding(.horizontal, 7)
        .padding(.vertical, 3)
        .background(group.color.opacity(0.14), in: Capsule())
        .foregroundStyle(group.color)
    }
}
