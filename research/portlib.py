import numpy as np, pandas as pd, glob, os
B=os.path.dirname(os.path.abspath(__file__)); M=f"{B}/multi"
def info(p): return dict(l.strip().split("=",1) for l in open(p))
def load(sym):
    if sym=="GOLD":
        fs=sorted(glob.glob(f"{B}/gold/GOLD_M5_20*.csv")); df=pd.concat([pd.read_csv(f) for f in fs]); pt=0.01
    else:
        df=pd.read_csv(f"{M}/{sym}_M5.csv"); pt=float(info(f"{M}/{sym}_info.txt")["point"])
    df["time"]=pd.to_datetime(df.time,format="%Y.%m.%d %H:%M")
    df=df.drop_duplicates("time").sort_values("time").reset_index(drop=True)
    df=df[df.time>="2016-01-01"].reset_index(drop=True)
    df["spr"]=df.spread*pt
    return df
