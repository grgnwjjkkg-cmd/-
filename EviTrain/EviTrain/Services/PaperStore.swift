import Foundation
import Observation

/// 論文データの読み込み・キャッシュ・ブックマークを管理する。
/// 読み込み順: 端末のキャッシュ → アプリ同梱のサンプル → 設定されたURLから最新を取得。
@MainActor
@Observable
final class PaperStore {
    enum Source: String {
        case bundled = "サンプル"
        case cache = "保存済み"
        case remote = "最新"
    }

    static let feedURLKey = "papersFeedURL"
    private static let bookmarksKey = "paperBookmarks"

    private(set) var papers: [Paper] = []
    private(set) var source: Source = .bundled
    private(set) var isLoading = false
    private(set) var lastError: String?
    private(set) var bookmarks: Set<String>

    private let cacheURL = URL.applicationSupportDirectory.appending(path: "papers.json")

    init() {
        bookmarks = Set(UserDefaults.standard.stringArray(forKey: Self.bookmarksKey) ?? [])
        if let cached = try? Self.decode(Data(contentsOf: cacheURL)) {
            papers = cached.papers
            source = .cache
        } else if let url = Bundle.main.url(forResource: "papers_sample", withExtension: "json"),
                  let bundled = try? Self.decode(Data(contentsOf: url)) {
            papers = bundled.papers
            source = .bundled
        }
    }

    var categories: [String] {
        var seen = Set<String>()
        return papers.map(\.category).filter { seen.insert($0).inserted }
    }

    /// 日替わりで1本選ぶ（同じ日は同じ論文）。
    func paperOfTheDay(calendar: Calendar = .current, date: Date = .now) -> Paper? {
        guard !papers.isEmpty else { return nil }
        let day = calendar.ordinality(of: .day, in: .era, for: date) ?? 0
        return papers[day % papers.count]
    }

    func isBookmarked(_ paper: Paper) -> Bool { bookmarks.contains(paper.id) }

    func toggleBookmark(_ paper: Paper) {
        if bookmarks.remove(paper.id) == nil { bookmarks.insert(paper.id) }
        UserDefaults.standard.set(Array(bookmarks), forKey: Self.bookmarksKey)
    }

    /// 種目に関連する論文を関連度の高い順に返す。
    func related(to exercise: Exercise, limit: Int = 5) -> [Paper] {
        let keywords = exercise.paperKeywords
        return papers
            .map { ($0, $0.relevance(to: keywords)) }
            .filter { $0.1 > 0 }
            .sorted { $0.1 > $1.1 }
            .prefix(limit)
            .map(\.0)
    }

    /// 設定画面で入力されたURLから最新の論文一覧を取得する。
    func refresh() async {
        let raw = UserDefaults.standard.string(forKey: Self.feedURLKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !raw.isEmpty else { return }
        guard let url = URL(string: raw), url.scheme == "https" else {
            lastError = "URLは https:// から始まる形で入力してください"
            return
        }
        isLoading = true
        defer { isLoading = false }
        do {
            let (data, response) = try await URLSession.shared.data(from: url)
            if let http = response as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                throw URLError(.badServerResponse)
            }
            let feed = try Self.decode(data)
            papers = feed.papers
            source = .remote
            lastError = nil
            try? FileManager.default.createDirectory(
                at: cacheURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try? data.write(to: cacheURL, options: .atomic)
        } catch is DecodingError {
            lastError = "論文データの形式が正しくありません"
        } catch {
            lastError = "論文を読み込めませんでした（\(error.localizedDescription)）"
        }
    }

    private static func decode(_ data: Data) throws -> PaperFeed {
        try JSONDecoder().decode(PaperFeed.self, from: data)
    }
}
