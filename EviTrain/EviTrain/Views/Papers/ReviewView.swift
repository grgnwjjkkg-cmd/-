#if DEBUG
import SwiftUI

/// 開発用の確認画面（App Store 版には入らない）。
/// 要約を読んで「公開OK」「保留」を付け、approvals.json として書き出してアプリに同梱する。
struct ReviewView: View {
    enum Filter: String, CaseIterable, Identifiable {
        case pending = "確認待ち"
        case published = "公開OK"
        case onHold = "保留"
        var id: String { rawValue }
    }

    @Environment(StudyStore.self) private var store
    @State private var filter: Filter = .pending
    @State private var field: String?

    private var studies: [Study] {
        store.allStudies.filter { study in
            let status = store.approval(for: study)?.status
            let matches = switch filter {
            case .pending: status == nil
            case .published: status == Approval.published
            case .onHold: status == Approval.onHold
            }
            return matches && (field == nil || study.field == field)
        }
        .sorted { ($0.fieldRank(store.fieldOrder), -$0.stars) < ($1.fieldRank(store.fieldOrder), -$1.stars) }
    }

    var body: some View {
        @Bindable var store = store
        List {
            Section {
                Picker("状態", selection: $filter) {
                    ForEach(Filter.allCases) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                Picker("分野", selection: $field) {
                    Text("すべての分野").tag(String?.none)
                    ForEach(store.fieldOrder, id: \.self) { Text($0).tag(String?.some($0)) }
                }
                Toggle("確認待ちもアプリに表示する（開発用）", isOn: $store.showPending)
            } footer: {
                Text("公開OK \(store.publishedCount)本 / 全\(store.allStudies.count)本。印は端末に保存されます。アプリに反映するには、下の「approvals.json を書き出す」で保存したファイルを Resources/Studies/approvals.json に置き換えてください。")
            }

            Section {
                ShareLink(item: store.approvalsFile(), preview: SharePreview("approvals.json")) {
                    Label("approvals.json を書き出す", systemImage: "square.and.arrow.up")
                }
            }

            Section("\(filter.rawValue) \(studies.count)本") {
                ForEach(studies) { study in
                    NavigationLink {
                        StudyDetailView(study: study)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(study.field) / \(study.theme)").font(.caption).foregroundStyle(.secondary)
                            StudyRow(study: study)
                        }
                    }
                }
            }
        }
        .navigationTitle("要約の確認（開発用）")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// 論文1本の画面の下に出る、公開OK / 保留のボタン（開発用）。
struct ReviewBar: View {
    @Environment(StudyStore.self) private var store
    let study: Study

    var body: some View {
        let status = store.approval(for: study)?.status
        HStack(spacing: 10) {
            Text(status ?? "確認待ち")
                .font(.caption.bold())
                .foregroundStyle(status == Approval.published ? .green : .orange)
            Spacer()
            Button("保留") { store.setApproval(Approval.onHold, for: study) }
                .buttonStyle(.bordered)
            Button("公開OK") { store.setApproval(Approval.published, for: study) }
                .buttonStyle(.borderedProminent)
            if status != nil {
                Button("取消") { store.setApproval(nil, for: study) }
                    .buttonStyle(.bordered)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }
}

private extension Study {
    func fieldRank(_ order: [String]) -> Int { order.firstIndex(of: field) ?? .max }
}
#endif
