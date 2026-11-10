// Commodity Channel Index and TRIX.

///|
/// Number of leading NaN values produced by `cci` for the given period.
pub fn cci_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Commodity Channel Index (Donald Lambert): the deviation of the typical
/// price `(high + low + close) / 3` from its SMA, normalized by
/// `0.015 * mean absolute deviation`. A flat window (mean deviation 0) reads
/// 0.
pub fn cci(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  if period <= 0 {
    raise @base.InvalidPeriod("period must be positive, got \{period}")
  }
  let n = candles.close.length()
  let tp : Array[Double] = []
  for i in 0..<n {
    let h = candles.high[i]
    let l = candles.low[i]
    let c = candles.close[i]
    if @base.is_nan(h) || @base.is_nan(l) || @base.is_nan(c) {
      tp.push(@base.nan())
    } else {
      tp.push((h + l + c) / 3.0)
    }
  }
  let ma = @overlap.sma(tp, period)
  let out : Array[Double] = []
  for i in 0..<n {
    let m = ma[i]
    if @base.is_nan(m) || @base.is_nan(tp[i]) {
      out.push(@base.nan())
      continue
    }
    let mut dev = 0.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      if @base.is_nan(tp[j]) {
        valid = false
        break
      }
      dev += (tp[j] - m).abs()
    }
    if !valid {
      out.push(@base.nan())
      continue
    }
    let mean_dev = dev / period.to_double()
    if mean_dev == 0.0 {
      out.push(0.0)
    } else {
      out.push((tp[i] - m) / (0.015 * mean_dev))
    }
  }
  out
}

///|
/// Number of leading NaN values produced by `trix` for the given period:
/// `3 * (period - 1) + 1`.
pub fn trix_lookback(period : Int32) -> Int32 {
  3 * (period - 1) + 1
}

///|
/// TRIX: the percent rate of change of a triple-EMA,
/// `100 * (e3[i] - e3[i - 1]) / e3[i - 1]`.
pub fn trix(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let e1 = @overlap.ema_from(data, period, 0)
  let e2 = @overlap.ema_from(e1, period, period - 1)
  let e3 = @overlap.ema_from(e2, period, 2 * (period - 1))
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i == 0 {
      out.push(@base.nan())
      continue
    }
    let cur = e3[i]
    let prev = e3[i - 1]
    if @base.is_nan(cur) || @base.is_nan(prev) || prev == 0.0 {
      out.push(@base.nan())
    } else {
      out.push(100.0 * (cur - prev) / prev)
    }
  }
  out
}
