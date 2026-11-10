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
  // Five O(n) rolling sums feed the Pearson formula; NaN in any window
  // propagates to NaN through the sums.
  let sx = @base.rolling_sum(data1, period)
  let sy = @base.rolling_sum(data2, period)
  let sq1 : Array[Double] = []
  let sq2 : Array[Double] = []
  let prod : Array[Double] = []
  for i in 0..<n {
    sq1.push(data1[i] * data1[i])
    sq2.push(data2[i] * data2[i])
    prod.push(data1[i] * data2[i])
  }
  let sxx = @base.rolling_sum(sq1, period)
  let syy = @base.rolling_sum(sq2, period)
  let sxy = @base.rolling_sum(prod, period)
  let pd = period.to_double()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 || @base.is_nan(sx[i]) || @base.is_nan(sxx[i]) {
      out.push(@base.nan())
      continue
    }
    let cov = sxy[i] - sx[i] * sy[i] / pd
    let var1 = sxx[i] - sx[i] * sx[i] / pd
    let var2 = syy[i] - sy[i] * sy[i] / pd
    let den = (var1 * var2).sqrt()
    if den == 0.0 {
      out.push(@base.nan())
    } else {
      out.push(cov / den)
    }
  }
  out
}
