// Volatility measures: true range, ATR/NATR (Wilder) and rolling
// dispersion (population stddev / variance).

///|
/// True range per bar; a thin wrapper over `base.true_range` that validates
/// the series first.
pub fn tr_range(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    out.push(@base.true_range(candles, i))
  }
  out
}

///|
/// Number of leading NaN values produced by `atr` for the given period.
pub fn atr_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Average True Range with Wilder smoothing: the seed is the simple mean of
/// the true range over the first `period` changes and lands at index
/// `period`; later values use `atr = (prev * (period - 1) + tr) / period`.
/// NaN inputs poison the seed and propagate forward.
pub fn atr(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  if period <= 0 {
    raise @base.InvalidPeriod("period must be positive, got \{period}")
  }
  let n = candles.close.length()
  if period > n {
    raise @base.NotEnoughData("period \{period} exceeds input length \{n}")
  }
  let out : Array[Double] = []
  if period >= n {
    for _ in 0..<n {
      out.push(@base.nan())
    }
    return out
  }
  for _ in 0..<period {
    out.push(@base.nan())
  }
  let pm = (period - 1).to_double()
  let pd = period.to_double()
  let mut seeded = true
  let mut sum = 0.0
  for i in 1..<(period + 1) {
    let t = @base.true_range(candles, i)
    if @base.is_nan(t) {
      seeded = false
      break
    }
    sum += t
  }
  let mut prev = if seeded { sum / pd } else { @base.nan() }
  out.push(prev)
  for i in (period + 1)..<n {
    let t = @base.true_range(candles, i)
    if @base.is_nan(prev) || @base.is_nan(t) {
      prev = @base.nan()
    } else {
      prev = (prev * pm + t) / pd
    }
    out.push(prev)
  }
  out
}

///|
/// Normalized ATR: `100 * ATR / close`, expressing volatility in percent of
/// the closing price.
pub fn natr(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  let atr_line = atr(candles, period)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let a = atr_line[i]
    let c = candles.close[i]
    if @base.is_nan(a) || @base.is_nan(c) || c == 0.0 {
      out.push(@base.nan())
    } else {
      out.push(100.0 * a / c)
    }
  }
  out
}

///|
/// Population variance of the last `period` values (denominator `period`).
/// A NaN inside the window yields NaN. The caller must guarantee
/// `period <= data.length()`; otherwise the position reads NaN.
fn variance_at(data : Array[Double], i : Int32, period : Int32) -> Double {
  let mut sum = 0.0
  for j in (i - period + 1)..<(i + 1) {
    let v = data[j]
    if @base.is_nan(v) {
      return @base.nan()
    }
    sum += v
  }
  let mean = sum / period.to_double()
  let mut acc = 0.0
  for j in (i - period + 1)..<(i + 1) {
    let d = data[j] - mean
    acc += d * d
  }
  acc / period.to_double()
}

///|
/// Number of leading NaN values produced by `variance` for the given period.
pub fn variance_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Population variance over a rolling window (TA-Lib `VAR` convention,
/// denominator `period`).
pub fn variance(
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
    out.push(variance_at(data, i, period))
  }
  out
}

///|
/// Number of leading NaN values produced by `stddev` for the given period.
pub fn stddev_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Population standard deviation over a rolling window (TA-Lib `STDDEV`
/// convention, denominator `period`).
pub fn stddev(
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
    out.push(variance_at(data, i, period).sqrt())
  }
  out
}
