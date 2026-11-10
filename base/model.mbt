// Data model, error type and shared options for moontalib.

///|
/// A single OHLCV bar (open, high, low, close, volume). Constructible from
/// any package (`pub(all)`); struct fields are public by default.
pub(all) struct Candle {
  open : Double
  high : Double
  low : Double
  close : Double
  volume : Double
}

///|
/// Column-oriented OHLCV series. All five arrays must have equal length;
/// indicator functions validate this and return `Err(MismatchedLength)`
/// otherwise. Constructible from any package (`pub(all)`).
pub(all) struct Candles {
  open : Array[Double]
  high : Array[Double]
  low : Array[Double]
  close : Array[Double]
  volume : Array[Double]
}

///|
/// Builds a column-oriented series from a row-oriented bar list.
pub fn Candles::from_bars(bars : Array[Candle]) -> Candles {
  let open : Array[Double] = []
  let high : Array[Double] = []
  let low : Array[Double] = []
  let close : Array[Double] = []
  let volume : Array[Double] = []
  for bar in bars {
    open.push(bar.open)
    high.push(bar.high)
    low.push(bar.low)
    close.push(bar.close)
    volume.push(bar.volume)
  }
  { open, high, low, close, volume, }
}

///|
/// Number of bars in the series (taken from the `close` column).
pub fn Candles::length(self : Candles) -> Int32 {
  self.close.length()
}

///|
/// True range of bar `i`: `high - low` for the first bar, otherwise the
/// greatest of `high - low`, `|high - prev_close|` and `|low - prev_close|`.
/// Any NaN component yields NaN.
pub fn true_range(candles : Candles, i : Int32) -> Double {
  let high = candles.high[i]
  let low = candles.low[i]
  if is_nan(high) || is_nan(low) {
    return nan()
  }
  if i == 0 {
    return high - low
  }
  let prev_close = candles.close[i - 1]
  if is_nan(prev_close) {
    return nan()
  }
  let hl = high - low
  let a = (high - prev_close).abs()
  let b = (low - prev_close).abs()
  let mut m = if a > b { a } else { b }
  if hl > m {
    m = hl
  }
  m
}

///|
/// Errors raised by moontalib functions. `TaError::to_string` gives a
/// human-readable message.
pub(all) suberror TaError {
  EmptyInput
  MismatchedLength(String)
  InvalidPeriod(String)
  NotEnoughData(String)
}

///|
/// Human-readable description of the error.
pub fn TaError::to_string(self : TaError) -> String {
  match self {
    EmptyInput => "input series is empty"
    MismatchedLength(msg) => "mismatched input lengths: \{msg}"
    InvalidPeriod(msg) => "invalid period: \{msg}"
    NotEnoughData(msg) => "not enough data: \{msg}"
  }
}

///|
/// Moving-average flavor used by APO/PPO and the `moving_average` dispatcher.
/// Constructible from any package (`pub(all)`).
pub(all) enum MAType {
  Sma
  Ema
}
