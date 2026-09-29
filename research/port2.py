import numpy as np, pandas as pd
R=pd.read_pickle("port_rows.pkl"); R=R[np.isfinite(R.m0)&np.isfinite(R.fwd)&(R.atr>0)]
R["tr"]=R.yr<=2021
DTR=6*252; DTE=(2026+9/12-2022)*252
def pf(p): p=np.asarray(p); return p[p>0].sum()/-p[p<0].sum() if (p<0).any() else np.inf
out=[]
for H in [3,6,12,24]:
  for imp in [2,3]:
    for k in [1,1.5,2,3,4]:
      for mode in ["mom","rev"]:
        s=R[(R.H==H)&(R.imp>=imp)&(R.m0.abs()>k)]
        d=np.sign(s.m0)*(1 if mode=="mom" else -1)
        p=(d*s.fwd-s.cost)/s.atr   # ATR単位
        a,b=p[s.tr],p[~s.tr]
        out.append((H,imp,k,mode,len(a)/DTR,pf(a),len(b)/DTE,pf(b)))
o=pd.DataFrame(out,columns=["H","imp","k","mode","tr_day","tr_PF","te_day","te_PF"])
print(o.sort_values("tr_PF",ascending=False).head(20).round(2).to_string())
