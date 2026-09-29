from bt import *
df=load(); o,h,l,c,spr=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
hour=df.time.dt.hour.to_numpy(); dow=df.time.dt.dayofweek.to_numpy()+1
day=(df.time.dt.year*1000+df.time.dt.dayofyear).to_numpy(); days=len(np.unique(day))
a=np.nan_to_num(np.concatenate([[np.nan],atr(h,l,c,14)[:-1]]))
rng=np.random.default_rng(0); n=len(c)
z=np.zeros(n)
for name,L,S in [("rand",rng.random(n)<0.02,rng.random(n)<0.02),("allLong",np.ones(n,bool),np.zeros(n,bool))]:
  for cost in [0,1]:
    sp=spr if cost else z; sl=0.03 if cost else 0.0
    en,ex,di,R=run(o,h,l,sp,L,S,a*3,2.0,0,72,hour,dow,day,0,24,10,1,22,9.0,sl)
    print(name,"cost" if cost else "nocost",len(R),"avgR %.4f PF_R %.3f"%(R.mean(),stats(R,days,0.01)["PF_R"]), "dir mean", di.mean())
print("gold", c[0], c[-1])
