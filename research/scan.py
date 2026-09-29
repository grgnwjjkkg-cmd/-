from bt import *
df=load(); o,h,l,c,spr=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
hour=df.time.dt.hour.to_numpy(); t=df.time.values
n=len(c)
# 連続した足か（5分差）
gap=np.diff(t).astype('timedelta64[m]').astype(int)
res=[]
for k in [1,3,6,12]:
  for m in [3,6,12,24]:
    past=c-np.roll(c,k)   # close[i]-close[i-k]
    fut=np.roll(c,-m)-c   # close[i+m]-close[i]
    ok=np.ones(n,bool); ok[:k]=False; ok[-m:]=False
    for hr in range(24):
      s=ok&(hour==hr)&(past!=0)
      mom=(np.sign(past[s])*fut[s]).mean()
      cost=np.median(spr[s])+0.06
      res.append((k,m,hr,mom,cost,s.sum()))
r=pd.DataFrame(res,columns=["k","m","hr","mom","cost","n"])
r["best"]=r.mom.abs()-r.cost
print(r.sort_values("best",ascending=False).head(25).to_string())
