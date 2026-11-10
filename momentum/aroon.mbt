// Aroon indicator (Tushar Chande): recency of the highest high and lowest
// low within the lookback window.

///|
/// Aroon decomposition: the down and up lines, both of input length.
pub struct AroonResult {
  down : Array[Double]
  up : Array[Double]
}

///|
/// Number of leading NaN values produced by `aroon` for the given period:
/// `period` (the window covers `period + 1` bars including the current one).
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
pub fn aroon(
  candles : @base.Candles,
  period : Int32,
) -> AroonResult raise @base.TaError {
  @base.validate_candles(candles)
  if period <= 0 {
    raise @base.InvalidPeriod("period must be positive, got \{period}")
  }
  let n = candles.close.length()
  let down : Array[Double] = []
  let up : Array[Double] = []
  for i in 0..<n {
    if i < period {
      down.push(@base.nan())
      up.push(@base.nan())
      continue
    }
    // Scan window indices `i - period ..= i`; `>=` / `<=` make the most
    // recent extreme win on ties.
    let mut hh_idx = -1
    let mut ll_idx = -1
    let mut valid = true
    for j in (i - period)..<(i + 1) {
      let h = candles.high[j]
      let l = candles.low[j]
      if @base.is_nan(h) || @base.is_nan(l) {
        valid = false
        break
      }
      if hh_idx == -1 || h >= candles.high[hh_idx] {
        hh_idx = j
      }
      if ll_idx == -1 || l <= candles.low[ll_idx] {
        ll_idx = j
      }
    }
    if !valid {
      down.push(@base.nan())
      up.push(@base.nan())
      continue
    }
    let pd = period.to_double()
    let since_hh = i - hh_idx
    let since_ll = i - ll_idx
    up.push(100.0 * (period - since_hh).to_double() / pd)
    down.push(100.0 * (period - since_ll).to_double() / pd)
  }
  { down, up, }
}
