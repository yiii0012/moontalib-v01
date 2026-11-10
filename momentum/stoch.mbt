// Stochastic oscillator family and Williams %R.

///|
/// Stochastic decomposition: the %K and %D lines, both of input length.
pub struct Stoch {
  k : Array[Double]
  d : Array[Double]
}

///|
/// Raw %K at bar `i`: position of the close within the `period`-bar
/// high/low range, scaled to 0..100. A flat window (highest high equals
/// lowest low) reads 0; a window containing NaN or a NaN close yields NaN.
fn fast_k_at(candles : @base.Candles, i : Int32, period : Int32) -> Double {
  let mut hh = 0.0
  let mut ll = 0.0
  let mut first = true
  let mut valid = true
  for j in (i - period + 1)..<(i + 1) {
    let h = candles.high[j]
    let l = candles.low[j]
    if @base.is_nan(h) || @base.is_nan(l) {
      valid = false
      break
    }
    if first {
      hh = h
      ll = l
      first = false
    } else {
      if h > hh {
        hh = h
      }
      if l < ll {
        ll = l
      }
    }
  }
  if !valid {
    return @base.nan()
  }
  let c = candles.close[i]
  if @base.is_nan(c) {
    return @base.nan()
  }
  let range = hh - ll
  if range == 0.0 {
    return 0.0
  }
  100.0 * (c - ll) / range
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
  let n = candles.close.length()
  let k : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      k.push(@base.nan())
      continue
    }
    k.push(fast_k_at(candles, i, period))
  }
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
  let n = candles.close.length()
  let fast : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      fast.push(@base.nan())
      continue
    }
    fast.push(fast_k_at(candles, i, period))
  }
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
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let k = fast_k_at(candles, i, period)
    if @base.is_nan(k) {
      out.push(@base.nan())
    } else {
      out.push(k - 100.0)
    }
  }
  out
}
