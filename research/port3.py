import numpy as np, pandas as pd
from portlib import load
from portlib import load
syms=["USDJPY","EURUSD","GBPUSD","AUDUSD","NZDUSD","USDCAD","USDCHF","EURJPY","GBPJPY","AUDJPY","GOLD","SILVER","OILCash","US30Cash","US100Cash","US500Cash","GER40Cash","JP225Cash"]
def pf(p): p=np.asarray(p); return p[p>0].sum()/-p[p<0].sum() if (p<0).any() else np.inf
out=[]
for sym in syms:
    df=load(sym); t=df.time
    slip=np.nanmedian(df.spr)
    for hold in [1,2,3]:   # 時間
        g=df.set_index("time").resample("1h",label="left",closed="left").agg(o=("open","first"),spr=("spr","median"),n=("open","size")).dropna()
        g=g[g.n>=10]
        ex=g.o.shift(-hold); okt=(g.index.to_series().shift(-hold)-g.index.to_series())==pd.Timedelta(hours=hold)
        g["r"]=(ex-g.o).where(okt); g=g.dropna(subset=["r"])
        g["cost"]=g.spr+2*slip; g["h"]=g.index.hour; g["dow"]=g.index.dayofweek; g["tr"]=g.index.year<=2021
        for hr in range(24):
            s=g[g.h==hr]
            a=s[s.tr]; b=s[~s.tr]
            if len(a)<300 or len(b)<200: continue
            d=np.sign(a.r.mean()); tstat=a.r.mean()/a.r.std()*np.sqrt(len(a))
            pa=d*a.r-a.cost; pb=d*b.r-b.cost
            out.append((sym,hold,hr,int(d),round(tstat,2),round(pf(pa),2),round(pf(pb),2),len(b)))
o=pd.DataFrame(out,columns=["sym","hold","hr","dir","t_tr","PF_tr","PF_te","n_te"])
o.to_pickle("hours_all.pkl")
c=o[(o.t_tr.abs()>2.5)&(o.PF_tr>1.2)]
print("train候補",len(c)); print(c.sort_values("PF_te",ascending=False).to_string())
