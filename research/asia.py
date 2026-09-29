from bt import *
df=load(); o,h,l,c,spr=[df[k].to_numpy() for k in ["open","high","low","close","spr"]]
t=df.time; hr=t.dt.hour.to_numpy(); mi=t.dt.minute.to_numpy(); yr=t.dt.year.to_numpy(); dow=t.dt.dayofweek.to_numpy()
n=len(c)
def trade(ent_mask, hold, direction=1, slip=0.03):
    idx=np.where(ent_mask)[0]; idx=idx[idx+hold<n]
    # 同じ日の連続性確認（hold本後が 5*hold 分後）
    ok=((t.values[idx+hold]-t.values[idx]).astype('timedelta64[m]').astype(int)==5*hold)
    idx=idx[ok]
    e=o[idx]+spr[idx]+slip if direction==1 else o[idx]-slip
    x=o[idx+hold]-slip if direction==1 else o[idx+hold]+spr[idx+hold]+slip
    p=(x-e)*direction
    return idx,p
print("entry  hold  n  win  avg$  PF  yrs+ (long)")
for eh,em in [(1,0),(1,5),(1,10),(1,15),(1,30),(2,0)]:
  for hold in [6,12,24,36]:
    m=(hr==eh)&(mi==em)&(dow<5)
    idx,p=trade(m,hold)
    ys=pd.Series(p).groupby(yr[idx]).sum()
    print(f"{eh:02d}:{em:02d} {hold*5:4d}m {len(p):5d} {np.mean(p>0):.2f} {p.mean():6.3f} {p[p>0].sum()/-p[p<0].sum():.2f} {(ys>0).sum()}/{len(ys)}  spr@entry {np.median(spr[idx]):.2f}")
