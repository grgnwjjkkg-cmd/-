import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(PaperStore.self) private var paperStore
    @AppStorage(RestTimer.defaultSecondsKey) private var defaultRestSeconds = 90.0
    @AppStorage(PaperStore.feedURLKey) private var feedURL = ""
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt)
    private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            Form {
                Section("トレーニング") {
                    Stepper(value: $defaultRestSeconds, in: 15...600, step: 15) {
                        LabeledContent("休憩タイマー", value: defaultRestSeconds.clock)
                    }
                }

                Section {
                    TextField("https://example.com/papers.json", text: $feedURL)
                        .keyboardType(.URL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    Button {
                        Task { await paperStore.refresh() }
                    } label: {
                        if paperStore.isLoading {
                            ProgressView()
                        } else {
                            Text("論文を読み込む")
                        }
                    }
                    .disabled(feedURL.isEmpty || paperStore.isLoading)
                    if let error = paperStore.lastError {
                        Text(error).font(.caption).foregroundStyle(.red)
                    }
                } header: {
                    Text("論文データ")
                } footer: {
                    Text("論文要約サイトが配信するJSONのURLです。空欄のときはアプリに入っているサンプルを表示します。")
                }

                Section("データ") {
                    ShareLink(item: CSVExport.make(workouts), preview: SharePreview("トレーニング記録.csv")) {
                        Label("記録をCSVで書き出す", systemImage: "square.and.arrow.up")
                    }
                    .disabled(workouts.isEmpty)
                }

                Section("このアプリについて") {
                    LabeledContent("バージョン", value: Bundle.main.appVersion)
                    Text("記録は端末の中だけに保存され、広告はありません。論文の要約は研究の紹介であり、医学的な助言ではありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("設定")
        }
    }
}

/// 表計算ソフトで開けるCSVを作る。
enum CSVExport {
    static func make(_ workouts: [Workout]) -> CSVFile {
        var lines = ["日付,種目,セット,重量(kg),回数,距離(m),時間(秒)"]
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime]
        for workout in workouts {
            for entry in workout.sortedEntries {
                let name = (entry.exercise?.name ?? "").replacingOccurrences(of: "\"", with: "\"\"")
                for (index, set) in entry.sortedSets.filter(\.isDone).enumerated() {
                    lines.append([
                        formatter.string(from: workout.startedAt), "\"\(name)\"", "\(index + 1)",
                        set.weight.short, "\(set.reps)", set.meters.short, set.seconds.short,
                    ].joined(separator: ","))
                }
            }
        }
        return CSVFile(text: lines.joined(separator: "\n"))
    }
}

struct CSVFile: Transferable {
    let text: String

    static var transferRepresentation: some TransferRepresentation {
        DataRepresentation(exportedContentType: .commaSeparatedText) { file in
            // Excel で文字化けしないよう BOM を付ける
            Data([0xEF, 0xBB, 0xBF]) + Data(file.text.utf8)
        }
        .suggestedFileName("トレーニング記録.csv")
    }
}

extension Bundle {
    var appVersion: String {
        let version = infoDictionary?["CFBundleShortVersionString"] as? String ?? "-"
        let build = infoDictionary?["CFBundleVersion"] as? String ?? "-"
        return "\(version) (\(build))"
    }
}
