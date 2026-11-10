// Blackbox tests for the moving-average family. Expected values are
// hand-computed golden values; tolerance is 1e-9.

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
test "sma computes the mean of each full window" {
  let out = @overlap.sma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(out, nan_prefix(2, [2.0, 3.0, 4.0]))
}

///|
test "sma marks windows touched by NaN" {
  let out = @overlap.sma([1.0, @base.nan(), 3.0, 4.0, 5.0], 3)
  assert_all_close(out, nan_prefix(4, [4.0]))
}

///|
test "sma lookback and error cases" {
  assert_eq(@overlap.sma_lookback(3), 2)
  assert_eq(err_msg(() => @overlap.sma([], 3)), "input series is empty")
  assert_eq(
    err_msg(() => @overlap.sma([1.0], 0)),
    "invalid period: period must be positive, got 0",
  )
  assert_eq(
    err_msg(() => @overlap.sma([1.0], 2)),
    "not enough data: period 2 exceeds input length 1",
  )
}

///|
test "ema seeds with the SMA of the first window" {
  let out = @overlap.ema([2.0, 4.0, 6.0, 8.0, 12.0], 3)
  assert_all_close(out, nan_prefix(2, [4.0, 6.0, 9.0]))
  assert_eq(@overlap.ema_lookback(3), 2)
}

///|
test "wma applies linearly decreasing weights" {
  let out = @overlap.wma([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(
    out,
    nan_prefix(2, [2.3333333333333335, 3.3333333333333335, 4.333333333333333]),
  )
  assert_eq(@overlap.wma_lookback(3), 2)
}

///|
test "hma smooths the lag of the weighted average" {
  let out = @overlap.hma([1.0, 2.0, 3.0, 4.0, 5.0], 4)
  assert_all_close(out, nan_prefix(4, [5.0]))
  assert_eq(@overlap.hma_lookback(4), 4)
}

///|
test "dema doubles the EMA chain" {
  let out = @overlap.dema([2.0, 4.0, 6.0, 8.0, 12.0], 3)
  assert_all_close(out, nan_prefix(4, [11.666666666666667]))
  assert_eq(@overlap.dema_lookback(3), 4)
}

///|
test "tema triples the EMA chain" {
  let out = @overlap.tema([2.0, 4.0, 6.0, 8.0, 12.0, 16.0, 20.0], 3)
  assert_all_close(out, nan_prefix(6, [19.77777777777778]))
  assert_eq(@overlap.tema_lookback(3), 6)
}

///|
test "moving_average dispatches to the selected flavor" {
  let data = [2.0, 4.0, 6.0, 8.0, 12.0]
  let via_sma = @overlap.moving_average(data, 3, ma_type=@base.Sma)
  assert_all_close(via_sma, @overlap.sma(data, 3))
  let via_ema = @overlap.moving_average(data, 3, ma_type=@base.Ema)
  assert_all_close(via_ema, @overlap.ema(data, 3))
}

///|
test "midpoint averages the rolling extremes" {
  let out = @overlap.midpoint([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(out, nan_prefix(2, [2.0, 3.0, 4.0]))
  assert_eq(@overlap.midpoint_lookback(3), 2)
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
