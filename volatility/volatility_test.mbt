// Blackbox tests for the volatility family. Expected values are hand-computed
// golden values; tolerance is 1e-9.

///|
fn is_close(a : Double, b : Double, tol : Double) -> Bool {
  if a != a && b != b {
    return true
  }
  if a != a || b != b {
    return false
  }
  (a - b).abs() <= tol
}

///|
fn assert_close(
  actual : Double,
  expected : Double,
  tol~ : Double = 0.000000001,
) -> Unit raise {
  if !is_close(actual, expected, tol) {
    fail("expected \{expected}, got \{actual}")
  }
}

///|
fn nan_prefix(count : Int32, rest : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(@base.nan())
  }
  for v in rest {
    out.push(v)
  }
  out
}

///|
fn assert_all_close(
  actual : Array[Double],
  expected : Array[Double],
  tol~ : Double = 0.000000001,
) -> Unit raise {
  if actual.length() != expected.length() {
    fail("length mismatch: \{actual.length()} vs \{expected.length()}")
  }
  for i in 0..<actual.length() {
    assert_close(actual[i], expected[i], tol~)
  }
}

///|
fn[T] err_msg(f : () -> T raise @base.TaError) -> String {
  try f() catch {
    e => e.to_string()
  } noraise {
    _ => "no error"
  }
}

///|
fn bars(
  rows : Array[(Double, Double, Double, Double, Double)],
) -> @base.Candles {
  let list : Array[@base.Candle] = []
  for row in rows {
    list.push({
      open: row.0,
      high: row.1,
      low: row.2,
      close: row.3,
      volume: row.4,
    })
  }
  @base.Candles::from_bars(list)
}

///|
fn sample_candles() -> @base.Candles {
  bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 5.0, 2.0, 4.0, 20.0),
    (4.0, 4.0, 3.0, 3.5, 30.0),
    (3.5, 6.0, 2.0, 5.0, 40.0),
  ])
}

///|
test "tr_range matches the per-bar true range" {
  let out = @volatility.tr_range(sample_candles())
  assert_all_close(out, [2.0, 3.0, 1.0, 4.0])
}

///|
test "atr seeds with the mean true range and applies Wilder smoothing" {
  let out = @volatility.atr(sample_candles(), 2)
  assert_all_close(out, nan_prefix(2, [2.0, 3.0]))
  assert_eq(@volatility.atr_lookback(2), 2)
}

///|
test "atr is graceful when the period equals the input length" {
  let out = @volatility.atr(sample_candles(), 4)
  assert_eq(out.length(), 4)
  for i in 0..<4 {
    assert_close(out[i], @base.nan())
  }
}

///|
test "natr divides the ATR by the close" {
  let out = @volatility.natr(sample_candles(), 2)
  assert_all_close(out, nan_prefix(2, [57.142857142857146, 60.0]))
}

///|
test "stddev uses the population convention" {
  let out = @volatility.stddev([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(
    out,
    nan_prefix(2, [0.816496580927726, 0.816496580927726, 0.816496580927726]),
  )
  assert_eq(@volatility.stddev_lookback(3), 2)
}

///|
test "variance is the squared stddev" {
  let out = @volatility.variance([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(
    out,
    nan_prefix(2, [0.6666666666666666, 0.6666666666666666, 0.6666666666666666]),
  )
}

///|
test "volatility functions validate their inputs" {
  assert_eq(
    err_msg(() => @volatility.atr(sample_candles(), 0)),
    "invalid period: period must be positive, got 0",
  )
  assert_eq(err_msg(() => @volatility.stddev([], 3)), "input series is empty")
}
