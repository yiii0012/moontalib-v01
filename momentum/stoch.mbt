// Stochastic oscillator family and Williams %R.

///|
/// Stochastic decomposition: the %K and %D lines, both of input length.
pub struct Stoch {
  k : Array[Double]
  d : Array[Double]
}

///|
/// Raw %K series: position of each close within its `period`-bar high/low
/// range, scaled to 0..100. A flat window (highest high equals lowest low)
/// reads 0; a window containing NaN or a NaN close yields NaN. Computed in
/// O(n) via the base rolling extremes.
fn fast_k_series(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  let hh = @base.rolling_max(candles.high, period)
  let ll = @base.rolling_min(candles.low, period)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let c = candles.close[i]
    if i < period - 1 ||
      @base.is_nan(c) ||
      @base.is_nan(hh[i]) ||
      @base.is_nan(ll[i]) {
      out.push(@base.nan())
      continue
    }
    let range = hh[i] - ll[i]
    if range == 0.0 {
      out.push(0.0)
    } else {
      out.push(100.0 * (c - ll[i]) / range)
    }
  }
  out
}

///|
/// Fast stochastic: raw %K plus its SMA over `d_period` (%D). The %D line is
/// valid at index `period + d_period - 2`.
pub fn stochf(
  candles : @base.Candles,
  period : Int32,
  d_period~ : Int32,
) -> Stoch raise @base.TaError {
  @base.validate_candles(candles)
  if period <= 0 || d_period <= 0 {
    raise @base.InvalidPeriod("all periods must be positive")
  }
  let k = fast_k_series(candles, period)
  let d = @overlap.sma(k, d_period)
  { k, d, }
}

///|
/// Number of leading NaN values produced by `stoch`:
/// `(period - 1) + (k_slowing - 1) + (d_period - 1)`.
pub fn stoch_lookback(
  period : Int32,
  k_slowing : Int32,
  d_period : Int32,
) -> Int32 {
  period - 1 + (k_slowing - 1) + (d_period - 1)
}

///|
/// Stochastic Oscillator (TA-Lib `STOCH`): raw %K is smoothed by an SMA over
/// `k_slowing` bars (slow %K), and %D is an SMA of slow %K over `d_period`
/// bars.
pub fn stoch(
  candles : @base.Candles,
  period : Int32,
  k_slowing~ : Int32,
  d_period~ : Int32,
) -> Stoch raise @base.TaError {
  @base.validate_candles(candles)
  if period <= 0 || k_slowing <= 0 || d_period <= 0 {
    raise @base.InvalidPeriod("all periods must be positive")
  }
  let fast = fast_k_series(candles, period)
  let k = @overlap.sma(fast, k_slowing)
  let d = @overlap.sma(k, d_period)
  { k, d, }
}

///|
/// Number of leading NaN values produced by `willr` for the given period.
pub fn willr_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Williams %R: `-100 * (highest_high - close) / (highest_high - lowest_low)`
/// over the window, computed through the identity `%R = %K - 100`. A flat
/// window therefore reads -100, mirroring the raw %K rule (reads 0).
pub fn willr(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  let k = fast_k_series(candles, period)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if @base.is_nan(k[i]) {
      out.push(@base.nan())
    } else {
      out.push(k[i] - 100.0)
    }
  }
  out
}
