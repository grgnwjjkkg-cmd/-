//+------------------------------------------------------------------+
//| ExportGold.mq5                                                   |
//| 足データを1年ずつCSVに書き出す。スプレッドも一緒に出す。         |
//| 出力先：データフォルダの MQL5/Files                              |
//+------------------------------------------------------------------+
#property version     "1.00"
#property description "足データ（スプレッド付き）を1年ずつCSVに書き出す"
#property script_show_inputs

input string          InpSymbol   = "";         // 銘柄（空なら今のチャートの銘柄）
input ENUM_TIMEFRAMES InpTF       = PERIOD_M5;  // 時間足
input int             InpFromYear = 2010;       // 何年から
input int             InpToYear   = 2026;       // 何年まで

void OnStart()
  {
   string sym = (InpSymbol == "") ? _Symbol : InpSymbol;
   if(!SymbolSelect(sym, true))
     {
      Print(sym, " が見つかりません");
      return;
     }
   int    digits = (int)SymbolInfoInteger(sym, SYMBOL_DIGITS);
   string tf     = StringSubstr(EnumToString(InpTF), 7);   // PERIOD_M5 → M5
   string base   = sym;
   StringReplace(base, "#", "");
   StringReplace(base, ".", "");

   WriteInfo(sym, base);

   int total = 0;
   for(int y = InpFromYear; y <= InpToYear; y++)
     {
      datetime from = StringToTime(IntegerToString(y) + ".01.01 00:00");
      datetime to   = StringToTime(IntegerToString(y + 1) + ".01.01 00:00") - 1;
      MqlRates r[];
      int n = -1;
      // 手元にない期間はサーバーから落とすので、数回待ち直す
      for(int tries = 0; tries < 15 && !IsStopped(); tries++)
        {
         n = CopyRates(sym, InpTF, from, to, r);
         if(n > 0)
            break;
         Sleep(1000);
        }
      if(n <= 0)
        {
         Print(y, "年：データなし");
         continue;
        }

      string fn = StringFormat("%s_%s_%d.csv", base, tf, y);
      int h = FileOpen(fn, FILE_WRITE | FILE_CSV | FILE_ANSI, ',');
      if(h == INVALID_HANDLE)
        {
         Print(fn, " を作れませんでした（", GetLastError(), "）");
         continue;
        }
      FileWrite(h, "time", "open", "high", "low", "close", "tick_volume", "spread");
      for(int i = 0; i < n; i++)
         FileWrite(h,
                   TimeToString(r[i].time, TIME_DATE | TIME_MINUTES),
                   DoubleToString(r[i].open, digits),
                   DoubleToString(r[i].high, digits),
                   DoubleToString(r[i].low, digits),
                   DoubleToString(r[i].close, digits),
                   (long)r[i].tick_volume,
                   r[i].spread);
      FileClose(h);
      total += n;
      PrintFormat("%d年：%d本 → %s", y, n, fn);
     }
   PrintFormat("完了：合計 %d 本。保存先は データフォルダ/MQL5/Files", total);
  }

// 検証に使う銘柄の条件（桁数・契約サイズ・スワップなど）
void WriteInfo(string sym, string base)
  {
   int h = FileOpen(base + "_info.txt", FILE_WRITE | FILE_TXT | FILE_ANSI);
   if(h == INVALID_HANDLE)
      return;
   FileWrite(h, "symbol="        + sym);
   FileWrite(h, "server="        + AccountInfoString(ACCOUNT_SERVER));
   FileWrite(h, "currency="      + AccountInfoString(ACCOUNT_CURRENCY));
   FileWrite(h, "leverage="      + IntegerToString(AccountInfoInteger(ACCOUNT_LEVERAGE)));
   FileWrite(h, "digits="        + IntegerToString(SymbolInfoInteger(sym, SYMBOL_DIGITS)));
   FileWrite(h, "point="         + DoubleToString(SymbolInfoDouble(sym, SYMBOL_POINT), 8));
   FileWrite(h, "contract_size=" + DoubleToString(SymbolInfoDouble(sym, SYMBOL_TRADE_CONTRACT_SIZE), 2));
   FileWrite(h, "volume_min="    + DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_MIN), 2));
   FileWrite(h, "volume_step="   + DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_STEP), 2));
   FileWrite(h, "volume_max="    + DoubleToString(SymbolInfoDouble(sym, SYMBOL_VOLUME_MAX), 2));
   FileWrite(h, "spread_now="    + IntegerToString(SymbolInfoInteger(sym, SYMBOL_SPREAD)));
   FileWrite(h, "stops_level="   + IntegerToString(SymbolInfoInteger(sym, SYMBOL_TRADE_STOPS_LEVEL)));
   FileWrite(h, "swap_long="     + DoubleToString(SymbolInfoDouble(sym, SYMBOL_SWAP_LONG), 4));
   FileWrite(h, "swap_short="    + DoubleToString(SymbolInfoDouble(sym, SYMBOL_SWAP_SHORT), 4));
   FileWrite(h, "margin_initial="+ DoubleToString(SymbolInfoDouble(sym, SYMBOL_MARGIN_INITIAL), 2));
   FileClose(h);
  }
//+------------------------------------------------------------------+
