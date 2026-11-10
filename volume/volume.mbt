// Volume-based indicators: On-Balance Volume, Money Flow Index, the Chaikin
// Accumulation/Distribution line and its oscillator.

///|
/// On-Balance Volume (Joe Granville): a running sum of volume signed by the
/// direction of the close. The first bar contributes its raw volume and bars
/// with an unchanged close contribute nothing. NaN anywhere propagates
/// forward from that bar on.
pub fn obv(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  let n = candles.close.length()
  let out : Array[Double] = []
  let mut acc = candles.volume[0]
  out.push(acc)
  for i in 1..<n {
    let prev_close = candles.close[i - 1]
    let close = candles.close[i]
    let vol = candles.volume[i]
    let poisoned = @base.is_nan(acc) ||
      @base.is_nan(prev_close) ||
      @base.is_nan(close) ||
      @base.is_nan(vol)
    if poisoned {
      acc = @base.nan()
    } else if close > prev_close {
      acc += vol
    } else if close < prev_close {
      acc -= vol
    }
    out.push(acc)
  }
  out
}

///|
/// Number of leading NaN values produced by `mfi` for the given period.
pub fn mfi_lookback(period : Int32) -> Int32 {
  period
}

///|
/// Money Flow Index (Gene Quong and Avrum Soudack): an RSI-style ratio of
/// positive to negative money flow, where flow is typical price times volume
/// and its sign comes from the change in typical price. A window with no
/// negative flow reads 100, with no positive flow 0. NaN inputs make the
/// position NaN.
pub fn mfi(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  if period <= 0 {
    raise @base.InvalidPeriod("period must be positive, got \{period}")
  }
  let n = candles.close.length()
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
  let tp : Array[Double] = []
  for i in 0..<n {
    let h = candles.high[i]
    let l = candles.low[i]
    let c = candles.close[i]
    if @base.is_nan(h) || @base.is_nan(l) || @base.is_nan(c) {
      tp.push(@base.nan())
    } else {
      tp.push((h + l + c) / 3.0)
    }
  }
  // Signed money flow per bar, computed once: typical price times volume,
  // positive on an up-tick of the typical price, negative on a down-tick,
  // zero on a flat tick; NaN when any input component is NaN.
  let flows : Array[Double] = []
  for j in 0..<n {
    let cur = tp[j]
    let prev = if j == 0 { @base.nan() } else { tp[j - 1] }
    let v = candles.volume[j]
    if @base.is_nan(cur) || @base.is_nan(prev) || @base.is_nan(v) {
      flows.push(@base.nan())
    } else if cur > prev {
      flows.push(cur * v)
    } else if cur < prev {
      flows.push(-(cur * v))
    } else {
      flows.push(0.0)
    }
  }
  for _ in 0..<period {
    out.push(@base.nan())
  }
  for i in period..<n {
    let mut pos = 0.0
    let mut neg = 0.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let f = flows[j]
      if @base.is_nan(f) {
        valid = false
        break
      }
      if f > 0.0 {
        pos += f
      } else {
        neg -= f
      }
    }
    if !valid {
      out.push(@base.nan())
    } else if neg == 0.0 {
      out.push(100.0)
    } else {
      out.push(100.0 - 100.0 / (1.0 + pos / neg))
    }
  }
  out
}

///|
/// The Chaikin money-flow multiplier of one bar:
/// `((close - low) - (high - close)) / (high - low)`, defined as 0 for flat
/// bars and NaN when a component is NaN.
fn clv_at(candles : @base.Candles, i : Int32) -> Double {
  let high = candles.high[i]
  let low = candles.low[i]
  let close = candles.close[i]
  if @base.is_nan(high) || @base.is_nan(low) || @base.is_nan(close) {
    return @base.nan()
  }
  let range = high - low
  if range == 0.0 {
    return 0.0
  }
  (close - low - (high - close)) / range
}

///|
/// Chaikin Accumulation/Distribution Line: the running sum of the
/// money-flow multiplier times volume. The first bar seeds the line with its
/// own money flow; NaN propagates forward.
pub fn ad(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  let n = candles.close.length()
  let out : Array[Double] = []
  let mut acc = clv_at(candles, 0) * candles.volume[0]
  out.push(acc)
  for i in 1..<n {
    let flow = clv_at(candles, i)
    let vol = candles.volume[i]
    let poisoned = @base.is_nan(acc) || @base.is_nan(flow) || @base.is_nan(vol)
    if poisoned {
      acc = @base.nan()
    } else {
      acc += flow * vol
    }
    out.push(acc)
  }
  out
}

///|
/// Chaikin A/D Oscillator: `EMA(fast) - EMA(slow)` of the A/D line, using the
/// SMA-seeded EMA of `overlap`. Valid from index `slow_period - 1`.
pub fn adosc(
  candles : @base.Candles,
  fast_period : Int32,
  slow_period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  if fast_period <= 0 || slow_period <= 0 {
    raise @base.InvalidPeriod("all periods must be positive")
  }
  if fast_period >= slow_period {
    raise @base.InvalidPeriod("fast_period must be smaller than slow_period")
  }
  let line = ad(candles)
  let fast_ma = @overlap.ema_from(line, fast_period, 0)
  let slow_ma = @overlap.ema_from(line, slow_period, 0)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let f = fast_ma[i]
    let s = slow_ma[i]
    if @base.is_nan(f) || @base.is_nan(s) {
      out.push(@base.nan())
    } else {
      out.push(f - s)
    }
  }
  out
}
