"""ナンピン・マーチン（バスケット決済）のシミュレーター"""
import numpy as np, pandas as pd
from numba import njit

@njit(cache=True)
def sim(o, h, l, c, spr, atr, sigL, sigS, hour, dow, wk, start_h, end_h,
        step, mult, K, tp, u, hs, slip, wk_target, wk_stop):
    """戻り値：バスケットごとの (開始足, 終了足, 損益%, 使った段数, 週番号)
    u  : 最初の1ロットが ATR 1本分逆行したときの損失（口座の%）
    hs : バスケットの損失がこの%に達したら全決済
    wk_target / wk_stop : 週の累計（%）がこれを超えたらその週は新規なし"""
    n = len(o)
    out = np.empty((n // 4, 5)); k = 0
    i = 1; cur_wk = -1; wk_acc = 0.0
    while i < n - 1:
        if wk[i] != cur_wk:
            cur_wk = wk[i]; wk_acc = 0.0
        in_s = hour[i] >= start_h and hour[i] < end_h and not (dow[i] == 5 and hour[i] >= 20)
        if not in_s or atr[i] <= 0 or wk_acc >= wk_target or wk_acc <= -wk_stop:
            i += 1; continue
        d = 0
        if sigL[i]: d = 1
        elif sigS[i]: d = -1
        if d == 0:
            i += 1; continue
        A = atr[i]; st = step * A
        q = u / A            # 1ロット・価格1単位あたりの損益（%）
        lots = np.zeros(K); ents = np.zeros(K); nl = 1
        lots[0] = 1.0
        ents[0] = (o[i] + spr[i] + slip) if d == 1 else (o[i] - slip)
        res = 0.0; j = i; done = False
        while not done:
            if j >= n - 1:
                break
            # 金曜の遅い時間は持ち越さない
            if j > i and (dow[j] == 5 and hour[j] >= 21 or wk[j] != wk[i]):
                px = (o[j] - slip) if d == 1 else (o[j] + spr[j] + slip)
                s = 0.0
                for m in range(nl): s += lots[m] * (px - ents[m]) * d
                res = s * q; done = True; break
            # 逆行側の値（買いなら安値、売りならASKの高値）
            worst = l[j] if d == 1 else h[j] + spr[j]
            best = h[j] if d == 1 else l[j] + spr[j]
            # ナンピン追加（指値のように step ごと）
            added = False
            while nl < K:
                nxt = ents[nl - 1] - st * d
                if (d == 1 and worst <= nxt - spr[j]) or (d == -1 and worst >= nxt + spr[j]):
                    lots[nl] = lots[nl - 1] * mult
                    ents[nl] = nxt + (spr[j] + slip) * (1 if d == 1 else 0) - slip * (1 if d == -1 else 0)
                    nl += 1; added = True
                else:
                    break
            # 強制損切り（先に判定＝保守的）
            s = 0.0; sl_ = 0.0
            for m in range(nl):
                s += lots[m] * (worst - ents[m]) * d; sl_ += lots[m]
            if s * q <= -hs:
                # 損失がちょうど hs% になる価格で決済＋スリップ
                res = -hs - sl_ * slip * q; done = True; break
            # 利確：平均値から tp*ATR 戻ったら
            avg = 0.0
            for m in range(nl): avg += lots[m] * ents[m]
            avg /= sl_
            tgt = avg + tp * A * d
            # 同じ足でナンピンが入ったら、その足の中の順番が分からないので終値でだけ判定する
            chk = best
            if added or j == i:
                chk = c[j] if d == 1 else c[j] + spr[j]
            if (d == 1 and chk >= tgt) or (d == -1 and chk <= tgt):
                res = sl_ * tp * A * q - sl_ * slip * q; done = True; break
            j += 1
        out[k, 0] = i; out[k, 1] = j; out[k, 2] = res; out[k, 3] = nl; out[k, 4] = wk[i]; k += 1
        wk_acc += res
        i = j + 1
    return out[:k]
