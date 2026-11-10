// Ultimate Oscillator (Larry Williams): a weighted blend of buying-pressure

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
// ratios over three periods.

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
  fn window_sums(i : Int32, p : Int32) -> (Double, Double, Bool) {
    let mut sum_bp = 0.0
    let mut sum_tr = 0.0
    for j in (i - p + 1)..<(i + 1) {
      let b = bp[j]
      let t = tr[j]
      if @base.is_nan(b) || @base.is_nan(t) {
        return (0.0, 0.0, false)
      }
      sum_bp += b
      sum_tr += t
    }
    (sum_bp, sum_tr, true)
  }
  let out : Array[Double] = []
  for i in 0..<n {
    if i < p3 {
      out.push(@base.nan())
      continue
    }
    let (bp1, tr1, ok1) = window_sums(i, p1)
    let (bp2, tr2, ok2) = window_sums(i, p2)
    let (bp3, tr3, ok3) = window_sums(i, p3)
    if !ok1 || !ok2 || !ok3 || tr1 == 0.0 || tr2 == 0.0 || tr3 == 0.0 {
      out.push(@base.nan())
      continue
    }
    let avg1 = bp1 / tr1
    let avg2 = bp2 / tr2
    let avg3 = bp3 / tr3
    out.push(100.0 * (4.0 * avg1 + 2.0 * avg2 + avg3) / 7.0)
  }
  out
}
