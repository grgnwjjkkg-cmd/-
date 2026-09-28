import Foundation

/// 論文1本の要約（はしりラボの summaries.json と同じ形）。
struct Study: Codable, Identifiable, Hashable {
    struct Citation: Codable, Hashable {
        var firstAuthor: String
        var year: String
        var journal: String
        var titleEn: String
    }

    var pmid: String
    var doi: String?
    var field: String
    var theme: String
    /// データ上の状態。アプリでの表示可否は approvals で決める（StudyStore 参照）
    var status: String?
    var basis: String?
    var checked: String?
    var headline: String
    var oneLine: String
    var forWhom: String
    var design: String
    var who: String
    var what: String
    var period: String?
    var results: [String]
    var howToUse: [String]
    var limitations: [String]
    var stars: Int
    var starsReason: String
    var verdict: String
    var tags: [String]
    var citation: Citation

    var id: String { pmid }
    var pubmedURL: URL? { URL(string: "https://pubmed.ncbi.nlm.nih.gov/\(pmid)/") }
    var verdictKind: Verdict { Verdict(rawValue: verdict) ?? .unknown }

    /// 種目とのひも付けや検索に使う言葉。
    var matchTerms: Set<String> { Set(tags).union([field, theme]) }

    func contains(_ text: String) -> Bool {
        [headline, oneLine, theme, field, forWhom].contains { $0.localizedStandardContains(text) }
            || tags.contains { $0.localizedStandardContains(text) }
    }
}

/// 研究の答え。
enum Verdict: String, CaseIterable {
    case yes = "はい"
    case probably = "たぶん はい"
    case unknown = "まだ分からない"
    case no = "効果はなさそう"
}

/// グラフ1本分（charts.json）。数字は論文の要旨の原文（quote）と照合済み。
struct StudyChart: Codable, Hashable {
    struct Bar: Codable, Hashable, Identifiable {
        var label: String
        var value: Double
        /// practice / after はメインの色、compare / before はグレー
        var kind: String
        var id: String { label }
        var isMain: Bool { kind == "practice" || kind == "after" }
    }

    var pmid: String
    var chartTitle: String
    var unit: String
    var bars: [Bar]
    var lowerIsBetter: Bool
    var note: String
    var quote: String
}

/// テーマ（質問の形）の一覧。
struct ThemeCatalog: Codable {
    struct Theme: Codable, Hashable {
        var field: String
        var theme: String
        var question: String
    }

    var fieldOrder: [String]
    var themes: [Theme]
}

/// 人が確認した結果（pmid ごと）。"公開OK" のものだけアプリに表示する。
struct Approval: Codable, Hashable {
    static let published = "公開OK"
    static let onHold = "保留"

    var status: String
    var date: String
}

enum StudyJSON {
    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return decoder
    }

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
