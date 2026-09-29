//+------------------------------------------------------------------+
//| ExportMulti.mq5                                                  |
//| 複数銘柄の足データ（スプレッド付き）と経済指標カレンダーを       |
//| CSVに書き出す。出力先：データフォルダの MQL5/Files/multi         |
//+------------------------------------------------------------------+
#property version     "1.00"
#property description "複数銘柄の足データと経済指標カレンダーをCSVに書き出す"
#property script_show_inputs

input string          InpSymbols  = "EURUSD#,USDJPY#,GBPUSD#,AUDUSD#,NZDUSD#,USDCAD#,USDCHF#,EURJPY#,GBPJPY#,AUDJPY#,GOLD#,SILVER#,US30Cash#,US500Cash#,US100Cash#,JP225Cash#,GER40Cash#,OILCash#"; // 銘柄（カンマ区切り、無いものは飛ばす）
input ENUM_TIMEFRAMES InpTF       = PERIOD_M5;  // 時間足
input int             InpFromYear = 2016;       // 何年から
input bool            InpBars     = true;       // 足データを書き出す
input bool            InpCalendar = true;       // 経済指標カレンダーも書き出す

void OnStart()
  {
   string syms[];
   int ns = StringSplit(InpSymbols, ',', syms);
   datetime from = StringToTime(IntegerToString(InpFromYear) + ".01.01 00:00");
   datetime to   = TimeCurrent();
   string tf = StringSubstr(EnumToString(InpTF), 7);

   for(int s = 0; InpBars && s < ns && !IsStopped(); s++)
     {
      string sym = syms[s];
      StringTrimLeft(sym);
      StringTrimRight(sym);
      if(sym == "" || !SymbolSelect(sym, true))
        {
         Print(sym, "：見つからないので飛ばします");
         continue;
        }
      ExportSymbol(sym, tf, from, to);
     }
   if(InpCalendar)
      ExportCalendar(from, to);
   Print("完了。保存先は データフォルダ/MQL5/Files/multi");
  }

void ExportSymbol(string sym, string tf, datetime from, datetime to)
  {
   int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   string base   = sym;
   StringReplace(base, "#", "");
   StringReplace(base, ".", "");
   string fn = StringFormat("multi\\%s_%s.csv", base, tf);
   int h = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
     {
      Print(fn, " を作れませんでした（", GetLastError(), "）");
      return;
     }
   FileWrite(h, "time", "open", "high", "low", "close", "tick_volume", "spread");

   // 1年ずつ取って同じファイルに足す（一度に取るとメモリが足りないことがある）
   int total = 0;
   MqlDateTime d;
   TimeToStruct(from, d);
   for(int y = d.year; ; y++)
     {
      datetime a = StringToTime(IntegerToString(y) + ".01.01 00:00");
      datetime b = StringToTime(IntegerToString(y + 1) + ".01.01 00:00") - 1;
      if(a > to)
         break;
      MqlRates r[];
      int n = -1;
      for(int tries = 0; tries < 15 && !IsStopped(); tries++)
        {
         n = CopyRates(sym, (ENUM_TIMEFRAMES)InpTF, a, b, r);
         if(n > 0)
            break;
         Sleep(1000);
        }
      for(int i = 0; i < n; i++)
         FileWrite(h,
                   TimeToString(r[i].time, TIME_DATE | TIME_MINUTES),
                   DoubleToString(r[i].open, digits),
                   DoubleToString(r[i].high, digits),
                   DoubleToString(r[i].low, digits),
                   DoubleToString(r[i].close, digits),
                   (long)r[i].tick_volume,
                   r[i].spread);
      if(n > 0)
         total += n;
     }
   FileClose(h);

   // 銘柄の条件も一緒に残す
   int hi = FileOpen(StringFormat("multi\\%s_info.txt", base), FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(hi != INVALID_HANDLE)
     {
      FileWrite(hi, "symbol="        + sym);
      FileWrite(hi, "digits="        + IntegerToString(digits));
      FileWrite(hi, "point="         + DoubleToString(SymbolInfoDouble(sym, SYMBOL_POINT), 8));
      FileWrite(hi, "contract_size=" + DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE), 2));
      FileWrite(hi, "profit_ccy="    + SymbolInfoString(sym, SYMBOL_CURRENCY_PROFIT));
      FileWrite(hi, "volume_min="    + DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN), 2));
      FileWrite(hi, "volume_step="   + DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP), 2));
      FileWrite(hi, "spread_now="    + IntegerToString(SymbolInfoInteger(sym, SYMBOL_SPREAD)));
      FileWrite(hi, "swap_long="     + DoubleToString(SymbolInfoDouble(sym, SYMBOL_SWAP_LONG), 4));
      FileWrite(hi, "swap_short="    + DoubleToString(SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT), 4));
      FileClose(hi);
     }
   PrintFormat("%s：%d本 → %s", sym, total, fn);
  }

// 重要度が中以上の指標を、発表時刻（サーバー時間）・通貨・結果・予想・前回つきで書き出す
void ExportCalendar(datetime from, datetime to)
  {
   int h = FileOpen("multi\\calendar.csv", FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
   if(h == INVALID_HANDLE)
     {
      Print("calendar.csv を作れませんでした（", GetLastError(), "）");
      return;
     }
   FileWrite(h, "time", "currency", "importance", "event_id", "event", "actual", "forecast", "previous");
   int n = 0, failed = 0;
   // 一度に長い期間を取ると失敗するので、1か月ずつ取る
   for(datetime a = from; a < to && !IsStopped(); )
     {
      MqlDateTime d;
      TimeToStruct(a, d);
      d.mon++;
      if(d.mon > 12) { d.mon = 1; d.year++; }
      datetime b = StructToTime(d);
      MqlCalendarValue v[];
      ResetLastError();
      bool ok = false;
      for(int tries = 0; tries < 5 && !ok; tries++)
        {
         ok = CalendarValueHistory(v, a, b);
         if(!ok) Sleep(500);
        }
      if(!ok)
        {
         failed++;
         PrintFormat("カレンダー %s：取れませんでした（%d）", TimeToString(a, TIME_DATE), GetLastError());
        }
      for(int i = 0; i < ArraySize(v); i++)
        {
         MqlCalendarEvent e;
         if(!CalendarEventById(v[i].event_id, e))
            continue;
         if(e.importance < CALENDAR_IMPORTANCE_MODERATE)
            continue;
         MqlCalendarCountry c;
         if(!CalendarCountryById(e.country_id, c))
            continue;
         string name = e.name;
         StringReplace(name, ",", " ");
         FileWrite(h,
                   TimeToString(v[i].time, TIME_DATE | TIME_MINUTES),
                   c.currency,
                   (int)e.importance,
                   (long)e.id,
                   name,
                   v[i].HasActualValue()   ? DoubleToString(v[i].GetActualValue(), 3)   : "",
                   v[i].HasForecastValue() ? DoubleToString(v[i].GetForecastValue(), 3) : "",
                   v[i].HasPreviousValue() ? DoubleToString(v[i].GetPreviousValue(), 3) : "");
         n++;
        }
      a = b;
     }
   FileClose(h);
   PrintFormat("カレンダー：%d件 → multi\\calendar.csv（取れなかった月 %d）", n, failed);
  }
//+------------------------------------------------------------------+
