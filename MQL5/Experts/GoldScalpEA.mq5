//+------------------------------------------------------------------+
//| GoldScalpEA.mq5                                                  |
//| XAUUSD 短期売買。上位足の流れに沿って、M5の押し目・戻りで入る。  |
//| 1日5〜10回ほどの売買を想定。1回のリスクが大きい攻めの設定。      |
//+------------------------------------------------------------------+
#property version     "1.00"
#property description "XAUUSD M5 押し目・戻りスキャル（ハイリスク）"

#include <Trade/Trade.mqh>

input group "資金管理"
input double InpRiskPct       = 20.0;  // 1回の損失（口座の%）
input double InpDailyLossPct  = 40.0;  // 1日の損失がこれを超えたらその日は止める（%、0で無効）
input double InpGuardDDPct    = 30.0;  // 最高値からこれだけ減ったらロットを下げる（%、0で無効）
input double InpGuardMul      = 0.5;   // 守りに入ったときのロット倍率
input double InpMaxLot        = 50.0;  // ロットの上限

input group "エントリー"
input ENUM_TIMEFRAMES InpTF      = PERIOD_M5;   // 売買する足
input ENUM_TIMEFRAMES InpTrendTF = PERIOD_H1;   // 流れを見る足
input int    InpTrendEMA       = 50;    // 流れを見るEMA
input int    InpTrendSlopeBars = 3;     // EMAの傾きを見る本数
input int    InpFastEMA        = 20;    // 押し目・戻りを測るEMA
input int    InpRSIPeriod      = 7;     // RSIの期間
input double InpRSIBuy         = 40.0;  // 買い：前の足のRSIがこれより下
input double InpRSISell        = 60.0;  // 売り：前の足のRSIがこれより上
input int    InpATRPeriod      = 14;    // ATRの期間
input double InpMinATR         = 0.0;   // ATRがこれ未満なら見送り（価格、0で無効）

input group "決済"
input double InpSLATR       = 1.5;  // 損切り＝ATR×この値
input double InpRR          = 1.5;  // 利確＝損切り幅×この値
input double InpBEAtR       = 1.0;  // 含み益が損切り幅×この値に来たら建値へ（0で無効）
input double InpTrailATR    = 0.0;  // 建値後のトレール幅＝ATR×この値（0で無効）
input int    InpMaxHoldBars = 36;   // この本数を超えたら決済（0で無効）

input group "時間・回数"
input int  InpStartHour       = 9;     // 売買を始める時（サーバー時間）
input int  InpEndHour         = 22;    // 売買をやめる時（サーバー時間）
input int  InpMaxTradesPerDay = 10;    // 1日の最大エントリー数
input int  InpCooldownBars    = 2;     // 前のエントリーから空ける本数
input bool InpCloseFriday     = true;  // 金曜は週をまたがずに決済
input int  InpFridayCloseHour = 22;    // 金曜に決済する時（サーバー時間）

input group "コスト・その他"
input int   InpMaxSpreadPts      = 50;       // スプレッドがこれを超えたら見送り（ポイント）
input int   InpSlippagePts       = 30;       // 許容スリッページ（ポイント）
input ulong InpMagic             = 20260929; // マジックナンバー
input int   InpMinTradesForScore = 200;      // 最適化の評価に必要な最低取引数

CTrade   trade;
int      hFast = INVALID_HANDLE, hTrend = INVALID_HANDLE, hRSI = INVALID_HANDLE, hATR = INVALID_HANDLE;
datetime g_lastBar   = 0;
datetime g_lastEntry = 0;
int      g_dayKey    = -1;
double   g_dayStartEq = 0.0;
double   g_peakEq     = 0.0;

//+------------------------------------------------------------------+
int OnInit()
  {
   hFast  = iMA(_Symbol, InpTF, InpFastEMA, 0, MODE_EMA, PRICE_CLOSE);
   hTrend = iMA(_Symbol, InpTrendTF, InpTrendEMA, 0, MODE_EMA, PRICE_CLOSE);
   hRSI   = iRSI(_Symbol, InpTF, InpRSIPeriod, PRICE_CLOSE);
   hATR   = iATR(_Symbol, InpTF, InpATRPeriod);
   if(hFast == INVALID_HANDLE || hTrend == INVALID_HANDLE || hRSI == INVALID_HANDLE || hATR == INVALID_HANDLE)
     {
      Print("インジケーターを作れませんでした");
      return INIT_FAILED;
     }
   trade.SetExpertMagicNumber(InpMagic);
   trade.SetDeviationInPoints(InpSlippagePts);
   trade.SetTypeFillingBySymbol(_Symbol);
   g_peakEq = AccountInfoDouble(ACCOUNT_EQUITY);
   return INIT_SUCCEEDED;
  }

void OnDeinit(const int reason)
  {
   IndicatorRelease(hFast);
   IndicatorRelease(hTrend);
   IndicatorRelease(hRSI);
   IndicatorRelease(hATR);
  }

//+------------------------------------------------------------------+
bool Buf(int handle, int shift, int count, double &arr[])
  {
   ArraySetAsSeries(arr, true);
   return CopyBuffer(handle, 0, shift, count, arr) == count;
  }

bool InSession(int hour)
  {
   if(InpStartHour <= InpEndHour)
      return hour >= InpStartHour && hour < InpEndHour;
   return hour >= InpStartHour || hour < InpEndHour;   // 日をまたぐ設定
  }

bool IsOurs(ulong ticket)
  {
   return PositionSelectByTicket(ticket)
          && PositionGetString(POSITION_SYMBOL) == _Symbol
          && (ulong)PositionGetInteger(POSITION_MAGIC) == InpMagic;
  }

bool HasPosition()
  {
   for(int i = PositionsTotal() - 1; i >= 0; i--)
      if(IsOurs(PositionGetTicket(i)))
         return true;
   return false;
  }

// 今日（サーバー時間）のエントリー数。再起動しても数え直せるよう履歴から数える
int TodayEntries()
  {
   MqlDateTime d;
   TimeToStruct(TimeCurrent(), d);
   d.hour = 0; d.min = 0; d.sec = 0;
   if(!HistorySelect(StructToTime(d), TimeCurrent() + 60))
      return 0;
   int n = 0;
   for(int i = HistoryDealsTotal() - 1; i >= 0; i--)
     {
      ulong t = HistoryDealGetTicket(i);
      if((ulong)HistoryDealGetInteger(t, DEAL_MAGIC) == InpMagic
         && HistoryDealGetString(t, DEAL_SYMBOL) == _Symbol
         && HistoryDealGetInteger(t, DEAL_ENTRY) == DEAL_ENTRY_IN)
         n++;
     }
   return n;
  }

// 損切りに掛かったとき口座の InpRiskPct% を失うロット
double CalcLots(ENUM_ORDER_TYPE type, double entry, double sl)
  {
   double eq   = AccountInfoDouble(ACCOUNT_EQUITY);
   double mult = 1.0;
   if(InpGuardDDPct > 0 && g_peakEq > 0 && eq < g_peakEq * (1.0 - InpGuardDDPct / 100.0))
      mult = InpGuardMul;
   double riskMoney = eq * InpRiskPct / 100.0 * mult;

   double pl = 0.0;
   if(!OrderCalcProfit(type, _Symbol, 1.0, entry, sl, pl) || pl >= 0)
      return 0.0;
   double lots = riskMoney / (-pl);

   double step = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double vmin = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double vmax = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   lots = MathFloor(lots / step) * step;
   lots = MathMin(lots, MathMin(vmax, InpMaxLot));

   // 証拠金が足りなければ入れる分まで下げる
   double margin = 0.0;
   if(OrderCalcMargin(type, _Symbol, lots, entry, margin) && margin > 0)
     {
      double freeMargin = AccountInfoDouble(ACCOUNT_MARGIN_FREE) * 0.9;
      if(margin > freeMargin)
         lots = MathFloor(lots * freeMargin / margin / step) * step;
     }
   if(lots < vmin)
      return 0.0;   // 最小ロットでもリスクを超えるなら入らない
   int digits = (int)MathMax(0, MathCeil(-MathLog10(step)));
   return NormalizeDouble(lots, digits);
  }

//+------------------------------------------------------------------+
void ManagePositions(const MqlDateTime &now)
  {
   double atr[];
   bool haveATR = Buf(hATR, 1, 1, atr);
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;

   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong ticket = PositionGetTicket(i);
      if(!IsOurs(ticket))
         continue;
      long     type  = PositionGetInteger(POSITION_TYPE);
      double   open  = PositionGetDouble(POSITION_PRICE_OPEN);
      double   sl    = PositionGetDouble(POSITION_SL);
      double   tp    = PositionGetDouble(POSITION_TP);
      datetime topen = (datetime)PositionGetInteger(POSITION_TIME);
      bool     buy   = (type == POSITION_TYPE_BUY);
      double   price = buy ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);

      if(InpCloseFriday && now.day_of_week == 5 && now.hour >= InpFridayCloseHour)
        {
         trade.PositionClose(ticket);
         continue;
        }
      if(InpMaxHoldBars > 0 && iBarShift(_Symbol, InpTF, topen, false) >= InpMaxHoldBars)
        {
         trade.PositionClose(ticket);
         continue;
        }

      double risk   = buy ? open - sl : sl - open;       // 損切りが損の側にある間は正
      double profit = buy ? price - open : open - price;
      double newSL  = sl;

      if(InpBEAtR > 0 && risk > 0 && profit >= risk * InpBEAtR)
         newSL = buy ? open + 5 * _Point : open - 5 * _Point;

      if(InpTrailATR > 0 && haveATR && (risk <= 0 || newSL != sl))
        {
         double cand = buy ? price - atr[0] * InpTrailATR : price + atr[0] * InpTrailATR;
         if(buy ? cand > newSL : cand < newSL)
            newSL = cand;
        }

      if(MathAbs(newSL - sl) < _Point)
         continue;
      if(buy ? newSL >= price - minDist : newSL <= price + minDist)
         continue;
      trade.PositionModify(ticket, NormalizeDouble(newSL, _Digits), tp);
     }
  }

//+------------------------------------------------------------------+
void OnTick()
  {
   double eq = AccountInfoDouble(ACCOUNT_EQUITY);
   MqlDateTime now;
   TimeToStruct(TimeCurrent(), now);

   int key = now.year * 1000 + now.day_of_year;
   if(key != g_dayKey)
     {
      g_dayKey     = key;
      g_dayStartEq = eq;
     }
   g_peakEq = MathMax(g_peakEq, eq);

   ManagePositions(now);

   // ここから下は新しい足が出たときだけ
   datetime bar0 = iTime(_Symbol, InpTF, 0);
   if(bar0 == 0 || bar0 == g_lastBar)
      return;
   g_lastBar = bar0;

   if(HasPosition())
      return;
   if(!InSession(now.hour))
      return;
   if(InpCloseFriday && now.day_of_week == 5 && now.hour >= InpFridayCloseHour - 1)
      return;
   if(InpDailyLossPct > 0 && eq < g_dayStartEq * (1.0 - InpDailyLossPct / 100.0))
      return;
   if(SymbolInfoInteger(_Symbol, SYMBOL_SPREAD) > InpMaxSpreadPts)
      return;
   if(g_lastEntry > 0 && iBarShift(_Symbol, InpTF, g_lastEntry, false) < InpCooldownBars)
      return;
   if(TodayEntries() >= InpMaxTradesPerDay)
      return;

   double fast[], rsi[], atr[], trend[];
   if(!Buf(hFast, 1, 2, fast) || !Buf(hRSI, 1, 2, rsi) || !Buf(hATR, 1, 1, atr)
      || !Buf(hTrend, 1, InpTrendSlopeBars + 1, trend))
      return;
   if(InpMinATR > 0 && atr[0] < InpMinATR)
      return;

   double trendClose = iClose(_Symbol, InpTrendTF, 1);
   bool up   = trendClose > trend[0] && trend[0] > trend[InpTrendSlopeBars];
   bool down = trendClose < trend[0] && trend[0] < trend[InpTrendSlopeBars];

   double c1 = iClose(_Symbol, InpTF, 1);
   double h1 = iHigh(_Symbol, InpTF, 1);
   double l1 = iLow(_Symbol, InpTF, 1);

   // rsi[0]＝1本前、rsi[1]＝2本前
   bool buySig  = up   && l1 <= fast[0] && c1 > fast[0] && rsi[1] < InpRSIBuy  && rsi[0] > rsi[1];
   bool sellSig = down && h1 >= fast[0] && c1 < fast[0] && rsi[1] > InpRSISell && rsi[0] < rsi[1];
   if(!buySig && !sellSig)
      return;

   double slDist  = atr[0] * InpSLATR;
   double minDist = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * _Point;
   if(slDist <= minDist)
      return;

   bool ok = false;
   if(buySig)
     {
      double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double sl  = NormalizeDouble(ask - slDist, _Digits);
      double tp  = NormalizeDouble(ask + slDist * InpRR, _Digits);
      double lots = CalcLots(ORDER_TYPE_BUY, ask, sl);
      if(lots > 0)
         ok = trade.Buy(lots, _Symbol, ask, sl, tp, "GoldScalp");
     }
   else
     {
      double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double sl  = NormalizeDouble(bid + slDist, _Digits);
      double tp  = NormalizeDouble(bid - slDist * InpRR, _Digits);
      double lots = CalcLots(ORDER_TYPE_SELL, bid, sl);
      if(lots > 0)
         ok = trade.Sell(lots, _Symbol, bid, sl, tp, "GoldScalp");
     }
   if(ok)
      g_lastEntry = bar0;
  }

//+------------------------------------------------------------------+
// 最適化の評価：PF × リカバリーファクター。取引数が少ない設定は0点
double OnTester()
  {
   double trades = TesterStatistics(STAT_TRADES);
   if(trades < InpMinTradesForScore)
      return 0.0;
   return TesterStatistics(STAT_PROFIT_FACTOR) * TesterStatistics(STAT_RECOVERY_FACTOR);
  }
//+------------------------------------------------------------------+
