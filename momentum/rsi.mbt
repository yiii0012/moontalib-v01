// Relative Strength Index (J. Welles Wilder, 1978).

///|
/// Number of leading NaN values produced by `rsi` for the given period.
pub fn rsi_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Maps Wilder-smoothed average gain/loss to the RSI value. A zero average
/// loss maps to 100 (and a flat window therefore reads 100), matching
/// pandas-ta.
fn rsi_from(gain : Double, loss : Double) -> Double {
  if @base.is_nan(gain) || @base.is_nan(loss) {
    @base.nan()
  } else if loss == 0.0 {
    100.0
  } else {
    100.0 - 100.0 / (1.0 + gain / loss)
  }
}

///|
/// Relative Strength Index.
///
/// The seed is the simple average of gains and losses over the first
/// `period` price changes; later averages use Wilder smoothing
/// `avg = (prev * (period - 1) + current) / period`. The first value lands
/// at index `period`. NaN inputs poison the seed and propagate forward.
pub fn rsi(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
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
  let mut avg_gain = @base.nan()
  let mut avg_loss = @base.nan()
  let mut seeded = false
  if n > period {
    let mut g = 0.0
    let mut l = 0.0
    let mut ok = true
    for i in 1..<(period + 1) {
      let d = data[i] - data[i - 1]
      if @base.is_nan(d) {
        ok = false
        break
      }
      if d > 0.0 {
        g += d
      } else {
        l -= d
      }
    }
    if ok {
      avg_gain = g / period.to_double()
      avg_loss = l / period.to_double()
      seeded = true
    }
  }
  if seeded {
    out.push(rsi_from(avg_gain, avg_loss))
    let pm = (period - 1).to_double()
    let pd = period.to_double()
    for i in (period + 1)..<n {
      let d = data[i] - data[i - 1]
      if @base.is_nan(d) || @base.is_nan(avg_gain) {
        avg_gain = @base.nan()
        avg_loss = @base.nan()
      } else if d > 0.0 {
        avg_gain = (avg_gain * pm + d) / pd
        avg_loss = avg_loss * pm / pd
      } else {
        avg_gain = avg_gain * pm / pd
        avg_loss = (avg_loss * pm - d) / pd
      }
      out.push(rsi_from(avg_gain, avg_loss))
    }
  } else {
    for _ in period..<n {
      out.push(@base.nan())
    }
  }
  out
}
