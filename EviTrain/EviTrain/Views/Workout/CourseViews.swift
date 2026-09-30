import SwiftData
import SwiftUI

/// コースを選ぶ画面（初回と、あとから変更するとき）。
struct CoursePickerView: View {
    @AppStorage(Course.storageKey) private var courseRaw = ""
    @Environment(\.dismiss) private var dismiss
    /// 初回は「あとで決める」を出す
    var showsSkip = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("目的を選ぼう")
                    .font(.largeTitle.bold())
                Text("選んだコースで、記録画面・おすすめメニュー・研究の根拠が変わります。あとから変えられます。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(Course.allCases) { course in
                    Button {
                        courseRaw = course.rawValue
                        dismiss()
                    } label: {
                        CourseCard(course: course, isSelected: courseRaw == course.rawValue)
                    }
                    .buttonStyle(.plain)
                }

                if showsSkip {
                    Button("あとで決める") {
                        courseRaw = "none"
                        dismiss()
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 6)
                }
            }
            .padding()
        }
        .themedBackground()
    }
}

private struct CourseCard: View {
    let course: Course
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: course.symbol)
                .font(.system(size: 34, weight: .bold))
                .frame(width: 56)
            VStack(alignment: .leading, spacing: 4) {
                Text(course.title).font(.title3.bold())
                Text(course.tagline)
                    .font(.footnote)
                    .opacity(0.9)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 0)
            if isSelected {
                Image(systemName: "checkmark.circle.fill").font(.title2)
            }
        }
        .foregroundStyle(.white)
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            LinearGradient(colors: course.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
    }
}

/// 記録タブの先頭に出す、コースのカード。
struct CourseHeaderCard: View {
    @Environment(\.modelContext) private var context
    @Environment(\.appTheme) private var theme
    let course: Course
    @State private var showingPicker = false

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 12) {
                Image(systemName: course.symbol)
                    .font(.system(size: 28, weight: .bold))
                VStack(alignment: .leading, spacing: 2) {
                    Text("いまのコース").font(.caption).opacity(0.85)
                    Text(course.title).font(.title3.bold())
                }
                Spacer()
                Button("変える") { showingPicker = true }
                    .buttonStyle(.plain)
                    .font(.footnote.bold())
                    .foregroundStyle(.white)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(.white.opacity(0.22), in: Capsule())
            }

            HStack(spacing: 10) {
                Button {
                    _ = CourseStarter.startWorkout(course: course, in: context)
                } label: {
                    Label("このコースで始める", systemImage: "play.fill")
                        .font(.subheadline.bold())
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 11)
                        .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(course.colors[0])
                }
                if course.usesStopwatch {
                    NavigationLink {
                        SprintTimerView(course: course)
                    } label: {
                        Label("タイム計測", systemImage: "stopwatch.fill")
                            .font(.subheadline.bold())
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 11)
                            .foregroundStyle(.white)
                            .background(.white.opacity(0.22), in: RoundedRectangle(cornerRadius: 12))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .foregroundStyle(.white)
        .padding(16)
        .background(
            LinearGradient(colors: course.colors, startPoint: .topLeading, endPoint: .bottomTrailing),
            in: RoundedRectangle(cornerRadius: 20)
        )
        .sheet(isPresented: $showingPicker) {
            CoursePickerView()
                .presentationDetents([.large])
        }
    }
}

/// コースのおすすめ種目でトレーニングを作る。
enum CourseStarter {
    @MainActor
    static func startWorkout(course: Course, in context: ModelContext) -> Workout {
        let workout = Workout()
        workout.menuName = "\(course.title)コース"
        context.insert(workout)
        let names = course.starterExercises
        let descriptor = FetchDescriptor<Exercise>(predicate: #Predicate { names.contains($0.name) })
        let found = (try? context.fetch(descriptor)) ?? []
        var order = 0
        for name in names {
            guard let exercise = found.first(where: { $0.name == name }) else { continue }
            let entry = WorkoutEntry(order: order, exercise: exercise)
            entry.restSeconds = exercise.restSeconds
            context.insert(entry)
            entry.workout = workout
            order += 1
            let previous = Stats.previousEntry(for: exercise, before: workout.startedAt)?.sortedSets
            let meters = exercise.tracking == .distanceTime ? distance(of: name, fallback: course.defaultDistance) : 0
            for setIndex in 0..<3 {
                let last = previous?[safe: setIndex] ?? previous?.last
                let set = SetRecord(order: setIndex,
                                    weight: last?.weight ?? 0,
                                    reps: last?.reps ?? 0,
                                    seconds: 0,
                                    meters: meters)
                context.insert(set)
                set.entry = entry
            }
        }
        try? context.save()
        return workout
    }

    /// 「30mダッシュ」のように名前が数字で始まるときはその距離、なければ fallback。
    private static func distance(of name: String, fallback: Double) -> Double {
        Double(name.prefix(while: \.isNumber)) ?? fallback
    }
}
