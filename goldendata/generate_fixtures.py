# Independent cross-verification fixture generator for moontalib.
#
# Builds the deterministic 300-bar zig-zag OHLCV series (identical to the
# series used by moontalib_test.mbt / zigzag_candles) and computes reference
# values for the whole indicator catalog with numpy/pandas following the
# documented TA-Lib conventions:
#   - EMA seeded with the SMA of its first `period` values (TA-Lib)
#   - Wilder smoothing (RSI/ATR) seeded with the simple mean
#   - population stddev/variance (denominator period)
#   - ties for rolling extremes resolve to the most recent bar
#   - flat windows: stoch reads 0, willr reads -100, cci reads 0
#
# Outputs:
#   - goldendata/fixtures.json  (name -> array, NaN as null)
#   - stdout checksum report
#
# Usage:  python generate_fixtures.py
# Refs:   TA-Lib https://github.com/TA-Lib/ta-lib (BSD), pandas-ta
#         https://github.com/twopirllc/pandas-ta (MIT) used for spot checks.

import json
import math

import numpy as np
import pandas as pd

N = 300


def zigzag_closes(n):
    return np.array(
        [100.0 + (i % 13) * 2.0 - (i % 7) * 1.5 for i in range(n)], dtype=float
    )


def zigzag_candles(n):
    c = zigzag_closes(n)
    prev = np.concatenate(([c[0]], c[:-1]))
    o = prev.copy()
    h = np.maximum(c, prev) + 1.0
    l = np.minimum(c, prev) - 1.0
    v = 10.0 + np.arange(n, dtype=float)
    return o, h, l, c, v


def is_nan(x):
    return isinstance(x, float) and math.isnan(x)


def prefix_nan(arr, count):
    out = np.array(arr, dtype=float)
    out[:count] = np.nan
    return out


def rolling_sum_nan_last(arr, p):
    # sum over the window; a NaN inside the window poisons the whole window
    out = np.full(len(arr), np.nan)
    for i in range(p - 1, len(arr)):
        w = arr[i - p + 1 : i + 1]
        if any(is_nan(x) for x in w):
            continue
        out[i] = w.sum()
    return out


def ema_sma_seeded(y, p, start=0):
    # EMA seeded with the SMA of its first `period` values beginning at
    # `start` (TA-Lib convention); NaN before start + p - 1.
    out = np.full(len(y), np.nan)
    if start + p > len(y):
        return out
    out[start + p - 1] = y[start : start + p].mean()
    k = 2.0 / (p + 1)
    for i in range(start + p, len(y)):
        if not is_nan(out[i - 1]) and not is_nan(y[i]):
            out[i] = k * y[i] + (1 - k) * out[i - 1]
        else:
            out[i] = np.nan
    return out


def wilder_rsi(c, p):
    # Wilder RSI: SMA-seeded average gain/loss over the first p changes,
    # then avg = (prev * (p - 1) + cur) / p.
    out = np.full(len(c), np.nan)
    d = np.diff(c)
    g = np.where(d > 0, d, 0.0)
    lo = np.where(d < 0, -d, 0.0)
    if len(c) <= p:
        return out
    ag = g[:p].mean()
    al = lo[:p].mean()
    out[p] = 100.0 - 100.0 / (1.0 + ag / al) if al != 0 else 100.0
    pm = (p - 1) / p
    for i in range(p + 1, len(c)):
        cur = d[i - 1]
        if cur > 0:
            ag = (ag * (p - 1) + cur) / p
            al = al * pm
        else:
            ag = ag * pm
            al = (al * (p - 1) - cur) / p
        out[i] = 100.0 - 100.0 / (1.0 + ag / al) if al != 0 else 100.0
    return out


def wilder_ema_sum(arr, p, start):
    # Wilder smoothing s = (s * (p - 1) + cur) / p seeded with the mean of
    # arr[start : start + p]; NaN before start + p.
    out = np.full(len(arr), np.nan)
    if start + p > len(arr):
        return out
    s = arr[start : start + p].mean()
    out[start + p - 1] = s
    for i in range(start + p, len(arr)):
        if not is_nan(s) and not is_nan(arr[i]):
            s = (s * (p - 1) + arr[i]) / p
        else:
            s = np.nan
        out[i] = s
    return out


def rolling_argextreme(arr, p, want_max):
    # 0-based index of the most recent extreme inside each window, -1 when
    # the window contains NaN (moontalib convention).
    out = np.full(len(arr), -1, dtype=int)
    for i in range(p - 1, len(arr)):
        w = arr[i - p + 1 : i + 1]
        if any(is_nan(x) for x in w):
            continue
        seg = w[::-1]
        j = int(np.argmax(seg)) if want_max else int(np.argmin(seg))
        out[i] = i - j
    return out


def wma_vals(y, p):
    weights = np.arange(1, p + 1, dtype=float)
    return (
        y.rolling(p, min_periods=p)
        .apply(lambda w: (w * weights).sum() / weights.sum(), raw=True)
        .to_numpy()
    )


def main():
    o, h, l, c, v = zigzag_candles(N)
    fx = {}
    P = 20

    # ---- overlap ----
    fx["sma20"] = pd.Series(c).rolling(P, min_periods=P).mean().to_numpy()
    fx["ema20"] = ema_sma_seeded(c, P)
    fx["wma20"] = wma_vals(pd.Series(c), P)
    half = P // 2
    isq = int(math.isqrt(P))
    wh = wma_vals(pd.Series(c), half)
    wP = wma_vals(pd.Series(c), P)
    diff = 2.0 * wh - wP
    fx["hma20"] = wma_vals(pd.Series(diff), isq)
    e1 = ema_sma_seeded(c, P)
    e2 = ema_sma_seeded(e1, P, start=P - 1)
    fx["dema20"] = 2.0 * e1 - e2
    e3 = ema_sma_seeded(e2, P, start=2 * (P - 1))
    fx["tema20"] = 3.0 * e1 - 3.0 * e2 + e3
    mid = pd.Series(c).rolling(P, min_periods=P).mean()
    sd = pd.Series(c).rolling(P, min_periods=P).std(ddof=0)
    fx["bbands_mid"] = mid.to_numpy()
    fx["bbands_up"] = (mid + 2.0 * sd).to_numpy()
    fx["bbands_lo"] = (mid - 2.0 * sd).to_numpy()
    fx["vwma20"] = (
        (pd.Series(c) * pd.Series(v)).rolling(P, min_periods=P).sum()
        / pd.Series(v).rolling(P, min_periods=P).sum()
    ).to_numpy()
    fx["midpoint20"] = (
        (
            pd.Series(c).rolling(P, min_periods=P).max()
            + pd.Series(c).rolling(P, min_periods=P).min()
        )
        / 2.0
    ).to_numpy()
    fx["midprice20"] = (
        (
            pd.Series(h).rolling(P, min_periods=P).max()
            + pd.Series(l).rolling(P, min_periods=P).min()
        )
        / 2.0
    ).to_numpy()

    # ---- momentum ----
    fx["rsi14"] = wilder_rsi(c, 14)
    e12 = ema_sma_seeded(c, 12)
    e26 = ema_sma_seeded(c, 26)
    line = np.full(N, np.nan)
    for i in range(25, N):
        if not is_nan(e12[i]) and not is_nan(e26[i]):
            line[i] = e12[i] - e26[i]
    sig = ema_sma_seeded(line, 9, start=25)
    fx["macd"] = line
    fx["macd_signal"] = sig
    fx["macd_hist"] = line - sig
    d10 = np.full(N, np.nan)
    d10[10:] = c[10:] - c[:-10]
    fx["roc10"] = np.where(
        np.isnan(np.concatenate(([np.nan] * 10, c[:-10]))), np.nan, 100.0 * d10[10:] / c[:-10]
    ) if False else np.concatenate(
        [np.full(10, np.nan), 100.0 * (c[10:] - c[:-10]) / c[:-10]]
    )
    fx["mom10"] = np.concatenate([np.full(10, np.nan), c[10:] - c[:-10]])
    up = np.concatenate([[np.nan], np.where(np.diff(c) > 0, np.diff(c), 0.0)])
    dn = np.concatenate([[np.nan], np.where(np.diff(c) < 0, -np.diff(c), 0.0)])
    us = pd.Series(up).rolling(14, min_periods=14).sum().to_numpy()
    ds = pd.Series(dn).rolling(14, min_periods=14).sum().to_numpy()
    fx["cmo14"] = np.where(us + ds == 0, 0.0, 100.0 * (us - ds) / (us + ds))
    e1t = ema_sma_seeded(c, 10)
    e2t = ema_sma_seeded(e1t, 10, start=9)
    e3t = ema_sma_seeded(e2t, 10, start=18)
    trix = np.full(N, np.nan)
    for i in range(28, N):
        if not is_nan(e3t[i]) and not is_nan(e3t[i - 1]) and e3t[i - 1] != 0:
            trix[i] = 100.0 * (e3t[i] - e3t[i - 1]) / e3t[i - 1]
    fx["trix10"] = trix
    hh14 = pd.Series(h).rolling(14, min_periods=14).max().to_numpy()
    ll14 = pd.Series(l).rolling(14, min_periods=14).min().to_numpy()
    fx["willr14"] = np.where(
        hh14 - ll14 == 0,
        -100.0,
        100.0 * (c - hh14) / (hh14 - ll14),
    )
    fx["stochk"] = np.where(
        hh14 - ll14 == 0, 0.0, 100.0 * (c - ll14) / np.where(hh14 - ll14 == 0, 1.0, hh14 - ll14)
    )
    sk = pd.Series(fx["stochk"]).rolling(3, min_periods=3).mean().to_numpy()
    fx["stochf_d"] = sk
    fx["stochd3"] = pd.Series(sk).rolling(3, min_periods=3).mean().to_numpy()
    tp = (pd.Series(h) + pd.Series(l) + pd.Series(c)) / 3.0
    tpm = tp.rolling(14, min_periods=14).mean().to_numpy()
    mad = (
        tp.rolling(14, min_periods=14)
        .apply(lambda w: np.abs(w - w.mean()).mean(), raw=True)
        .to_numpy()
    )
    fx["cci14"] = np.where(
        mad == 0, 0.0, (tp.to_numpy() - tpm) / (0.015 * mad)
    )
    # Aroon window spans period+1 data points (current bar plus the
    # preceding period bars), matching the moontalib documented semantics.
    amx = rolling_argextreme(h, 14 + 1, True)
    amn = rolling_argextreme(l, 14 + 1, False)
    aroon_u = np.full(N, np.nan)
    aroon_d = np.full(N, np.nan)
    for i in range(14, N):
        if amx[i] == -1 or amn[i] == -1:
            continue
        aroon_u[i] = 100.0 * (14 - (i - amx[i])) / 14.0
        aroon_d[i] = 100.0 * (14 - (i - amn[i])) / 14.0
    fx["aroon_up14"] = aroon_u
    fx["aroon_down14"] = aroon_d
    fx["aroonosc14"] = np.where(
        np.isnan(aroon_u) | np.isnan(aroon_d), np.nan, aroon_u - aroon_d
    )
    rng = (pd.Series(h) - pd.Series(l)).to_numpy()
    fx["bop"] = np.where(
        rng == 0,
        0.0,
        (pd.Series(c).to_numpy() - pd.Series(o).to_numpy()) / np.where(rng == 0, 1.0, rng),
    )
    apo = np.full(N, np.nan)
    e5 = ema_sma_seeded(c, 5)
    e20 = ema_sma_seeded(c, 20)
    for i in range(19, N):
        if not is_nan(e5[i]) and not is_nan(e20[i]):
            apo[i] = e5[i] - e20[i]
    fx["apo"] = apo
    ppo = np.full(N, np.nan)
    for i in range(19, N):
        if not is_nan(e5[i]) and not is_nan(e20[i]) and e20[i] != 0:
            ppo[i] = 100.0 * (e5[i] - e20[i]) / e20[i]
    fx["ppo"] = ppo
    uo = np.full(N, np.nan)
    bp = np.full(N, np.nan)
    trr = np.full(N, np.nan)
    pc = np.concatenate(([c[0]], c[:-1]))
    for i in range(1, N):
        mi = min(l[i], pc[i])
        ma = max(h[i], pc[i])
        if is_nan(mi) or is_nan(ma):
            continue
        bp[i] = c[i] - mi
        trr[i] = ma - mi
    for i in range(28, N):
        s7b = s7t = s14b = s14t = s28b = s28t = 0.0
        ok = True
        for arr_p, acc in ((7, "a"), (14, "b"), (28, "c")):
            pass
        def wsum(p):
            sb = st = 0.0
            for j in range(i - p + 1, i + 1):
                if is_nan(bp[j]) or is_nan(trr[j]):
                    return 0.0, 0.0, False
                sb += bp[j]
                st += trr[j]
            return sb, st, True
        b7, t7, k1 = wsum(7)
        b14, t14, k2 = wsum(14)
        b28, t28, k3 = wsum(28)
        if not (k1 and k2 and k3) or t7 == 0 or t14 == 0 or t28 == 0:
            continue
        uo[i] = 100.0 * (4.0 * b7 / t7 + 2.0 * b14 / t14 + b28 / t28) / 7.0
    fx["ultosc"] = uo
    fx["dx14"] = np.where(
        (pd.Series(hh14) + pd.Series(ll14)) == 0,
        0.0,
        100.0
        * (0.0).abs().where(lambda x: True).to_numpy(),
    ) if False else np.full(N, np.nan)
    # dx reference: Wilder DI lines then DX
    pdm = np.full(N, np.nan)
    pdn = np.full(N, np.nan)
    for i in range(1, N):
        upm = h[i] - h[i - 1]
        dnm = l[i - 1] - l[i]
        if is_nan(upm) or is_nan(dnm):
            pdm[i] = np.nan
            pdn[i] = np.nan
        else:
            pdm[i] = upm if (upm > dnm and upm > 0) else 0.0
            pdn[i] = dnm if (dnm > upm and dnm > 0) else 0.0
    tr_i = np.full(N, np.nan)
    tr_i[0] = h[0] - l[0]
    for i in range(1, N):
        tr_i[i] = max(h[i] - l[i], abs(h[i] - pc[i]), abs(l[i] - pc[i]))
    s_tr = wilder_ema_sum(tr_i, 14, 1)
    s_p = wilder_ema_sum(pdm, 14, 1)
    s_n = wilder_ema_sum(pdn, 14, 1)
    plus_di = np.where(s_tr == 0, 0.0, 100.0 * s_p / np.where(s_tr == 0, 1, s_tr))
    minus_di = np.where(s_tr == 0, 0.0, 100.0 * s_n / np.where(s_tr == 0, 1, s_tr))
    dx14 = np.full(N, np.nan)
    for i in range(14, N):
        tot = plus_di[i] + minus_di[i]
        if is_nan(tot) or tot == 0:
            dx14[i] = 0.0 if not (is_nan(plus_di[i]) or is_nan(minus_di[i])) else np.nan
        else:
            dx14[i] = 100.0 * abs(plus_di[i] - minus_di[i]) / tot
    fx["dx14"] = dx14

    # ---- volume ----
    sign = np.sign(np.diff(c))
    obv = np.concatenate(([v[0]], v[1:] * np.nan_to_num(sign) + 0.0))
    obv = np.cumsum(np.concatenate(([v[0]], np.where(sign > 0, v[1:], np.where(sign < 0, -v[1:], 0.0)))))
    fx["obv"] = obv
    tpv = tp.to_numpy() * v
    posf = np.where(np.diff(tp) > 0, tpv[1:], 0.0)
    negf = np.where(np.diff(tp) < 0, tpv[1:], 0.0)
    posf = np.concatenate(([np.nan], posf))
    negf = np.concatenate(([np.nan], negf))
    pos_s = pd.Series(posf).rolling(14, min_periods=14).sum().to_numpy()
    neg_s = pd.Series(negf).rolling(14, min_periods=14).sum().to_numpy()
    mfi = np.full(N, np.nan)
    for i in range(14, N):
        if is_nan(pos_s[i]) or is_nan(neg_s[i]):
            continue
        mfi[i] = 100.0 - 100.0 / (1.0 + pos_s[i] / neg_s[i]) if neg_s[i] != 0 else 100.0
    fx["mfi14"] = mfi
    clv = np.full(N, np.nan)
    for i in range(N):
        rng = h[i] - l[i]
        if rng == 0:
            clv[i] = 0.0
        else:
            clv[i] = ((c[i] - l[i]) - (h[i] - c[i])) / rng
    ad_line = np.cumsum(np.concatenate(([clv[0] * v[0]], clv[1:] * v[1:])))
    fx["ad"] = ad_line
    ad_ema5 = ema_sma_seeded(ad_line, 5)
    ad_ema20 = ema_sma_seeded(ad_line, 20)
    adosc = np.full(N, np.nan)
    for i in range(19, N):
        if not is_nan(ad_ema5[i]) and not is_nan(ad_ema20[i]):
            adosc[i] = ad_ema5[i] - ad_ema20[i]
    fx["adosc"] = adosc

    # ---- volatility ----
    trng = np.full(N, np.nan)
    trng[0] = h[0] - l[0]
    for i in range(1, N):
        trng[i] = max(h[i] - l[i], abs(h[i] - pc[i]), abs(l[i] - pc[i]))
    fx["trange"] = trng
    atr = np.full(N, np.nan)
    if N > 14:
        atr[14] = trng[1:15].mean()
        for i in range(15, N):
            atr[i] = (atr[i - 1] * 13.0 + trng[i]) / 14.0
    fx["atr14"] = atr
    fx["natr14"] = np.where(c == 0, np.nan, 100.0 * atr / c)

    # ---- statistic ----
    fx["max20"] = pd.Series(h if False else c).rolling(P, min_periods=P).max().to_numpy()
    fx["min20"] = pd.Series(c).rolling(P, min_periods=P).min().to_numpy()
    fx["sum20"] = pd.Series(c).rolling(P, min_periods=P).sum().to_numpy()
    fx["var20"] = pd.Series(c).rolling(P, min_periods=P).var(ddof=0).to_numpy()
    fx["stdev20"] = pd.Series(c).rolling(P, min_periods=P).std(ddof=0).to_numpy()
    mx = rolling_argextreme(c, P, True)
    mn = rolling_argextreme(c, P, False)
    fx["minmaxindex_max"] = mx.astype(float)
    fx["minmaxindex_min"] = mn.astype(float)
    # linear regression family (offset 0..P-1, least squares)
    xs = np.arange(P, dtype=float)
    x_bar = xs.mean()
    dxa = xs - x_bar
    den = (dxa * dxa).sum()
    lr_s = np.full(N, np.nan)
    lr_i = np.full(N, np.nan)
    lr_e = np.full(N, np.nan)
    lr_a = np.full(N, np.nan)
    lr_t = np.full(N, np.nan)
    for i in range(P - 1, N):
        y = c[i - P + 1 : i + 1]
        y_bar = y.mean()
        slope = (dxa * (y - y_bar)).sum() / den
        intercept = y_bar - slope * x_bar
        lr_s[i] = slope
        lr_i[i] = intercept
        lr_e[i] = intercept + slope * (P - 1)
        lr_a[i] = math.atan(slope) * 180.0 / math.pi
        lr_t[i] = intercept + slope * P
    fx["linearreg_slope20"] = lr_s
    fx["linearreg_intercept20"] = lr_i
    fx["linearreg20"] = lr_e
    fx["linearreg_angle20"] = lr_a
    fx["tsf20"] = lr_t
    fx["correl20"] = (
        pd.Series(c)
        .rolling(P, min_periods=P)
        .corr(pd.Series(h))
        .to_numpy()
    )
    fx["avgdev20"] = (
        pd.Series(c)
        .rolling(P, min_periods=P)
        .apply(lambda w: np.abs(w - w.mean()).mean(), raw=True)
        .to_numpy()
    )

    # checksum report
    print("checksum report (pandas reference):")
    for k in sorted(fx):
        arr = np.asarray(fx[k], dtype=float)
        valid = arr[~np.isnan(arr)]
        print(f"  {k}: n={len(valid)} checksum={valid.sum():.6f}")

    for k in list(fx):
        arr = np.asarray(fx[k], dtype=float)
        assert arr.ndim == 1, k
        fx[k] = arr.tolist()
    with open("goldendata/fixtures.json", "w") as f:
        json.dump(fx, f)
    print("wrote goldendata/fixtures.json with", len(fx), "fixtures")


if __name__ == "__main__":
    main()
