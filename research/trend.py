import numpy as np, pandas as pd, itertools, pickle
from portlib import load
from bt import run, atr
syms=["USDJPY","EURUSD","GBPUSD","AUDUSD","NZDUSD","USDCAD","USDCHF","EURJPY","GBPJPY","AUDJPY","GOLD","SILVER","OILCash","US30Cash","US100Cash","US500Cash","GER40Cash","JP225Cash"]
D={}
for s in syms:
    df=load(s); slip=float(np.nanmedian(df.spr))
    g=df.set_index("time").resample("1h",label="left",closed="left").agg(open=("open","first"),high=("high","max"),low=("low","min"),close=("close","last"),spr=("spr","median"),n=("open","size")).dropna()
    g=g[g.n>=6].reset_index()
    D[s]=(g,slip)
pickle.dump(D,open("h1.pkl","wb"))
sh=lambda x,k: np.concatenate([np.full(k,np.nan),x[:-k]])
res=[]
for N,slm,trail,rr,mh in itertools.product([12,24,48,96],[1.5,2.5],[0,2,3],[3,10],[24,72]):
    per={}
    for s,(g,slip) in D.items():
        o,h,l,c,sp=[g[k].to_numpy() for k in ["open","high","low","close","spr"]]
        t=g.time; hour=t.dt.hour.to_numpy(); dow=t.dt.dayofweek.to_numpy()+1; day=(t.dt.year*1000+t.dt.dayofyear).to_numpy()
        a1=sh(atr(h,l,c,24),1)
        hi=sh(pd.Series(h).rolling(N).max().to_numpy(),2); lo=sh(pd.Series(l).rolling(N).min().to_numpy(),2); c1=sh(c,1)
        L=c1>hi; S=c1<lo
        en,ex,di,R=run(o,h,l,sp,L,S,np.nan_to_num(a1*slm),rr,0,mh,hour,dow,day,0,24,3,1,22,1e9,slip,trail)
        per[s]=(R,t.dt.year.to_numpy()[en])
    allR=np.concatenate([v[0] for v in per.values()]); allY=np.concatenate([v[1] for v in per.values()])
    pf=lambda r: r[r>0].sum()/-r[r<0].sum()
    a=allR[allY<=2021]; b=allR[allY>=2022]
    res.append((N,slm,trail,rr,mh,len(a)/(6*260),pf(a),a.mean(),len(b)/(4.75*260),pf(b),b.mean()))
o=pd.DataFrame(res,columns=["N","sl","trail","rr","mh","tr_day","tr_PF","tr_R","te_day","te_PF","te_R"])
o.to_pickle("trend_grid.pkl")
print(o[o.tr_day>=5].sort_values("tr_PF",ascending=False).head(15).round(3).to_string())
