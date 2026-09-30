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
