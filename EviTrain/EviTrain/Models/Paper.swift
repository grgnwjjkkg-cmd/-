import Foundation

/// 論文要約サイトが配信する JSON 全体。形式は docs/papers-feed.md を参照。
struct PaperFeed: Codable {
    var version: Int
    var updatedAt: String?
    var papers: [Paper]
}

struct Paper: Codable, Identifiable, Hashable {
    var id: String
    /// 日本語の見出し（例:「週あたりのセット数が多いほど筋肉は大きくなる」）
    var title: String
    var originalTitle: String?
    var authors: String?
    var journal: String?
    var year: Int?
    var doi: String?
    /// 要約サイト上の記事URL
    var url: String?
    /// 大分類（例: "筋肥大", "スピード", "栄養"）
    var category: String
    /// 種目とのひも付け用タグ
    var tags: [String]
    /// 研究デザイン（例: "メタ分析", "ランダム化比較試験"）
    var studyType: String?
    var summary: String
    var keyPoints: [String]
    /// トレーニングへの活かし方
    var practical: String?
    /// 論文の内容をアプリの設定にワンタップで反映するボタン
    var action: PaperAction?

    var doiURL: URL? { doi.flatMap { URL(string: "https://doi.org/\($0)") } }
    var articleURL: URL? { url.flatMap(URL.init(string:)) }

    var citation: String {
        [authors, journal, year.map(String.init)].compactMap { $0 }.joined(separator: " / ")
    }

    /// 種目のキーワードとの一致数（関連度）。
    func relevance(to keywords: Set<String>) -> Int {
        Set(tags).union([category]).intersection(keywords).count
    }
}

/// 論文から実行できる操作。未知の kind は無視されるよう文字列で持つ。
struct PaperAction: Codable, Hashable {
    enum Kind: String {
        /// 休憩タイマーの秒数を value にする
        case restTimer
        /// 部位ごとの週の目標セット数を value にする
        case weeklySets
    }

    var kind: String
    var value: Double
    var label: String

    var knownKind: Kind? { Kind(rawValue: kind) }
}
