// Blackbox tests for the root facade: every function must behave exactly
// like its subpackage counterpart.

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
test "facade sma matches the golden values" {
  let out = @moontalib.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(out, nan_prefix(2, [2.0, 3.0, 4.0]))
}

///|
test "facade rsi matches the golden values" {
  let out = @moontalib.rsi([1.0, 2.0, 3.0, 2.0, 4.0], 3)
  assert_all_close(out, nan_prefix(3, [66.66666666666667, 83.33333333333333]))
}

///|
test "facade macd exposes line, signal and histogram" {
  let m = @moontalib.macd([1.0, 2.0, 3.0, 4.0, 5.0], 2, 4, 2)
  assert_all_close(m.macd, nan_prefix(3, [1.0, 1.0]))
  assert_all_close(m.signal, nan_prefix(4, [1.0]))
  assert_all_close(m.hist, nan_prefix(4, [0.0]))
}

///|
test "facade atr works on candles" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 5.0, 2.0, 4.0, 20.0),
    (4.0, 4.0, 3.0, 3.5, 30.0),
    (3.5, 6.0, 2.0, 5.0, 40.0),
  ])
  let out = @moontalib.atr(candles, 2)
  assert_all_close(out, nan_prefix(2, [2.0, 3.0]))
}

///|
test "facade propagates validation errors" {
  assert_eq(err_msg(() => @moontalib.sma([], 3)), "input series is empty")
  assert_eq(
    err_msg(() => @moontalib.rsi([1.0], 0)),
    "invalid period: period must be positive, got 0",
  )
  assert_eq(err_msg(() => @moontalib.atr(bars([]), 2)), "input series is empty")
}
