import SwiftData
import SwiftUI
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @State private var backupURL: URL?
    @State private var importing = false
    @State private var restoreMessage: String?
    @AppStorage(TrainingReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(TrainingReminder.weekdaysKey) private var reminderWeekdays = "2,4,6"
    @AppStorage(TrainingReminder.hourKey) private var reminderHour = 19
    @AppStorage(TrainingReminder.minuteKey) private var reminderMinute = 0

    /// リマインダーの設定のどれかが変わったら通知を入れ直すための目印
    private var reminderSignature: String {
        "\(reminderEnabled)-\(reminderWeekdays)-\(reminderHour)-\(reminderMinute)"
    }
    @AppStorage(RestTimer.defaultSecondsKey) private var defaultRestSeconds = 90.0
    @AppStorage(AppSettings.weeklySetTargetKey) private var weeklySetTarget = 0
    @AppStorage(AppSettings.appearanceKey) private var appearance = Appearance.system
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.track
    @Query(filter: #Predicate<Workout> { $0.finishedAt != nil }, sort: \Workout.startedAt)
    private var workouts: [Workout]

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Stepper(value: $defaultRestSeconds, in: 15...600, step: 15) {
                        LabeledContent("休憩タイマー", value: defaultRestSeconds.clock)
                    }
                    Stepper(value: $weeklySetTarget, in: 0...30) {
                        LabeledContent("週の目標セット数（部位ごと）", value: weeklySetTarget == 0 ? "表示しない" : "\(weeklySetTarget)")
                    }
                } header: {
                    Text("トレーニング")
                } footer: {
                    Text("目標を決めると、記録タブに部位ごとの今週のセット数が表示されます。")
                }

                Section {
                    ForEach(AppTheme.allCases) { item in
                        Button {
                            theme = item
                        } label: {
                            HStack(spacing: 12) {
                                ThemeSwatch(theme: item)
                                Text(item.rawValue).foregroundStyle(.primary)
                                Spacer()
                                if theme == item {
                                    Image(systemName: "checkmark.circle.fill").foregroundStyle(item.accent)
                                }
                            }
                        }
                    }
                    Picker("明るさ", selection: $appearance) {
                        ForEach(Appearance.allCases) { Text($0.rawValue).tag($0) }
                    }
                } header: {
                    Text("色")
                } footer: {
                    Text("メインの色と背景の色が変わります。明るさは「端末に合わせる」だと、iPhone のダークモードに合わせて切り替わります。")
                }


                Section {
                    ReminderSettingsView()
                } header: {
                    Text("リマインダー")
                } footer: {
                    Text("選んだ曜日の時刻に通知します。")
                }
                .onChange(of: reminderSignature) { ReminderSettingsView.apply() }

                Section {
                    Button {
                        backupURL = writeBackup()
                    } label: {
                        Label("バックアップを作る", systemImage: "externaldrive.badge.plus")
                    }
                    if let backupURL {
                        ShareLink(item: backupURL) {
                            Label("できたバックアップを保存・送る", systemImage: "square.and.arrow.up")
                        }
                    }
                    Button {
                        importing = true
                    } label: {
                        Label("バックアップから戻す", systemImage: "arrow.counterclockwise.circle")
                    }
                    ShareLink(item: CSVExport.make(workouts), preview: SharePreview("トレーニング記録.csv")) {
                        Label("記録をCSVで書き出す（表計算用）", systemImage: "tablecells")
                    }
                    .disabled(workouts.isEmpty)
                } header: {
                    Text("データ")
                } footer: {
                    Text("バックアップには、記録・自作種目と休憩時間・マイメニューが入ります。「ファイル」アプリや iCloud Drive に保存しておくと、機種変更のときに戻せます。戻すときは、今のデータに足されます（同じ日時の記録は重ねて入りません）。")
                }

                Section("このアプリについて") {
                    LabeledContent("バージョン", value: Bundle.main.appVersion)
                    Text("記録は端末の中だけに保存され、広告はありません。論文の要約は研究の紹介であり、医療・治療についての助言ではありません。")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
            .themedBackground()
            .navigationTitle("設定")
            .fileImporter(isPresented: $importing, allowedContentTypes: [.json]) { result in
                restore(result)
            }
            .alert("バックアップ", isPresented: Binding(get: { restoreMessage != nil }, set: { if !$0 { restoreMessage = nil } })) {
                Button("OK") { restoreMessage = nil }
            } message: {
                Text(restoreMessage ?? "")
            }
        }
    }

    /// バックアップを一時ファイルに書き出して、その場所を返す。
    private func writeBackup() -> URL? {
        let backup = BackupService.make(from: context)
        guard let data = try? BackupFile.encoder().encode(backup) else { return nil }
        let name = "エビトレ_バックアップ_" + Date.now.formatted(.iso8601.year().month().day()) + ".json"
        let url = FileManager.default.temporaryDirectory.appending(path: name)
        do {
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            restoreMessage = "バックアップを作れませんでした（\(error.localizedDescription)）"
            return nil
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        do {
            let url = try result.get()
            let accessing = url.startAccessingSecurityScopedResource()
            defer { if accessing { url.stopAccessingSecurityScopedResource() } }
            let backup = try BackupFile.decoder().decode(BackupFile.self, from: Data(contentsOf: url))
            let restored = BackupService.restore(backup, into: context)
            restoreMessage = "記録 \(restored.workouts)件・メニュー \(restored.menus)件を戻しました。"
                + (restored.skipped > 0 ? "（すでにある \(restored.skipped)件は重ねて入れていません）" : "")
        } catch {
            restoreMessage = "このファイルは読み込めませんでした。エビトレで作ったバックアップを選んでください。"
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

/// 設定画面の色見本（背景の上にメインの色の丸）。
private struct ThemeSwatch: View {
    let theme: AppTheme

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(theme.background)
                .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(.separator))
            Circle().fill(theme.accent).frame(width: 16, height: 16)
        }
        .frame(width: 44, height: 30)
    }
}
