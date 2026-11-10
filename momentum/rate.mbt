// Rate-of-change family: ROC, MOM, CMO, APO and PPO.

///|
/// Number of leading NaN values produced by `roc` for the given period.
pub fn roc_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Rate of change in percent: `100 * (x[i] - x[i - period]) / x[i - period]`.
/// A zero base value yields NaN.
pub fn roc(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period {
      out.push(@base.nan())
      continue
    }
    let prev = data[i - period]
    let cur = data[i]
    if @base.is_nan(prev) || @base.is_nan(cur) || prev == 0.0 {
      out.push(@base.nan())
    } else {
      out.push(100.0 * (cur - prev) / prev)
    }
  }
  out
}

///|
/// Number of leading NaN values produced by `mom` for the given period.
pub fn mom_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Momentum: `x[i] - x[i - period]`. NaN inputs yield NaN.
pub fn mom(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period {
      out.push(@base.nan())
      continue
    }
    let prev = data[i - period]
    let cur = data[i]
    if @base.is_nan(prev) || @base.is_nan(cur) {
      out.push(@base.nan())
    } else {
      out.push(cur - prev)
    }
  }
  out
}

///|
/// Number of leading NaN values produced by `cmo` for the given period.
pub fn cmo_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Chande Momentum Oscillator:
/// `100 * (sum_up - sum_down) / (sum_up + sum_down)` over the last `period`
/// price changes. A completely flat window reads 0.
pub fn cmo(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  // Price changes computed once per bar; each window then only sums.
  let diffs : Array[Double] = []
  for j in 0..<n {
    if j == 0 {
      diffs.push(@base.nan())
      continue
    }
    diffs.push(data[j] - data[j - 1])
  }
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period {
      out.push(@base.nan())
      continue
    }
    let mut up = 0.0
    let mut down = 0.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let d = diffs[j]
      if @base.is_nan(d) {
        valid = false
        break
      }
      if d > 0.0 {
        up += d
      } else {
        down -= d
      }
    }
    if !valid {
      out.push(@base.nan())
      continue
    }
    let total = up + down
    if total == 0.0 {
      out.push(0.0)
    } else {
      out.push(100.0 * (up - down) / total)
    }
  }
  out
}

///|
/// Absolute Price Oscillator: `fast_MA - slow_MA` with a selectable MA flavor.
pub fn apo(
  data : Array[Double],
  fast_period : Int32,
  slow_period : Int32,
  ma_type~ : @base.MAType,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, slow_period)
  if fast_period <= 0 || slow_period <= 0 {
    raise @base.InvalidPeriod("all periods must be positive")
  }
  if fast_period >= slow_period {
    raise @base.InvalidPeriod("fast_period must be smaller than slow_period")
  }
  let fast_ma = @overlap.moving_average(data, fast_period, ma_type~)
  let slow_ma = @overlap.moving_average(data, slow_period, ma_type~)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let f = fast_ma[i]
    let s = slow_ma[i]
    if @base.is_nan(f) || @base.is_nan(s) {
      out.push(@base.nan())
    } else {
      out.push(f - s)
    }
  }
  out
}

///|
/// Percentage Price Oscillator: `100 * (fast_MA - slow_MA) / slow_MA`.
/// A zero slow MA yields NaN.
pub fn ppo(
  data : Array[Double],
  fast_period : Int32,
  slow_period : Int32,
  ma_type~ : @base.MAType,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, slow_period)
  if fast_period <= 0 || slow_period <= 0 {
    raise @base.InvalidPeriod("all periods must be positive")
  }
  if fast_period >= slow_period {
    raise @base.InvalidPeriod("fast_period must be smaller than slow_period")
  }
  let fast_ma = @overlap.moving_average(data, fast_period, ma_type~)
  let slow_ma = @overlap.moving_average(data, slow_period, ma_type~)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let f = fast_ma[i]
    let s = slow_ma[i]
    if @base.is_nan(f) || @base.is_nan(s) || s == 0.0 {
      out.push(@base.nan())
    } else {
      out.push(100.0 * (f - s) / s)
    }
  }
  out
}

///|
/// Balance of Power (Igor Livshin): `(close - open) / (high - low)`.
/// A flat bar (high equals low) reads 0; any NaN component yields NaN.
pub fn bop(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let o = candles.open[i]
    let h = candles.high[i]
    let l = candles.low[i]
    let c = candles.close[i]
    if @base.is_nan(o) || @base.is_nan(h) || @base.is_nan(l) || @base.is_nan(c) {
      out.push(@base.nan())
    } else {
      let range = h - l
      if range == 0.0 {
        out.push(0.0)
      } else {
        out.push((c - o) / range)
      }
    }
  }
  out
}
