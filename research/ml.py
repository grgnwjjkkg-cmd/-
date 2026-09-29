from bt import *
import lightgbm as lgb, sys
H=int(sys.argv[1]) if len(sys.argv)>1 else 12
df=load(); o,h,l,c,spr=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
t=df.time; n=len(c)
a14=atr(h,l,c,14); a96=atr(h,l,c,96)
F={}
for k in [1,2,3,6,12,24,48,96,288]:
    F[f"r{k}"]=(c-np.roll(c,k))/a14
for k in [20,50,200]:
    F[f"d_ema{k}"]=(c-ema(c,k))/a14
F["rsi7"]=rsi(c,7); F["rsi14"]=rsi(c,14)
F["atr_ratio"]=a14/a96
F["bar_rng"]=(h-l)/a14; F["body"]=(c-o)/a14
F["hour"]=t.dt.hour.to_numpy()+t.dt.minute.to_numpy()/60; F["dow"]=t.dt.dayofweek.to_numpy()
for rule,nm in [("1h","h1"),("4h","h4"),("1D","d1")]:
    e,cc,_=htf(df,rule,20); F[f"{nm}_d"]=(c-e)/a14
    e,cc,_=htf(df,rule,50); F[f"{nm}_d50"]=(c-e)/a14
# 当日の高安の中での位置
d=t.dt.floor("1D"); hi=pd.Series(h).groupby(d.values).cummax().to_numpy(); lo=pd.Series(l).groupby(d.values).cummin().to_numpy()
F["day_pos"]=(c-lo)/np.maximum(hi-lo,1e-6); F["day_rng"]=(hi-lo)/a14
F["spr_atr"]=spr/a14
X=pd.DataFrame(F)
# 目的：次の足の始値で入って H 本後の始値で出る損益（ATR単位）
ent=np.roll(o,-1); ex=np.roll(o,-1-H)
valid=np.ones(n,bool); valid[-H-2:]=False; valid[:300]=False
dt=(np.roll(t.values,-1-H)-np.roll(t.values,-1)).astype('timedelta64[m]').astype(int)
valid&=dt==5*H
y=(ex-ent)/a14
yr=t.dt.year.to_numpy()
tr=valid&(yr<=2019); va=valid&(yr>=2020)&(yr<=2021); te=valid&(yr>=2022)
m=lgb.LGBMRegressor(n_estimators=400,learning_rate=0.03,num_leaves=31,min_child_samples=500,subsample=0.8,subsample_freq=1,colsample_bytree=0.8,verbose=-1)
m.fit(X[tr],y[tr],eval_set=[(X[va],y[va])],callbacks=[lgb.early_stopping(50,verbose=False)])
p=m.predict(X)
hour=t.dt.hour.to_numpy(); day=(yr*1000+t.dt.dayofyear.to_numpy())
cost=np.roll(spr,-1)+0.06   # 入口のスプレッド＋往復スリップ
def sim(mask,thr):
    # 1ポジションずつ、予測の絶対値が thr 超で入る
    i=0; out=[]; last=-1
    idxs=np.where(mask&(np.abs(p)>thr)&(hour>=2)&(hour<=21)&(spr<=0.4))[0]
    for i in idxs:
        if i<=last: continue
        dr=np.sign(p[i]); pnl=dr*(ex[i]-ent[i])-cost[i]
        out.append((i,pnl/a14[i],pnl)); last=i+H
    return np.array(out)
nd=lambda msk: len(np.unique(day[msk]))
for thr in np.quantile(np.abs(p[va]),[0.9,0.95,0.98,0.99,0.995]):
    for nm,msk in [("valid",va),("test",te)]:
        r=sim(msk,thr)
        if len(r)==0: continue
        R=r[:,1]; P=r[:,2]
        print(f"H={H} thr={thr:.3f} {nm:5s} n={len(r)} perday={len(r)/nd(msk):.2f} win={np.mean(P>0):.2f} PF$={P[P>0].sum()/-P[P<0].sum():.2f} avgR={R.mean():.3f}")
