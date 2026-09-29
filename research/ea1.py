from bt import *
import time
t=time.time()
df=load(); o,h,l,c,spr=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
hour=df.time.dt.hour.to_numpy(); dow=df.time.dt.dayofweek.to_numpy()+1  # Mon=1
dow=np.where(dow==7,0,dow)
day=(df.time.dt.year*1000+df.time.dt.dayofyear).to_numpy()
days=len(np.unique(day))
print(len(df), df.time.iloc[0], df.time.iloc[-1], "days",days, "load",round(time.time()-t,1))
print("spread $ median/p90:", np.median(spr), np.percentile(spr,90))
f=ema(c,20); r=rsi(c,7); a=atr(h,l,c,14)
te,tc,_=htf(df,"1h",50)
te3=np.roll(te,0)
# 傾き: 3本前のH1 EMA
g=df.set_index("time")["close"].resample("1h",label="left",closed="left").last().dropna()
e=ema(g.to_numpy(),50); tclose=g.index+pd.Timedelta("1h")
idx=np.searchsorted(tclose.values,df.time.values,side="right")-1
e3=np.where(idx>=3,e[np.maximum(idx-3,0)],np.nan)
# 足 i の始値で判断：bar1=i-1, bar2=i-2
sh=lambda x,k: np.concatenate([np.full(k,np.nan),x[:-k]])
up=(tc>te)&(te>e3); dn=(tc<te)&(te<e3)
f1,c1,h1,l1,r1,r2,a1=sh(f,1),sh(c,1),sh(h,1),sh(l,1),sh(r,1),sh(r,2),sh(a,1)
L=up&(l1<=f1)&(c1>f1)&(r2<40)&(r1>r2)
S=dn&(h1>=f1)&(c1<f1)&(r2>60)&(r1<r2)
sld=np.nan_to_num(a1*1.5)
en,ex,di,R=run(o,h,l,spr,L,S,sld,1.5,1.0,36,hour,dow,day,9,22,10,2,22,0.50,0.03)
print(stats(R,days,0.2,day[en]))
yrs=df.time.dt.year.to_numpy()[en]
for y in np.unique(yrs):
    m=yrs==y; s=stats(R[m],1,0.01); print(y, m.sum(), "PF_R %.2f avgR %.3f"%(s["PF_R"],s["avgR"]))
