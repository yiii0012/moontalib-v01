// Blackbox tests for price transforms and rolling utilities.

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
fn one_bar() -> @base.Candles {
  let list : Array[@base.Candle] = []
  list.push({ open: 1.0, high: 4.0, low: 2.0, close: 3.0, volume: 10.0, })
  @base.Candles::from_bars(list)
}

///|
test "price transforms combine the four prices" {
  let candles = one_bar()
  assert_all_close(@statistic.avg_price(candles), [2.5])
  assert_all_close(@statistic.med_price(candles), [3.0])
  assert_all_close(@statistic.typ_price(candles), [3.0])
  assert_all_close(@statistic.wcl_price(candles), [3.0])
}

///|
test "max tracks the rolling window maximum" {
  let out = @statistic.max([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(out, nan_prefix(2, [3.0, 4.0, 5.0]))
}

///|
test "min tracks the rolling window minimum" {
  let out = @statistic.min([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(out, nan_prefix(2, [1.0, 2.0, 3.0]))
}

///|
test "sum totals the rolling window" {
  let out = @statistic.sum([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(out, nan_prefix(2, [6.0, 9.0, 12.0]))
  assert_eq(@statistic.window_lookback(3), 2)
}

///|
test "window functions mark NaN-touched windows" {
  let out = @statistic.max([1.0, @base.nan(), 3.0], 3)
  assert_all_close(out, nan_prefix(3, []))
}

///|
test "statistic functions validate their inputs" {
  assert_eq(err_msg(() => @statistic.max([], 3)), "input series is empty")
  assert_eq(err_msg(() => @statistic.avg_price(one_bar())), "no error")
}

///|
test "linear regression family fits the least-squares line" {
  // data [1, 2, 4]: slope = 1.5, intercept = 5/6, endpoint = 23/6, forecast = 16/3
  let slope = @statistic.linearreg_slope([1.0, 2.0, 4.0], 3)
  assert_all_close(slope, nan_prefix(2, [1.5]))
  let intercept = @statistic.linearreg_intercept([1.0, 2.0, 4.0], 3)
  assert_all_close(intercept, nan_prefix(2, [0.8333333333333334]))
  let lr = @statistic.linearreg([1.0, 2.0, 4.0], 3)
  assert_all_close(lr, nan_prefix(2, [3.8333333333333335]))
  let tsf = @statistic.tsf([1.0, 2.0, 4.0], 3)
  assert_all_close(tsf, nan_prefix(2, [5.333333333333333]))
  let angle = @statistic.linearreg_angle([1.0, 2.0, 4.0], 3)
  assert_all_close(angle, nan_prefix(2, [56.309932474020215]))
}

///|
test "linear regression recovers a perfect line" {
  let data = [1.0, 2.0, 3.0, 4.0, 5.0]
  assert_all_close(
    @statistic.linearreg_slope(data, 3),
    nan_prefix(2, [1.0, 1.0, 1.0]),
  )
  assert_all_close(
    @statistic.linearreg(data, 3),
    nan_prefix(2, [3.0, 4.0, 5.0]),
  )
  assert_all_close(@statistic.tsf(data, 3), nan_prefix(2, [4.0, 5.0, 6.0]))
  assert_all_close(
    @statistic.linearreg_angle(data, 3),
    nan_prefix(2, [45.0, 45.0, 45.0]),
  )
}

///|
test "linear regression validates its inputs" {
  assert_eq(err_msg(() => @statistic.linearreg([], 3)), "input series is empty")
  assert_eq(
    err_msg(() => @statistic.tsf([1.0], 1)),
    "invalid period: period must be at least 2, got 1",
  )
}
