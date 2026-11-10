// Blackbox tests for the base package: primitives, validation and the
// true-range helper.

///|
fn err_msg(f : () -> Unit raise @base.TaError) -> String {
  try f() catch {
    e => e.to_string()
  } noraise {
    _ => "no error"
  }
}

///|
test "isqrt computes floor square roots" {
  assert_eq(@base.isqrt(0), 0)
  assert_eq(@base.isqrt(1), 1)
  assert_eq(@base.isqrt(2), 1)
  assert_eq(@base.isqrt(3), 1)
  assert_eq(@base.isqrt(4), 2)
  assert_eq(@base.isqrt(5), 2)
  assert_eq(@base.isqrt(8), 2)
  assert_eq(@base.isqrt(9), 3)
  assert_eq(@base.isqrt(16), 4)
  assert_eq(@base.isqrt(17), 4)
  assert_eq(@base.isqrt(100), 10)
  assert_eq(@base.isqrt(1000), 31)
}

///|
test "nan helper produces quiet NaN detected by is_nan" {
  assert_eq(@base.is_nan(@base.nan()), true)
  assert_eq(@base.is_nan(1.0), false)
  assert_eq(@base.is_nan(0.0), false)
}

///|
test "validate_series accepts a well-formed series" {
  @base.validate_series([1.0, 2.0, 3.0], 3)
}

///|
test "validate_series rejects empty input" {
  assert_eq(
    err_msg(() => @base.validate_series([], 3)),
    "input series is empty",
  )
}

///|
test "validate_series rejects non-positive period" {
  assert_eq(
    err_msg(() => @base.validate_series([1.0, 2.0, 3.0], 0)),
    "invalid period: period must be positive, got 0",
  )
}

///|
test "validate_series rejects period longer than input" {
  assert_eq(
    err_msg(() => @base.validate_series([1.0, 2.0], 5)),
    "not enough data: period 5 exceeds input length 2",
  )
}

///|
test "true_range uses the previous close after the first bar" {
  let candles = @base.Candles::from_bars([
    { open: 2.0, high: 3.0, low: 1.0, close: 2.0, volume: 10.0, },
    { open: 2.0, high: 5.0, low: 2.0, close: 4.0, volume: 20.0, },
    { open: 4.0, high: 4.0, low: 3.0, close: 3.5, volume: 30.0, },
    { open: 3.5, high: 6.0, low: 2.0, close: 5.0, volume: 40.0, },
  ])
  assert_eq(candles.length(), 4)
  let expected : Array[Double] = [2.0, 3.0, 1.0, 4.0]
  for i in 0..<4 {
    assert_eq(@base.true_range(candles, i), expected[i])
  }
}

///|
test "true_range propagates NaN components" {
  let candles = @base.Candles::from_bars([
    { open: 2.0, high: 3.0, low: 1.0, close: 2.0, volume: 10.0, },
    { open: 2.0, high: @base.nan(), low: 2.0, close: 4.0, volume: 20.0, },
  ])
  assert_eq(@base.is_nan(@base.true_range(candles, 1)), true)
}

///|
test "validate_candles rejects mismatched column lengths" {
  let candles : @base.Candles = {
    open: [1.0, 2.0],
    high: [1.0, 2.0],
    low: [1.0, 2.0],
    close: [1.0],
    volume: [1.0, 2.0],
  }
  assert_eq(
    err_msg(() => @base.validate_candles(candles)),
    "mismatched input lengths: open column length differs from close",
  )
}

///|
test "validate_candles rejects empty input" {
  let candles : @base.Candles = {
    open: [],
    high: [],
    low: [],
    close: [],
    volume: [],
  }
  assert_eq(
    err_msg(() => @base.validate_candles(candles)),
    "input series is empty",
  )
}
