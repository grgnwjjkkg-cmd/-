# 論文パート 引き継ぎ（筋トレアプリ用）

このフォルダは、Webサイト「はしりラボ」用に作った **スポーツ科学の論文要約** を、筋トレアプリに組み込むための引き継ぎ一式。
Claude Code はまずこのファイルを全部読み、次に `data/` と `rules/` と `design/画面とグラフの仕様.md` を読んでから作業すること。

## ユーザーについて（必ず守る）
- 返答は必ず日本語
- 開発は初心者。専門用語は言い換えて説明する
- MacBook のトラックパッド操作（マウスなし）。操作手順は右クリック前提で書かない
- ファイルやデータを勝手に消さない。消す前に中身と理由を説明して了解を取る
- zip やビルドを渡すときは、ターミナルに貼れる取り込みコマンドも一緒に書く

## 方針
- アプリに **画像（イラスト）は入れない**。グラフ・★・研究の答えなどの表示は入れる
- 論文の中身は **医療・治療の話をしない**（ケガの治し方・サプリ・病気は扱わない）
- 「絶対」「必ず」「誰でも」「治る」は使わない
- 要約はすべて `status: 確認待ち`。**人が確認して「公開OK」にしたものだけ**をアプリに表示する仕組みにする

## データ（data/）
| ファイル | 中身 |
|---|---|
| summaries.json | 論文要約 714本（全分野）。1件=1論文 |
| summaries_kintore.json | 上のうち筋トレ・筋力に関係する 88本（最初はここから使う） |
| charts.json | グラフにできる数字 10本分（要旨の原文と照合済み） |
| topics.json | 分野・テーマの一覧と、PubMed の検索語 |
| unsummarized_147.json | 集めたがまだ要約していない論文（要旨つき） |

### summaries.json の1件の形
```
pmid, doi            … 論文ID（PubMed / DOI）
field, theme         … 分野 / テーマ（例: 筋力 / 速さを見ながら筋トレ（VBT））
status               … 確認待ち / 公開OK（アプリ側で管理）
basis                … 要旨のみ（本文までは読んでいない）
checked              … AI点検済み
headline             … 見出し（結論が分かる文）
one_line             … ひとこと結論
for_whom             … こんな人向け
design               … 研究の種類（まとめ研究（メタ分析）/ くじ引きで分けた実験 など）
who / what / period  … だれを / なにを / 期間
results[]            … 結果（数字は要旨どおり）
how_to_use[]         … 練習にどう使う？
limitations[]        … 気をつけたい点
stars (1〜5)         … 研究の確かさ
stars_reason         … ★の理由
verdict              … はい / たぶん はい / まだ分からない / 効果はなさそう
tags[]               … 子ども・大人・競技名など
citation             … first_author, year, journal, title_en
```

### charts.json の1件の形
```
pmid         … summaries.json の pmid と対応
chart_title  … グラフの題
unit         … % / 秒 / cm など
bars[]       … {label, value, kind(practice/compare/before/after)}
lower_is_better … true ならタイムなど「小さいほど良い」
note         … グラフの下に添える1文
quote        … 数字の根拠となる要旨の原文（空白の違いを除き一字一句同じ）
```

## 論文を追加するとき
1. `data/topics.json` にテーマと検索語を足す（筋トレ向けの例は `design/画面とグラフの仕様.md` の最後）
2. `scripts/fetch_pubmed.py` で PubMed から要旨を集める（使い方はファイル冒頭のコメント）
3. `rules/要約の作り方.md` のルールで要約を作る
4. `rules/点検のしかた.md` のルールで、**要約を作ったのとは別のエージェント**が要旨と照合して直す
5. 新しい要約を summaries.json に追加（pmid が重複しないように）

グラフを追加するときは、数字が要旨の原文にあることをプログラムで必ず確かめる（quote が要旨に含まれ、各 value がその quote に含まれること）。

## 最初にやってほしいこと（おすすめ順）
1. このフォルダを読んだうえで、筋トレアプリのどこに論文パートを入れるかを提案する
2. summaries_kintore.json をアプリに読み込んで、一覧と詳細の画面を作る
3. charts.json のグラフを詳細画面に表示する
4. 「確認待ち → 公開OK」を切り替えられる仕組み（開発者だけが使える画面、またはデータ上の印）を作る

## このリポジトリでの置き場所（筋トレアプリに組み込み済み）
| もの | 場所 |
|---|---|
| summaries.json / charts.json（アプリが読むデータ） | `EviTrain/EviTrain/Resources/Studies/` |
| themes.json（テーマごとの質問文 98件） | `EviTrain/EviTrain/Resources/Studies/` |
| approvals.json（人が「公開OK」にした pmid の一覧。2026-09-28 に714本すべて公開OK） | `EviTrain/EviTrain/Resources/Studies/` |
| menus.json（論文 → 練習メニュー 50本。作り方は `rules/メニューの作り方.md`） | `EviTrain/EviTrain/Resources/Studies/` |
| menus_skipped.json（メニューにしなかった80本と理由） | この `ronbun/data/` |
| topics.json・未要約の論文・ルール・仕様・取得スクリプト | この `ronbun/` フォルダ |

- summaries_kintore.json は summaries.json の一部なので、アプリには入れていない（全714本を入れ、公開OKのものだけ表示する）
- 要約を追加・修正したら `EviTrain/EviTrain/Resources/Studies/summaries.json` を更新し、新しいテーマがあれば themes.json に質問文を足す
- 公開OKの付け方: 開発用ビルドの「論文」タブ右上の「確認」→ 要約を読んで「公開OK」→「approvals.json を書き出す」→ 書き出したファイルで `Resources/Studies/approvals.json` を置き換える

### 論文メニュー（menus.json）
- 要旨（PubMed）をもとに作成係が下書き → 別の点検係が要旨と照合 → プログラムで「数字がすべて要旨にある・引用が原文どおり」を確認、の3段階
- すべて `status: 確認待ち`。開発用ビルドでは表示、App Store 版では `公開OK` にしたものだけ「このメニューで練習する」ボタンが出る
- 公開するときは menus.json の該当メニューの status を "公開OK" に変える
