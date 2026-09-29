from bt import *
import itertools
df=load(); o,h,l,c,spr=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
hour=df.time.dt.hour.to_numpy(); dow=df.time.dt.dayofweek.to_numpy()+1
day=(df.time.dt.year*1000+df.time.dt.dayofyear).to_numpy(); days=len(np.unique(day)); yr=df.time.dt.year.to_numpy()
sh=lambda x,k: np.concatenate([np.full(k,np.nan),x[:-k]])
res=[]
for an in [14,48]:
  a1=sh(atr(h,l,c,an),1)
  for N in [6,12,24]:
    hi=sh(pd.Series(h).rolling(N).max().to_numpy(),2); lo=sh(pd.Series(l).rolling(N).min().to_numpy(),2); c1=sh(c,1)
    # 直前N本のレンジが狭い（ATR比）ときだけ＝スクイーズ後のブレイク
    for sq in [0,3,5]:
      rng=hi-lo; cond=(rng< sq*a1) if sq else np.ones(len(c),bool)
      L=(c1>hi)&cond; S=(c1<lo)&cond
      for slm,trail,(s_,e_) in itertools.product([0.5,1,2],[0.5,1,1.5],[(9,22),(8,12),(14,19)]):
        en,ex,di,R=run(o,h,l,spr,L,S,np.nan_to_num(a1*slm),20.0,0,48,hour,dow,day,s_,e_,10,1,22,0.40,0.03,trail)
        if len(R)<1000: continue
        s=stats(R,days,0.01); ys=[R[yr[en]==y].mean() for y in range(2015,2027)]
        res.append((an,N,sq,slm,trail,s_,e_,len(R)/days,s["PF_R"],s["avgR"],sum(v>0 for v in ys)))
r=pd.DataFrame(res,columns=["atr","N","sq","sl","trail","sh","eh","perday","PF_R","avgR","yrs+"])
print(len(r)); print(r.sort_values("PF_R",ascending=False).head(15).to_string())
