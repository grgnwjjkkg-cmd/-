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
        let study = try XCTUnwrap(store.allStudies.first)
        XCTAssertTrue(store.isPublished(study), "同梱の approvals.json で公開OKになっているはず")
        XCTAssertTrue(store.visibleStudies.contains(study))
        XCTAssertNotNil(store.studyOfTheDay())

        store.setApproval(Approval.onHold, for: study)
        XCTAssertFalse(store.visibleStudies.contains(study), "保留の論文が表示されている")

        store.setApproval(nil, for: study)
        XCTAssertTrue(store.visibleStudies.contains(study), "印を外すと同梱の状態（公開OK）に戻る")
    }

    @MainActor
    func testThemeAnswerUsesReviewNotOffTopicStudy() throws {
        let store = StudyStore()
        let hill = try XCTUnwrap(store.themeSummaries().first { $0.theme == "坂道ダッシュ" })
        // ★4 同士でも、本題から外れた実験（効果はなさそう）ではなく、まとめ研究（たぶん はい）を答えにする
        XCTAssertEqual(hill.answer.verdict, .probably)
        XCTAssertTrue(hill.answer.lead?.design.contains("まとめ研究") ?? false)
        XCTAssertEqual(hill.lead?.pmid, hill.answer.lead?.pmid, "一覧の答えと、先頭に出す研究が一致する")
    }

    func testMenusMatchQuotesAndStudies() throws {
        let studies = try StudyJSON.decoder().decode([Study].self, from: data("summaries"))
        let menus = try StudyJSON.decoder().decode([StudyMenu].self, from: data("menus"))
        let ids = Set(studies.map(\.pmid))
        XCTAssertFalse(menus.isEmpty)
        XCTAssertEqual(Set(menus.map(\.pmid)).count, menus.count, "メニューの pmid が重複している")
        for menu in menus {
            XCTAssertTrue(ids.contains(menu.pmid), "メニュー \(menu.pmid) の論文が要約にない")
            XCTAssertFalse(menu.items.isEmpty, "メニュー \(menu.pmid) に種目がない")
            XCTAssertFalse(menu.quote.isEmpty)
            for item in menu.items {
                XCTAssertTrue(["weightReps", "reps", "time", "distanceTime"].contains(item.tracking), "\(menu.pmid) の tracking が不正")
                XCTAssertNotNil(MuscleGroup(rawValue: item.group), "\(menu.pmid) の部位 \(item.group) が不正")
            }
        }
    }
}

/// 記録まわりの計算。
final class StatsTests: XCTestCase {
    @MainActor
    func testMenuFromStudyAndStartWorkout() throws {
        let container = try ModelContainer(for: Exercise.self, Workout.self, WorkoutEntry.self, SetRecord.self,
                                           MenuTemplate.self, MenuItem.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        context.insert(Exercise(name: "スクワット", group: .legs, tracking: .weightReps))
        let studyMenu = StudyMenu(
            pmid: "1", status: "確認待ち", checked: "AI点検済み", name: "テスト", groupLabel: nil, weeks: 8, perWeek: 2,
            items: [
                .init(exercise: "スクワット", tracking: "weightReps", group: "脚", sets: 3, reps: 8, meters: nil,
                      seconds: nil, restSeconds: 120, load: "最大の80%", note: ""),
                .init(exercise: "20mダッシュ", tracking: "distanceTime", group: "スプリント", sets: 4, reps: nil, meters: 20,
                      seconds: nil, restSeconds: nil, load: "全力", note: ""),
            ],
            quote: "q", caution: "c")
        let template = MenuBuilder.addMenu(studyMenu, in: context)
        XCTAssertEqual(template.sortedItems.map { $0.exercise?.name }, ["スクワット", "20mダッシュ"])
        XCTAssertEqual(template.sortedItems.first?.exercise?.isCustom, false, "標準種目を使う")
        XCTAssertEqual(template.sortedItems.last?.exercise?.isCustom, true, "無い種目は自作種目として作る")

        let workout = MenuBuilder.startWorkout(from: template, in: context)
        XCTAssertEqual(workout.sortedEntries.count, 2)
        XCTAssertEqual(workout.sortedEntries.first?.sets.count, 3)
        XCTAssertEqual(workout.sortedEntries.first?.restSeconds, 120)
        XCTAssertEqual(workout.sortedEntries.last?.sortedSets.first?.meters, 20)
        XCTAssertEqual(workout.menuName, "テスト")
    }

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
    func testFinishSummaryComparesWithPreviousWorkout() throws {
        let container = try ModelContainer(for: Exercise.self, Workout.self, WorkoutEntry.self, SetRecord.self,
                                           MenuTemplate.self, MenuItem.self,
                                           configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        let context = container.mainContext
        let squat = Exercise(name: "スクワット", group: .legs, tracking: .weightReps)
        context.insert(squat)
        func workout(daysAgo: Double, weight: Double) -> Workout {
            let workout = Workout(startedAt: Date.now.addingTimeInterval(-daysAgo * 86_400))
            context.insert(workout)
            let entry = WorkoutEntry(order: 0, exercise: squat)
            context.insert(entry)
            entry.workout = workout
            let set = SetRecord(order: 0, weight: weight, reps: 10)
            set.isDone = true
            context.insert(set)
            set.entry = entry
            workout.finishedAt = workout.startedAt.addingTimeInterval(3600)
            return workout
        }
        _ = workout(daysAgo: 2, weight: 60)
        let today = workout(daysAgo: 0, weight: 62.5)
        try context.save()

        let summary = Stats.finishSummary(for: today)
        let result = try XCTUnwrap(summary.results.first)
        XCTAssertTrue(result.improved)
        XCTAssertEqual(result.delta ?? 0, 62.5 * (1 + 10.0 / 30) - 60 * (1 + 10.0 / 30), accuracy: 0.001, "推定1RM で比べる")
        XCTAssertTrue(result.isRecord)
        XCTAssertEqual(summary.improvedCount, 1)
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
