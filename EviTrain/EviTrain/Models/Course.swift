import SwiftUI

/// 目的別のコース。選んだコースで、記録画面・ストップウォッチ・おすすめメニュー・「今日の根拠」が変わる。
enum Course: String, CaseIterable, Identifiable {
    case speed
    case soccer
    case muscle

    /// 選んだコースの保存先（未選択は空文字）
    static let storageKey = "course"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .speed: "足を速くする"
        case .soccer: "サッカー"
        case .muscle: "筋肉を大きくする"
        }
    }

    var tagline: String {
        switch self {
        case .speed: "ダッシュのタイムを測って、速くなった根拠を見る"
        case .soccer: "加速・切り返し・ジャンプ。サッカーの研究で組み立てる"
        case .muscle: "重さと回数を記録して、週のセット数を整える"
        }
    }

    var symbol: String {
        switch self {
        case .speed: "figure.run"
        case .soccer: "soccerball"
        case .muscle: "dumbbell.fill"
        }
    }

    /// コースの色（カードの背景のグラデーション用）
    var colors: [Color] {
        switch self {
        case .speed: [Color(red: 0.12, green: 0.31, blue: 0.58), Color(red: 0.20, green: 0.55, blue: 0.85)]
        case .soccer: [Color(red: 0.10, green: 0.42, blue: 0.27), Color(red: 0.25, green: 0.68, blue: 0.42)]
        case .muscle: [Color(red: 0.62, green: 0.20, blue: 0.10), Color(red: 0.93, green: 0.45, blue: 0.20)]
        }
    }

    /// ストップウォッチを使うコースか
    var usesStopwatch: Bool { self != .muscle }

    /// このコースに関係する論文のタグ（強く一致）
    var paperTags: Set<String> {
        switch self {
        case .speed: ["スプリント", "ダッシュ", "短距離", "ジャンプ", "陸上", "くり返しダッシュ", "ソリ引き", "跳ねる運動"]
        case .soccer: ["サッカー", "フットサル", "切り返し", "方向転換", "スプリント", "ジャンプ"]
        case .muscle: ["筋トレ", "体幹"]
        }
    }

    /// このコースに関係する論文の分野（弱く一致）
    var paperFields: Set<String> {
        switch self {
        case .speed: ["走る", "跳ぶ"]
        case .soccer: ["競技別", "切り返し", "走る"]
        case .muscle: ["筋力"]
        }
    }

    /// 「このコースで始める」で並べる種目（ExerciseCatalog の名前）
    var starterExercises: [String] {
        switch self {
        case .speed: ["30mダッシュ", "そり引きダッシュ", "スクワット", "ボックスジャンプ"]
        case .soccer: ["10mダッシュ", "30mダッシュ", "ブルガリアンスクワット", "ノルディックハムストリング"]
        case .muscle: ["ベンチプレス", "ラットプルダウン", "スクワット", "ショルダープレス"]
        }
    }

    /// ストップウォッチで最初に選ぶ距離（m）
    var defaultDistance: Double {
        switch self {
        case .speed: 30
        case .soccer: 10
        case .muscle: 0
        }
    }

    /// 選んだコースを読む（未選択なら nil）
    static func stored(_ raw: String) -> Course? { Course(rawValue: raw) }
}

/// コースの「基本メニュー」。論文の研究ではなく、よくある組み立ての目安。種目は ExerciseCatalog の名前だけを使う。
struct CoursePreset: Identifiable {
    struct Item {
        let exercise: String
        let sets: Int
        var reps: Int = 0
        var meters: Double = 0
        var seconds: Double = 0
        var rest: Double?
    }

    let name: String
    let summary: String
    let items: [Item]

    var id: String { name }
    var exerciseNames: String { items.map(\.exercise).joined(separator: "・") }
}

extension Course {
    var presets: [CoursePreset] {
        switch self {
        case .muscle: [
            CoursePreset(name: "胸・肩・腕の日", summary: "押す動きの日。1部位あたり週10セット前後が目安です。", items: [
                .init(exercise: "ベンチプレス", sets: 3, reps: 8, rest: 120),
                .init(exercise: "インクラインダンベルプレス", sets: 3, reps: 10, rest: 90),
                .init(exercise: "ショルダープレス", sets: 3, reps: 10, rest: 90),
                .init(exercise: "サイドレイズ", sets: 3, reps: 12, rest: 60),
                .init(exercise: "トライセプスエクステンション", sets: 3, reps: 12, rest: 60),
            ]),
            CoursePreset(name: "背中・腕の日", summary: "引く動きの日。", items: [
                .init(exercise: "デッドリフト", sets: 3, reps: 5, rest: 150),
                .init(exercise: "ラットプルダウン", sets: 3, reps: 10, rest: 90),
                .init(exercise: "ベントオーバーロウ", sets: 3, reps: 10, rest: 90),
                .init(exercise: "シーテッドロウ", sets: 3, reps: 12, rest: 60),
                .init(exercise: "バーベルカール", sets: 3, reps: 12, rest: 60),
            ]),
            CoursePreset(name: "脚・体幹の日", summary: "脚と体幹の日。", items: [
                .init(exercise: "スクワット", sets: 3, reps: 8, rest: 150),
                .init(exercise: "ルーマニアンデッドリフト", sets: 3, reps: 10, rest: 120),
                .init(exercise: "レッグプレス", sets: 3, reps: 12, rest: 90),
                .init(exercise: "カーフレイズ", sets: 3, reps: 15, rest: 60),
                .init(exercise: "プランク", sets: 3, seconds: 45, rest: 60),
            ]),
            CoursePreset(name: "全身（週2回）", summary: "時間がない人向け。1回で全身を回します。", items: [
                .init(exercise: "スクワット", sets: 3, reps: 8, rest: 120),
                .init(exercise: "ベンチプレス", sets: 3, reps: 8, rest: 120),
                .init(exercise: "ベントオーバーロウ", sets: 3, reps: 10, rest: 90),
                .init(exercise: "ショルダープレス", sets: 2, reps: 10, rest: 90),
                .init(exercise: "プランク", sets: 2, seconds: 45, rest: 60),
            ]),
        ]
        case .speed: [
            CoursePreset(name: "加速ダッシュの日", summary: "スタートから10〜30mの加速をのばす日。しっかり休んで全力で。", items: [
                .init(exercise: "10mダッシュ", sets: 6, meters: 10, rest: 120),
                .init(exercise: "30mダッシュ", sets: 4, meters: 30, rest: 180),
                .init(exercise: "そり引きダッシュ", sets: 4, meters: 20, rest: 150),
                .init(exercise: "スクワット", sets: 3, reps: 5, rest: 150),
            ]),
            CoursePreset(name: "最大速度の日", summary: "60mで最高速度に乗せる日。", items: [
                .init(exercise: "30mダッシュ", sets: 3, meters: 30, rest: 150),
                .init(exercise: "60mダッシュ", sets: 4, meters: 60, rest: 240),
                .init(exercise: "ノルディックハムストリング", sets: 3, reps: 5, rest: 120),
                .init(exercise: "ヒップスラスト", sets: 3, reps: 8, rest: 120),
            ]),
            CoursePreset(name: "ジャンプ・パワーの日", summary: "跳ぶ力と爆発力を鍛える日。", items: [
                .init(exercise: "ボックスジャンプ", sets: 4, reps: 5, rest: 90),
                .init(exercise: "バウンディング", sets: 4, reps: 6, rest: 90),
                .init(exercise: "立ち幅跳び", sets: 3, reps: 5, rest: 90),
                .init(exercise: "パワークリーン", sets: 4, reps: 3, rest: 150),
            ]),
            CoursePreset(name: "坂道ダッシュの日", summary: "坂で前傾を作って加速を身につける日。", items: [
                .init(exercise: "坂道ダッシュ", sets: 8, meters: 20, rest: 90),
                .init(exercise: "ヒップスラスト", sets: 3, reps: 10, rest: 90),
            ]),
        ]
        case .soccer: [
            CoursePreset(name: "加速・切り返しの日", summary: "短いダッシュをくり返して、試合の動きに近づける日。", items: [
                .init(exercise: "10mダッシュ", sets: 8, meters: 10, rest: 60),
                .init(exercise: "30mダッシュ", sets: 4, meters: 30, rest: 120),
                .init(exercise: "ブルガリアンスクワット", sets: 3, reps: 8, rest: 90),
                .init(exercise: "ボックスジャンプ", sets: 3, reps: 5, rest: 90),
            ]),
            CoursePreset(name: "ケガ予防＋脚力の日", summary: "ハムストリングと体幹でケガを減らす日。", items: [
                .init(exercise: "ノルディックハムストリング", sets: 3, reps: 6, rest: 120),
                .init(exercise: "ヒップスラスト", sets: 3, reps: 10, rest: 90),
                .init(exercise: "ルーマニアンデッドリフト", sets: 3, reps: 8, rest: 120),
                .init(exercise: "プランク", sets: 3, seconds: 45, rest: 60),
            ]),
            CoursePreset(name: "くり返しダッシュの日", summary: "短い休みでくり返し走る力（スプリントをくり返す力）を作る日。", items: [
                .init(exercise: "30mダッシュ", sets: 10, meters: 30, rest: 30),
                .init(exercise: "バウンディング", sets: 3, reps: 6, rest: 90),
            ]),
        ]
        }
    }
}

extension StudyStore {
    /// コースに関係する論文（タグの一致 → 分野の一致 → ★の多い順）。
    func studies(for course: Course, limit: Int = 5) -> [Study] {
        struct Scored {
            let study: Study
            let score: Int
        }
        let scored: [Scored] = visibleStudies.compactMap { study in
            let tagHits = Set(study.tags).intersection(course.paperTags).count
            let fieldHit = course.paperFields.contains(study.field) ? 1 : 0
            let score = tagHits * 2 + fieldHit
            return tagHits > 0 ? Scored(study: study, score: score) : nil
        }
        let sorted = scored.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.study.stars > b.study.stars
        }
        return sorted.prefix(limit).map(\.study)
    }

    /// コースの「今日の根拠」（★4以上の中から日替わりで1本）。
    func studyOfTheDay(for course: Course, calendar: Calendar = .current, date: Date = .now) -> Study? {
        let all = studies(for: course, limit: 60)
        let strong = all.filter { $0.stars >= 4 }
        let pool = strong.isEmpty ? all : strong
        guard !pool.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[day % pool.count]
    }
}
