// Average Directional Index with +DI / -DI (J. Welles Wilder).

///|
/// ADX decomposition: the ADX trend-strength line plus the +DI and -DI
/// directional indicators. All three arrays have the input length.
pub struct AdxResult {
  adx : Array[Double]
  plus_di : Array[Double]
  minus_di : Array[Double]
}

///|
fn dm_plus(candles : @base.Candles, i : Int32) -> Double {
  let up = candles.high[i] - candles.high[i - 1]
  let down = candles.low[i - 1] - candles.low[i]
  if @base.is_nan(up) || @base.is_nan(down) {
    return @base.nan()
  }
  if up > down && up > 0.0 {
    up
  } else {
    0.0
  }
}

///|
fn dm_minus(candles : @base.Candles, i : Int32) -> Double {
  let up = candles.high[i] - candles.high[i - 1]
  let down = candles.low[i - 1] - candles.low[i]
  if @base.is_nan(up) || @base.is_nan(down) {
    return @base.nan()
  }
  if down > up && down > 0.0 {
    down
  } else {
    0.0
  }
}

///|
/// Number of leading NaN values produced by `adx` for the given period:
/// `2 * period - 1` (the DI lines themselves are valid from `period`).
pub fn adx_lookback(period : Int32) -> Int32 {
  2 * period - 1
}

///|
/// Average Directional Index.
///
/// True range and directional movement are accumulated with Wilder's
/// smoothing (`s = s - s / period + current`, seeded by a simple sum over
/// the first `period` changes). +DI/-DI are valid from index `period`, and
/// ADX (a Wilder average of the DX) from index `2 * period - 1`. A zero
/// smoothed true range (perfectly flat window) maps the DI lines to 0.
pub fn adx(
  candles : @base.Candles,
  period : Int32,
) -> AdxResult raise @base.TaError {
  @base.validate_candles(candles)
  if period < 2 {
    raise @base.InvalidPeriod("ADX period must be at least 2, got \{period}")
  }
  let n = candles.close.length()
  if period > n {
    raise @base.NotEnoughData("period \{period} exceeds input length \{n}")
  }
  let pd = period.to_double()
  let plus_di : Array[Double] = []
  let minus_di : Array[Double] = []
  for _ in 0..<n {
    plus_di.push(@base.nan())
    minus_di.push(@base.nan())
  }
  let mut s_tr = 0.0
  let mut s_p = 0.0
  let mut s_m = 0.0
  let mut seeded = n > period
  if seeded {
    for i in 1..<(period + 1) {
      let t = @base.true_range(candles, i)
      let p = dm_plus(candles, i)
      let m = dm_minus(candles, i)
      if @base.is_nan(t) || @base.is_nan(p) || @base.is_nan(m) {
        seeded = false
        break
      }
      s_tr += t
      s_p += p
      s_m += m
    }
  }
  if seeded {
    plus_di[period] = if s_tr == 0.0 { 0.0 } else { 100.0 * s_p / s_tr }
    minus_di[period] = if s_tr == 0.0 { 0.0 } else { 100.0 * s_m / s_tr }
    for i in (period + 1)..<n {
      let t = @base.true_range(candles, i)
      let p = dm_plus(candles, i)
      let m = dm_minus(candles, i)
      if @base.is_nan(t) || @base.is_nan(p) || @base.is_nan(m) {
        s_tr = @base.nan()
        s_p = @base.nan()
        s_m = @base.nan()
      } else {
        s_tr = s_tr - s_tr / pd + t
        s_p = s_p - s_p / pd + p
        s_m = s_m - s_m / pd + m
      }
      plus_di[i] = if s_tr == 0.0 { 0.0 } else { 100.0 * s_p / s_tr }
      minus_di[i] = if s_tr == 0.0 { 0.0 } else { 100.0 * s_m / s_tr }
    }
  }
  // DX wherever both DI lines are available.
  let dx : Array[Double] = []
  for i in 0..<n {
    let p = plus_di[i]
    let m = minus_di[i]
    if @base.is_nan(p) || @base.is_nan(m) {
      dx.push(@base.nan())
    } else {
      let total = p + m
      if total == 0.0 {
        dx.push(0.0)
      } else {
        dx.push(100.0 * (p - m).abs() / total)
      }
    }
  }
  let adx_out : Array[Double] = []
  for _ in 0..<n {
    adx_out.push(@base.nan())
  }
  let first = 2 * period - 1
  if seeded && n > first {
    let mut sum = 0.0
    let mut ok = true
    for i in period..<(first + 1) {
      if @base.is_nan(dx[i]) {
        ok = false
        break
      }
      sum += dx[i]
    }
    if ok {
      let mut a = sum / pd
      adx_out[first] = a
      for i in (first + 1)..<n {
        if @base.is_nan(dx[i]) || @base.is_nan(a) {
          a = @base.nan()
        } else {
          a = (a * (period - 1).to_double() + dx[i]) / pd
        }
        adx_out[i] = a
      }
    }
  }
  { adx: adx_out, plus_di, minus_di, }
}
