import Foundation
import SwiftData

/// 初回起動時に登録する標準種目。
enum ExerciseCatalog {
    private static let strength = ["筋力", "筋肥大"]

    static let defaults: [(String, MuscleGroup, TrackingType, [String])] = [
        // 胸
        ("ベンチプレス", .chest, .weightReps, strength),
        ("インクラインダンベルプレス", .chest, .weightReps, strength),
        ("ダンベルフライ", .chest, .weightReps, ["筋肥大"]),
        ("腕立て伏せ", .chest, .reps, strength),
        ("ディップス", .chest, .reps, strength),
        // 背中
        ("デッドリフト", .back, .weightReps, strength + ["パワー"]),
        ("懸垂", .back, .reps, strength),
        ("ラットプルダウン", .back, .weightReps, strength),
        ("ベントオーバーロウ", .back, .weightReps, strength),
        ("シーテッドロウ", .back, .weightReps, ["筋肥大"]),
        // 脚
        ("スクワット", .legs, .weightReps, strength + ["スプリント", "パワー"]),
        ("フロントスクワット", .legs, .weightReps, strength + ["スプリント"]),
        ("ブルガリアンスクワット", .legs, .weightReps, strength + ["スプリント"]),
        ("ルーマニアンデッドリフト", .legs, .weightReps, strength + ["スプリント"]),
        ("ヒップスラスト", .legs, .weightReps, strength + ["スプリント"]),
        ("ノルディックハムストリング", .legs, .reps, ["筋力", "スプリント", "ケガ予防"]),
        ("レッグプレス", .legs, .weightReps, strength),
        ("カーフレイズ", .legs, .weightReps, ["筋肥大"]),
        ("パワークリーン", .legs, .weightReps, ["パワー", "筋力", "スプリント"]),
        // 肩・腕
        ("ショルダープレス", .shoulders, .weightReps, strength),
        ("サイドレイズ", .shoulders, .weightReps, ["筋肥大"]),
        ("バーベルカール", .arms, .weightReps, ["筋肥大"]),
        ("トライセプスエクステンション", .arms, .weightReps, ["筋肥大"]),
        // 体幹
        ("プランク", .core, .time, ["体幹"]),
        ("アブローラー", .core, .reps, ["体幹"]),
        // スプリント
        ("10mダッシュ", .sprint, .distanceTime, ["スプリント", "加速"]),
        ("30mダッシュ", .sprint, .distanceTime, ["スプリント", "加速"]),
        ("60mダッシュ", .sprint, .distanceTime, ["スプリント", "最大速度"]),
        ("坂道ダッシュ", .sprint, .distanceTime, ["スプリント", "加速"]),
        ("そり引きダッシュ", .sprint, .distanceTime, ["スプリント", "加速"]),
        // ジャンプ
        ("ボックスジャンプ", .plyometric, .reps, ["パワー", "スプリント"]),
        ("バウンディング", .plyometric, .reps, ["パワー", "スプリント"]),
        ("立ち幅跳び", .plyometric, .reps, ["パワー"]),
        // 有酸素
        ("ランニング", .cardio, .time, ["持久力"]),
    ]

    @MainActor
    static func seedIfNeeded(_ context: ModelContext) {
        let count = (try? context.fetchCount(FetchDescriptor<Exercise>())) ?? 0
        guard count == 0 else { return }
        for (name, group, tracking, tags) in defaults {
            context.insert(Exercise(name: name, group: group, tracking: tracking, tags: tags))
        }
        try? context.save()
    }
}
