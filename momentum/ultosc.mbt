// Ultimate Oscillator (Larry Williams): a weighted blend of buying-pressure
// ratios over three periods.
//
// fmin / fmax assume non-NaN inputs; ultosc filters NaN before use.

///|
fn fmin(a : Double, b : Double) -> Double {
  if a < b {
    a
  } else {
    b
  }
}

///|
fn fmax(a : Double, b : Double) -> Double {
  if a > b {
    a
  } else {
    b
  }
}

///|
/// Number of leading NaN values produced by `ultosc`: the longest period
/// `p3` (each output needs `p3` buying-pressure / true-range values).
pub fn ultosc_lookback(p3 : Int32) -> Int32 {
  p3
}

///|
/// Ultimate Oscillator.
///
/// Buying pressure is `close - min(low, prev_close)` and true range is
/// `max(high, prev_close) - min(low, prev_close)`. For each of the three
/// periods the ratio `sum(BP) / sum(TR)` is taken, then blended as
/// `100 * (4 * avg1 + 2 * avg2 + avg3) / 7` with `avg1 <= avg2 <= avg3` the
/// short / mid / long ratios. A window whose true-range sum is zero, or that
/// contains NaN, yields NaN. The periods must satisfy `p1 <= p2 <= p3`.
pub fn ultosc(
  candles : @base.Candles,
  p1~ : Int32,
  p2~ : Int32,
  p3~ : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  if p1 <= 0 || p2 <= 0 || p3 <= 0 {
    raise @base.InvalidPeriod("all periods must be positive")
  }
  if p1 > p2 || p2 > p3 {
    raise @base.InvalidPeriod("periods must satisfy p1 <= p2 <= p3")
  }
  let n = candles.close.length()
  // Buying pressure and true range per bar; index 0 has no previous close
  // and is never read (outputs start at `p3`).
  let bp : Array[Double] = []
  let tr : Array[Double] = []
  bp.push(@base.nan())
  tr.push(@base.nan())
  for i in 1..<n {
    let prev_close = candles.close[i - 1]
    let high = candles.high[i]
    let low = candles.low[i]
    let close = candles.close[i]
    let bad = @base.is_nan(prev_close) ||
      @base.is_nan(high) ||
      @base.is_nan(low) ||
      @base.is_nan(close)
    if bad {
      bp.push(@base.nan())
      tr.push(@base.nan())
    } else {
      bp.push(close - fmin(low, prev_close))
      tr.push(fmax(high, prev_close) - fmin(low, prev_close))
    }
  }
  // O(n): the six per-period BP/TR window sums come from the base
  // rolling_sum; NaN windows yield NaN sums and NaN outputs below.
  let sbp1 = @base.rolling_sum(bp, p1)
  let str1 = @base.rolling_sum(tr, p1)
  let sbp2 = @base.rolling_sum(bp, p2)
  let str2 = @base.rolling_sum(tr, p2)
  let sbp3 = @base.rolling_sum(bp, p3)
  let str3 = @base.rolling_sum(tr, p3)
  let out : Array[Double] = []
  for i in 0..<n {
    if i < p3 {
      out.push(@base.nan())
      continue
    }
    if @base.is_nan(sbp1[i]) || @base.is_nan(sbp2[i]) || @base.is_nan(sbp3[i]) {
      out.push(@base.nan())
      continue
    }
    if str1[i] == 0.0 || str2[i] == 0.0 || str3[i] == 0.0 {
      out.push(@base.nan())
      continue
    }
    let avg1 = sbp1[i] / str1[i]
    let avg2 = sbp2[i] / str2[i]
    let avg3 = sbp3[i] / str3[i]
    out.push(100.0 * (4.0 * avg1 + 2.0 * avg2 + avg3) / 7.0)
  }
  out
}
