from bt import *
df=load(); df["y"]=df.time.dt.year; df["h"]=df.time.dt.hour
# 各時間の最初の始値→最後の終値（その1時間の値動き）
g=df.groupby([df.time.dt.floor("1h")]).agg(o=("open","first"),c=("close","last"),spr=("spr","median"),n=("open","size"))
g=g[g.n>=10]; g["h"]=g.index.hour; g["y"]=g.index.year; g["ret"]=g.c-g.o
g["rel"]=g.ret/g.o*1e4  # bp
t=g.groupby("h").agg(bp=("rel","mean"),usd=("ret","mean"),spr=("spr","median"),n=("rel","size"))
t["t"]=g.groupby("h").rel.mean()/g.groupby("h").rel.std()*np.sqrt(t.n)
yy=g.pivot_table(index="h",columns="y",values="rel",aggfunc="mean")
t["yrs+"]=(yy>0).sum(1); t["yrs-"]=(yy<0).sum(1)
print(t.round(3).to_string())
