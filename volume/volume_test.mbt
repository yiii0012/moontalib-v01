// Blackbox tests for the volume family. Expected values are hand-computed
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
test "obv accumulates signed volume" {
  let candles = bars([
    (2.0, 2.0, 2.0, 2.0, 10.0),
    (2.0, 3.0, 3.0, 3.0, 20.0),
    (3.0, 2.0, 2.0, 2.0, 30.0),
    (2.0, 5.0, 5.0, 5.0, 40.0),
  ])
  let out = @volume.obv(candles)
  assert_all_close(out, [10.0, 30.0, 0.0, 40.0])
}

///|
test "mfi weighs typical price flows by volume" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (3.0, 4.0, 2.0, 3.0, 20.0),
    (2.0, 4.0, 2.0, 1.0, 30.0),
    (5.0, 6.0, 4.0, 5.0, 40.0),
  ])
  let out = @volume.mfi(candles, 2)
  assert_all_close(out, nan_prefix(2, [46.15384615384615, 74.07407407407408]))
  assert_eq(@volume.mfi_lookback(2), 2)
}

///|
test "mfi reads 100 when a window has no negative flow" {
  let candles = bars([
    (2.0, 2.0, 2.0, 2.0, 10.0),
    (2.0, 3.0, 3.0, 3.0, 20.0),
    (3.0, 4.0, 4.0, 4.0, 30.0),
  ])
  let out = @volume.mfi(candles, 2)
  assert_all_close(out, nan_prefix(2, [100.0]))
}

///|
test "ad accumulates the Chaikin money flow" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 5.0, 1.0, 4.0, 30.0),
    (4.0, 4.0, 2.0, 3.0, 20.0),
    (3.0, 6.0, 3.0, 4.0, 40.0),
  ])
  let out = @volume.ad(candles)
  assert_all_close(out, [0.0, 15.0, 15.0, 1.666666666666667])
}

///|
test "adosc is the MA spread of the public A/D line" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 5.0, 1.0, 4.0, 30.0),
    (4.0, 4.0, 2.0, 3.0, 20.0),
    (3.0, 6.0, 3.0, 4.0, 40.0),
    (4.0, 7.0, 4.0, 6.0, 50.0),
    (6.0, 8.0, 5.0, 7.0, 60.0),
    (7.0, 9.0, 6.0, 8.0, 70.0),
    (8.0, 10.0, 7.0, 9.0, 80.0),
  ])
  let line = @volume.ad(candles)
  let osc = @volume.adosc(candles, 2, 5)
  let fast = @overlap.ema_from(line, 2, 0)
  let slow = @overlap.ema_from(line, 5, 0)
  for i in 0..<line.length() {
    let f = fast[i]
    let s = slow[i]
    if @base.is_nan(f) || @base.is_nan(s) {
      assert_close(osc[i], @base.nan())
    } else {
      assert_close(osc[i], f - s)
    }
  }
}

///|
test "volume functions validate their inputs" {
  assert_eq(err_msg(() => @volume.obv(bars([]))), "input series is empty")
  // Candle validation runs before the period checks.
  assert_eq(
    err_msg(() => @volume.adosc(bars([]), 5, 2)),
    "input series is empty",
  )
  let one = bars([(2.0, 3.0, 1.0, 2.0, 10.0)])
  assert_eq(
    err_msg(() => @volume.adosc(one, 5, 2)),
    "invalid period: fast_period must be smaller than slow_period",
  )
}
