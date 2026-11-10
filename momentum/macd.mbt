// MACD: fast EMA minus slow EMA, with an EMA signal line and histogram.

///|
/// MACD decomposition: the MACD line, its signal line and the histogram
/// (MACD minus signal). All three arrays have the input length.
pub struct Macd {
  macd : Array[Double]
  signal : Array[Double]
  hist : Array[Double]
}

///|
/// Number of leading NaN values: `(slow - 1) + (signal - 1)`.
pub fn macd_lookback(slow_period : Int32, signal_period : Int32) -> Int32 {
  slow_period - 1 + (signal_period - 1)
}

///|
/// Moving Average Convergence/Divergence.
///
/// The MACD line is `EMA(fast) - EMA(slow)` and becomes valid at index
/// `slow_period - 1`. The signal line is an EMA of the MACD line seeded with
/// the SMA of the first `signal_period` MACD values, valid at index
/// `slow_period + signal_period - 2`. Uses the SMA-seeded EMA of `overlap`
/// (TA-Lib convention), so a NaN input poisons the chain from that point on.
pub fn macd(
  data : Array[Double],
  fast_period : Int32,
  slow_period : Int32,
  signal_period : Int32,
) -> Macd raise @base.TaError {
  @base.validate_series(data, slow_period)
  if fast_period <= 0 || slow_period <= 0 || signal_period <= 0 {
    raise @base.InvalidPeriod("all periods must be positive")
  }
  if fast_period >= slow_period {
    raise @base.InvalidPeriod("fast_period must be smaller than slow_period")
  }
  let n = data.length()
  let ema_fast = @overlap.ema_from(data, fast_period, 0)
  let ema_slow = @overlap.ema_from(data, slow_period, 0)
  let line : Array[Double] = []
  for i in 0..<n {
    let f = ema_fast[i]
    let s = ema_slow[i]
    if @base.is_nan(f) || @base.is_nan(s) {
      line.push(@base.nan())
    } else {
      line.push(f - s)
    }
  }
  let signal = @overlap.ema_from(line, signal_period, slow_period - 1)
  let hist : Array[Double] = []
  for i in 0..<n {
    let m = line[i]
    let s = signal[i]
    if @base.is_nan(m) || @base.is_nan(s) {
      hist.push(@base.nan())
    } else {
      hist.push(m - s)
    }
  }
  { macd: line, signal, hist, }
}
