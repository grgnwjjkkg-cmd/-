//+------------------------------------------------------------------+
//| FlowEA_B.mq5  v0.44（試作品）  2つ目のEA                           |
//|  FlowEA3 とは別の市場（主に仮想通貨）で「お金の流れ」を取る。         |
//|  FlowEA3 と同じ口座で同時に使える（マジック番号 92001〜92008）。      |
//|  【動く手法】                                                      |
//|  B. ビットコインCOT逆張り：資産運用会社の偏りが大きい週に逆張り、     |
//|     毎週1グループずつ入れて4週間(28日)保有（損切り=日足ATR×3）      |
//|  D. 仮想通貨 米CPIストラドル：BTC・ETH、幅=日足ATR×0.05、60分で決済  |
//|  E. COT「4週間の変化」逆張り：ドル絡み8銘柄、毎週入替・1週間保有     |
//|     （投機筋ポジションが4週間で急に動いた通貨の逆へ。FlowEA3のCOTとは別物）|
//|  F. USDT(テザー)大量発行の翌日にBTC・ETHを買い、3日保有（損切りATR×2）|
//|     ※Jのプレミアムもプラスのときだけにしてある（初期設定）                |
//|  J. USDTの上乗せ価格（コインベースのUSDT/USD）が高い→BTC・ETH買い、   |
//|     安い→売り。毎時判定、損切り=日足ATR×1                           |
//|  【初期OFF】C 原油在庫統計・G ハイテク決算（計算ミス修正後に弱い）、  |
//|            I 指数CPI（FlowEA3のCPIストラドルと重なる）              |
//|  【記録のみ】H 木曜の仮想通貨の下げ → MQL5/Files/floweab_shadow.csv  |
//|  必要なファイル（MQL5/Files）：cot_btc.csv cot_lev.csv               |
//|                               usdt_supply.csv usdt_usd_1h.csv       |
//|  WebRequest許可：publicreporting.cftc.gov / stablecoins.llama.fi /   |
//|                  api.exchange.coinbase.com                          |
//+------------------------------------------------------------------+
#property copyright "research"
#property version   "0.44"
#property tester_file "cot_btc.csv"
#property tester_file "cot_lev.csv"
#property tester_file "usdt_supply.csv"
#property tester_file "usdt_usd_1h.csv"
#include <Trade/Trade.mqh>

input double InpRiskPct      = 3.0;   // ★全体のリスク：B・Dの1回あたりの損失％（他の手法も同じ割合で大きくなる）。元の検証は0.5
input double InpBTCCOTRisk   = 0.5;   // B. BTC COT 1回で失ってよい割合 %
input bool   InpUseBTCCOT    = true;  // B. ビットコインCOT逆張り
input double InpBTCCOTThr    = 1.5;   // B. 偏りの基準（z）
input bool   InpCOTAutoUpdate= true;  // B. COTを毎週CFTCから自動取得（要：WebRequest許可 https://publicreporting.cftc.gov）
input bool   InpUseOilEIA    = false; // C. 原油 在庫統計ストラドル（v0.32：検証の計算ミスを直したら効果なし→初期OFF）
input double InpOilRisk      = 0.5;   // C. 1回で失ってよい割合 %
input double InpOilK         = 0.05;  // C. 逆指値の幅（日足ATRの何倍）
input int    InpOilHoldMin   = 30;    // C. 保有分数
input bool   InpUseCryptoCPI = true;  // D. 仮想通貨 米CPIストラドル
input double InpCryptoRisk   = 0.5;   // D. 1銘柄あたり失ってよい割合 %
input double InpCryptoK      = 0.05;  // D. 逆指値の幅（日足ATRの何倍）
input int    InpCryptoHoldMin= 60;    // D. 保有分数
input double InpCryptoMaxSpreadPct=50; // D. スプレッドが逆指値の幅(上下合計)の何%までなら入る（検証：50%まで入っても成績は良い）
input bool   InpCryptoUseYoY = false; // D. 米CPI前年比が3%以下なら休む（初期OFF：2023年以降は低インフレ期もプラスだったため）
input double InpUSCPIYoY     = 3.4;   // D. 米CPI前年比%（上をONにした時だけ使う。FlowEA3と同じ数字）
input string InpCPITimes     = "2026-10-14 12:30,2026-11-10 13:30,2026-12-10 13:30"; // 米CPI発表（UTC）FlowEA3と同じ
input string InpOilSym       = "OILCash#";  // 原油の銘柄名
input string InpBTCSym       = "BTCUSD#";   // ビットコインの銘柄名
input string InpETHSym       = "ETHUSD#";   // イーサリアムの銘柄名
input bool   InpUseCOTW      = true;  // E. COT 4週間の変化 逆張り（単体はほぼ±0だが、FlowEA3が負けた2020年に守りになった）
input double InpCOTWRisk     = 0.3;   // E. 1ポジションで失ってよい割合 %
input double InpCOTWThr      = 1.0;   // E. 基準
input bool   InpUseNQEarn    = false; // G. 巨大ハイテク決算ストラドル（v0.32：計算ミス修正で弱くなった→初期OFF）
input double InpNQRisk       = 0.5;   // G. 1回で失ってよい割合 %
input double InpNQK          = 0.1;   // G. 逆指値の幅（日足ATRの何倍）
input string InpNQTimes      = "2026-10-21 20:00,2026-10-28 20:00,2026-10-29 20:00,2026-11-17 21:00,2026-12-09 21:00"; // G. 決算日（米国16:00をUTCで。夏時間20:00/冬時間21:00）。対象：AAPL MSFT NVDA AMZN GOOGL META TSLA AVGO
input string InpNQSym        = "US100Cash#"; // G/I. ナスダック指数CFDの銘柄名
input bool   InpUseIdxCPI    = false; // I. ナスダック指数 米CPIストラドル（初期OFF：FlowEA3のCPIストラドルと同じ日・同じ向きで重なるため）
input double InpIdxCPIRisk   = 0.3;   // I. 1回で失ってよい割合 %
input double InpIdxCPIK      = 0.1;   // I. 逆指値の幅（日足ATRの何倍）
input double InpMaxSpreadPct = 25.0;  // スプレッドが損切り幅の何%を超えたら見送る
input bool   InpUseDDThrottle= true;  // 守り：口座残高（FlowEA3の分も含む）が最高値から減ったらロットを小さくする
input double InpDD1Pct       = 8.0;   // 守り1段目（口座残高の最高値から%）
input double InpDD1Mul       = 0.5;
input double InpDD2Pct       = 15.0;
input double InpDD2Mul       = 0.33;
input bool   InpUseUSDT      = true;  // F. USDT(テザー)大量発行の翌日にBTC・ETHを買う（3日保有）※要WebRequest許可 https://stablecoins.llama.fi
input double InpUSDTRisk     = 0.3;   // F. 1銘柄あたり失ってよい割合 %
input double InpUSDTThr      = 1.5;   // F. 発行の多さの基準（z）
input int    InpUSDTHoldD    = 3;     // F. 保有日数
input bool   InpUSDTNeedPrem = true;  // F. JのUSDTプレミアムもプラスの時だけ買う（検証：Jがマイナスの日のFは損）
input double InpUSDTSLk      = 2.0;   // F. 損切り（日足ATRの何倍）
input bool   InpUseUPrem     = true;  // J. USDTの上乗せ価格でBTC・ETHを売買（毎時判定）※要WebRequest許可 https://api.exchange.coinbase.com
input double InpUPRisk       = 0.3;   // J. 1銘柄あたり失ってよい割合 %
input double InpUPThr        = 1.0;   // J. 基準（z）
input double InpUPSLk        = 1.0;   // J. 損切り（日足ATRの何倍）
input string InpUPExtraSyms  = "";    // J. 追加するアルトコイン（例 SOLUSD#,XRPUSD#）。空=BTC・ETHだけ
input double InpUPExtraRisk  = 0.15;  // J. アルトコイン1銘柄あたり失ってよい割合 %
input double InpUPMaxSpreadBp= 25;    // J. スプレッドがこれ(0.01%単位)を超える銘柄は見送り（アルト用の安全装置）
input int    InpUPStepH      = 1;     // J. 何時間ごとに判定するか（1=毎時。検証では1時間ごとが最良）
input bool   InpShadowThu    = true;  // H(記録のみ・お金は動かない)：木曜の仮想通貨は下がりやすい？ を検証 → MQL5/Files/floweab_shadow.csv
input bool   InpNotify       = true;  // スマホに通知（FlowEA3の売買も含め、この口座の全部の約定）※MT5のオプション→通知でMetaQuotes IDの設定が必要
input bool   InpVerbose      = true;

CTrade trade;
#define MAGIC_BCOT  92001
#define MAGIC_OIL   92002
#define MAGIC_CCPI  92003
#define MAGIC_COTW  92004
#define MAGIC_NQ    92005
#define MAGIC_ICPI  92006
#define MAGIC_USDT  92007
#define MAGIC_UPREM 92008

// テスター用：過去の米CPI発表（UTC）2017.07〜2026.09
const string HIST_CPI  = "2017.07.14 12:30,2017.08.11 12:30,2017.09.14 12:30,2017.10.13 12:30,2017.11.15 13:30,2017.12.13 13:30,2018.01.12 13:30,2018.02.14 13:30,2018.03.13 12:30,2018.04.11 12:30,2018.05.10 12:30,2018.06.12 12:30,2018.07.12 12:30,2018.08.10 12:30,2018.09.13 12:30,2018.10.11 12:30,2018.11.14 13:30,2018.12.12 13:30,2019.01.11 13:30,2019.02.13 13:30,2019.03.12 12:30,2019.04.10 12:30,2019.05.10 12:30,2019.06.12 12:30,2019.07.11 12:30,2019.08.13 12:30,2019.09.12 12:30,2019.10.10 12:30,2019.11.13 13:30,2019.12.11 13:30,2020.01.14 13:30,2020.02.13 13:30,2020.03.11 12:30,2020.04.10 12:30,2020.05.12 12:30,2020.06.10 12:30,2020.07.14 12:30,2020.08.12 12:30,2020.09.11 12:30,2020.10.13 12:30,2020.11.12 13:30,2020.12.10 13:30,2021.01.13 13:30,2021.02.10 13:30,2021.03.10 13:30,2021.04.13 12:30,2021.05.12 12:30,2021.06.10 12:30,2021.07.13 12:30,2021.08.11 12:30,2021.09.14 12:30,2021.10.13 12:30,2021.11.10 13:30,2021.12.10 13:30,2022.01.12 13:30,2022.02.10 13:30,2022.03.10 13:30,2022.04.12 12:30,2022.05.11 12:30,2022.06.10 12:30,2022.07.13 12:30,2022.08.10 12:30,2022.09.13 12:30,2022.10.13 12:30,2022.11.10 13:30,2022.12.13 13:30,2023.01.12 13:30,2023.02.14 13:30,2023.03.14 12:30,2023.04.12 12:30,2023.05.10 12:30,2023.06.13 12:30,2023.07.12 12:30,2023.08.10 12:30,2023.09.13 12:30,2023.10.12 12:30,2023.11.14 13:30,2023.12.12 13:30,2024.01.11 13:30,2024.02.13 13:30,2024.03.12 12:30,2024.04.10 12:30,2024.05.15 12:30,2024.06.12 12:30,2024.07.11 12:30,2024.08.14 12:30,2024.09.11 12:30,2024.10.10 12:30,2024.11.13 13:30,2024.12.11 13:30,2025.01.15 13:30,2025.02.12 13:30,2025.03.12 12:30,2025.04.10 12:30,2025.05.13 12:30,2025.06.11 12:30,2025.07.15 12:30,2025.08.12 12:30,2025.09.11 12:30,2025.10.24 12:30,2025.12.18 13:30,2026.01.13 13:30,2026.02.13 13:30,2026.03.11 12:30,2026.04.10 12:30,2026.05.12 12:30,2026.06.10 12:30,2026.07.14 12:30,2026.08.12 12:30,2026.09.11 12:30";

const string HIST_YOY = "2008.01:4.3,2008.02:4.0,2008.03:4.0,2008.04:3.9,2008.05:4.2,2008.06:5.0,2008.07:5.6,2008.08:5.4,2008.09:4.9,2008.10:3.7,2008.11:1.1,2008.12:0.1,2009.01:0.0,2009.02:0.2,2009.03:-0.4,2009.04:-0.7,2009.05:-1.3,2009.06:-1.4,2009.07:-2.1,2009.08:-1.5,2009.09:-1.3,2009.10:-0.2,2009.11:1.8,2009.12:2.7,2010.01:2.6,2010.02:2.1,2010.03:2.3,2010.04:2.2,2010.05:2.0,2010.06:1.1,2010.07:1.2,2010.08:1.1,2010.09:1.1,2010.10:1.2,2010.11:1.1,2010.12:1.5,2011.01:1.6,2011.02:2.1,2011.03:2.7,2011.04:3.2,2011.05:3.6,2011.06:3.6,2011.07:3.6,2011.08:3.8,2011.09:3.9,2011.10:3.5,2011.11:3.4,2011.12:3.0,2012.01:2.9,2012.02:2.9,2012.03:2.7,2012.04:2.3,2012.05:1.7,2012.06:1.7,2012.07:1.4,2012.08:1.7,2012.09:2.0,2012.10:2.2,2012.11:1.8,2012.12:1.7,2013.01:1.6,2013.02:2.0,2013.03:1.5,2013.04:1.1,2013.05:1.4,2013.06:1.8,2013.07:2.0,2013.08:1.5,2013.09:1.2,2013.10:1.0,2013.11:1.2,2013.12:1.5,2014.01:1.6,2014.02:1.1,2014.03:1.5,2014.04:2.0,2014.05:2.1,2014.06:2.1,2014.07:2.0,2014.08:1.7,2014.09:1.7,2014.10:1.7,2014.11:1.3,2014.12:0.8,2015.01:-0.1,2015.02:-0.0,2015.03:-0.1,2015.04:-0.2,2015.05:-0.0,2015.06:0.1,2015.07:0.2,2015.08:0.2,2015.09:-0.0,2015.10:0.2,2015.11:0.5,2015.12:0.7,2016.01:1.4,2016.02:1.0,2016.03:0.9,2016.04:1.1,2016.05:1.0,2016.06:1.0,2016.07:0.8,2016.08:1.1,2016.09:1.5,2016.10:1.6,2016.11:1.7,2016.12:2.1,2017.01:2.5,2017.02:2.7,2017.03:2.4,2017.04:2.2,2017.05:1.9,2017.06:1.6,2017.07:1.7,2017.08:1.9,2017.09:2.2,2017.10:2.0,2017.11:2.2,2017.12:2.1,2018.01:2.1,2018.02:2.2,2018.03:2.4,2018.04:2.5,2018.05:2.8,2018.06:2.9,2018.07:2.9,2018.08:2.7,2018.09:2.3,2018.10:2.5,2018.11:2.2,2018.12:1.9,2019.01:1.6,2019.02:1.5,2019.03:1.9,2019.04:2.0,2019.05:1.8,2019.06:1.6,2019.07:1.8,2019.08:1.7,2019.09:1.7,2019.10:1.8,2019.11:2.1,2019.12:2.3,2020.01:2.5,2020.02:2.3,2020.03:1.5,2020.04:0.3,2020.05:0.1,2020.06:0.6,2020.07:1.0,2020.08:1.3,2020.09:1.4,2020.10:1.2,2020.11:1.2,2020.12:1.4,2021.01:1.4,2021.02:1.7,2021.03:2.6,2021.04:4.2,2021.05:5.0,2021.06:5.4,2021.07:5.4,2021.08:5.3,2021.09:5.4,2021.10:6.2,2021.11:6.8,2021.12:7.0,2022.01:7.5,2022.02:7.9,2022.03:8.5,2022.04:8.3,2022.05:8.6,2022.06:9.1,2022.07:8.5,2022.08:8.3,2022.09:8.2,2022.10:7.7,2022.11:7.1,2022.12:6.5,2023.01:6.4,2023.02:6.0,2023.03:5.0,2023.04:4.9,2023.05:4.0,2023.06:3.0,2023.07:3.2,2023.08:3.7,2023.09:3.7,2023.10:3.2,2023.11:3.1,2023.12:3.4,2024.01:3.1,2024.02:3.2,2024.03:3.5,2024.04:3.4,2024.05:3.3,2024.06:3.0,2024.07:2.9,2024.08:2.5,2024.09:2.4,2024.10:2.6,2024.11:2.7,2024.12:2.9,2025.01:3.0,2025.02:2.8,2025.03:2.4,2025.04:2.3,2025.05:2.4,2025.06:2.7,2025.07:2.7,2025.08:2.9,2025.09:3.0,2025.11:2.7,2025.12:2.7,2026.01:2.4,2026.02:2.4,2026.03:3.3,2026.04:3.8,2026.05:4.2,2026.06:3.5,2026.07:3.4";
const string HIST_NQ = "2016.01.26 21:00,2016.01.27 21:00,2016.01.28 21:00,2016.02.01 21:00,2016.02.10 21:00,2016.02.17 21:00,2016.03.03 21:00,2016.04.21 20:00,2016.04.26 20:00,2016.04.27 20:00,2016.04.28 20:00,2016.05.04 20:00,2016.06.02 20:00,2016.07.19 20:00,2016.07.26 20:00,2016.07.27 20:00,2016.07.28 20:00,2016.08.03 20:00,2016.08.11 20:00,2016.09.01 20:00,2016.10.20 20:00,2016.10.25 20:00,2016.10.26 20:00,2016.10.27 20:00,2016.11.02 20:00,2016.11.10 21:00,2016.12.08 21:00,2017.01.26 21:00,2017.01.31 21:00,2017.02.01 21:00,2017.02.02 21:00,2017.02.09 21:00,2017.02.22 21:00,2017.03.01 21:00,2017.04.27 20:00,2017.05.02 20:00,2017.05.03 20:00,2017.05.09 20:00,2017.06.01 20:00,2017.07.20 20:00,2017.07.24 20:00,2017.07.26 20:00,2017.07.27 20:00,2017.08.01 20:00,2017.08.02 20:00,2017.08.10 20:00,2017.08.24 20:00,2017.10.26 20:00,2017.11.01 20:00,2017.11.02 20:00,2017.11.09 21:00,2017.12.06 21:00,2018.01.31 21:00,2018.02.01 21:00,2018.02.07 21:00,2018.02.08 21:00,2018.03.15 20:00,2018.04.23 20:00,2018.04.25 20:00,2018.04.26 20:00,2018.05.01 20:00,2018.05.02 20:00,2018.05.10 20:00,2018.06.07 20:00,2018.07.19 20:00,2018.07.23 20:00,2018.07.25 20:00,2018.07.26 20:00,2018.07.31 20:00,2018.08.01 20:00,2018.08.16 20:00,2018.09.06 20:00,2018.10.24 20:00,2018.10.25 20:00,2018.10.30 20:00,2018.11.01 20:00,2018.11.15 21:00,2018.12.06 21:00,2019.01.29 21:00,2019.01.30 21:00,2019.01.31 21:00,2019.02.04 21:00,2019.02.14 21:00,2019.03.14 20:00,2019.04.24 20:00,2019.04.25 20:00,2019.04.29 20:00,2019.04.30 20:00,2019.05.16 20:00,2019.06.13 20:00,2019.07.18 20:00,2019.07.24 20:00,2019.07.25 20:00,2019.07.30 20:00,2019.08.15 20:00,2019.09.12 20:00,2019.10.23 20:00,2019.10.24 20:00,2019.10.28 20:00,2019.10.30 20:00,2019.11.14 21:00,2019.12.12 21:00,2020.01.28 21:00,2020.01.29 21:00,2020.01.30 21:00,2020.02.03 21:00,2020.02.13 21:00,2020.03.12 20:00,2020.04.28 20:00,2020.04.29 20:00,2020.05.21 20:00,2020.06.04 20:00,2020.07.22 20:00,2020.07.30 20:00,2020.08.19 20:00,2020.09.03 20:00,2020.10.27 20:00,2020.10.29 20:00,2020.11.18 21:00,2020.12.10 21:00,2021.01.26 21:00,2021.01.27 21:00,2021.02.02 21:00,2021.02.24 21:00,2021.03.04 21:00,2021.04.26 20:00,2021.04.27 20:00,2021.04.28 20:00,2021.04.29 20:00,2021.05.26 20:00,2021.06.03 20:00,2021.07.26 20:00,2021.07.27 20:00,2021.07.28 20:00,2021.07.29 20:00,2021.08.18 20:00,2021.09.02 20:00,2021.10.25 20:00,2021.10.26 20:00,2021.10.28 20:00,2021.11.17 21:00,2021.12.09 21:00,2022.01.25 21:00,2022.01.26 21:00,2022.01.27 21:00,2022.02.01 21:00,2022.02.02 21:00,2022.02.03 21:00,2022.02.16 21:00,2022.03.03 21:00,2022.04.20 20:00,2022.04.26 20:00,2022.04.27 20:00,2022.04.28 20:00,2022.05.25 20:00,2022.07.26 20:00,2022.07.27 20:00,2022.07.28 20:00,2022.08.24 20:00,2022.09.01 20:00,2022.10.25 20:00,2022.10.26 20:00,2022.10.27 20:00,2022.11.16 21:00,2022.12.08 21:00,2023.01.24 21:00,2023.01.25 21:00,2023.02.01 21:00,2023.02.02 21:00,2023.02.22 21:00,2023.03.02 21:00,2023.04.19 20:00,2023.04.25 20:00,2023.04.26 20:00,2023.04.27 20:00,2023.05.04 20:00,2023.05.24 20:00,2023.06.01 20:00,2023.07.19 20:00,2023.07.25 20:00,2023.07.26 20:00,2023.08.03 20:00,2023.08.23 20:00,2023.08.31 20:00,2023.10.18 20:00,2023.10.24 20:00,2023.10.25 20:00,2023.10.26 20:00,2023.11.02 20:00,2023.11.21 21:00,2023.12.07 21:00,2024.01.24 21:00,2024.01.30 21:00,2024.02.01 21:00,2024.02.21 21:00,2024.03.07 21:00,2024.04.23 20:00,2024.04.24 20:00,2024.04.25 20:00,2024.04.30 20:00,2024.05.02 20:00,2024.05.22 20:00,2024.06.12 20:00,2024.07.23 20:00,2024.07.30 20:00,2024.07.31 20:00,2024.08.01 20:00,2024.08.28 20:00,2024.09.05 20:00,2024.10.23 20:00,2024.10.29 20:00,2024.10.30 20:00,2024.10.31 20:00,2024.11.20 21:00,2024.12.12 21:00,2025.01.29 21:00,2025.01.30 21:00,2025.02.04 21:00,2025.02.06 21:00,2025.02.26 21:00,2025.03.06 21:00,2025.04.22 20:00,2025.04.24 20:00,2025.04.30 20:00,2025.05.01 20:00,2025.05.28 20:00,2025.06.05 20:00,2025.07.23 20:00,2025.07.30 20:00,2025.07.31 20:00,2025.08.27 20:00,2025.09.04 20:00,2025.10.22 20:00,2025.10.29 20:00,2025.10.30 20:00,2025.11.19 21:00,2025.12.11 21:00,2026.01.28 21:00,2026.01.29 21:00,2026.02.04 21:00,2026.02.05 21:00,2026.02.25 21:00,2026.03.04 21:00,2026.04.22 20:00,2026.04.29 20:00,2026.04.30 20:00,2026.05.20 20:00,2026.06.03 20:00,2026.07.22 20:00,2026.07.29 20:00,2026.07.30 20:00,2026.08.26 20:00";
string g_oil="", g_btc="", g_eth="", g_nq="";
double HistYoY(datetime relUTC)
{
   MqlDateTime t; TimeToStruct(relUTC,t); int y=t.year, m=t.mon-2; if(m<=0){ m+=12; y--; }
   string key=StringFormat("%04d.%02d:",y,m); int p=StringFind(HIST_YOY,key); if(p<0) return -999;
   int q=StringFind(HIST_YOY,",",p); string v=(q<0)?StringSubstr(HIST_YOY,p+8):StringSubstr(HIST_YOY,p+8,q-p-8);
   return StringToDouble(v);
}
//================== 時刻 ===========================================
datetime MakeT(int y,int m,int d,int hh=0,int mi=0){ MqlDateTime s; s.year=y; s.mon=m; s.day=d; s.hour=hh; s.min=mi; s.sec=0; return StructToTime(s); }
int DowOf(datetime t){ MqlDateTime s; TimeToStruct(t,s); return s.day_of_week; }
datetime NthSunday(int y,int m,int n)
{
   if(n>0){ datetime t=MakeT(y,m,1); while(DowOf(t)!=0) t+=86400; return t+(n-1)*7*86400; }
   datetime t=MakeT(y,m,1)+(datetime)(31*86400); MqlDateTime s; TimeToStruct(t,s);
   t=MakeT(s.year,s.mon,1)-86400; while(DowOf(t)!=0) t-=86400; return t;
}
bool IsUSDST(datetime utc){ MqlDateTime s; TimeToStruct(utc,s); datetime a=NthSunday(s.year,3,2)+7*3600, b=NthSunday(s.year,11,1)+6*3600; return utc>=a && utc<b; }
bool IsUKDST(datetime utc){ MqlDateTime s; TimeToStruct(utc,s); datetime a=NthSunday(s.year,3,-1)+3600, b=NthSunday(s.year,10,-1)+3600; return utc>=a && utc<b; }
int ServerOffsetHours(datetime utcGuess)
{
   if(!MQLInfoInteger(MQL_TESTER)){ long d=(long)(TimeTradeServer()-TimeGMT()); int h=(int)MathRound(d/3600.0); if(h==2||h==3) return h; }
   return IsUKDST(utcGuess)?3:2;
}
datetime ServerToUTC(datetime srv){ return srv-ServerOffsetHours(srv-2*3600)*3600; }
datetime UTCToServer(datetime utc){ return utc+ServerOffsetHours(utc)*3600; }
datetime NowUTC(){ return ServerToUTC(TimeTradeServer()); }
datetime ToNY(datetime utc){ return utc-(IsUSDST(utc)?4:5)*3600; }
datetime NYToUTC(datetime ny){ datetime g=ny+5*3600; return ny+(IsUSDST(g)?4:5)*3600; }
// 米国の祝日（連邦祝日、振替あり）
datetime NthWd(int y,int m,int wd,int n){ if(n>0){ datetime t=MakeT(y,m,1); while(DowOf(t)!=wd) t+=86400; return t+(n-1)*7*86400; }
   datetime t=(m==12?MakeT(y+1,1,1):MakeT(y,m+1,1))-86400; while(DowOf(t)!=wd) t-=86400; return t; }
datetime Observed(datetime d){ int w=DowOf(d); if(w==6) return d-86400; if(w==0) return d+86400; return d; }
bool IsUSHoliday(datetime day)
{
   MqlDateTime s; TimeToStruct(day,s); int y=s.year;
   datetime h[11]; h[0]=Observed(MakeT(y,1,1)); h[1]=NthWd(y,1,1,3); h[2]=NthWd(y,2,1,3); h[3]=NthWd(y,5,1,-1);
   h[4]=(y>=2021)?Observed(MakeT(y,6,19)):(datetime)0; h[5]=Observed(MakeT(y,7,4)); h[6]=NthWd(y,9,1,1); h[7]=NthWd(y,10,1,2);
   h[8]=Observed(MakeT(y,11,11)); h[9]=NthWd(y,11,4,4); h[10]=Observed(MakeT(y,12,25));
   for(int i=0;i<11;i++) if(h[i]==day) return true;
   if(Observed(MakeT(y+1,1,1))==day) return true;   // 翌年元日の振替が12/31になる場合
   return false;
}
//================== 守り・ロット ======================================
double g_peak=0; string g_gvPeak="";
double RiskMult()
{
   double sc=InpRiskPct/0.5;                          // 全体の倍率（3.0なら6倍）
   if(!InpUseDDThrottle) return sc;
   double b=AccountInfoDouble(ACCOUNT_BALANCE); if(g_peak<=0) g_peak=b; if(b>g_peak) g_peak=b;
   double dd=(g_peak>0)?(1.0-b/g_peak)*100.0:0;
   double m=1.0; if(dd>=InpDD1Pct) m=InpDD1Mul; if(dd>=InpDD2Pct) m=InpDD2Mul;
   if(!MQLInfoInteger(MQL_TESTER)) GlobalVariableSet(g_gvPeak,g_peak);
   return m*sc;
}
string Resolve(string want)
{
   if(SymbolSelect(want,true) && SymbolInfoInteger(want,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_FULL) return want;
   string base=want; StringReplace(base,"#","");
   for(int i=0;i<SymbolsTotal(false);i++){ string nm=SymbolName(i,false);
      if(StringFind(nm,base)==0 && StringLen(nm)<=StringLen(base)+2 && SymbolSelect(nm,true) && SymbolInfoInteger(nm,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_FULL) return nm; }
   return "";
}
double DailyATR(string sym)
{
   int h=iATR(sym,PERIOD_D1,14); if(h==INVALID_HANDLE) return 0;
   double b[]; if(CopyBuffer(h,0,1,1,b)!=1){ IndicatorRelease(h); return 0; }
   IndicatorRelease(h); return b[0];
}
double LotsFor(string sym,double slDist,double money)
{
   MqlTick t; if(!SymbolInfoTick(sym,t) || slDist<=0) return 0;
   double loss1=0; if(!OrderCalcProfit(ORDER_TYPE_BUY,sym,1.0,t.ask,t.ask-slDist,loss1)) return 0;
   loss1=MathAbs(loss1); if(loss1<=0) return 0;
   double st=SymbolInfoDouble(sym,SYMBOL_VOLUME_STEP), mn=SymbolInfoDouble(sym,SYMBOL_VOLUME_MIN), mx=SymbolInfoDouble(sym,SYMBOL_VOLUME_MAX);
   double lots=MathFloor(money/loss1/st)*st;
   if(lots<mn) return 0; if(lots*loss1>money*1.05) return 0;
   return MathMin(lots,mx);
}
void LogFill(string sym,int dir,double want,double got,string tag)
{
   int f=FileOpen("floweab_fills.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
   if(f==INVALID_HANDLE) return; FileSeek(f,0,SEEK_END);
   // 滑りは「価格の0.01%単位」で記録（銘柄をまたいで比べやすくするため）
   double bp=(want>0)?dir*(got-want)/want*10000.0:0;
   FileWrite(f,TimeToString(TimeTradeServer(),TIME_DATE|TIME_SECONDS),tag,sym,dir,DoubleToString(want,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)),
             DoubleToString(got,(int)SymbolInfoInteger(sym,SYMBOL_DIGITS)),DoubleToString(bp,2));
   FileClose(f);
}
bool ClosePos(ulong tk){ if(!PositionSelectByTicket(tk)) return false; trade.SetExpertMagicNumber((ulong)PositionGetInteger(POSITION_MAGIC)); return trade.PositionClose(tk); }

//================== ストラドル（C・D 共通）============================
struct Ev { datetime relUTC; int kind; int holdMin; bool placed; bool closed; };   // kind 1=原油EIA 2=仮想CPI 3=ハイテク決算 4=指数CPI
Ev g_ev[];
datetime ParseUTC(string x){ StringTrimLeft(x); StringTrimRight(x); StringReplace(x,"-","."); return StringToTime(x); }
void AddEv(datetime t,int kind,int hold)
{
   for(int i=0;i<ArraySize(g_ev);i++) if(g_ev[i].relUTC==t && g_ev[i].kind==kind) return;
   int k=ArraySize(g_ev); ArrayResize(g_ev,k+1); g_ev[k].relUTC=t; g_ev[k].kind=kind; g_ev[k].holdMin=hold; g_ev[k].placed=false; g_ev[k].closed=false;
}
void AddList(string list,int kind,int hold){ string p[]; int n=StringSplit(list,',',p); for(int i=0;i<n;i++){ datetime t=ParseUTC(p[i]); if(t>0) AddEv(t,kind,hold);} }
// 今週の水曜10:30(NY)を登録（月〜水に米国の祝日がある週は、発表日がずれるので見送り）
void AddOilWeek(datetime utc)
{
   datetime ny=ToNY(utc); datetime d=ny-(ny%86400); int w=DowOf(d);
   datetime wed=d+(3-w)*86400; if(w>3) wed+=7*86400;
   for(int i=0;i<=2;i++) if(IsUSHoliday(wed-(2-i)*86400)) return;
   datetime rel=NYToUTC(wed+10*3600+30*60);
   AddEv(rel,1,InpOilHoldMin);
}
string EvTag(int kind){ return kind==1?"OIL_EIA":kind==2?"CRYPTO_CPI":kind==3?"NQ_EARN":"IDX_CPI"; }
long EvMagic(int kind){ return kind==1?MAGIC_OIL:kind==2?MAGIC_CCPI:kind==3?MAGIC_NQ:MAGIC_ICPI; }
void PlaceEv(int e)
{
   string syms[]; double kk; double risk; int n=0;
   if(g_ev[e].kind==1){ if(!InpUseOilEIA || g_oil=="") return; ArrayResize(syms,1); syms[0]=g_oil; n=1; kk=InpOilK; risk=InpOilRisk; }
   else if(g_ev[e].kind==3){ if(!InpUseNQEarn || g_nq=="") return; ArrayResize(syms,1); syms[0]=g_nq; n=1; kk=InpNQK; risk=InpNQRisk; }
   else if(g_ev[e].kind==4){ if(!InpUseIdxCPI || g_nq=="") return; ArrayResize(syms,1); syms[0]=g_nq; n=1; kk=InpIdxCPIK; risk=InpIdxCPIRisk; }
   else
   {
      if(!InpUseCryptoCPI) return;
      if(InpCryptoUseYoY && InpUSCPIYoY>0)
      {
         double yy=MQLInfoInteger(MQL_TESTER)?HistYoY(g_ev[e].relUTC):InpUSCPIYoY;
         if(yy>-900 && yy<=3.0){ if(InpVerbose) Print("米CPI前年比 ",DoubleToString(yy,1),"% ≤ 3% のため仮想通貨CPIは休み"); return; }
      }
      ArrayResize(syms,2); n=0; if(g_btc!=""){ syms[n]=g_btc; n++; } if(g_eth!=""){ syms[n]=g_eth; n++; } kk=InpCryptoK; risk=InpCryptoRisk;
   }
   string tag=EvTag(g_ev[e].kind);
   datetime expSrv=UTCToServer(g_ev[e].relUTC)+g_ev[e].holdMin*60;
   for(int i=0;i<n;i++)
   {
      string sym=syms[i]; double a=DailyATR(sym); if(a<=0) continue;
      MqlTick t; if(!SymbolInfoTick(sym,t)) continue;
      int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      double k=kk*a, p0=(t.bid+t.ask)/2.0, up=NormalizeDouble(p0+k,dg), dn=NormalizeDouble(p0-k,dg);
      double spPct=(g_ev[e].kind==2)?InpCryptoMaxSpreadPct:InpMaxSpreadPct;
      if(t.ask-t.bid > 2*k*spPct/100.0){ if(InpVerbose) Print(tag," ",sym," スプレッドが広いので見送り"); continue; }
      double money=AccountInfoDouble(ACCOUNT_BALANCE)*risk*RiskMult()/100.0;
      double lots=LotsFor(sym,2*k,money); if(lots<=0){ if(InpVerbose) Print(tag," ",sym," ロット不足で見送り"); continue; }
      trade.SetExpertMagicNumber(EvMagic(g_ev[e].kind));
      trade.BuyStop (lots,up,sym,dn,0,ORDER_TIME_SPECIFIED,expSrv,tag);
      trade.SellStop(lots,dn,sym,up,0,ORDER_TIME_SPECIFIED,expSrv,tag);
      if(InpVerbose) Print(tag," ",sym," 逆指値 上 ",up," 下 ",dn," ",DoubleToString(lots,2),"lot");
   }
}
bool IsStrMagic(long m){ return m==MAGIC_OIL || m==MAGIC_CCPI || m==MAGIC_NQ || m==MAGIC_ICPI; }
void ManageStr()
{
   for(int i=PositionsTotal()-1;i>=0;i--)
   {
      ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue;
      long mg=PositionGetInteger(POSITION_MAGIC); if(!IsStrMagic(mg)) continue;
      string sym=PositionGetString(POSITION_SYMBOL);
      for(int j=OrdersTotal()-1;j>=0;j--)
      {
         ulong ot=OrderGetTicket(j); if(!OrderSelect(ot)) continue;
         if(OrderGetInteger(ORDER_MAGIC)!=mg || OrderGetString(ORDER_SYMBOL)!=sym) continue;
         int pdir=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1;
         double want=OrderGetDouble(ORDER_SL);
         trade.OrderDelete(ot);
         LogFill(sym,pdir,want,PositionGetDouble(POSITION_PRICE_OPEN),PositionGetString(POSITION_COMMENT));
      }
   }
}
void CloseEvExpired(datetime utc)
{
   for(int e=0;e<ArraySize(g_ev);e++)
   {
      if(!g_ev[e].placed || g_ev[e].closed) continue;
      if(utc < g_ev[e].relUTC + g_ev[e].holdMin*60) continue;
      long mg=EvMagic(g_ev[e].kind);
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC)==mg) ClosePos(tk); }
      for(int j=OrdersTotal()-1;j>=0;j--){ ulong ot=OrderGetTicket(j); if(OrderSelect(ot) && OrderGetInteger(ORDER_MAGIC)==mg) trade.OrderDelete(ot); }
      g_ev[e].closed=true;
   }
}

//================== B. ビットコインCOT ===============================
datetime c_asof[]; datetime c_rel[]; double c_net[]; double c_z[];
bool g_cotOK=false; datetime g_lastFetch=0; long g_doneWeek=-1;
bool LoadCOT()
{
   ArrayResize(c_asof,0); ArrayResize(c_rel,0); ArrayResize(c_net,0); ArrayResize(c_z,0);
   int f=FileOpen("cot_btc.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(f==INVALID_HANDLE){ Print("cot_btc.csv が見つかりません（MQL5/Files に入れてください）"); return false; }
   while(!FileIsEnding(f))
   {
      string ln=FileReadString(f); if(StringLen(ln)<10) continue;
      string p[]; if(StringSplit(ln,',',p)<4) continue;
      int k=ArraySize(c_asof); ArrayResize(c_asof,k+1); ArrayResize(c_rel,k+1); ArrayResize(c_net,k+1); ArrayResize(c_z,k+1);
      c_asof[k]=StringToTime(p[1]); c_rel[k]=StringToTime(p[2]); c_net[k]=StringToDouble(p[3]);
      c_z[k]=(ArraySize(p)>=5 && StringLen(p[4])>0)?StringToDouble(p[4]):EMPTY_VALUE;
   }
   FileClose(f); Print("BTC COTデータ読み込み: ",ArraySize(c_asof)," 行"); return ArraySize(c_asof)>0;
}
bool GetZ(datetime utc,double &z)
{
   int best=-1; for(int i=0;i<ArraySize(c_asof);i++) if(c_rel[i]<=utc && (best<0 || c_rel[i]>c_rel[best])) best=i;
   if(best<0 || c_z[best]==EMPTY_VALUE) return false;
   if(utc-c_asof[best] > 13*86400) return false;
   z=c_z[best]; return true;
}
datetime LatestAsof(){ datetime m=0; for(int i=0;i<ArraySize(c_asof);i++) if(c_asof[i]>m) m=c_asof[i]; return m; }
double ZFromNets(double newNet)
{
   int n=ArraySize(c_net); if(n<103) return EMPTY_VALUE;
   int L=MathMin(155,n); double w[]; ArrayResize(w,L+1);
   for(int j=0;j<L;j++) w[j]=c_net[n-L+j]; w[L]=newNet;
   double m=0; for(int j=0;j<=L;j++) m+=w[j]; m/=(L+1);
   double s=0; for(int j=0;j<=L;j++) s+=(w[j]-m)*(w[j]-m); s=MathSqrt(s/L);
   return s>0?(newNet-m)/s:EMPTY_VALUE;
}
string JsonVal(string obj,string key)
{
   int p=StringFind(obj,"\""+key+"\""); if(p<0) return "";
   int c=StringFind(obj,":",p); if(c<0) return "";
   int a=c+1; while(a<StringLen(obj) && (StringGetCharacter(obj,a)==' '||StringGetCharacter(obj,a)=='"')) a++;
   int b=a; while(b<StringLen(obj)){ ushort ch=StringGetCharacter(obj,b); if(ch=='"'||ch==','||ch=='}') break; b++; }
   return StringSubstr(obj,a,b-a);
}
void FetchCOT()
{
   string url="https://publicreporting.cftc.gov/resource/gpe5-46if.json?cftc_contract_market_code=133741&$order=report_date_as_yyyy_mm_dd%20DESC&$limit=4";
   char data[],res[]; string hdr;
   int r=WebRequest("GET",url,"",10000,data,res,hdr);
   if(r!=200){ Print("BTC COT取得に失敗 code=",r," err=",GetLastError()," → オプションでURLの許可を確認してください"); return; }
   string js=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   string objs[]; int n=0,pos=0;
   while(true){ int a=StringFind(js,"{",pos); if(a<0) break; int b=StringFind(js,"}",a); if(b<0) break; ArrayResize(objs,n+1); objs[n]=StringSubstr(js,a,b-a+1); n++; pos=b+1; }
   for(int j=n-1;j>=0;j--)
   {
      string d=StringSubstr(JsonVal(objs[j],"report_date_as_yyyy_mm_dd"),0,10); StringReplace(d,"-",".");
      datetime asof=StringToTime(d); if(asof<=0 || asof<=LatestAsof()) continue;
      double L=StringToDouble(JsonVal(objs[j],"asset_mgr_positions_long")), S=StringToDouble(JsonVal(objs[j],"asset_mgr_positions_short"));
      double oi=StringToDouble(JsonVal(objs[j],"open_interest_all")); if(oi<=0) continue;
      datetime fri=asof+3*86400+15*3600+30*60; datetime rel=fri+(IsUSDST(fri+5*3600)?4:5)*3600;
      double net=(L-S)/oi, z=ZFromNets(net);
      int k=ArraySize(c_asof); ArrayResize(c_asof,k+1); ArrayResize(c_rel,k+1); ArrayResize(c_net,k+1); ArrayResize(c_z,k+1);
      c_asof[k]=asof; c_rel[k]=rel; c_net[k]=net; c_z[k]=z;
      int f=FileOpen("cot_btc.csv",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(f!=INVALID_HANDLE){ FileSeek(f,0,SEEK_END);
         FileWriteString(f,StringFormat("BTC,%s,%s,%.6f,%s\n",TimeToString(asof,TIME_DATE),TimeToString(rel,TIME_DATE|TIME_MINUTES),net,z==EMPTY_VALUE?"":DoubleToString(z,4))); FileClose(f); }
      Print("BTC COT更新: ",d," net/OI=",DoubleToString(net,4)," z=",z==EMPTY_VALUE?"-":DoubleToString(z,2));
   }
}
// 月曜00:05(UTC)に判定。zが基準を超えたら逆張りで新しいグループを入れる。28日たったら決済
void BTCCOTStep(datetime utc)
{
   if(!InpUseBTCCOT || !g_cotOK || g_btc=="") return;
   if(InpCOTAutoUpdate && !MQLInfoInteger(MQL_TESTER) && TimeLocal()-g_lastFetch>6*3600)
   { g_lastFetch=TimeLocal(); if(utc-LatestAsof()>9*86400) FetchCOT(); }
   // 20日経過したポジションを決済
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MAGIC_BCOT) continue;
      if(TimeTradeServer()-(datetime)PositionGetInteger(POSITION_TIME) >= 28*86400) ClosePos(tk); }
   if(DowOf(utc)!=1) return;
   long wk=(long)(utc/(7*86400));
   if(wk==g_doneWeek) return;
   if((utc%86400) < 5*60) return;                    // 00:05以降
   g_doneWeek=wk;
   double z; if(!GetZ(utc,z)){ if(InpVerbose) Print("BTC COT: 使えるデータなし"); return; }
   if(MathAbs(z)<=InpBTCCOTThr){ if(InpVerbose) Print("BTC COT: z=",DoubleToString(z,2)," 基準以下なので見送り"); return; }
   int dir=(z>0)?-1:1;                               // 逆張り
   double a=DailyATR(g_btc); if(a<=0) return;
   double sl=3.0*a; MqlTick t; if(!SymbolInfoTick(g_btc,t)) return;
   if(t.ask-t.bid > sl*InpMaxSpreadPct/100.0) return;
   double lots=LotsFor(g_btc,sl,AccountInfoDouble(ACCOUNT_BALANCE)*InpBTCCOTRisk*RiskMult()/100.0);
   if(lots<=0){ if(InpVerbose) Print("BTC COT: ロット不足で見送り"); return; }
   int dg=(int)SymbolInfoInteger(g_btc,SYMBOL_DIGITS);
   trade.SetExpertMagicNumber(MAGIC_BCOT);
   bool ok=(dir>0)?trade.Buy(lots,g_btc,0,NormalizeDouble(t.ask-sl,dg),0,"BTC_COT"):trade.Sell(lots,g_btc,0,NormalizeDouble(t.bid+sl,dg),0,"BTC_COT");
   if(InpVerbose) Print("BTC COT ",dir>0?"買い ":"売り ",DoubleToString(lots,2),"lot z=",DoubleToString(z,2)," ",ok?"OK":"失敗");
}


//================== E. COT 4週間の変化 逆張り =========================
string W8[]  = {"EURUSD","GBPUSD","AUDUSD","NZDUSD","USDJPY","USDCAD","USDCHF","XAUUSD"};
string W8R[];
string w_ccy[]; datetime w_asof[]; datetime w_rel[]; double w_net[]; double w_z[];
bool g_wOK=false; long g_wWeek=-1; bool g_wDone[]; datetime g_wFetch=0;
string ResolveFX(string base)
{
   string alt=base; if(base=="XAUUSD") alt="GOLD";
   string c1=base+"#", c2=alt+"#";
   if(SymbolSelect(c1,true) && SymbolInfoInteger(c1,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_FULL) return c1;
   if(SymbolSelect(c2,true) && SymbolInfoInteger(c2,SYMBOL_TRADE_MODE)==SYMBOL_TRADE_MODE_FULL) return c2;
   string r=Resolve(base); if(r=="") r=Resolve(alt); return r;
}
bool LoadCOTW()
{
   ArrayResize(w_ccy,0); ArrayResize(w_asof,0); ArrayResize(w_rel,0); ArrayResize(w_net,0); ArrayResize(w_z,0);
   int f=FileOpen("cot_lev.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(f==INVALID_HANDLE){ Print("cot_lev.csv が見つかりません（MQL5/Files に入れてください）"); return false; }
   while(!FileIsEnding(f))
   {
      string ln=FileReadString(f); if(StringLen(ln)<10) continue;
      string p[]; if(StringSplit(ln,',',p)<4) continue;
      if(StringToDouble(p[3])==0.0) continue;          // 読み取りミスの行（net=0）は使わない
      int k=ArraySize(w_ccy); ArrayResize(w_ccy,k+1); ArrayResize(w_asof,k+1); ArrayResize(w_rel,k+1); ArrayResize(w_net,k+1); ArrayResize(w_z,k+1);
      w_ccy[k]=p[0]; w_asof[k]=StringToTime(p[1]); w_rel[k]=StringToTime(p[2]); w_net[k]=StringToDouble(p[3]);
      w_z[k]=(ArraySize(p)>=5 && StringLen(p[4])>0)?StringToDouble(p[4]):EMPTY_VALUE;
   }
   FileClose(f); Print("COT(4週変化)データ読み込み: ",ArraySize(w_ccy)," 行"); return ArraySize(w_ccy)>0;
}
bool GetZW(string ccy,datetime utc,double &z)
{
   if(ccy=="USD"){ z=0; return true; }
   int best=-1; for(int i=0;i<ArraySize(w_ccy);i++) if(w_ccy[i]==ccy && w_rel[i]<=utc && (best<0 || w_rel[i]>w_rel[best])) best=i;
   if(best<0 || w_z[best]==EMPTY_VALUE) return false;
   if(utc-w_asof[best] > 13*86400) return false;
   z=w_z[best]; return true;
}
datetime LatestAsofW(string ccy){ datetime m=0; for(int i=0;i<ArraySize(w_ccy);i++) if(w_ccy[i]==ccy && w_asof[i]>m) m=w_asof[i]; return m; }
// 新しい週の値 newNet を加えたときの「4週間の変化 ÷ 過去156本の4週間変化の標準偏差」
double ZD4(string ccy,double newNet)
{
   double v[]; int n=0;
   for(int i=0;i<ArraySize(w_ccy);i++) if(w_ccy[i]==ccy){ ArrayResize(v,n+1); v[n]=w_net[i]; n++; }
   ArrayResize(v,n+1); v[n]=newNet; n++;
   if(n<4+156) return EMPTY_VALUE;
   double ch[156]; for(int j=0;j<156;j++){ int t=n-156+j; ch[j]=v[t]-v[t-4]; }
   double m=0; for(int j=0;j<156;j++) m+=ch[j]; m/=156;
   double s=0; for(int j=0;j<156;j++) s+=(ch[j]-m)*(ch[j]-m); s=MathSqrt(s/155);
   return s>0 ? ch[155]/s : EMPTY_VALUE;
}
void FetchCOTW()
{
   string cc[]={"EUR","GBP","JPY","CHF","CAD","AUD","NZD","XAU"};
   string code[]={"099741","096742","097741","092741","090741","232741","112741","088691"};
   for(int i=0;i<ArraySize(cc);i++)
   {
      bool gold=(cc[i]=="XAU");
      string url="https://publicreporting.cftc.gov/resource/"+(gold?"72hh-3qpy":"gpe5-46if")+".json?cftc_contract_market_code="+code[i]
                 +"&$order=report_date_as_yyyy_mm_dd%20DESC&$limit=4";
      char data[],res[]; string hdr;
      int r=WebRequest("GET",url,"",10000,data,res,hdr);
      if(r!=200){ Print("COT(4週変化)取得に失敗(",cc[i],") code=",r," err=",GetLastError()); return; }
      string js=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
      string objs[]; int n=0,pos=0;
      while(true){ int a=StringFind(js,"{",pos); if(a<0) break; int b=StringFind(js,"}",a); if(b<0) break; ArrayResize(objs,n+1); objs[n]=StringSubstr(js,a,b-a+1); n++; pos=b+1; }
      for(int j=n-1;j>=0;j--)
      {
         string d=StringSubstr(JsonVal(objs[j],"report_date_as_yyyy_mm_dd"),0,10); StringReplace(d,"-",".");
         datetime asof=StringToTime(d); if(asof<=0 || asof<=LatestAsofW(cc[i])) continue;
         double L=StringToDouble(JsonVal(objs[j],gold?"m_money_positions_long_all":"lev_money_positions_long"));
         double S=StringToDouble(JsonVal(objs[j],gold?"m_money_positions_short_all":"lev_money_positions_short"));
         if(L<=0 && S<=0){ Print("COT(4週変化) ",cc[i]," の値が読めないので見送り"); continue; }
         datetime fri=asof+3*86400+15*3600+30*60; datetime rel=fri+(IsUSDST(fri+5*3600)?4:5)*3600;
         double net=L-S, z=ZD4(cc[i],net);
         int k=ArraySize(w_ccy); ArrayResize(w_ccy,k+1); ArrayResize(w_asof,k+1); ArrayResize(w_rel,k+1); ArrayResize(w_net,k+1); ArrayResize(w_z,k+1);
         w_ccy[k]=cc[i]; w_asof[k]=asof; w_rel[k]=rel; w_net[k]=net; w_z[k]=z;
         int f=FileOpen("cot_lev.csv",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI);
         if(f!=INVALID_HANDLE){ FileSeek(f,0,SEEK_END);
            FileWriteString(f,StringFormat("%s,%s,%s,%.0f,%s\n",cc[i],TimeToString(asof,TIME_DATE),TimeToString(rel,TIME_DATE|TIME_MINUTES),net,z==EMPTY_VALUE?"":DoubleToString(z,4))); FileClose(f); }
         Print("COT(4週変化)更新: ",cc[i]," ",d," net=",net," z=",z==EMPTY_VALUE?"-":DoubleToString(z,2));
      }
   }
}
datetime WeekStartNY(datetime ny){ datetime d=ny-(ny%86400); int w=DowOf(d); datetime s=d-w*86400+18*3600; if(ny<s) s-=7*86400; return s; }
void COTWStep(datetime utc)
{
   if(!InpUseCOTW || !g_wOK) return;
   if(InpCOTAutoUpdate && !MQLInfoInteger(MQL_TESTER) && TimeLocal()-g_wFetch>6*3600)
   { g_wFetch=TimeLocal(); if(utc-LatestAsofW("EUR")>9*86400 || utc-LatestAsofW("XAU")>9*86400) FetchCOTW(); }
   datetime ny=ToNY(utc), ws=WeekStartNY(ny);
   long wk=(long)(ws/(7*86400));
   if(!(ny>=ws && ny<ws+6*3600)) return;           // 日曜18:00〜24:00(NY)の間に入替
   if(g_wWeek!=wk)
   {
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC)==MAGIC_COTW) ClosePos(tk); }
      ArrayInitialize(g_wDone,false); g_wWeek=wk;
   }
   double bal=AccountInfoDouble(ACCOUNT_BALANCE);
   for(int i=0;i<ArraySize(W8);i++)
   {
      if(g_wDone[i] || W8R[i]=="") continue;
      string base=StringSubstr(W8[i],0,3), quote=StringSubstr(W8[i],3,3);
      double zb,zq; if(!GetZW(base,utc,zb) || !GetZW(quote,utc,zq)){ g_wDone[i]=true; continue; }
      double score=-(zb-zq);
      if(MathAbs(score)<=InpCOTWThr){ g_wDone[i]=true; continue; }
      int dir=score>0?1:-1;
      double a=DailyATR(W8R[i]); if(a<=0) continue;
      double sl=3.0*a; MqlTick t; if(!SymbolInfoTick(W8R[i],t)) continue;
      if(t.ask-t.bid > 0.05*sl) continue;          // 週明け直後でスプレッドが広い → 少し待って再挑戦
      double lots=LotsFor(W8R[i],sl,bal*InpCOTWRisk*RiskMult()/100.0);
      g_wDone[i]=true;
      if(lots<=0){ if(InpVerbose) Print("COTW ",W8R[i]," ロット不足で見送り"); continue; }
      int dg=(int)SymbolInfoInteger(W8R[i],SYMBOL_DIGITS);
      trade.SetExpertMagicNumber(MAGIC_COTW);
      bool ok=dir>0?trade.Buy(lots,W8R[i],0,NormalizeDouble(t.ask-sl,dg),0,"COTW"):trade.Sell(lots,W8R[i],0,NormalizeDouble(t.bid+sl,dg),0,"COTW");
      if(InpVerbose) Print("COTW ",W8R[i],dir>0?" 買い ":" 売り ",DoubleToString(lots,2),"lot score=",DoubleToString(score,2)," ",ok?"OK":"失敗");
   }
}


//================== H. 記録だけ：木曜の仮想通貨（実際には売買しない）=====
double g_thuP[2]; int g_thuDay=-1; bool g_thuOpen=false;
void ShadowThu(datetime utc)
{
   if(!InpShadowThu || MQLInfoInteger(MQL_TESTER)) return;
   string sy[2]; sy[0]=g_btc; sy[1]=g_eth;
   int dow=DowOf(utc); int key=(int)(utc/86400);
   if(dow==4 && !g_thuOpen && key!=g_thuDay && (utc%86400)<3600)          // 木曜 00:00(UTC) に記録開始
   {
      for(int i=0;i<2;i++){ MqlTick t; g_thuP[i]=(sy[i]!="" && SymbolInfoTick(sy[i],t))?t.bid:0; }
      g_thuOpen=true; g_thuDay=key;
   }
   if(dow==5 && g_thuOpen)                            // 金曜 00:00(UTC) に記録終了（売りで入った想定）
   {
      int f=FileOpen("floweab_shadow.csv",FILE_READ|FILE_WRITE|FILE_CSV|FILE_ANSI,',');
      if(f!=INVALID_HANDLE){ FileSeek(f,0,SEEK_END);
         for(int i=0;i<2;i++){ MqlTick t; if(sy[i]=="" || g_thuP[i]<=0 || !SymbolInfoTick(sy[i],t)) continue;
            double bp=(g_thuP[i]-t.ask)/g_thuP[i]*10000.0;
            FileWrite(f,TimeToString(utc,TIME_DATE),"THU_SHORT",sy[i],DoubleToString(g_thuP[i],2),DoubleToString(t.ask,2),DoubleToString(bp,1)); }
         FileClose(f); }
      g_thuOpen=false;
   }
}

bool UPZNow(datetime utc,double &z);   // 下（J）で定義
//================== F. USDT（テザー）発行 → BTC・ETH買い ================
// テザー社がUSDTを大量に発行した翌日は、その資金で仮想通貨が買われやすい（発行=買いたい人が多い）。
// 毎日 02:00(UTC) に前日のUSDT発行量をチェック。いつもより多ければ（z>基準）BTC・ETHを買って3日持つ。
datetime u_t[]; double u_v[]; bool g_uOK=false; long g_uDay=-1; datetime g_uFetch=0;
bool LoadUSDT()
{
   ArrayResize(u_t,0); ArrayResize(u_v,0);
   int f=FileOpen("usdt_supply.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(f==INVALID_HANDLE){ Print("usdt_supply.csv が見つかりません（MQL5/Files に入れてください）"); return false; }
   while(!FileIsEnding(f))
   {
      string ln=FileReadString(f); string p[]; if(StringSplit(ln,',',p)<2) continue;
      datetime t=StringToTime(p[0]); double v=StringToDouble(p[1]); if(t<=0 || v<=0) continue;
      int k=ArraySize(u_t); ArrayResize(u_t,k+1,4096); ArrayResize(u_v,k+1,4096); u_t[k]=t; u_v[k]=v;
   }
   FileClose(f);
   return ArraySize(u_t)>100;
}
bool FetchUSDT()
{
   string url="https://stablecoins.llama.fi/stablecoincharts/all?stablecoin=1";
   char data[],res[]; string hdr;
   int r=WebRequest("GET",url,"",20000,data,res,hdr);
   if(r!=200){ Print("USDT発行量の取得に失敗 code=",r," err=",GetLastError()," → ツール→オプション→エキスパートアドバイザで https://stablecoins.llama.fi を許可してください"); return false; }
   string js=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   datetime tt[]; double vv[]; int n=0,pos=0,L=StringLen(js);
   while(true)
   {
      int a=StringFind(js,"\"date\":\"",pos); if(a<0) break; a+=8;
      int b=StringFind(js,"\"",a); if(b<0) break;
      long ts=StringToInteger(StringSubstr(js,a,b-a));
      int c=StringFind(js,"\"totalCirculating\":{\"peggedUSD\":",b); if(c<0) break; c+=32;
      int nx=StringFind(js,"\"date\":\"",b); if(nx>0 && c>nx){ pos=b; continue; }   // この日の値が無い
      int e=c; while(e<L){ ushort ch=StringGetCharacter(js,e); if((ch>='0'&&ch<='9')||ch=='.'||ch=='e'||ch=='E'||ch=='+'||ch=='-') e++; else break; }
      double v=StringToDouble(StringSubstr(js,c,e-c)); pos=e;
      if(ts>0 && v>0){ ArrayResize(tt,n+1,4096); ArrayResize(vv,n+1,4096); tt[n]=(datetime)ts; vv[n]=v; n++; }
   }
   if(n<1000){ Print("USDT発行量のデータが少なすぎます（",n,"件）"); return false; }
   ArrayResize(u_t,n); ArrayResize(u_v,n);
   for(int i=0;i<n;i++){ u_t[i]=tt[i]; u_v[i]=vv[i]; }
   int f=FileOpen("usdt_supply.csv",FILE_WRITE|FILE_TXT|FILE_ANSI);
   if(f!=INVALID_HANDLE){ for(int i=0;i<n;i++) FileWriteString(f,TimeToString(u_t[i],TIME_DATE)+","+DoubleToString(u_v[i],0)+"\n"); FileClose(f); }
   g_uOK=true;
   if(InpVerbose) Print("USDT発行量を更新: ",TimeToString(u_t[n-1],TIME_DATE)," ",DoubleToString(u_v[n-1]/1e9,2),"B$");
   return true;
}
// stamp の日の「前日比の伸び」が、過去90日の中でどれだけ大きいか（z）
bool USDTZ(datetime stamp,double &z)
{
   int k=-1; for(int i=ArraySize(u_t)-1;i>=0;i--) if(u_t[i]==stamp){ k=i; break; }
   if(k<91) return false;
   double g[90]; double m=0;
   for(int j=0;j<90;j++){ if(u_v[k-j-1]<=0) return false; g[j]=MathLog(u_v[k-j]/u_v[k-j-1]); m+=g[j]; }
   m/=90.0; double s=0; for(int j=0;j<90;j++) s+=(g[j]-m)*(g[j]-m); s=MathSqrt(s/89.0);
   if(s<=0) return false; z=(g[0]-m)/s; return true;
}
void USDTStep(datetime utc)
{
   if(!InpUseUSDT) return;
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)!=MAGIC_USDT) continue;
      if(TimeTradeServer()-(datetime)PositionGetInteger(POSITION_TIME) >= InpUSDTHoldD*86400) ClosePos(tk); }
   if((utc%86400) < 2*3600) return;                  // 02:00(UTC)以降
   long day=(long)(utc/86400); if(day==g_uDay) return;
   datetime stamp=(datetime)((day-1)*86400);         // 前日分（前日の終わりの発行量）
   int n=ArraySize(u_t);
   if(n==0 || u_t[n-1]<stamp)
   {
      if(!MQLInfoInteger(MQL_TESTER) && TimeLocal()-g_uFetch>1800){ g_uFetch=TimeLocal(); FetchUSDT(); }
      n=ArraySize(u_t);
      if(n==0 || u_t[n-1]<stamp){ if((utc%86400) > 8*3600){ g_uDay=day; Print("USDT: 前日のデータが取れないので今日は見送り"); } return; }
   }
   g_uDay=day;
   double z; if(!USDTZ(stamp,z)) return;
   if(z<=InpUSDTThr){ if(InpVerbose) Print("USDT発行 z=",DoubleToString(z,2)," 基準以下"); return; }
   if(InpUSDTNeedPrem)
   {
      double zp; if(!UPZNow(utc,zp)){ if(InpVerbose) Print("USDT発行: プレミアムが計算できないので見送り"); return; }
      if(zp<=0){ if(InpVerbose) Print("USDT発行 z=",DoubleToString(z,2)," だがプレミアム z=",DoubleToString(zp,2),"≤0 なので見送り"); return; }
   }
   string sy[2]; sy[0]=g_btc; sy[1]=g_eth;
   for(int s=0;s<2;s++)
   {
      string sym=sy[s]; if(sym=="") continue;
      bool have=false;
      for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC)==MAGIC_USDT && PositionGetString(POSITION_SYMBOL)==sym) have=true; }
      if(have) continue;                                // 保有中は重ねない
      double a=DailyATR(sym); if(a<=0) continue;
      double sl=InpUSDTSLk*a; MqlTick t; if(!SymbolInfoTick(sym,t)) continue;
      if(t.ask-t.bid > sl*InpMaxSpreadPct/100.0){ if(InpVerbose) Print("USDT ",sym," スプレッドが広いので見送り"); continue; }
      double lots=LotsFor(sym,sl,AccountInfoDouble(ACCOUNT_BALANCE)*InpUSDTRisk*RiskMult()/100.0);
      if(lots<=0){ if(InpVerbose) Print("USDT ",sym," ロット不足で見送り"); continue; }
      int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      trade.SetExpertMagicNumber(MAGIC_USDT);
      bool ok=trade.Buy(lots,sym,0,NormalizeDouble(t.ask-sl,dg),0,"USDT_MINT");
      if(ok && trade.ResultPrice()>0) LogFill(sym,1,t.ask,trade.ResultPrice(),"USDT_MINT");
      if(InpVerbose) Print("USDT発行 z=",DoubleToString(z,2)," → ",sym," 買い ",DoubleToString(lots,2),"lot ",ok?"OK":"失敗");
   }
}

//================== J. USDTの上乗せ価格（プレミアム）→ BTC・ETH 売買 ==========
// USDTが1ドルより少し高く売られている＝仮想通貨を買いたい人が多い → 次の数時間〜数日 BTC・ETH が上がりやすい。
// 逆に1ドルより安い＝売りたい人が多い → 下がりやすい。毎時（直前の1時間足が確定した2分後）に判定。
datetime p_t[]; double p_v[]; datetime g_pFetch=0; long g_pBlock=-1; double p_cs[]; int p_csN=0; string g_upExtra[];
bool LoadUP()
{
   ArrayResize(p_t,0); ArrayResize(p_v,0); p_csN=0;
   int f=FileOpen("usdt_usd_1h.csv",FILE_READ|FILE_TXT|FILE_ANSI|FILE_SHARE_READ);
   if(f==INVALID_HANDLE){ Print("usdt_usd_1h.csv が見つかりません（MQL5/Files に入れてください）"); return false; }
   while(!FileIsEnding(f))
   {
      string ln=FileReadString(f); string q[]; if(StringSplit(ln,',',q)<2) continue;
      datetime t=StringToTime(q[0]); double v=StringToDouble(q[1]); if(t<=0 || v<=0) continue;
      int k=ArraySize(p_t); ArrayResize(p_t,k+1,65536); ArrayResize(p_v,k+1,65536); p_t[k]=t; p_v[k]=v;
   }
   FileClose(f); return ArraySize(p_t)>1500;
}
bool FetchUP()
{
   string url="https://api.exchange.coinbase.com/products/USDT-USD/candles?granularity=3600";
   char data[],res[]; string hdr;
   int r=WebRequest("GET",url,"User-Agent: MT5-FlowEAB\r\n",15000,data,res,hdr);
   if(r!=200){ Print("USDT価格の取得に失敗 code=",r," err=",GetLastError()," → ツール→オプション→エキスパートアドバイザで https://api.exchange.coinbase.com を許可してください"); return false; }
   string js=CharArrayToString(res,0,WHOLE_ARRAY,CP_UTF8);
   // [[time,low,high,open,close,volume],...] 新しい順
   datetime nt[]; double nv[]; int n=0,pos=0;
   while(true)
   {
      int a=StringFind(js,"[",pos); if(a<0) break;
      int b=StringFind(js,"]",a); if(b<0) break;
      string body=StringSubstr(js,a+1,b-a-1); pos=b+1;
      if(StringFind(body,"[")>=0){ pos=a+1; continue; }   // 外側の [
      string q[]; if(StringSplit(body,',',q)<6) continue;
      datetime t=(datetime)StringToInteger(q[0]); double c=StringToDouble(q[4]);
      if(t>0 && c>0){ ArrayResize(nt,n+1,512); ArrayResize(nv,n+1,512); nt[n]=t; nv[n]=c; n++; }
   }
   if(n==0) return false;
   datetime last=(ArraySize(p_t)>0)?p_t[ArraySize(p_t)-1]:0;
   datetime nowH=(datetime)((TimeGMT()/3600)*3600);
   int f=FileOpen("usdt_usd_1h.csv",FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI); if(f!=INVALID_HANDLE) FileSeek(f,0,SEEK_END);
   int added=0;
   for(int i=n-1;i>=0;i--)                               // 古い順に追加
   {
      if(nt[i]<=last) continue;
      if(!MQLInfoInteger(MQL_TESTER) && nt[i]>=nowH) continue;   // まだ終わっていない1時間足は使わない
      int k=ArraySize(p_t); ArrayResize(p_t,k+1,65536); ArrayResize(p_v,k+1,65536); p_t[k]=nt[i]; p_v[k]=nv[i]; last=nt[i]; added++;
      if(f!=INVALID_HANDLE) FileWriteString(f,TimeToString(nt[i],TIME_DATE|TIME_MINUTES)+","+DoubleToString(nv[i],6)+"\n");
   }
   if(f!=INVALID_HANDLE) FileClose(f);
   if(InpVerbose && added>0) Print("USDT価格を更新: +",added,"本 最新 ",TimeToString(last,TIME_DATE|TIME_MINUTES)," UTC");
   return true;
}
// k本目（その1時間足の終わり）時点の z（累積和で高速化）
void UPPrefix()
{
   int n=ArraySize(p_v); if(p_csN==n) return;
   ArrayResize(p_cs,n+1); if(p_csN==0){ p_cs[0]=0; }
   for(int i=p_csN;i<n;i++) p_cs[i+1]=p_cs[i]+MathLog(p_v[i])*1e4;
   p_csN=n;
}
bool UPZ(int k,double &z)
{
   int W=8, Z=1440; if(k < W+Z) return false;
   UPPrefix();
   double sum=0,sum2=0,m0=0;
   for(int j=0;j<Z;j++)
   {
      int e=k-j;                                   // e本目までの8本平均
      double m=(p_cs[e+1]-p_cs[e+1-W])/W;
      sum+=m; sum2+=m*m; if(j==0) m0=m;
   }
   double mean=sum/Z, var=(sum2-Z*mean*mean)/(Z-1); if(var<=0) return false;
   z=(m0-mean)/MathSqrt(var); return true;
}
// p_t の中で t 以下の最後の番号（二分探索。テスターでは過去の時刻を探すので全体から探す）
int UPFind(datetime t)
{
   int lo=0, hi=ArraySize(p_t)-1, r=-1;
   while(lo<=hi){ int mid=(lo+hi)/2; if(p_t[mid]<=t){ r=mid; lo=mid+1; } else hi=mid-1; }
   return r;
}
// 今の時刻の直前の1時間足で z を計算（データが無ければ取りに行く）
bool UPZNow(datetime utc,double &z)
{
   datetime need=(datetime)((utc/3600-1)*3600);
   int n=ArraySize(p_t);
   if((n==0 || p_t[n-1]<need) && !MQLInfoInteger(MQL_TESTER) && TimeLocal()-g_pFetch>60){ g_pFetch=TimeLocal(); FetchUP(); n=ArraySize(p_t); }
   int k=UPFind(need);
   if(k<0 || need-p_t[k]>3*3600) return false;
   return UPZ(k,z);
}
int UPDir(string sym)
{
   for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(!PositionSelectByTicket(tk)) continue;
      if(PositionGetInteger(POSITION_MAGIC)==MAGIC_UPREM && PositionGetString(POSITION_SYMBOL)==sym) return (PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)?1:-1; }
   return 0;
}
void UPStep(datetime utc)
{
   if(!InpUseUPrem) return;
   long hr=(long)(utc/3600); if(InpUPStepH>1 && hr%InpUPStepH!=0) return;   // 判定する時刻
   if((utc%3600) < 120) return;                              // 2分待つ（1時間足の確定待ち）
   if(hr==g_pBlock) return;
   datetime need=(datetime)((hr-1)*3600);                    // 直前の1時間足（開始時刻）
   int n=ArraySize(p_t);
   if(n==0 || p_t[n-1]<need)
   {
      if(!MQLInfoInteger(MQL_TESTER) && TimeLocal()-g_pFetch>60){ g_pFetch=TimeLocal(); FetchUP(); }
      n=ArraySize(p_t);
      if(n==0 || p_t[n-1]<need){ if((utc%3600) > 50*60){ g_pBlock=hr; Print("USDT価格: データが取れないので今回は見送り"); } return; }
   }
   g_pBlock=hr;
   int k=UPFind(need); if(k>=0 && p_t[k]!=need) k=-1;
   if(k<0){ Print("USDT価格: 直前の1時間足が見つからない"); return; }
   double z; if(!UPZ(k,z)) return;
   int want=(z>InpUPThr)?1:((z<-InpUPThr)?-1:0);
   if(InpVerbose && want!=0) Print("USDTプレミアム z=",DoubleToString(z,2)," → ",want>0?"買い":"売り");
   string sy[]; double rk[]; int ns=0;
   ArrayResize(sy,2); ArrayResize(rk,2); sy[0]=g_btc; sy[1]=g_eth; rk[0]=InpUPRisk; rk[1]=InpUPRisk; ns=2;
   for(int x=0;x<ArraySize(g_upExtra);x++){ ArrayResize(sy,ns+1); ArrayResize(rk,ns+1); sy[ns]=g_upExtra[x]; rk[ns]=InpUPExtraRisk; ns++; }
   for(int s=0;s<ns;s++)
   {
      string sym=sy[s]; if(sym=="") continue;
      int cur=UPDir(sym);
      if(cur!=0 && cur!=want)
         for(int i=PositionsTotal()-1;i>=0;i--){ ulong tk=PositionGetTicket(i); if(PositionSelectByTicket(tk) && PositionGetInteger(POSITION_MAGIC)==MAGIC_UPREM && PositionGetString(POSITION_SYMBOL)==sym) ClosePos(tk); }
      if(want==0 || cur==want) continue;
      double a=DailyATR(sym); if(a<=0) continue;
      double sl=InpUPSLk*a; MqlTick t; if(!SymbolInfoTick(sym,t)) continue;
      if(t.ask-t.bid > sl*InpMaxSpreadPct/100.0 || (t.ask-t.bid)/t.bid*10000.0 > InpUPMaxSpreadBp){ if(InpVerbose) Print("USDTプレミアム ",sym," スプレッドが広いので見送り"); continue; }
      double lots=LotsFor(sym,sl,AccountInfoDouble(ACCOUNT_BALANCE)*rk[s]*RiskMult()/100.0);
      if(lots<=0){ if(InpVerbose) Print("USDTプレミアム ",sym," ロット不足で見送り"); continue; }
      int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
      trade.SetExpertMagicNumber(MAGIC_UPREM);
      bool ok=(want>0)?trade.Buy(lots,sym,0,NormalizeDouble(t.ask-sl,dg),0,"USDT_PREM"):trade.Sell(lots,sym,0,NormalizeDouble(t.bid+sl,dg),0,"USDT_PREM");
      if(ok && trade.ResultPrice()>0) LogFill(sym,want,want>0?t.ask:t.bid,trade.ResultPrice(),"USDT_PREM");
      if(InpVerbose) Print("USDTプレミアム ",sym," ",want>0?"買い ":"売り ",DoubleToString(lots,2),"lot ",ok?"OK":"失敗");
   }
}


//================== スマホ通知（口座の全約定。FlowEA3の分も） ==========
string g_nq_msg[];
string MagicName(long m)
{
   switch((int)m){
      case 91001: return "FlowEA3 ①ゴトー日"; case 91002: return "FlowEA3 ②月末ドル売り"; case 91003: return "FlowEA3 ③月末ドル買い";
      case 91004: return "FlowEA3 ④FOMC"; case 91005: return "FlowEA3 ⑤指標"; case 91015: return "FlowEA3 ⑥カナダCPI";
      case 91006: return "FlowEA3 ⑦COT"; case 91007: return "FlowEA3 ⑧連休明け";
      case 92001: return "B ビットコインCOT"; case 92002: return "C 原油"; case 92003: return "D 仮想通貨CPI"; case 92004: return "E COT4週変化";
      case 92005: return "G ハイテク決算"; case 92006: return "I 指数CPI"; case 92007: return "F USDT発行"; case 92008: return "J USDTプレミアム";
   }
   return (m==0)?"手動":"番号"+IntegerToString(m);
}
void OnTradeTransaction(const MqlTradeTransaction &tr,const MqlTradeRequest &rq,const MqlTradeResult &rs)
{
   if(!InpNotify || MQLInfoInteger(MQL_TESTER)) return;
   if(tr.type!=TRADE_TRANSACTION_DEAL_ADD || tr.deal==0) return;
   if(!HistoryDealSelect(tr.deal)) return;
   long entry=HistoryDealGetInteger(tr.deal,DEAL_ENTRY); long typ=HistoryDealGetInteger(tr.deal,DEAL_TYPE);
   if(typ!=DEAL_TYPE_BUY && typ!=DEAL_TYPE_SELL) return;
   string sym=HistoryDealGetString(tr.deal,DEAL_SYMBOL); long mg=HistoryDealGetInteger(tr.deal,DEAL_MAGIC);
   double vol=HistoryDealGetDouble(tr.deal,DEAL_VOLUME), px=HistoryDealGetDouble(tr.deal,DEAL_PRICE);
   int dg=(int)SymbolInfoInteger(sym,SYMBOL_DIGITS);
   string msg;
   if(entry==DEAL_ENTRY_IN)
      msg=StringFormat("【新規】%s %s %s %.2flot @%s",MagicName(mg),sym,typ==DEAL_TYPE_BUY?"買い":"売り",vol,DoubleToString(px,dg));
   else
   {
      double pl=HistoryDealGetDouble(tr.deal,DEAL_PROFIT)+HistoryDealGetDouble(tr.deal,DEAL_SWAP)+HistoryDealGetDouble(tr.deal,DEAL_COMMISSION);
      msg=StringFormat("【決済】%s %s 損益 %s円 残高 %s円",MagicName(mg),sym,DoubleToString(pl,0),DoubleToString(AccountInfoDouble(ACCOUNT_BALANCE),0));
   }
   int k=ArraySize(g_nq_msg); ArrayResize(g_nq_msg,k+1); g_nq_msg[k]=msg;
}
datetime g_nq_last=0;
void NotifyStep()
{
   if(ArraySize(g_nq_msg)==0 || TimeLocal()-g_nq_last<7) return;   // 通知は約7秒に1回まで（MT5の上限対策）
   g_nq_last=TimeLocal();
   if(!SendNotification(g_nq_msg[0])) Print("スマホ通知に失敗 err=",GetLastError()," → MT5のツール→オプション→通知 で MetaQuotes ID を設定してください");
   int n=ArraySize(g_nq_msg); for(int i=1;i<n;i++) g_nq_msg[i-1]=g_nq_msg[i]; ArrayResize(g_nq_msg,n-1);
}
//================== 手法ごとの成績 =====================================
void PrintStats()
{
   if(!HistorySelect(0,TimeCurrent()+86400)) return;
   string nm[8]={"B ビットコインCOT","C 原油 在庫統計","D 仮想通貨CPI","E COT4週変化","G ハイテク決算","I 指数CPI","F USDT発行","J USDTプレミアム"}; long mg[8]={MAGIC_BCOT,MAGIC_OIL,MAGIC_CCPI,MAGIC_COTW,MAGIC_NQ,MAGIC_ICPI,MAGIC_USDT,MAGIC_UPREM};
   double pl[8]={0,0,0,0,0,0,0,0}; int cnt[8]={0,0,0,0,0,0,0,0}, win[8]={0,0,0,0,0,0,0,0};
   for(int i=0;i<HistoryDealsTotal();i++){ ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      long m=HistoryDealGetInteger(d,DEAL_MAGIC); int k=-1; for(int j=0;j<8;j++) if(mg[j]==m) k=j; if(k<0) continue;
      double p=HistoryDealGetDouble(d,DEAL_PROFIT)+HistoryDealGetDouble(d,DEAL_SWAP)+HistoryDealGetDouble(d,DEAL_COMMISSION); pl[k]+=p;
      long en=HistoryDealGetInteger(d,DEAL_ENTRY); if(en==DEAL_ENTRY_OUT||en==DEAL_ENTRY_INOUT||en==DEAL_ENTRY_OUT_BY){ cnt[k]++; if(p>0) win[k]++; } }
   Print("===== FlowEA_B 手法ごとの成績（決済済み・スワップ手数料込み）=====");
   for(int j=0;j<8;j++) Print(StringFormat("%s : %d回  勝率 %.0f%%  損益 %s",nm[j],cnt[j],cnt[j]>0?100.0*win[j]/cnt[j]:0.0,DoubleToString(pl[j],0)));
}

//================== 本体 ============================================
int OnInit()
{
   g_oil=Resolve(InpOilSym); g_btc=Resolve(InpBTCSym); g_eth=Resolve(InpETHSym); g_nq=(InpUseNQEarn||InpUseIdxCPI)?Resolve(InpNQSym):"";
   Print("銘柄 原油=",g_oil," BTC=",g_btc," ETH=",g_eth);
   if(InpUseOilEIA && g_oil=="") Print("原油の銘柄が見つかりません（",InpOilSym,"）");
   ArrayResize(g_ev,0);
   if(InpUseCryptoCPI){ AddList(InpCPITimes,2,InpCryptoHoldMin); AddList(HIST_CPI,2,InpCryptoHoldMin); }
   if(InpUseIdxCPI){ AddList(InpCPITimes,4,30); AddList(HIST_CPI,4,30); if(g_nq=="") Print("ナスダック指数CFDが見つかりません（",InpNQSym,"）"); }
   if(InpUseNQEarn){ AddList(InpNQTimes,3,55); AddList(HIST_NQ,3,55); if(g_nq=="") Print("ナスダック指数CFDが見つかりません（",InpNQSym,"）"); }
   g_cotOK=InpUseBTCCOT?LoadCOT():false;
   int nw=ArraySize(W8); ArrayResize(W8R,nw); ArrayResize(g_wDone,nw); ArrayInitialize(g_wDone,false);
   for(int i=0;i<nw;i++){ W8R[i]=InpUseCOTW?ResolveFX(W8[i]):""; if(InpUseCOTW && W8R[i]=="") Print("COTW 銘柄が見つかりません: ",W8[i]); }
   g_wOK=InpUseCOTW?LoadCOTW():false;
   if(InpUseUPrem && StringLen(InpUPExtraSyms)>0){ string q[]; int nq=StringSplit(InpUPExtraSyms,',',q); ArrayResize(g_upExtra,0);
      for(int i=0;i<nq;i++){ StringTrimLeft(q[i]); StringTrimRight(q[i]); string r=Resolve(q[i]); if(r==""){ Print("J 追加銘柄が見つかりません: ",q[i]); continue; } int k=ArraySize(g_upExtra); ArrayResize(g_upExtra,k+1); g_upExtra[k]=r; } }
   if(InpUseUPrem || (InpUseUSDT && InpUSDTNeedPrem)){ if(!LoadUP()) Print("USDT価格の履歴が足りません（usdt_usd_1h.csv）"); if(!MQLInfoInteger(MQL_TESTER)) FetchUP(); }
   if(InpUseUSDT){ g_uOK=LoadUSDT(); if(!g_uOK && !MQLInfoInteger(MQL_TESTER)) FetchUSDT(); }
   g_gvPeak="FlowEAB_peak_"+IntegerToString(AccountInfoInteger(ACCOUNT_LOGIN));
   if(!MQLInfoInteger(MQL_TESTER) && GlobalVariableCheck(g_gvPeak)) g_peak=GlobalVariableGet(g_gvPeak);
   RiskMult();
   EventSetTimer(1);
   Comment("FlowEA_B 動作中（BTC COT / 仮想通貨CPI / COT4週変化 / USDT発行 / USDTプレミアム）");
   return INIT_SUCCEEDED;
}
void OnDeinit(const int r){ EventKillTimer(); Comment(""); if(!MQLInfoInteger(MQL_TESTER)) PrintStats(); }
// テスター終了時に全取引を共通フォルダへ書き出す（年ごとの集計用）
void DumpDeals()
{
   if(!HistorySelect(0,TimeCurrent()+86400)) return;
   int f=FileOpen("FlowEA_B_deals.csv",FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_COMMON);
   if(f==INVALID_HANDLE){ Print("取引の書き出しに失敗 err=",GetLastError()); return; }
   FileWriteString(f,"time,symbol,magic,entry,type,volume,price,profit,swap,commission\n");
   for(int i=0;i<HistoryDealsTotal();i++){ ulong d=HistoryDealGetTicket(i); if(d==0) continue;
      FileWriteString(f,StringFormat("%s,%s,%d,%d,%d,%.2f,%.5f,%.2f,%.2f,%.2f\n",TimeToString((datetime)HistoryDealGetInteger(d,DEAL_TIME),TIME_DATE|TIME_SECONDS),
         HistoryDealGetString(d,DEAL_SYMBOL),(int)HistoryDealGetInteger(d,DEAL_MAGIC),(int)HistoryDealGetInteger(d,DEAL_ENTRY),(int)HistoryDealGetInteger(d,DEAL_TYPE),
         HistoryDealGetDouble(d,DEAL_VOLUME),HistoryDealGetDouble(d,DEAL_PRICE),HistoryDealGetDouble(d,DEAL_PROFIT),HistoryDealGetDouble(d,DEAL_SWAP),HistoryDealGetDouble(d,DEAL_COMMISSION))); }
   FileClose(f); Print("全取引を書き出しました → 共通フォルダ Files/FlowEA_B_deals.csv");
}
double OnTester(){ PrintStats(); DumpDeals(); return 0; }
void OnTick(){ }
void OnTimer()
{
   datetime utc=NowUTC();
   RiskMult();
   if(InpUseOilEIA) AddOilWeek(utc);
   for(int e=0;e<ArraySize(g_ev);e++)
   {
      if(g_ev[e].placed) continue;
      long dt=(long)(g_ev[e].relUTC-utc);
      if(dt<=10 && dt>=0){ g_ev[e].placed=true; PlaceEv(e); }
      else if(dt<0 && dt>-60) g_ev[e].placed=true;
      else if(dt<=-60) { g_ev[e].placed=true; g_ev[e].closed=true; }   // 過去の予定は無視
   }
   ManageStr();
   CloseEvExpired(utc);
   BTCCOTStep(utc);
   COTWStep(utc);
   USDTStep(utc);
   UPStep(utc);
   ShadowThu(utc);
   NotifyStep();
}
//+------------------------------------------------------------------+
