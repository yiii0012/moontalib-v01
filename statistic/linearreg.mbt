// Linear-regression family (TA-Lib "Statistic Functions"): slope, intercept,
// regression endpoint, angle in degrees and one-bar forecast. All five share
// the least-squares core `linreg_at`.

///|
/// Least-squares slope and intercept of the last `period` values ending at
/// index `i`, using the bar offset 0..period-1 as x. A NaN inside the window
/// yields (NaN, NaN).
fn linreg_at(
  data : Array[Double],
  i : Int32,
  period : Int32,
) -> (Double, Double) {
  let mut sx = 0.0
  let mut sy = 0.0
  let mut valid = true
  for j in (i - period + 1)..<(i + 1) {
    let y = data[j]
    if @base.is_nan(y) {
      valid = false
      break
    }
    sx += (j - i + period - 1).to_double()
    sy += y
  }
  if !valid {
    return (@base.nan(), @base.nan())
  }
  let pd = period.to_double()
  let x_bar = sx / pd
  let y_bar = sy / pd
  let mut num = 0.0
  let mut den = 0.0
  for j in (i - period + 1)..<(i + 1) {
    let dx = (j - i + period - 1).to_double() - x_bar
    let dy = data[j] - y_bar
    num += dx * dy
    den += dx * dx
  }
  if den == 0.0 {
    return (@base.nan(), @base.nan())
  }
  let slope = num / den
  (slope, y_bar - slope * x_bar)
}

///|
/// Least-squares slope over a rolling window. A window shorter than 2 bars
/// cannot define a slope; `period` must be at least 2.
pub fn linearreg_slope(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  if period < 2 {
    raise @base.InvalidPeriod("period must be at least 2, got \{period}")
  }
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let (slope, _) = linreg_at(data, i, period)
    out.push(slope)
  }
  out
}

///|
/// Least-squares intercept over a rolling window, defined at bar offset 0.
pub fn linearreg_intercept(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  if period < 2 {
    raise @base.InvalidPeriod("period must be at least 2, got \{period}")
  }
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let (_, intercept) = linreg_at(data, i, period)
    out.push(intercept)
  }
  out
}

///|
/// Number of leading NaN values produced by the linear-regression family for
/// the given period.
pub fn linearreg_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Linear regression endpoint: the fitted value at the current bar,
/// `intercept + slope * (period - 1)`.
pub fn linearreg(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  if period < 2 {
    raise @base.InvalidPeriod("period must be at least 2, got \{period}")
  }
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let (slope, intercept) = linreg_at(data, i, period)
    if @base.is_nan(slope) {
      out.push(@base.nan())
    } else {
      out.push(intercept + slope * (period - 1).to_double())
    }
  }
  out
}

///|
/// Linear regression angle in degrees: `atan(slope)` converted from radians.
pub fn linearreg_angle(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  if period < 2 {
    raise @base.InvalidPeriod("period must be at least 2, got \{period}")
  }
  let n = data.length()
  let rad_to_deg = 180.0 / 3.141592653589793
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let (slope, _) = linreg_at(data, i, period)
    if @base.is_nan(slope) {
      out.push(@base.nan())
    } else {
      out.push(@math.atan(slope) * rad_to_deg)
    }
  }
  out
}

///|
/// Time series forecast: the regression value one bar beyond the current
/// one, `intercept + slope * period`.
pub fn tsf(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  if period < 2 {
    raise @base.InvalidPeriod("period must be at least 2, got \{period}")
  }
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let (slope, intercept) = linreg_at(data, i, period)
    if @base.is_nan(slope) {
      out.push(@base.nan())
    } else {
      out.push(intercept + slope * period.to_double())
    }
  }
  out
}
