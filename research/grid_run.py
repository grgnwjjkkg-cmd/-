import numpy as np, pandas as pd, itertools, pickle, sys
from portlib import load
from grid import sim
from bt import atr, ema
syms=sys.argv[1].split(",")
res=[]
for sym in syms:
    df=load(sym); slip=float(np.nanmedian(df.spr))*0.5
    o,h,l,c,sp=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
    t=df.time; hour=t.dt.hour.to_numpy(); dow=t.dt.dayofweek.to_numpy()+1
    iso=t.dt.isocalendar(); wk=(iso.year.to_numpy().astype(np.int64)*100+iso.week.to_numpy().astype(np.int64))
    yr=t.dt.year.to_numpy()
    a=pd.Series(np.maximum(h-l,1e-9)).rolling(48).mean().shift(1).to_numpy(); a=np.nan_to_num(a)
    for N,kb in [(20,2.0),(20,2.5),(50,2.5)]:
        m=pd.Series(c).rolling(N).mean().shift(1).to_numpy(); sd=pd.Series(c).rolling(N).std().shift(1).to_numpy()
        c1=np.concatenate([[np.nan],c[:-1]])
        L=np.nan_to_num(c1<m-kb*sd).astype(bool); S=np.nan_to_num(c1>m+kb*sd).astype(bool)
        for (sh_,eh),st,mu,K,tp in itertools.product([(0,24),(2,10),(9,21)],[1,2,3],[1.5,2.0],[5,8],[0.5,1.0]):
            u=1.0; hs=30.0
            B=sim(o,h,l,c,sp,a,L,S,hour,dow,wk,sh_,eh,st,mu,K,tp,u,hs,slip,1e9,1e9)
            if len(B)<200: continue
            r=B[:,2]; y=yr[B[:,0].astype(int)]
            for per,msk in [("tr",y<=2021),("te",y>=2022)]:
                rr=r[msk]
                if len(rr)==0: continue
                wkr=pd.Series(rr).groupby(B[msk,4]).sum()
                res.append((sym,N,kb,sh_,eh,st,mu,K,tp,per,len(rr),len(rr)/ (len(wkr)*5),rr.mean(),(rr<=-hs+0.5).mean(),wkr.mean(),(wkr>0).mean(),wkr.quantile(0.02)))
o_=pd.DataFrame(res,columns=["sym","N","kb","sh","eh","step","mult","K","tp","per","n","perday","avg%","stop_rate","wk_mean%","wk_win","wk_p2%"])
o_.to_pickle(f"grid_{syms[0]}.pkl")
tr=o_[o_.per=="tr"].set_index(["sym","N","kb","sh","eh","step","mult","K","tp"]); te=o_[o_.per=="te"].set_index(tr.index.names)
j=tr.join(te,lsuffix="_tr",rsuffix="_te",how="inner")
print(j.sort_values("wk_mean%_tr",ascending=False).head(8)[["perday_tr","wk_mean%_tr","wk_win_tr","stop_rate_tr","wk_mean%_te","wk_win_te","stop_rate_te","wk_p2%_te"]].round(3).to_string())
