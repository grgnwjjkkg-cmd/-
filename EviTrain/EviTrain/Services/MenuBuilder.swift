import Foundation
import SwiftData

/// マイメニュー ⇄ トレーニングの変換。
@MainActor
enum MenuBuilder {
    /// メニューから今日のトレーニングを作る。重さや回数が空の項目は、前回の記録で埋める。
    @discardableResult
    static func startWorkout(from template: MenuTemplate, in context: ModelContext) -> Workout {
        let workout = Workout()
        workout.menuName = template.name
        context.insert(workout)
        for (index, item) in template.sortedItems.enumerated() {
            guard let exercise = item.exercise else { continue }
            let entry = WorkoutEntry(order: index, exercise: exercise)
            entry.restSeconds = item.restSeconds ?? exercise.restSeconds
            context.insert(entry)
            entry.workout = workout
            let previous = Stats.previousEntry(for: exercise, before: workout.startedAt)?.sortedSets
            for setIndex in 0..<max(item.sets, 1) {
                let last = previous?[safe: setIndex] ?? previous?.last
                let set = SetRecord(order: setIndex,
                                    weight: item.weight > 0 ? item.weight : (last?.weight ?? 0),
                                    reps: item.reps > 0 ? item.reps : (last?.reps ?? 0),
                                    seconds: item.seconds > 0 ? item.seconds : (last?.seconds ?? 0),
                                    meters: item.meters > 0 ? item.meters : (last?.meters ?? 0))
                context.insert(set)
                set.entry = entry
            }
        }
        template.lastUsedAt = .now
        if template.firstUsedAt == nil { template.firstUsedAt = .now }
        try? context.save()
        return workout
    }

    /// 前回（直近の完了した）トレーニングと同じ内容で今日のトレーニングを作る。
    @discardableResult
    static func startWorkout(copying source: Workout, in context: ModelContext) -> Workout {
        let workout = Workout()
        workout.menuName = source.menuName
        context.insert(workout)
        for (index, entry) in source.sortedEntries.enumerated() {
            guard let exercise = entry.exercise else { continue }
            let newEntry = WorkoutEntry(order: index, exercise: exercise)
            newEntry.restSeconds = entry.restSeconds ?? exercise.restSeconds
            context.insert(newEntry)
            newEntry.workout = workout
            for (setIndex, set) in entry.sortedSets.filter(\.isDone).enumerated() {
                let copy = SetRecord(order: setIndex, weight: set.weight, reps: set.reps,
                                     seconds: set.seconds, meters: set.meters)
                context.insert(copy)
                copy.entry = newEntry
            }
        }
        try? context.save()
        return workout
    }

    /// 記録したトレーニングをマイメニューとして保存する。
    @discardableResult
    static func saveAsMenu(_ workout: Workout, name: String, in context: ModelContext) -> MenuTemplate {
        let template = MenuTemplate(name: name)
        context.insert(template)
        for (index, entry) in workout.sortedEntries.enumerated() {
            guard let exercise = entry.exercise else { continue }
            let sets = entry.sortedSets.filter(\.isDone)
            let reference = sets.last ?? entry.sortedSets.last
            let item = MenuItem(order: index, exercise: exercise, sets: max(sets.count, 1),
                                weight: reference?.weight ?? 0, reps: reference?.reps ?? 0,
                                seconds: reference?.seconds ?? 0, meters: reference?.meters ?? 0,
                                restSeconds: entry.restSeconds)
            context.insert(item)
            item.template = template
        }
        try? context.save()
        return template
    }

    /// 論文のメニューをマイメニューに追加する。標準種目に無い種目は自作種目として作る。
    @discardableResult
    static func addMenu(_ studyMenu: StudyMenu, in context: ModelContext) -> MenuTemplate {
        let template = MenuTemplate(name: studyMenu.name, note: studyMenu.caution, sourcePMID: studyMenu.pmid,
                                    weeks: studyMenu.weeks, perWeek: studyMenu.perWeek)
        context.insert(template)
        for (index, source) in studyMenu.items.enumerated() {
            let exercise = exercise(named: source.exercise, group: source.muscleGroup,
                                    tracking: source.trackingType, in: context)
            let note = [source.load, source.note].filter { !$0.isEmpty }.joined(separator: "。")
            let item = MenuItem(order: index, exercise: exercise, sets: source.sets ?? 1,
                                reps: source.reps ?? 0, seconds: source.seconds ?? 0,
                                meters: source.meters ?? 0, restSeconds: source.restSeconds, note: note)
            context.insert(item)
            item.template = template
        }
        try? context.save()
        return template
    }

    /// 名前で種目を探し、無ければ自作種目として作る。
    static func exercise(named name: String, group: MuscleGroup, tracking: TrackingType,
                         in context: ModelContext) -> Exercise {
        var descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        descriptor.fetchLimit = 1
        if let found = try? context.fetch(descriptor).first { return found }
        let tags: [String] = switch group {
        case .sprint: ["スプリント"]
        case .plyometric: ["パワー"]
        default: tracking == .weightReps ? ["筋力", "筋肥大"] : []
        }
        let exercise = Exercise(name: name, group: group, tracking: tracking, tags: tags, isCustom: true)
        context.insert(exercise)
        return exercise
    }
}
