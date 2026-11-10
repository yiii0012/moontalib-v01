// Rolling Pearson correlation between two series.

///|
/// Number of leading NaN values produced by `correl` for the given period.
pub fn correl_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Pearson correlation coefficient of `data1` and `data2` over a rolling
/// window of `period` values: `sum(dx * dy) / sqrt(sum(dx^2) * sum(dy^2))`
/// with `dx`/`dy` the per-window deviations from the mean. Result ranges
/// from -1 to +1; a window containing NaN, or where either series is flat
/// (zero deviation sum), yields NaN.
pub fn correl(
  data1 : Array[Double],
  data2 : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data1, period)
  @base.validate_series(data2, period)
  if data1.length() != data2.length() {
    raise @base.MismatchedLength("data1 and data2 must have equal lengths")
  }
  let n = data1.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let mut s1 = 0.0
    let mut s2 = 0.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let a = data1[j]
      let b = data2[j]
      if @base.is_nan(a) || @base.is_nan(b) {
        valid = false
        break
      }
      s1 += a
      s2 += b
    }
    if !valid {
      out.push(@base.nan())
      continue
    }
    let pd = period.to_double()
    let mean1 = s1 / pd
    let mean2 = s2 / pd
    let mut num = 0.0
    let mut den1 = 0.0
    let mut den2 = 0.0
    for j in (i - period + 1)..<(i + 1) {
      let da = data1[j] - mean1
      let db = data2[j] - mean2
      num += da * db
      den1 += da * da
      den2 += db * db
    }
    let den = (den1 * den2).sqrt()
    if den == 0.0 {
      out.push(@base.nan())
    } else {
      out.push(num / den)
    }
  }
  out
}
