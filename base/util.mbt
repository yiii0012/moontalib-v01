// Small numeric helpers shared by every indicator package.

///|
/// Quiet NaN used to mark positions where an indicator has no value yet.
pub fn nan() -> Double {
  let zero = 0.0
  zero / zero
}

///|
/// Returns true when the value is NaN.
pub fn is_nan(x : Double) -> Bool {
  x != x
}

///|
/// Integer square root (floor of the square root), used by HMA to size its
/// final WMA window.
pub fn isqrt(n : Int32) -> Int32 {
  if n <= 0 {
    return 0
  }
  let mut x = n
  let mut y = (x + 1) / 2
  while y < x {
    x = y
    y = (x + n / x) / 2
  }
  x
}

///|
/// Shared validation for a single price series plus a window length: the
/// input must be non-empty and the period positive and not larger than the
/// input. Indicators are otherwise graceful — positions without a full
/// window are simply NaN in the output.
pub fn validate_series(
  data : Array[Double],
  period : Int32,
) -> Unit raise TaError {
  if data.length() == 0 {
    raise EmptyInput
  }
  if period <= 0 {
    raise InvalidPeriod("period must be positive, got \{period}")
  }
  if period > data.length() {
    raise NotEnoughData(
      "period \{period} exceeds input length \{data.length()}",
    )
  }
}

///|
/// Shared validation for a `Candles` series: non-empty and equal-length
/// columns.
pub fn validate_candles(candles : Candles) -> Unit raise TaError {
  let n = candles.close.length()
  if n == 0 {
    raise EmptyInput
  }
  if candles.open.length() != n {
    raise MismatchedLength("open column length differs from close")
  }
  if candles.high.length() != n {
    raise MismatchedLength("high column length differs from close")
  }
  if candles.low.length() != n {
    raise MismatchedLength("low column length differs from close")
  }
  if candles.volume.length() != n {
    raise MismatchedLength("volume column length differs from close")
  }
}
