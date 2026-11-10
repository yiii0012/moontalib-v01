// Moving averages: SMA, EMA, WMA, HMA, DEMA, TEMA and the shared
// `moving_average` dispatcher used by APO/PPO.

///|
/// Number of leading NaN values produced by `sma` for the given period.
pub fn sma_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Simple moving average.
///
/// Output has the same length as `data`; positions before the first full
/// window are NaN, and a NaN anywhere inside a window makes that position
/// NaN.
pub fn sma(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  let pd = period.to_double()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let mut sum = 0.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let v = data[j]
      if @base.is_nan(v) {
        valid = false
        break
      }
      sum += v
    }
    if valid {
      out.push(sum / pd)
    } else {
      out.push(@base.nan())
    }
  }
  out
}

///|
/// Exponential moving average over a series that only becomes valid at index
/// `first_valid` (positions before it are leading NaN padding, as produced by
/// chained indicators).
///
/// The seed is the SMA of the first `period` valid values (TA-Lib
/// convention); any NaN inside the seed window poisons the whole chain, and a
/// NaN input later on propagates forward. This is the primitive that `ema`,
/// `dema`, `tema`, `trix` and `macd` are built on.
pub fn ema_from(
  data : Array[Double],
  period : Int32,
  first_valid : Int32,
) -> Array[Double] {
  let n = data.length()
  let out : Array[Double] = []
  let fv = if first_valid < 0 { 0 } else { first_valid }
  let warm = fv + period - 1
  if warm >= n {
    for _ in 0..<n {
      out.push(@base.nan())
    }
    return out
  }
  for _ in 0..<warm {
    out.push(@base.nan())
  }
  let mut seed_ok = true
  let mut seed_sum = 0.0
  for i in fv..<(fv + period) {
    let v = data[i]
    if @base.is_nan(v) {
      seed_ok = false
      break
    }
    seed_sum += v
  }
  let k = 2.0 / (period.to_double() + 1.0)
  let mut prev = if seed_ok {
    seed_sum / period.to_double()
  } else {
    @base.nan()
  }
  out.push(prev)
  for i in (warm + 1)..<n {
    if @base.is_nan(prev) || @base.is_nan(data[i]) {
      prev = @base.nan()
    } else {
      prev = k * data[i] + (1.0 - k) * prev
    }
    out.push(prev)
  }
  out
}

///|
/// Number of leading NaN values produced by `ema` for the given period.
pub fn ema_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Exponential moving average with smoothing factor `2 / (period + 1)`,
/// seeded by the SMA of the first `period` values (TA-Lib convention).
pub fn ema(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  ema_from(data, period, 0)
}

///|
/// Number of leading NaN values produced by `wma` for the given period.
pub fn wma_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Linearly weighted moving average: the newest bar of the window gets
/// weight `period`, the oldest gets weight 1.
pub fn wma(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  let denom = (period * (period + 1) / 2).to_double()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let mut acc = 0.0
    let mut w = 1.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let v = data[j]
      if @base.is_nan(v) {
        valid = false
        break
      }
      acc += v * w
      w += 1.0
    }
    if valid {
      out.push(acc / denom)
    } else {
      out.push(@base.nan())
    }
  }
  out
}

///|
/// Number of leading NaN values produced by `hma` for the given period.
pub fn hma_lookback(period : Int32) -> Int32 {
  period + @base.isqrt(period) - 2
}

///|
/// Hull moving average: `WMA(2 * WMA(n/2) - WMA(n), sqrt(n))`, smoothing the
/// lag of the weighted average against the price series.
pub fn hma(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let half = if period / 2 < 1 { 1 } else { period / 2 }
  let sq = @base.isqrt(period)
  let w1 = wma(data, half)
  let w2 = wma(data, period)
  let n = data.length()
  let diff : Array[Double] = []
  for i in 0..<n {
    let a = w1[i]
    let b = w2[i]
    if @base.is_nan(a) || @base.is_nan(b) {
      diff.push(@base.nan())
    } else {
      diff.push(2.0 * a - b)
    }
  }
  // `diff` becomes valid at index `period - 1`; its NaN prefix is handled by
  // the window scan inside `wma`.
  wma(diff, sq)
}

///|
/// Number of leading NaN values produced by `dema` for the given period.
pub fn dema_lookback(period : Int32) -> Int32 {
  2 * (period - 1)
}

///|
/// Double exponential moving average: `2 * EMA - EMA(EMA)`.
pub fn dema(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let e1 = ema_from(data, period, 0)
  let e2 = ema_from(e1, period, period - 1)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let a = e1[i]
    let b = e2[i]
    if @base.is_nan(a) || @base.is_nan(b) {
      out.push(@base.nan())
    } else {
      out.push(2.0 * a - b)
    }
  }
  out
}

///|
/// Number of leading NaN values produced by `tema` for the given period.
pub fn tema_lookback(period : Int32) -> Int32 {
  3 * (period - 1)
}

///|
/// Triple exponential moving average:
/// `3 * EMA - 3 * EMA(EMA) + EMA(EMA(EMA))`.
pub fn tema(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let e1 = ema_from(data, period, 0)
  let e2 = ema_from(e1, period, period - 1)
  let e3 = ema_from(e2, period, 2 * (period - 1))
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let a = e1[i]
    let b = e2[i]
    let c = e3[i]
    if @base.is_nan(a) || @base.is_nan(b) || @base.is_nan(c) {
      out.push(@base.nan())
    } else {
      out.push(3.0 * a - 3.0 * b + c)
    }
  }
  out
}

///|
/// Moving average with a selectable flavor; the dispatch point shared by
/// APO/PPO.
pub fn moving_average(
  data : Array[Double],
  period : Int32,
  ma_type~ : @base.MAType,
) -> Array[Double] raise @base.TaError {
  match ma_type {
    @base.Sma => sma(data, period)
    @base.Ema => ema(data, period)
  }
}

///|
/// Number of leading NaN values produced by `midpoint` for the given period.
pub fn midpoint_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Midpoint over a rolling window: `(max + min) / 2` of the last `period`
/// values. A NaN inside the window yields NaN.
pub fn midpoint(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let mut best_max = 0.0
    let mut best_min = 0.0
    let mut first = true
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let v = data[j]
      if @base.is_nan(v) {
        valid = false
        break
      }
      if first {
        best_max = v
        best_min = v
        first = false
      } else {
        if v > best_max {
          best_max = v
        }
        if v < best_min {
          best_min = v
        }
      }
    }
    if valid {
      out.push((best_max + best_min) / 2.0)
    } else {
      out.push(@base.nan())
    }
  }
  out
}
