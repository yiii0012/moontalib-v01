// Band indicators and volume-weighted averaging.

///|
/// Bollinger Bands: upper / middle / lower arrays of equal length. Produced
/// by `bbands`; fields are readable everywhere but the struct is only
/// constructed inside this package.
pub struct BBands {
  upper : Array[Double]
  middle : Array[Double]
  lower : Array[Double]
}

///|
/// Number of leading NaN values produced by `bbands` for the given period.
pub fn bbands_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Bollinger Bands over `data` with a moving window of `period` values and
/// `ndev` standard deviations (population stddev, TA-Lib convention).
/// A NaN inside a window makes all three outputs NaN at that position.
pub fn bbands(
  data : Array[Double],
  period : Int32,
  ndev~ : Double,
) -> BBands raise @base.TaError {
  @base.validate_series(data, period)
  let s1 = @base.rolling_sum(data, period)
  let sq : Array[Double] = []
  for v in data {
    sq.push(v * v)
  }
  let s2 = @base.rolling_sum(sq, period)
  let pd = period.to_double()
  let n = data.length()
  let upper : Array[Double] = []
  let middle : Array[Double] = []
  let lower : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      upper.push(@base.nan())
      middle.push(@base.nan())
      lower.push(@base.nan())
      continue
    }
    if @base.is_nan(s1[i]) || @base.is_nan(s2[i]) {
      upper.push(@base.nan())
      middle.push(@base.nan())
      lower.push(@base.nan())
      continue
    }
    let mean = s1[i] / pd
    let v = (s2[i] - s1[i] * mean) / pd
    let varr = if v < 0.0 { 0.0 } else { v }
    let dev = ndev * varr.sqrt()
    middle.push(mean)
    upper.push(mean + dev)
    lower.push(mean - dev)
  }
  { upper, middle, lower, }
}

///|
/// Volume-weighted moving average: `sum(price * volume) / sum(volume)` over
/// the window. Windows containing NaN, or whose volume sums to zero, yield
/// NaN.
pub fn vwma(
  price : Array[Double],
  volume : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(price, period)
  if volume.length() != price.length() {
    raise @base.MismatchedLength("price and volume must have equal lengths")
  }
  let pv : Array[Double] = []
  for i in 0..<price.length() {
    pv.push(price[i] * volume[i])
  }
  let spv = @base.rolling_sum(pv, period)
  let sv = @base.rolling_sum(volume, period)
  let n = price.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 ||
      @base.is_nan(spv[i]) ||
      @base.is_nan(sv[i]) ||
      sv[i] == 0.0 {
      out.push(@base.nan())
    } else {
      out.push(spv[i] / sv[i])
    }
  }
  out
}

///|
/// Midprice over a rolling candle window: `(highest_high + lowest_low) / 2`.
/// A NaN inside the window yields NaN.
pub fn midprice(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  let hh = @base.rolling_max(candles.high, period)
  let ll = @base.rolling_min(candles.low, period)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    out.push((hh[i] + ll[i]) / 2.0)
  }
  out
}
