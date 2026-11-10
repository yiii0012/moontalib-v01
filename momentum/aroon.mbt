// Aroon indicator (Tushar Chande): recency of the highest high and lowest
// low within the lookback window.

///|
/// Aroon decomposition: the down and up lines, both of input length.
pub struct AroonResult {
  down : Array[Double]
  up : Array[Double]
}

///|
/// Number of leading NaN values produced by `aroon` for the given period.
pub fn aroon_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Aroon up/down.
///
/// For each bar the window spans the `period` bars before it plus itself
/// (TA-Lib convention, `period + 1` data points). `up` is
/// `100 * (period - bars_since_highest_high) / period` and `down` mirrors it
/// with the lowest low; when several bars share the extreme, the most recent
/// occurrence wins. A window containing NaN yields NaN for that position.
/// Computed in O(n) via the base rolling argmax/argmin.
pub fn aroon(
  candles : @base.Candles,
  period : Int32,
) -> AroonResult raise @base.TaError {
  @base.validate_candles(candles)
  if period <= 0 {
    raise @base.InvalidPeriod("period must be positive, got \{period}")
  }
  let n = candles.close.length()
  if period + 1 > n {
    raise @base.NotEnoughData("period \{period} exceeds input length \{n}")
  }
  let hh_idx = @base.rolling_argmax(candles.high, period + 1)
  let ll_idx = @base.rolling_argmin(candles.low, period + 1)
  let pd = period.to_double()
  let down : Array[Double] = []
  let up : Array[Double] = []
  for i in 0..<n {
    if i < period {
      down.push(@base.nan())
      up.push(@base.nan())
      continue
    }
    let ih = hh_idx[i]
    let il = ll_idx[i]
    if ih == -1 || il == -1 {
      down.push(@base.nan())
      up.push(@base.nan())
      continue
    }
    up.push(100.0 * (period - (i - ih)).to_double() / pd)
    down.push(100.0 * (period - (i - il)).to_double() / pd)
  }
  { down, up, }
}

///|
/// Number of leading NaN values produced by `aroonosc` for the given period.
pub fn aroonosc_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Aroon Oscillator: `up - down`. Ranges from -100 (downtrend) to +100
/// (uptrend) with the same window rules as `aroon`.
pub fn aroonosc(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  let r = aroon(candles, period)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let u = r.up[i]
    let d = r.down[i]
    if @base.is_nan(u) || @base.is_nan(d) {
      out.push(@base.nan())
    } else {
      out.push(u - d)
    }
  }
  out
}
