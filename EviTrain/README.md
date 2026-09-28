# エビトレ（EviTrain）

筋トレとスプリントの記録アプリ。下のタブに、研究論文の要約を読める「論文」タブがあります。
アプリ名は仮です。

- **記録**：トレーニング中の入力（前回値の自動入力・休憩タイマー・自己ベスト更新のお知らせ）
- **履歴**：日付別の記録、種目別のグラフ、その種目に関係する研究
- **論文**：要約サイトの記事一覧（カテゴリ・検索・保存）
- **設定**：休憩時間、論文データのURL、CSVで書き出し

動作環境は iOS 17 以降です。SwiftUI、SwiftData、Swift Charts を使っています。外部ライブラリはありません。

競合分析は [`../docs/market-analysis.md`](../docs/market-analysis.md)、論文データの形式は [`../docs/papers-feed.md`](../docs/papers-feed.md) にあります。

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

Claude Code を使う場合は、このフォルダで次のように頼めます。

> xcodegen でプロジェクトを作って、シミュレータ向けにビルドして。エラーが出たら直して

## まだ無いもの

- アプリアイコンの画像（`Assets.xcassets/AppIcon.appiconset` に 1024×1024 の画像を入れる）
- Apple Watch、iCloud 同期、ルーティン機能（`docs/market-analysis.md` の「次のバージョンの候補」を参照）
