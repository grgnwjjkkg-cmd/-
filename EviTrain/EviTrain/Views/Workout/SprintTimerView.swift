import SwiftData
import SwiftUI

/// ダッシュのタイム計測。スタート → ストップで1本ずつ記録し、まとめて保存できる。
struct SprintTimerView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme) private var theme
    @Environment(\.dismiss) private var dismiss
    @Query(filter: #Predicate<SetRecord> { $0.isDone && $0.seconds > 0 }) private var doneSets: [SetRecord]

    let course: Course
    @State private var distance: Double
    @State private var startedAt: Date?
    @State private var runs: [TimeInterval] = []
    @State private var saved = false

    private static let distances: [Double] = [10, 20, 30, 40, 60, 100]

    init(course: Course) {
        self.course = course
        _distance = State(initialValue: course.defaultDistance > 0 ? course.defaultDistance : 30)
    }

    private var isRunning: Bool { startedAt != nil }

    /// 今までの自己ベスト（この距離）
    private var previousBest: TimeInterval? {
        doneSets.filter { $0.meters == distance }.map(\.seconds).min()
    }

    private var sessionBest: TimeInterval? { runs.min() }

    var body: some View {
        VStack(spacing: 18) {
            distancePicker

            TimelineView(.animation(minimumInterval: 1.0 / 60.0, paused: !isRunning)) { timeline in
                let elapsed = startedAt.map { timeline.date.timeIntervalSince($0) } ?? 0
                Text(Self.format(elapsed))
                    .font(.system(size: 76, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .minimumScaleFactor(0.5)
                    .lineLimit(1)
                    .foregroundStyle(isRunning ? theme.accent : .primary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 22)
            .background(theme.card, in: RoundedRectangle(cornerRadius: 22))

            bestRow

            Button(action: toggle) {
                Text(isRunning ? "ストップ" : "スタート")
                    .font(.title2.bold())
                    .frame(maxWidth: .infinity)
                    .frame(height: 88)
                    .foregroundStyle(theme.onAccent)
                    .background(isRunning ? Color.red : theme.accent, in: RoundedRectangle(cornerRadius: 24))
            }
            .buttonStyle(.plain)

            runsList

            Button {
                save()
            } label: {
                Label(saved ? "保存しました" : "\(runs.count)本を記録に保存", systemImage: saved ? "checkmark" : "square.and.arrow.down")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: 14))
            }
            .buttonStyle(.plain)
            .disabled(runs.isEmpty || saved || isRunning)
        }
        .padding()
        .themedBackground()
        .navigationTitle("タイム計測")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var distancePicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.distances, id: \.self) { d in
                    Button {
                        distance = d
                    } label: {
                        Text("\(Int(d))m")
                            .font(.subheadline.bold())
                            .padding(.horizontal, 16)
                            .padding(.vertical, 9)
                            .foregroundStyle(distance == d ? theme.onAccent : .primary)
                            .background(distance == d ? theme.accent : theme.card, in: Capsule())
                    }
                    .buttonStyle(.plain)
                    .disabled(isRunning)
                }
            }
        }
    }

    private var bestRow: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("これまでのベスト").font(.caption).foregroundStyle(.secondary)
                Text(previousBest.map(Self.format) ?? "―")
                    .font(.title3.bold()).monospacedDigit()
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("今日のベスト").font(.caption).foregroundStyle(.secondary)
                Text(sessionBest.map(Self.format) ?? "―")
                    .font(.title3.bold()).monospacedDigit()
                    .foregroundStyle(isNewRecord ? Color.orange : Color.primary)
            }
        }
        .padding(.horizontal, 6)
    }

    private var isNewRecord: Bool {
        guard let today = sessionBest else { return false }
        guard let before = previousBest else { return true }
        return today < before
    }

    private var runsList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(Array(runs.enumerated().reversed()), id: \.offset) { index, seconds in
                    HStack {
                        Text("\(index + 1)本目").foregroundStyle(.secondary)
                        Spacer()
                        Text(Self.format(seconds)).font(.title3.bold()).monospacedDigit()
                        if seconds == sessionBest {
                            Image(systemName: "crown.fill").foregroundStyle(.orange)
                        }
                        Text(String(format: "%.1f km/h", distance / seconds * 3.6))
                            .font(.caption).foregroundStyle(.secondary).monospacedDigit()
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(theme.card, in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
    }

    private func toggle() {
        if let start = startedAt {
            runs.append(Date.now.timeIntervalSince(start))
            startedAt = nil
            saved = false
        } else {
            startedAt = .now
        }
    }

    /// 走った本数ぶんのセットを、ダッシュの種目として保存する。
    private func save() {
        let name: String
        switch distance {
        case ..<20: name = "10mダッシュ"
        case ..<45: name = "30mダッシュ"
        default: name = "60mダッシュ"
        }
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { $0.name == name })
        guard let exercise = try? context.fetch(descriptor).first else { return }
        let workout = Workout()
        workout.menuName = "\(course.title)コース"
        context.insert(workout)
        let entry = WorkoutEntry(order: 0, exercise: exercise)
        context.insert(entry)
        entry.workout = workout
        for (index, seconds) in runs.enumerated() {
            let set = SetRecord(order: index, seconds: seconds, meters: distance)
            set.isDone = true
            set.completedAt = .now
            context.insert(set)
            set.entry = entry
        }
        workout.finishedAt = .now
        try? context.save()
        saved = true
    }

    /// 秒（小数第2位まで）。1分以上は「分:秒」。
    static func format(_ t: TimeInterval) -> String {
        if t >= 60 {
            let m = Int(t) / 60
            return String(format: "%d:%05.2f", m, t - Double(m * 60))
        }
        return String(format: "%.2f", t)
    }
}
