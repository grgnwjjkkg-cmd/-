# エビトレ（EviTrain）

筋トレとスプリントの記録アプリ。下のタブに、研究論文の要約を読める「論文」タブがあります。
アプリ名は仮です。

- **記録**：トレーニング中の入力（前回値の自動入力・休憩タイマー・自己ベスト更新のお知らせ）
- **履歴**：日付別の記録、種目別のグラフ、その種目に関係する研究
- **論文**：スポーツ科学の論文要約（はしりラボのデータ 714本）。知りたいこと（質問）で選び、答え・★・グラフで1画面で分かる
- **設定**：休憩時間、週の目標セット数、テーマ、CSVで書き出し

動作環境は iOS 17 以降です。SwiftUI、SwiftData、Swift Charts を使っています。外部ライブラリはありません。

競合分析は [`../docs/market-analysis.md`](../docs/market-analysis.md)、論文データの作り方とルールは [`../ronbun/CLAUDE.md`](../ronbun/CLAUDE.md) にあります。

## 論文の表示ルール

- データ（`EviTrain/Resources/Studies/summaries.json`）はすべて「確認待ち」。**`approvals.json` で「公開OK」になっている論文だけ**を表示する
- `approvals.json` が空のあいだ、論文タブは「準備中」、今日の研究カードは出ない
- 開発用ビルド（Debug）だけ、論文タブ右上に「確認」画面が出る。要約を読んで「公開OK／保留」を付け、`approvals.json` を書き出して同梱ファイルと置き換える。App Store 版（Release）にはこの画面は入らない
- 画像は入れない。グラフ（charts.json）、★、研究の答えは表示する

## Mac でビルドする

Xcode のプロジェクトファイルは [XcodeGen](https://github.com/yonaskolb/XcodeGen) で `project.yml` から生成します。

```sh
brew install xcodegen      # 初回だけ
cd EviTrain
xcodegen generate          # EviTrain.xcodeproj ができる
open EviTrain.xcodeproj
```

Xcode を開いたら、次の手順でビルドします。

1. `EviTrain` ターゲットの **Signing & Capabilities** で Team を選ぶ
2. Bundle Identifier を自分のものに変える（例: `com.あなたの名前.evitrain`）。`project.yml` の `PRODUCT_BUNDLE_IDENTIFIER` を書き換えてもよい
3. シミュレータを選んで ▶︎ で実行する

テストはターミナルで次のように実行できます（シミュレータの iPhone を自動で選びます）。

```sh
DEVICE=$(xcrun simctl list devices available | grep -m1 -o 'iPhone [^(]*' | sed 's/ *$//')
xcodebuild test -project EviTrain.xcodeproj -scheme EviTrain -destination "platform=iOS Simulator,name=$DEVICE"
```

テストの中身（`EviTrainTests/`）: 論文714本が読めるか、★と研究の答えが決まった値か、グラフの数字が要旨の原文にあるか、全テーマに質問文があるか、公開OKだけが表示されるか、1RM・速度・連続日数の計算。

Claude Code を使う場合は、このフォルダで次のように頼めます。

> xcodegen でプロジェクトを作って、シミュレータでビルドとテストをして。エラーが出たら直して

## まだ無いもの

- アプリアイコンの画像（`Assets.xcassets/AppIcon.appiconset` に 1024×1024 の画像を入れる）
- Apple Watch、iCloud 同期、ルーティン機能（`docs/market-analysis.md` の「次のバージョンの候補」を参照）
