import Foundation
import Observation

/// 論文要約・グラフ・テーマ・公開OKの状態をまとめて扱う。
///
/// 表示のルール: approvals.json（アプリ同梱）か、開発用の確認画面で「公開OK」にした論文だけを表示する。
/// 要約データ（summaries.json）そのものは書き換えない。
@MainActor
@Observable
final class StudyStore {
    struct ThemeSummary: Identifiable, Hashable {
        let field: String
        let theme: String
        let question: String
        /// ★の多い順
        let studies: [Study]
        var id: String { field + "/" + theme }
        var maxStars: Int { studies.map(\.stars).max() ?? 0 }
        /// いちばん確かな研究（★が最多）の答えを、テーマの答えとして見せる
        var lead: Study? { studies.first }

        func count(of verdict: Verdict) -> Int { studies.filter { $0.verdictKind == verdict }.count }
    }

    private static let bookmarksKey = "studyBookmarks"
    private static let localApprovalsKey = "localApprovals"
    static let showPendingKey = "showPendingStudies"

    let allStudies: [Study]
    let fieldOrder: [String]
    private let charts: [String: StudyChart]
    private let menus: [String: StudyMenu]
    private let questions: [String: String]
    private let bundledApprovals: [String: Approval]

    /// 開発用の確認画面で付けた印（端末に保存）。書き出して approvals.json に反映する。
    private(set) var localApprovals: [String: Approval]
    private(set) var bookmarks: Set<String>
    /// 開発用: 確認待ちも表示する
    var showPending: Bool {
        didSet {
            UserDefaults.standard.set(showPending, forKey: Self.showPendingKey)
            refreshVisibility()
        }
    }

    /// 同梱分と端末の印をあわせた現在の状態（端末の印が優先）。印が変わったときだけ作り直す。
    private(set) var approvals: [String: Approval] = [:]
    /// アプリに表示する論文。印や設定が変わったときだけ作り直す（毎回計算すると重いため）。
    private(set) var visibleStudies: [Study] = []

    init(bundle: Bundle = .main) {
        let decoder = StudyJSON.decoder()
        func load<T: Decodable>(_ name: String, as type: T.Type) -> T? {
            guard let url = bundle.url(forResource: name, withExtension: "json"),
                  let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(T.self, from: data)
        }
        allStudies = load("summaries", as: [Study].self) ?? []
        charts = Dictionary((load("charts", as: [StudyChart].self) ?? []).map { ($0.pmid, $0) },
                            uniquingKeysWith: { first, _ in first })
        menus = Dictionary((load("menus", as: [StudyMenu].self) ?? []).map { ($0.pmid, $0) },
                           uniquingKeysWith: { first, _ in first })
        let catalog = load("themes", as: ThemeCatalog.self)
        fieldOrder = catalog?.fieldOrder ?? []
        questions = Dictionary((catalog?.themes ?? []).map { ($0.field + "/" + $0.theme, $0.question) },
                               uniquingKeysWith: { first, _ in first })
        // approvals.json のキーは pmid なので、キー変換をしない素のデコーダーで読む
        if let url = bundle.url(forResource: "approvals", withExtension: "json"),
           let data = try? Data(contentsOf: url) {
            bundledApprovals = (try? JSONDecoder().decode([String: Approval].self, from: data)) ?? [:]
        } else {
            bundledApprovals = [:]
        }

        let defaults = UserDefaults.standard
        localApprovals = defaults.data(forKey: Self.localApprovalsKey)
            .flatMap { try? JSONDecoder().decode([String: Approval].self, from: $0) } ?? [:]
        bookmarks = Set(defaults.stringArray(forKey: Self.bookmarksKey) ?? [])
        #if DEBUG
        showPending = defaults.bool(forKey: Self.showPendingKey)
        #else
        showPending = false
        #endif
        refreshVisibility()
    }

    private func refreshVisibility() {
        let merged = bundledApprovals.merging(localApprovals) { _, local in local }
        approvals = merged
        visibleStudies = showPending ? allStudies : allStudies.filter { merged[$0.pmid]?.status == Approval.published }
    }

    // MARK: - 公開OKの管理

    func approval(for study: Study) -> Approval? { approvals[study.pmid] }

    func isPublished(_ study: Study) -> Bool { approval(for: study)?.status == Approval.published }

    var publishedCount: Int { approvals.values.filter { $0.status == Approval.published }.count }

    /// 開発用の確認画面から呼ぶ。nil で印を外す。
    func setApproval(_ status: String?, for study: Study) {
        if let status {
            localApprovals[study.pmid] = Approval(status: status, date: Date.now.formatted(.iso8601.year().month().day()))
        } else {
            localApprovals[study.pmid] = nil
        }
        if let data = try? JSONEncoder().encode(localApprovals) {
            UserDefaults.standard.set(data, forKey: Self.localApprovalsKey)
        }
        refreshVisibility()
    }

    /// approvals.json として書き出す内容（同梱分＋端末の印）。
    func approvalsFile() -> ApprovalsFile {
        let data = (try? StudyJSON.encoder().encode(approvals)) ?? Data("{}".utf8)
        return ApprovalsFile(data: data)
    }

    // MARK: - 表示用

    func chart(for study: Study) -> StudyChart? { charts[study.pmid] }

    /// 論文のメニュー。App Store 版では「公開OK」のメニューだけ、開発用ビルドでは確認待ちも出す。
    func menu(for study: Study) -> StudyMenu? {
        guard let menu = menus[study.pmid] else { return nil }
        #if DEBUG
        return menu
        #else
        return menu.isPublished ? menu : nil
        #endif
    }

    func study(pmid: String) -> Study? { allStudies.first { $0.pmid == pmid } }

    func question(for study: Study) -> String {
        questions[study.field + "/" + study.theme] ?? study.theme
    }

    /// 表示中の論文をテーマごとにまとめる（分野の並び順 → 本数の多い順）。
    func themeSummaries(minStars: Int = 0, field: String? = nil) -> [ThemeSummary] {
        let studies = visibleStudies.filter { $0.stars >= minStars && (field == nil || $0.field == field) }
        let groups = Dictionary(grouping: studies) { $0.field + "/" + $0.theme }
        return groups.values.compactMap { group -> ThemeSummary? in
            guard let first = group.first else { return nil }
            return ThemeSummary(field: first.field, theme: first.theme,
                                question: questions[first.field + "/" + first.theme] ?? first.theme,
                                studies: group.sorted { $0.stars > $1.stars })
        }
        .sorted { first, second in
            let a: Int = fieldOrder.firstIndex(of: first.field) ?? Int.max
            let b: Int = fieldOrder.firstIndex(of: second.field) ?? Int.max
            if a != b { return a < b }
            return first.studies.count > second.studies.count
        }
    }

    /// 表示中の論文がある分野（決められた並び順）。
    var visibleFields: [String] {
        let present = Set(visibleStudies.map(\.field))
        return fieldOrder.filter(present.contains)
    }

    /// 日替わりの1本。★4以上があればその中から選ぶ。
    func studyOfTheDay(calendar: Calendar = .current, date: Date = .now) -> Study? {
        let strong = visibleStudies.filter { $0.stars >= 4 }
        let pool = strong.isEmpty ? visibleStudies : strong
        guard !pool.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return pool[day % pool.count]
    }

    /// 種目に関係する論文（一致する言葉が多い順 → ★の多い順）。
    func related(to exercise: Exercise, limit: Int = 5) -> [Study] {
        struct Scored {
            let study: Study
            let score: Int
        }
        let keywords = StudyMatcher.keywords(for: exercise)
        let scored: [Scored] = visibleStudies.compactMap { study in
            let score = study.matchTerms.intersection(keywords).count
            return score > 0 ? Scored(study: study, score: score) : nil
        }
        let sorted = scored.sorted { a, b in
            if a.score != b.score { return a.score > b.score }
            return a.study.stars > b.study.stars
        }
        return sorted.prefix(limit).map(\.study)
    }

    // MARK: - 保存

    func isBookmarked(_ study: Study) -> Bool { bookmarks.contains(study.pmid) }

    func toggleBookmark(_ study: Study) {
        if bookmarks.remove(study.pmid) == nil { bookmarks.insert(study.pmid) }
        UserDefaults.standard.set(Array(bookmarks), forKey: Self.bookmarksKey)
    }
}

/// 種目 → 論文データの言葉（分野・テーマ・タグ）への対応。
enum StudyMatcher {
    static func keywords(for exercise: Exercise) -> Set<String> {
        var words: Set<String> = []
        switch exercise.group {
        case .legs: words.formUnion(["筋トレ", "スクワット", "筋トレと足の速さ"])
        case .sprint: words.formUnion(["走る", "ダッシュ", "スプリント", "短距離"])
        case .plyometric: words.formUnion(["跳ぶ", "ジャンプ", "跳ねる運動", "ジャンプ練習と足の速さ"])
        case .core: words.formUnion(["体幹", "体幹トレーニング"])
        case .cardio: words.formUnion(["持久力", "インターバル走", "ランニングエコノミー"])
        case .chest, .back, .shoulders, .arms: words.insert("筋トレ")
        }
        if exercise.tracking == .weightReps { words.formUnion(["速さを見ながら筋トレ（VBT）", "重いものと軽いものを交互に"]) }
        if exercise.tracking == .reps && exercise.group != .plyometric { words.insert("自分の体重で筋トレ") }

        let name = exercise.name
        let byName: [(String, [String])] = [
            ("ブルガリアン", ["片脚トレーニング", "片脚"]),
            ("片脚", ["片脚トレーニング", "片脚"]),
            ("ノルディック", ["ゆっくり下ろす練習（エキセントリック）", "もも裏"]),
            ("坂道", ["坂道ダッシュ"]),
            ("そり", ["ソリを引くダッシュ"]),
            ("10m", ["スタート・加速"]),
            ("30m", ["スタート・加速"]),
            ("60m", ["最高スピード"]),
            ("クリーン", ["重いものと軽いものを交互に"]),
            ("メディシン", ["メディシンボール", "投げるスピード"]),
        ]
        for (key, terms) in byName where name.contains(key) { words.formUnion(terms) }
        return words
    }
}
