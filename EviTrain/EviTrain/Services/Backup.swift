import Foundation
import SwiftData

/// 全データのバックアップ（記録・自作種目と休憩時間・マイメニュー）。JSON で書き出し、読み込んで復元できる。
struct BackupFile: Codable {
    struct ExerciseData: Codable {
        var name: String
        var group: String
        var tracking: String
        var tags: [String]
        var isCustom: Bool
        var restSeconds: Double?
    }

    struct SetData: Codable {
        var order: Int
        var weight: Double
        var reps: Int
        var seconds: Double
        var meters: Double
        var isDone: Bool
    }

    struct EntryData: Codable {
        var order: Int
        var exercise: String
        var restSeconds: Double?
        var sets: [SetData]
    }

    struct WorkoutData: Codable {
        var startedAt: Date
        var finishedAt: Date?
        var note: String
        var menuName: String?
        var entries: [EntryData]
    }

    struct MenuItemData: Codable {
        var order: Int
        var exercise: String
        var sets: Int
        var weight: Double
        var reps: Int
        var seconds: Double
        var meters: Double
        var restSeconds: Double?
        var note: String
    }

    struct MenuData: Codable {
        var name: String
        var note: String
        var isFavorite: Bool
        var sourcePMID: String?
        var weeks: Int?
        var perWeek: Int?
        var items: [MenuItemData]
    }

    struct BodyWeightData: Codable {
        var date: Date
        var kilograms: Double
    }

    var version = 1
    var exportedAt: Date
    var exercises: [ExerciseData]
    var workouts: [WorkoutData]
    var menus: [MenuData]
    /// 古いバックアップには無いので省略可
    var bodyWeights: [BodyWeightData]? = nil

    static func encoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return encoder
    }

    static func decoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

@MainActor
enum BackupService {
    struct RestoreResult {
        var workouts = 0
        var menus = 0
        var exercises = 0
        var skipped = 0
    }

    static func make(from context: ModelContext) -> BackupFile {
        let exercises: [Exercise] = (try? context.fetch(FetchDescriptor<Exercise>())) ?? []
        let workoutDescriptor = FetchDescriptor<Workout>(predicate: #Predicate { $0.finishedAt != nil },
                                                         sortBy: [SortDescriptor(\.startedAt)])
        let workouts: [Workout] = (try? context.fetch(workoutDescriptor)) ?? []
        let menus: [MenuTemplate] = (try? context.fetch(FetchDescriptor<MenuTemplate>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []

        // 標準種目は休憩時間を覚えているものだけ、自作種目はすべて保存する
        var exerciseData: [BackupFile.ExerciseData] = []
        for exercise in exercises where exercise.isCustom || exercise.restSeconds != nil {
            exerciseData.append(BackupFile.ExerciseData(name: exercise.name, group: exercise.groupRaw,
                                                        tracking: exercise.trackingRaw, tags: exercise.tags,
                                                        isCustom: exercise.isCustom, restSeconds: exercise.restSeconds))
        }

        var workoutData: [BackupFile.WorkoutData] = []
        for workout in workouts {
            var entries: [BackupFile.EntryData] = []
            for entry in workout.sortedEntries {
                guard let name = entry.exercise?.name else { continue }
                var sets: [BackupFile.SetData] = []
                for set in entry.sortedSets {
                    sets.append(BackupFile.SetData(order: set.order, weight: set.weight, reps: set.reps,
                                                   seconds: set.seconds, meters: set.meters, isDone: set.isDone))
                }
                entries.append(BackupFile.EntryData(order: entry.order, exercise: name,
                                                    restSeconds: entry.restSeconds, sets: sets))
            }
            workoutData.append(BackupFile.WorkoutData(startedAt: workout.startedAt, finishedAt: workout.finishedAt,
                                                      note: workout.note, menuName: workout.menuName, entries: entries))
        }

        var menuData: [BackupFile.MenuData] = []
        for menu in menus {
            var items: [BackupFile.MenuItemData] = []
            for item in menu.sortedItems {
                guard let name = item.exercise?.name else { continue }
                items.append(BackupFile.MenuItemData(order: item.order, exercise: name, sets: item.sets,
                                                     weight: item.weight, reps: item.reps, seconds: item.seconds,
                                                     meters: item.meters, restSeconds: item.restSeconds, note: item.note))
            }
            menuData.append(BackupFile.MenuData(name: menu.name, note: menu.note, isFavorite: menu.isFavorite,
                                                sourcePMID: menu.sourcePMID, weeks: menu.weeks, perWeek: menu.perWeek,
                                                items: items))
        }
        let weights: [BodyWeight] = (try? context.fetch(FetchDescriptor<BodyWeight>(sortBy: [SortDescriptor(\.date)]))) ?? []
        let weightData = weights.map { BackupFile.BodyWeightData(date: $0.date, kilograms: $0.kilograms) }
        return BackupFile(exportedAt: .now, exercises: exerciseData, workouts: workoutData, menus: menuData,
                          bodyWeights: weightData)
    }

    /// バックアップを今のデータに足す。同じ日時の記録・同じ名前のメニューは重ねて入れない。
    @discardableResult
    static func restore(_ backup: BackupFile, into context: ModelContext) -> RestoreResult {
        var result = RestoreResult()
        var byName: [String: Exercise] = [:]
        for exercise in (try? context.fetch(FetchDescriptor<Exercise>())) ?? [] { byName[exercise.name] = exercise }

        func exercise(named name: String) -> Exercise {
            if let found = byName[name] { return found }
            let info = backup.exercises.first { $0.name == name }
            let created = Exercise(name: name,
                                   group: info.flatMap { MuscleGroup(rawValue: $0.group) } ?? .legs,
                                   tracking: info.flatMap { TrackingType(rawValue: $0.tracking) } ?? .weightReps,
                                   tags: info?.tags ?? [], isCustom: true)
            created.restSeconds = info?.restSeconds
            context.insert(created)
            byName[name] = created
            result.exercises += 1
            return created
        }

        for info in backup.exercises {
            let target = exercise(named: info.name)
            if target.restSeconds == nil { target.restSeconds = info.restSeconds }
        }

        let existingStarts = ((try? context.fetch(FetchDescriptor<Workout>())) ?? []).map(\.startedAt)
        for data in backup.workouts {
            if existingStarts.contains(where: { abs($0.timeIntervalSince(data.startedAt)) < 1 }) {
                result.skipped += 1
                continue
            }
            let workout = Workout(startedAt: data.startedAt)
            workout.finishedAt = data.finishedAt ?? data.startedAt
            workout.note = data.note
            workout.menuName = data.menuName
            context.insert(workout)
            for entryData in data.entries {
                let entry = WorkoutEntry(order: entryData.order, exercise: exercise(named: entryData.exercise))
                entry.restSeconds = entryData.restSeconds
                context.insert(entry)
                entry.workout = workout
                for setData in entryData.sets {
                    let set = SetRecord(order: setData.order, weight: setData.weight, reps: setData.reps,
                                        seconds: setData.seconds, meters: setData.meters)
                    set.isDone = setData.isDone
                    context.insert(set)
                    set.entry = entry
                }
            }
            result.workouts += 1
        }

        let existingMenus = Set(((try? context.fetch(FetchDescriptor<MenuTemplate>())) ?? []).map(\.name))
        for data in backup.menus {
            if existingMenus.contains(data.name) {
                result.skipped += 1
                continue
            }
            let menu = MenuTemplate(name: data.name, note: data.note, sourcePMID: data.sourcePMID,
                                    weeks: data.weeks, perWeek: data.perWeek)
            menu.isFavorite = data.isFavorite
            context.insert(menu)
            for itemData in data.items {
                let item = MenuItem(order: itemData.order, exercise: exercise(named: itemData.exercise),
                                    sets: itemData.sets, weight: itemData.weight, reps: itemData.reps,
                                    seconds: itemData.seconds, meters: itemData.meters,
                                    restSeconds: itemData.restSeconds, note: itemData.note)
                context.insert(item)
                item.template = menu
            }
            result.menus += 1
        }
        let existingWeights = ((try? context.fetch(FetchDescriptor<BodyWeight>())) ?? []).map(\.date)
        for data in backup.bodyWeights ?? [] {
            let sameDay = existingWeights.contains { Calendar.current.isDate($0, inSameDayAs: data.date) }
            if !sameDay { context.insert(BodyWeight(date: data.date, kilograms: data.kilograms)) }
        }
        try? context.save()
        return result
    }
}
