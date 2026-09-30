# FlowEA3 / FlowEA_B 引き渡しメモ（Claude Code用）

## 何のファイルか
- FlowEA3.mq5 (v3.42): FX中心のEA。ゴトー日/月末/FOMC/指標/カナダCPI/豪CPI/COT+守り。Magic 91001-91007, 91015。稼働中（リスク3%）。
- FlowEA_B.mq5 (v0.44): FlowEA3と値動きが違う手法の別EA。稼働中（リスク3%）。Magic 92001-92008。
  - B: BTC COT逆張り(28日保有) / D: 仮想通貨CPIストラドル / E: FX COT4週変化(守り役)
  - F: USDT発行→BTC/ETH買い(3日) / J: USDTプレミアム(毎時) / H: 木曜シャドーログ
  - C(原油EIA)・G(ハイテク決算)・I(指数CPI)は検証でNGだったためOFF
  - 売買のたびSendNotificationでスマホ通知
- LiveReport.mq5: 稼働中の成績を手法(Magic)ごとに集計するスクリプト

## データファイル（MQL5/Files に置く。#property tester_file で指定済み）
- FlowEA3: cot_hist.csv（あれば同梱）
- FlowEA_B: cot_btc.csv, cot_lev.csv, usdt_supply.csv, usdt_usd_1h.csv
- 稼働中はWebRequestで自動更新（許可URL: publicreporting.cftc.gov / stablecoins.llama.fi / api.exchange.coinbase.com）

## 環境
- XM KIWAMI デモ口座 75610109、Mac上のMT5(Wine)。FX銘柄は末尾#（例 USDJPY#）
- 1ヶ月後にリアル(最初1.5%)＋MQL5 VPSへ移行予定。VPSはDLL不可・スクリプトは移行されない

## 統合するときの注意（重要）
- Magic番号は絶対にぶつけない（91001-91015 / 92001-92008 は使用済み）
- 同一口座の合計リスクが増える。RiskMult()のDDスロットル(8%→x0.5, 15%→x0.33)は口座残高基準
- 同バーで損切りと利確が両方あたる場合は「負け」として数える方針（バックテスト時）
- ナンピン・マーチンゲールは禁止
- 稼働中のEAを壊さないこと。統合版は別名で作り、デモで確認してから差し替える
