import numpy as np, pandas as pd
R=pd.read_pickle("news_rows.pkl"); R["yr"]=pd.to_datetime(R.time).dt.year
R["train"]=R.yr<=2021
days_tr=6*260; days_te=(2026.75-2022)*260
def pf(p): return p[p>0].sum()/-p[p<0].sum() if (p<0).any() else np.inf
out=[]
for (sym,H),g in R.groupby(["sym","H"]):
    # 発表足の動きに乗る（サプライズ不問）、しきい値別
    for th in [0.0005,0.001,0.002,0.003]:
        m=g.r0.abs()>th
        s=g[m]; p=np.sign(s.r0)*s.fwd-s.cost
        tr=p[s.train]; te=p[~s.train]
        out.append(("mom",sym,H,th,len(tr)/days_tr,pf(tr.values),len(te)/days_te,pf(te.values)))
    # サプライズに乗る（向きは学習期間で指標ごとに決める）
    tr=g[g.train&(g.sur!=0)]
    sgn=tr.groupby("eid").apply(lambda x: np.sign(np.corrcoef(np.sign(x.sur),x.r0)[0,1]) if len(x)>=12 and x.r0.std()>0 else 0, include_groups=False)
    g=g.assign(es=g.eid.map(sgn).fillna(0))
    for th in [0.0,0.0005,0.001]:
        s=g[(g.es!=0)&(g.sur!=0)&(g.r0.abs()>th)]
        d=s.es*np.sign(s.sur)
        s=s[np.sign(s.r0)==d]; d=d[np.sign(s.r0)==d] if False else s.es*np.sign(s.sur)
        p=d*s.fwd-s.cost
        tr=p[s.train]; te=p[~s.train]
        out.append(("sur",sym,H,th,len(tr)/days_tr,pf(tr.values),len(te)/days_te,pf(te.values)))
o=pd.DataFrame(out,columns=["kind","sym","H","th","tr_perday","tr_PF","te_perday","te_PF"])
print(o.round(3).to_string())
