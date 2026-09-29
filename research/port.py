import numpy as np, pandas as pd, glob, os
B=os.path.dirname(os.path.abspath(__file__)); M=f"{B}/multi"
def info(p): return dict(l.strip().split("=",1) for l in open(p))
def load(sym):
    if sym=="GOLD":
        fs=sorted(glob.glob(f"{B}/gold/GOLD_M5_20*.csv")); df=pd.concat([pd.read_csv(f) for f in fs]); pt=0.01
    else:
        df=pd.read_csv(f"{M}/{sym}_M5.csv"); pt=float(info(f"{M}/{sym}_info.txt")["point"])
    df["time"]=pd.to_datetime(df.time,format="%Y.%m.%d %H:%M")
    df=df.drop_duplicates("time").sort_values("time").reset_index(drop=True)
    df=df[df.time>="2016-01-01"].reset_index(drop=True)
    df["spr"]=df.spread*pt
    return df
# 通貨が強くなったとき銘柄が上がるなら +1
CC={"USDJPY":{"USD":1,"JPY":-1},"EURUSD":{"EUR":1,"USD":-1},"GBPUSD":{"GBP":1,"USD":-1},"AUDUSD":{"AUD":1,"USD":-1},
    "NZDUSD":{"NZD":1,"USD":-1},"USDCAD":{"USD":1,"CAD":-1},"USDCHF":{"USD":1,"CHF":-1},"EURJPY":{"EUR":1,"JPY":-1},
    "GBPJPY":{"GBP":1,"JPY":-1},"AUDJPY":{"AUD":1,"JPY":-1},"GOLD":{"USD":-1},"SILVER":{"USD":-1},"OILCash":{"USD":-1},
    "US30Cash":{"USD":0},"US100Cash":{"USD":0},"US500Cash":{"USD":0},"GER40Cash":{"EUR":0},"JP225Cash":{"JPY":0}}
cal=pd.read_csv(f"{M}/calendar.csv",encoding="cp932"); cal["time"]=pd.to_datetime(cal.time,format="%Y.%m.%d %H:%M")
rows=[]
for sym,cc in CC.items():
    df=load(sym); t=df.time.values; o,h,l,c,sp=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
    pc=np.roll(c,1); tr=np.maximum(h-l,np.maximum(abs(h-pc),abs(l-pc))); atr=pd.Series(tr).rolling(48).mean().shift(1).to_numpy()
    slip=np.nanmedian(sp)   # 片道スリップ＝ふだんのスプレッドの中央値
    ev=cal[cal.currency.isin(cc.keys())&(cal.importance>=2)].drop_duplicates("time")  # 同時刻は1回
    i=np.searchsorted(t,ev.time.values); ok=i+40<len(t); ev=ev[ok]; i=i[ok]
    ok=t[i]==ev.time.values; ev=ev[ok]; i=i[ok]
    imp=ev.groupby("time").importance.max()
    for H in [3,6,12,24]:
        ent=o[i+1]+np.nan
        rows.append(pd.DataFrame(dict(sym=sym,H=H,time=ev.time.values,imp=ev.importance.values,
            m0=(c[i]-o[i])/atr[i], fwd=(o[i+1+H]-o[i+1]), cost=sp[i+1]+2*slip, atr=atr[i],
            # 途中の最大逆行（損切り用）
            )))
R=pd.concat(rows); R["yr"]=pd.to_datetime(R.time).dt.year; R.to_pickle("port_rows.pkl")
print(R.groupby("sym").size()/4)
