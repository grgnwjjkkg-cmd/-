//+------------------------------------------------------------------+
//| GridMartinEA.mq5                                                 |
//| ボリンジャーの外側で逆張りし、逆行したらロットを増やして         |
//| ナンピン。平均値から少し戻ったらまとめて決済する。               |
//| 資金管理：バスケットの強制損切り、週の目標と週の損失上限。       |
//| ハイリスク。必ずリアルティックのテストとデモで確かめてから使う。 |
//+------------------------------------------------------------------+
#property version     "1.00"
#property description "BB逆張り＋ナンピンマーチン（バスケット決済・資金管理つき）"

#include <Trade/Trade.mqh>

input group "エントリー"
input ENUM_TIMEFRAMES InpTF       = PERIOD_M5; // 判断する足
input int    InpBBPeriod          = 50;    // ボリンジャーの期間
input double InpBBDev             = 2.5;   // ボリンジャーの幅（σ）
input int    InpATRPeriod         = 48;    // ナンピン幅・利確幅に使うATRの期間
input int    InpStartHour         = 9;     // 新しいバスケットを始める時（サーバー時間）
input int    InpEndHour           = 21;    // 新しいバスケットをやめる時（サーバー時間）
input int    InpMaxSpreadPts      = 0;     // スプレッドがこれを超えたら新規なし（ポイント、0で無効）

input group "ナンピン・マーチン"
input double InpStepATR           = 2.0;   // ナンピン幅＝ATR×この値
input double InpLotMult           = 1.5;   // ナンピンごとのロット倍率
input int    InpMaxLevels         = 5;     // 最大段数（最初の1回を含む）
input double InpTPATR             = 0.5;   // 利確＝平均値からATR×この値

input group "資金管理"
input double InpBaseRiskPct       = 0.3;   // 最初の1ロットがATR 1本分逆行したときの損失（口座の%）
input double InpBasketStopPct     = 5.0;   // バスケットの含み損がこれに達したら全決済（口座の%）
input double InpWeekTargetPct     = 0.0;   // 週の利益がこれを超えたらその週は新規なし（%、0で無効）
input double InpWeekStopPct       = 20.0;  // 週の損失がこれを超えたらその週は新規なし（%、0で無効）
input double InpMaxLot            = 50.0;  // 1ポジションのロット上限
input bool   InpCloseFriday       = true;  // 金曜は週をまたがずに全決済
input int    InpFridayCloseHour   = 21;    // 金曜に全決済する時（サーバー時間）

input group "その他"
input int    InpSlippagePts       = 30;       // 許容スリッページ（ポイント）
input ulong  InpMagic             = 20260930; // マジックナンバー

CTrade   trade;
int      hBB = INVALID_HANDLE, hATR = INVALID_HANDLE;
datetime g_lastBar       = 0;
int      g_weekKey       = -1;
double   g_weekStartBal  = 0.0;
double   g_basketStartEq = 0.0;   // バスケット開始時の口座残高（強制損切りの基準）
double   g_basketATR     = 0.0;   // バスケット開始時のATR（ナンピン幅・利確幅を固定する）

//+------------------------------------------------------------------+
int OnInit()
  {
   hBB  = iBands(_Symbol, InpTF, InpBBPeriod, 0, InpBBDev, PRICE_CLOSE);
   hATR = iATR(_Symbol, InpTF, InpATRPeriod);
   if(hBB == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      Print("インジケーターを作れませんでした");
      return INIT_FAILED;
     }
   if(InpMaxLevels < 1 || InpLotMult < 1.0)
     {
      Print("最大段数は1以上、ロット倍率は1.0以上にしてください");
      return INIT_PARAMETERS_INCORRECT;
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   IndicatorRelease(hBB);
   IndicatorRelease(hATR);
  }

//+------------------------------------------------------------------+
// 自分のポジションの集計
struct Basket
  {
   int    count;
   int    dir;        // 1=買い、-1=売り、0=なし
   double lots;
   double avg;        // ロット加重の平均建値
   double lastPrice;  // いちばん最後に建てた価格
   double lastLot;
   double profit;     // 含み損益（スワップ・手数料込み）
  };

Basket GetBasket()
  {
   Basket b;
   b.count = 0; b.dir = 0; b.lots = 0; b.avg = 0; b.lastPrice = 0; b.lastLot = 0; b.profit = 0;
   datetime lastTime = 0;
   double sumPx = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) != _Symbol || (ulong)PositionGetInteger(POSITION_MAGIC) != InpMagic)
         continue;
      double vol = PositionGetDouble(POSITION_VOLUME);
      double px  = PositionGetDouble(POSITION_PRICE_OPEN);
      b.count++;
      b.dir = (PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) ? 1 : -1;
      b.lots += vol;
      sumPx  += vol * px;
      b.profit += PositionGetDouble(POSITION_PROFIT) + PositionGetDouble(POSITION_SWAP);
      datetime pt = (datetime)PositionGetInteger(POSITION_TIME_MSC);
      if(pt >= lastTime)
        {
         lastTime = pt;
         b.lastPrice = px;
         b.lastLot = vol;
        }
     }
   if(b.lots > 0)
      b.avg = sumPx / b.lots;
   return b;
  }

void CloseAll()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong t = PositionGetTicket(i);
      if(!PositionSelectByTicket(t))
         continue;
      if(PositionGetString(POSITION_SYMBOL) == _Symbol && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic)
         trade.PositionClose(t);
     }
  }

double NormalizeLot(double lots)
  {
   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = MathMin(SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX), InpMaxLot);
   lots = MathFloor(lots / step) * step;
   lots = MathMin(lots, vmax);
   if(lots < vmin)
      return 0.0;
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lots, digits);
  }

// 最初の1ロット：ATR 1本分の逆行で口座の InpBaseRiskPct% を失う量
double BaseLot(int dir, double atr)
  {
   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double pl = 0.0;
   ENUM_ORDER_TYPE type = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(!OrderCalcProfit(type, _Symbol, 1.0, price, price - dir * atr, pl) || pl >= 0)
      return 0.0;
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   return eq * InpBaseRiskPct / 100.0 / (-pl);
  }

bool Open(int dir, double lots, string comment)
  {
   lots = NormalizeLot(lots);
   if(lots <= 0)
      return false;
   double margin = 0.0;
   double price = (dir == 1) ? SymbolInfoDouble(_Symbol, SYMBOL_ASK) : SymbolInfoDouble(_Symbol, SYMBOL_BID);
   ENUM_ORDER_TYPE type = (dir == 1) ? ORDER_TYPE_BUY : ORDER_TYPE_SELL;
   if(OrderCalcMargin(type, _Symbol, lots, price, margin) && margin > AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.95)
     {
      Print("証拠金が足りないので建てません");
      return false;
     }
   return (dir == 1) ? trade.Buy(lots, _Symbol, 0, 0, 0, comment) : trade.Sell(lots, _Symbol, 0, 0, 0, comment);
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);
   double bal = AccountInfoDouble(ACCOUNT_BALANCE);
   double eq  = AccountInfoDouble(ACCOUNT_EQUITY);

   // 週の切り替え（月曜を週の始まりとする）
   int wkey = (int)((TimeCurrent() - (now.day_of_week == 0 ? 6 : now.day_of_week - 1) * 86400) / 86400);
   if(wkey != g_weekKey)
     {
      g_weekKey = wkey;
      g_weekStartBal = bal;
     }

   Basket b = GetBasket();

   // ---- 持っているバスケットの管理 ----
   if(b.count > 0)
     {
      if(g_basketStartEq <= 0)
         g_basketStartEq = bal;          // 再起動したときは今の残高を基準にする
      if(g_basketATR <= 0)
        {
         double a[];
         if(CopyBuffer(hATR, 0, 1, 1, a) == 1)
            g_basketATR = a[0];
        }

      // 金曜は持ち越さない
      if(InpCloseFriday && now.day_of_week == 5 && now.hour >= InpFridayCloseHour)
        {
         CloseAll();
         return;
        }
      // 強制損切り
      if(b.profit <= -g_basketStartEq * InpBasketStopPct / 100.0)
        {
         PrintFormat("強制損切り：含み損 %.0f（基準 %.0f の %.1f%%）", b.profit, g_basketStartEq, InpBasketStopPct);
         CloseAll();
         return;
        }
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double px  = (b.dir == 1) ? bid : ask;        // 決済するときの価格
      // 利確：平均値から ATR×InpTPATR 戻ったら
      if((px - b.avg) * b.dir >= g_basketATR * InpTPATR)
        {
         CloseAll();
         return;
        }
      // ナンピン：最後の建値から ATR×InpStepATR 逆行したら
      double entryPx = (b.dir == 1) ? ask : bid;
      if(b.count < InpMaxLevels && (b.lastPrice - entryPx) * b.dir >= g_basketATR * InpStepATR)
        {
         if(InpMaxSpreadPts <= 0 || SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) <= InpMaxSpreadPts)
            Open(b.dir, b.lastLot * InpLotMult, StringFormat("GM L%d", b.count + 1));
        }
      return;
     }

   // ---- バスケットなし：新しいバスケットは足の確定ごとに判断 ----
   g_basketStartEq = 0;
   g_basketATR = 0;
   datetime bar0 = iTime(_Symbol, InpTF, 0);
   if(bar0 == 0 || bar0 == g_lastBar)
      return;
   g_lastBar = bar0;

   if(now.hour < InpStartHour || now.hour >= InpEndHour)
      return;
   if(InpCloseFriday && now.day_of_week == 5 && now.hour >= InpFridayCloseHour - 1)
      return;
   double wk = (g_weekStartBal > 0) ? (bal - g_weekStartBal) / g_weekStartBal * 100.0 : 0.0;
   if(InpWeekTargetPct > 0 && wk >= InpWeekTargetPct)
      return;
   if(InpWeekStopPct > 0 && wk <= -InpWeekStopPct)
      return;
   if(InpMaxSpreadPts > 0 && SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPts)
      return;

   double up[], lo[], a[];
   if(CopyBuffer(hBB, 1, 1, 1, up) != 1 || CopyBuffer(hBB, 2, 1, 1, lo) != 1 || CopyBuffer(hATR, 0, 1, 1, a) != 1)
      return;
   double c1 = iClose(_Symbol, InpTF, 1);
   int dir = 0;
   if(c1 < lo[0]) dir = 1;          // 下に行きすぎ → 買い
   else if(c1 > up[0]) dir = -1;    // 上に行きすぎ → 売り
   if(dir == 0 || a[0] <= 0)
      return;

   double lots = BaseLot(dir, a[0]);
   if(Open(dir, lots, "GM L1"))
     {
      g_basketStartEq = bal;
      g_basketATR = a[0];
     }
  }

//+------------------------------------------------------------------+
// 最適化の評価：純利益 ÷ 最大ドローダウン（リカバリーファクター）
double OnTester()
  {
   double dd = TesterStatistics(STAT_EQUITY_DD);
   if(dd <= 0)
      return 0.0;
   return TesterStatistics(STAT_PROFIT) / dd;
  }
//+------------------------------------------------------------------+
