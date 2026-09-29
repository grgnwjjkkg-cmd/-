"""GOLD# M5 の簡易バックテスター（足ごとのスプレッド込み）"""
import glob, os
import numpy as np, pandas as pd
from numba import njit

D = os.environ.get("GOLD_DIR", os.path.join(os.path.dirname(__file__), "gold"))


def load():
    fs = sorted(f for f in glob.glob(f"{D}/GOLD_M5_*.csv") if int(f[-8:-4]) >= 2014)
    df = pd.concat([pd.read_csv(f) for f in fs], ignore_index=True)
    df["time"] = pd.to_datetime(df["time"], format="%Y.%m.%d %H:%M")
    df = df.drop_duplicates("time").sort_values("time").reset_index(drop=True)
    df = df[df.time >= "2014-06-01"].reset_index(drop=True)
    df["spr"] = df["spread"] * 0.01
    return df


def ema(x, n):
    return pd.Series(x).ewm(span=n, adjust=False).mean().to_numpy()


def rsi(c, n):
    d = np.diff(c, prepend=c[0])
    up = pd.Series(np.where(d > 0, d, 0.0)).ewm(alpha=1 / n, adjust=False).mean()
    dn = pd.Series(np.where(d < 0, -d, 0.0)).ewm(alpha=1 / n, adjust=False).mean()
    return (100 - 100 / (1 + up / dn.replace(0, np.nan))).fillna(50).to_numpy()


def atr(h, l, c, n):
    pc = np.roll(c, 1); pc[0] = c[0]
    tr = np.maximum(h - l, np.maximum(abs(h - pc), abs(l - pc)))
    return pd.Series(tr).rolling(n).mean().to_numpy()   # MT5 の iATR は単純平均


def htf(df, rule, n):
    """上位足の EMA と終値を、確定済みの足だけ使って M5 に並べる（先読みなし）"""
    g = df.set_index("time")["close"].resample(rule, label="left", closed="left").last().dropna()
    e = ema(g.to_numpy(), n)
    t_close = g.index + pd.Timedelta(rule)                    # その上位足が確定する時刻
    idx = np.searchsorted(t_close.values, df.time.values, side="right") - 1
    ok = idx >= 0
    out_e = np.full(len(df), np.nan); out_c = np.full(len(df), np.nan)
    out_e[ok] = e[idx[ok]]; out_c[ok] = g.to_numpy()[idx[ok]]
    return out_e, out_c, idx


@njit(cache=True)
def run(o, h, l, spr, sigL, sigS, sld, rr, be, maxhold, hour, dow, day,
        start_h, end_h, maxday, cool, fri_h, maxspr, slip, trail=0.0):
    n = len(o)
    ent = np.empty(n, np.int64); ext = np.empty(n, np.int64)
    dirs = np.empty(n, np.int64); R = np.empty(n); k = 0
    i = 1; last_ent = -10**9; cur_day = -1; cnt = 0
    while i < n - 1:
        if day[i] != cur_day:
            cur_day = day[i]; cnt = 0
        in_s = (hour[i] >= start_h and hour[i] < end_h) if start_h <= end_h else (hour[i] >= start_h or hour[i] < end_h)
        go = 0
        if in_s and cnt < maxday and i - last_ent >= cool and spr[i] <= maxspr and sld[i] > 0 \
                and not (dow[i] == 5 and hour[i] >= fri_h - 1):
            if sigL[i]: go = 1
            elif sigS[i]: go = -1
        if go == 0:
            i += 1; continue
        d = sld[i]
        if go == 1:
            e = o[i] + spr[i] + slip; sl = e - d; tp = e + d * rr
        else:
            e = o[i] - slip; sl = e + d; tp = e - d * rr
        moved = False; x = 0.0; j = i
        while True:
            if j >= n:
                j = n - 1; x = o[j] if go == 1 else o[j] + spr[j]; break
            if j > i and ((maxhold > 0 and j - i >= maxhold) or (dow[j] == 5 and hour[j] >= fri_h) or day[j] != day[i] and dow[j] == 1):
                x = (o[j] - slip) if go == 1 else (o[j] + spr[j] + slip); break
            if go == 1:
                if l[j] <= sl:
                    x = min(o[j], sl) - slip if j > i else sl - slip; break
                if h[j] >= tp:
                    x = tp; break
                if be > 0 and not moved and h[j] - e >= d * be:
                    sl = e + 0.05; moved = True
                if trail > 0 and h[j] - d * trail > sl:
                    sl = h[j] - d * trail
            else:
                a_h = h[j] + spr[j]; a_l = l[j] + spr[j]
                if a_h >= sl:
                    x = max(o[j] + spr[j], sl) + slip if j > i else sl + slip; break
                if a_l <= tp:
                    x = tp; break
                if be > 0 and not moved and e - a_l >= d * be:
                    sl = e - 0.05; moved = True
                if trail > 0 and a_l + d * trail < sl:
                    sl = a_l + d * trail
            j += 1
        pnl = (x - e) if go == 1 else (e - x)
        ent[k] = i; ext[k] = j; dirs[k] = go; R[k] = pnl / d; k += 1
        cnt += 1; last_ent = i
        i = j + 1 if j > i else i + 1
    return ent[:k], ext[:k], dirs[:k], R[:k]


def stats(R, days, risk=0.2, day_ids=None, day_stop=0.4):
    """R の並びから、固定比率 risk で複利運用したときの成績"""
    R = np.asarray(R)
    if len(R) == 0:
        return {}
    gp = R[R > 0].sum(); gl = -R[R < 0].sum()
    eq = 1.0; peak = 1.0; mdd = 0.0; gpm = 0.0; glm = 0.0; mdd_m = 0.0; peak_m = 1.0
    dstart = 1.0; cur = None; skipped = 0
    for i, r in enumerate(R):
        if day_ids is not None and day_ids[i] != cur:
            cur = day_ids[i]; dstart = eq
        if day_stop and eq < dstart * (1 - day_stop):
            skipped += 1; continue
        p = eq * risk * r
        if p > 0: gpm += p
        else: glm -= p
        eq += p
        if eq <= 0.001:
            eq = 0.0; mdd = 1.0; break
        peak = max(peak, eq); mdd = max(mdd, 1 - eq / peak); mdd_m = max(mdd_m, peak - eq)
    return dict(n=len(R), per_day=len(R) / days, win=(R > 0).mean(), avgR=R.mean(),
                PF_R=gp / gl if gl else np.inf,
                PF=gpm / glm if glm else np.inf, RF=(eq - 1) / mdd_m if mdd_m else np.inf,
                mult=eq, maxDD=mdd)
