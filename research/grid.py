from bt import *
import itertools
df=load(); o,h,l,c,spr=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
hour=df.time.dt.hour.to_numpy(); dow=df.time.dt.dayofweek.to_numpy()+1
day=(df.time.dt.year*1000+df.time.dt.dayofyear).to_numpy(); days=len(np.unique(day))
yr=df.time.dt.year.to_numpy()
sh=lambda x,k: np.concatenate([np.full(k,np.nan),x[:-k]])
a1=sh(atr(h,l,c,14),1)
res=[]
def ev(name,L,S,slm,rr,be,mh,sh_,eh):
    en,ex,di,R=run(o,h,l,spr,L,S,np.nan_to_num(a1*slm),rr,be,mh,hour,dow,day,sh_,eh,10,1,22,0.40,0.03)
    if len(R)<500: return
    s=stats(R,days,0.01)
    ys=[R[yr[en]==y].mean() for y in range(2015,2027)]
    res.append((name,slm,rr,be,mh,sh_,eh,len(R)/days,s["PF_R"],s["avgR"],sum(v>0 for v in ys)))
# 1) ドンチャン・ブレイク（順張り）
for N in [12,24,48]:
    hi=sh(pd.Series(h).rolling(N).max().to_numpy(),2); lo=sh(pd.Series(l).rolling(N).min().to_numpy(),2)
    c1=sh(c,1)
    for tf in [0,50,200]:
        if tf: e=ema(c,tf); e1=sh(e,1); up=c1>e1; dn=c1<e1
        else: up=dn=np.ones(len(c),bool)
        L=(c1>hi)&up; S=(c1<lo)&dn
        for slm,rr,mh,(s_,e_) in itertools.product([1,2,3],[1,2,3],[24,72],[(9,22),(14,20),(0,24)]):
            ev(f"brk{N}_ema{tf}",L,S,slm,rr,0,mh,s_,e_)
# 2) ボリンジャー逆張り
for N in [20,50]:
    m=pd.Series(c).rolling(N).mean().to_numpy(); sd=pd.Series(c).rolling(N).std().to_numpy()
    c1=sh(c,1); m1=sh(m,1); s1=sh(sd,1)
    for k in [2,2.5,3]:
        L=c1<m1-k*s1; S=c1>m1+k*s1
        for slm,rr,mh,(s_,e_) in itertools.product([1,2,3],[0.5,1,2],[12,36],[(0,8),(9,22),(0,24)]):
            ev(f"bb{N}_{k}",L,S,slm,rr,0,mh,s_,e_)
r=pd.DataFrame(res,columns=["name","sl","rr","be","mh","sh","eh","perday","PF_R","avgR","yrs+"])
print(len(r)); print(r.sort_values("PF_R",ascending=False).head(20).to_string())
print(r[r.perday>=4].sort_values("PF_R",ascending=False).head(10).to_string())
