import numpy as np, pandas as pd, os
M=os.path.join(os.path.dirname(os.path.abspath(__file__)),"multi"); G=os.path.join(os.path.dirname(os.path.abspath(__file__)),"gold")
cal=pd.read_csv(f"{M}/calendar.csv",encoding="cp932")
cal["time"]=pd.to_datetime(cal.time,format="%Y.%m.%d %H:%M")
cal=cal.dropna(subset=["actual","forecast"])
def bars(path_or_list):
    if isinstance(path_or_list,list): df=pd.concat([pd.read_csv(f) for f in path_or_list])
    else: df=pd.read_csv(path_or_list)
    df["time"]=pd.to_datetime(df.time,format="%Y.%m.%d %H:%M")
    return df.drop_duplicates("time").sort_values("time").set_index("time")
import glob
SYM={"USDJPY":(bars(f"{M}/USDJPY_M5.csv"),0.001),"EURUSD":(bars(f"{M}/EURUSD_M5.csv"),0.00001),
     "GOLD":(bars(sorted(glob.glob(f"{G}/GOLD_M5_20*.csv"))),0.01)}
# 通貨→(銘柄, 通貨が強い時の銘柄の向き)
MAP={"USD":[("USDJPY",1),("EURUSD",-1),("GOLD",-1)],"JPY":[("USDJPY",-1)],"EUR":[("EURUSD",1)]}
rows=[]
for sym,(df,pt) in SYM.items():
    t=df.index.values; o=df.open.values; c=df.close.values; sp=df.spread.values*pt
    for ccy,lst in MAP.items():
        for s,dr in lst:
            if s!=sym: continue
            ev=cal[cal.currency==ccy]
            i=np.searchsorted(t,ev.time.values)   # 発表時刻を含む足
            ok=(i+13<len(t))
            ev=ev[ok]; i=i[ok]
            ok=(t[i]==ev.time.values); ev=ev[ok]; i=i[ok]   # 発表時刻ちょうどの足があるもの
            for H in [3,6,12]:
                r0=(c[i]-o[i])            # 発表足の動き
                ent=o[i+1]; ex=o[i+1+H]
                rows.append(pd.DataFrame(dict(sym=sym,dir=dr,H=H,eid=ev.event_id.values,ev=ev.event.values,ccy=ccy,imp=ev.importance.values,
                    time=ev.time.values,sur=(ev.actual-ev.forecast).values,r0=r0/ o[i],fwd=(ex-ent)/ent,cost=(sp[i+1]+ (2*pt*10 if sym!="GOLD" else 0.06))/ent)))
R=pd.concat(rows); R.to_pickle("news_rows.pkl"); print(len(R)); print(R.groupby(["sym","H"]).size())
