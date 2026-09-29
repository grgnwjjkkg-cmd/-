import numpy as np, pandas as pd, itertools
from portlib import load
from grid import sim
P=dict(N=50,kb=2.5,sh=9,eh=21,step=2.0,mult=1.5,K=5,tp=0.5)
data={}
for sym in ["GOLD","GER40Cash"]:
    df=load(sym); slip=float(np.nanmedian(df.spr))*0.5
    o,h,l,c,sp=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
    t=df.time; hour=t.dt.hour.to_numpy(); dow=t.dt.dayofweek.to_numpy()+1
    iso=t.dt.isocalendar(); wk=(iso.year.to_numpy().astype(np.int64)*100+iso.week.to_numpy().astype(np.int64))
    a=np.nan_to_num(pd.Series(np.maximum(h-l,1e-9)).rolling(48).mean().shift(1).to_numpy())
    m=pd.Series(c).rolling(P["N"]).mean().shift(1).to_numpy(); sd=pd.Series(c).rolling(P["N"]).std().shift(1).to_numpy()
    c1=np.concatenate([[np.nan],c[:-1]])
    L=np.nan_to_num(c1<m-P["kb"]*sd).astype(bool); S=np.nan_to_num(c1>m+P["kb"]*sd).astype(bool)
    data[sym]=(o,h,l,c,sp,a,L,S,hour,dow,wk,slip,t)
def run(sym,u,hs,wt,ws):
    o,h,l,c,sp,a,L,S,hour,dow,wk,slip,t=data[sym]
    B=sim(o,h,l,c,sp,a,L,S,hour,dow,wk,P["sh"],P["eh"],P["step"],P["mult"],P["K"],P["tp"],u,hs,slip,wt,ws)
    return pd.DataFrame(dict(t=t.values[B[:,0].astype(int)],r=B[:,2],lv=B[:,3],wk=B[:,4]))
rows=[]
for u,hs,wt,ws in itertools.product([0.25,0.5,1],[15,25,40],[1e9],[20,1e9]):
    for sym in data:
        b=run(sym,u,hs,wt,ws)
        # 週内は複利、週ごとに結果を記録（週の終わりの残高/週の始まり）
        wkret=b.groupby("wk").r.apply(lambda x: np.prod(1+x/100)-1)*100
        yr=(wkret.index//100)
        eq=np.cumprod(1+wkret.values/100); peak=np.maximum.accumulate(eq); dd=(1-eq/peak).max()
        tr=wkret[yr<=2021]; te=wkret[yr>=2022]
        rows.append((sym,u,hs,wt,ws,len(b)/len(wkret)/5,tr.median(),tr.mean(),te.median(),te.mean(),(te>0).mean(),te.quantile(0.02),te.min(),(te<=-30).mean(),dd,eq[-1]))
o=pd.DataFrame(rows,columns=["sym","u","hs","wt","ws","set/day","tr_med","tr_mean","te_med","te_mean","te_win","te_p2","te_min","te_le-30%","maxDD","final_x"])
o.to_pickle("grid_mm.pkl")
pd.set_option("display.width",250)
print(o.sort_values("te_mean",ascending=False).groupby("sym").head(8).round(2).to_string())
