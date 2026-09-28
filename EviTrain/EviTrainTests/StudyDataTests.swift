import SwiftData
import XCTest
@testable import EviTrain

/// 同梱の論文データ（summaries / charts / themes / approvals）が正しく読めて、ルールを守っているかを確かめる。
final class StudyDataTests: XCTestCase {
    private func data(_ name: String) throws -> Data {
        let url = try XCTUnwrap(Bundle.main.url(forResource: name, withExtension: "json"), "\(name).json がアプリに入っていない")
        return try Data(contentsOf: url)
    }

    func testSummariesDecode() throws {
        let studies = try StudyJSON.decoder().decode([Study].self, from: data("summaries"))
        XCTAssertEqual(studies.count, 714)
        XCTAssertEqual(Set(studies.map(\.pmid)).count, studies.count, "pmid が重複している")
        for study in studies {
            XCTAssertTrue((1...5).contains(study.stars), "\(study.pmid) の★が1〜5ではない")
            XCTAssertNotNil(Verdict(rawValue: study.verdict), "\(study.pmid) の研究の答えが4種類のどれでもない")
            XCTAssertFalse(study.headline.isEmpty)
            XCTAssertFalse(study.oneLine.isEmpty)
        }
    }

    func testChartsMatchQuotes() throws {
        let studies = try StudyJSON.decoder().decode([Study].self, from: data("summaries"))
        let charts = try StudyJSON.decoder().decode([StudyChart].self, from: data("charts"))
        let ids = Set(studies.map(\.pmid))
        XCTAssertFalse(charts.isEmpty)
        for chart in charts {
            XCTAssertTrue(ids.contains(chart.pmid), "グラフ \(chart.pmid) の論文が要約にない")
            for bar in chart.bars {
                let number = abs(bar.value).formatted(.number.grouping(.never).locale(Locale(identifier: "en_US")))
                XCTAssertTrue(chart.quote.contains(number), "グラフ \(chart.pmid) の数字 \(number) が要旨の原文にない")
            }
        }
    }

    func testEveryThemeHasQuestion() throws {
        let studies = try StudyJSON.decoder().decode([Study].self, from: data("summaries"))
        let catalog = try StudyJSON.decoder().decode(ThemeCatalog.self, from: data("themes"))
        let known = Set(catalog.themes.map { $0.field + "/" + $0.theme })
        for study in studies {
            XCTAssertTrue(known.contains(study.field + "/" + study.theme), "\(study.field)/\(study.theme) の質問文がない")
            XCTAssertTrue(catalog.fieldOrder.contains(study.field))
        }
    }

    func testApprovalsFileDecodes() throws {
        XCTAssertNoThrow(try JSONDecoder().decode([String: Approval].self, from: data("approvals")))
    }

    @MainActor
    func testOnlyPublishedStudiesAreVisible() throws {
        let store = StudyStore()
        store.showPending = false
        let study = try XCTUnwrap(store.allStudies.first { store.approval(for: $0) == nil })
        XCTAssertFalse(store.visibleStudies.contains(study), "確認待ちの論文が表示されている")

        store.setApproval(Approval.published, for: study)
        XCTAssertTrue(store.visibleStudies.contains(study))
        XCTAssertNotNil(store.studyOfTheDay())

        store.setApproval(Approval.onHold, for: study)
        XCTAssertFalse(store.visibleStudies.contains(study), "保留の論文が表示されている")

        store.setApproval(nil, for: study)
        XCTAssertFalse(store.visibleStudies.contains(study))
    }
}

/// 記録まわりの計算。
final class StatsTests: XCTestCase {
    func testEstimated1RMAndSpeed() {
        let heavy = SetRecord(order: 0, weight: 100, reps: 1)
        XCTAssertEqual(heavy.estimated1RM, 100)
        let set = SetRecord(order: 0, weight: 60, reps: 10)
        XCTAssertEqual(set.estimated1RM, 80, accuracy: 0.001)
        let dash = SetRecord(order: 0, seconds: 4.5, meters: 30)
        XCTAssertEqual(dash.speedKmh ?? 0, 24, accuracy: 0.001)
        XCTAssertNil(SetRecord(order: 0).speedKmh)
    }

    @MainActor
    func testStreakDays() throws {
        let container = try ModelContainer(for: Workout.self, WorkoutEntry.self, SetRecord.self, Exercise.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let calendar = Calendar(identifier: .gregorian)
        let now = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 9, day: 30, hour: 12)))
        let workouts = [0, 1, 2, 4].map { daysAgo -> Workout in
            let workout = Workout(startedAt: calendar.date(byAdding: .day, value: -daysAgo, to: now)!)
            container.mainContext.insert(workout)
            return workout
        }
        XCTAssertEqual(Stats.streakDays(workouts, calendar: calendar, now: now), 3)
        XCTAssertEqual(Stats.streakDays(Array(workouts.dropFirst()), calendar: calendar, now: now), 2, "昨日までの連続も数える")
    }
}
