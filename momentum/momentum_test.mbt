// Blackbox tests for the momentum family. Expected values are hand-computed
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
test "rsi uses Wilder smoothing from an SMA seed" {
  let out = @momentum.rsi([1.0, 2.0, 3.0, 2.0, 4.0], 3)
  assert_all_close(out, nan_prefix(3, [66.66666666666667, 83.33333333333333]))
  assert_eq(@momentum.rsi_lookback(3), 3)
}

///|
test "rsi reads 100 for a rising and for a flat window" {
  let rising = @momentum.rsi([1.0, 2.0, 3.0, 4.0, 5.0], 3)
  assert_all_close(rising, nan_prefix(3, [100.0, 100.0]))
  let flat = @momentum.rsi([2.0, 2.0, 2.0, 2.0, 2.0], 3)
  assert_all_close(flat, nan_prefix(3, [100.0, 100.0]))
}

///|
test "macd decomposes into line, signal and histogram" {
  let m = @momentum.macd([1.0, 2.0, 3.0, 4.0, 5.0], 2, 4, 2)
  assert_all_close(m.macd, nan_prefix(3, [1.0, 1.0]))
  assert_all_close(m.signal, nan_prefix(4, [1.0]))
  assert_all_close(m.hist, nan_prefix(4, [0.0]))
  assert_eq(@momentum.macd_lookback(4, 2), 4)
}

///|
test "macd line equals the difference of the two public EMAs" {
  let data = [
    3.0, 5.0, 4.0, 8.0, 7.0, 9.0, 12.0, 11.0, 14.0, 13.0, 15.0, 17.0, 16.0, 19.0,
  ]
  let m = @momentum.macd(data, 3, 6, 3)
  let e_fast = @overlap.ema(data, 3)
  let e_slow = @overlap.ema(data, 6)
  for i in 0..<data.length() {
    let f = e_fast[i]
    let s = e_slow[i]
    if @base.is_nan(f) || @base.is_nan(s) {
      assert_close(m.macd[i], @base.nan())
    } else {
      assert_close(m.macd[i], f - s)
    }
  }
}

///|
test "macd rejects a fast period that is not smaller than the slow one" {
  assert_eq(
    err_msg(() => @momentum.macd([1.0, 2.0, 3.0, 4.0], 4, 4, 2)),
    "invalid period: fast_period must be smaller than slow_period",
  )
}

///|
test "roc measures percent change over the period" {
  let out = @momentum.roc([1.0, 2.0, 4.0, 8.0], 2)
  assert_all_close(out, nan_prefix(2, [300.0, 300.0]))
}

///|
test "mom measures absolute change over the period" {
  let out = @momentum.mom([1.0, 2.0, 4.0, 8.0], 2)
  assert_all_close(out, nan_prefix(2, [3.0, 6.0]))
}

///|
test "cmo normalizes net up/down movement" {
  let out = @momentum.cmo([1.0, 2.0, 3.0, 2.0, 4.0], 3)
  assert_all_close(out, nan_prefix(3, [33.333333333333336, 50.0]))
}

///|
test "willr mirrors the raw stochastic below zero" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 4.0, 1.0, 3.0, 20.0),
    (3.0, 5.0, 2.0, 4.0, 30.0),
  ])
  let out = @momentum.willr(candles, 2)
  assert_all_close(out, nan_prefix(1, [-33.33333333333333, -25.0]))
}

///|
test "stochf returns raw %K and its SMA" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 4.0, 1.0, 3.0, 20.0),
    (3.0, 5.0, 2.0, 4.0, 30.0),
  ])
  let s = @momentum.stochf(candles, 2, d_period=2)
  assert_all_close(s.k, nan_prefix(1, [66.66666666666667, 75.0]))
  assert_all_close(s.d, nan_prefix(2, [70.83333333333333]))
}

///|
test "stoch slows %K before averaging into %D" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 4.0, 1.0, 3.0, 20.0),
    (3.0, 5.0, 2.0, 4.0, 30.0),
    (3.0, 6.0, 2.0, 5.0, 40.0),
    (4.0, 6.0, 3.0, 4.0, 50.0),
  ])
  let s = @momentum.stoch(candles, 2, k_slowing=2, d_period=2)
  assert_all_close(s.k, nan_prefix(2, [70.83333333333333, 75.0, 62.5]))
  assert_all_close(s.d, nan_prefix(3, [72.91666666666667, 68.75]))
  assert_eq(@momentum.stoch_lookback(2, 2, 2), 3)
}

///|
test "cci normalizes the typical price deviation" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (3.0, 4.0, 2.0, 3.0, 20.0),
    (4.0, 5.0, 3.0, 4.0, 30.0),
    (5.0, 6.0, 4.0, 5.0, 40.0),
  ])
  let out = @momentum.cci(candles, 3)
  assert_all_close(out, nan_prefix(2, [100.0, 100.0]))
}

///|
test "trix is the percent rate of change of the triple EMA" {
  let out = @momentum.trix([2.0, 4.0, 6.0, 8.0, 12.0], 2)
  assert_all_close(out, nan_prefix(4, [51.85185185185185]))
  assert_eq(@momentum.trix_lookback(2), 4)
}

///|
test "adx tracks the strength of the trend direction" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 5.0, 2.0, 4.0, 20.0),
    (3.5, 4.0, 3.0, 3.5, 30.0),
    (3.5, 6.0, 4.0, 5.0, 40.0),
    (4.0, 5.0, 3.0, 4.0, 50.0),
  ])
  let r = @momentum.adx(candles, 2)
  assert_all_close(
    r.plus_di,
    nan_prefix(2, [50.0, 66.66666666666667, 35.294117647058826]),
  )
  assert_all_close(r.minus_di, nan_prefix(2, [0.0, 0.0, 23.529411764705884]))
  assert_all_close(r.adx, nan_prefix(3, [100.0, 60.0]))
  assert_eq(@momentum.adx_lookback(2), 3)
}

///|
test "apo subtracts the slow MA from the fast one" {
  let out = @momentum.apo([2.0, 4.0, 6.0, 8.0, 12.0], 2, 3, ma_type=@base.Sma)
  assert_all_close(out, nan_prefix(2, [1.0, 1.0, 1.3333333333333333]))
}

///|
test "ppo scales the MA spread by the slow MA" {
  let out = @momentum.ppo([2.0, 4.0, 6.0, 8.0, 12.0], 2, 3, ma_type=@base.Sma)
  assert_all_close(
    out,
    nan_prefix(2, [25.0, 16.666666666666668, 15.384615384615385]),
  )
}

///|
test "momentum functions validate their inputs" {
  assert_eq(err_msg(() => @momentum.rsi([], 3)), "input series is empty")
  // Candle validation runs before the period checks.
  assert_eq(
    err_msg(() => @momentum.stochf(bars([]), 2, d_period=0)),
    "input series is empty",
  )
  let one = bars([(2.0, 3.0, 1.0, 2.0, 10.0)])
  assert_eq(
    err_msg(() => @momentum.stochf(one, 2, d_period=0)),
    "invalid period: all periods must be positive",
  )
}

///|
test "bop measures open-to-close power within the bar range" {
  let candles = bars([
    (1.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 4.0, 2.0, 3.0, 20.0),
    (3.0, 3.0, 2.0, 2.5, 30.0),
    (2.0, 2.0, 2.0, 2.0, 40.0),
  ])
  let out = @momentum.bop(candles)
  assert_all_close(out, [0.5, 0.5, -0.5, 0.0])
}

///|
test "aroon tracks the recency of the extremes" {
  let candles = bars([
    (1.0, 1.0, 1.0, 1.0, 10.0),
    (1.0, 3.0, 2.0, 2.0, 20.0),
    (2.0, 2.0, 1.0, 1.5, 30.0),
    (2.0, 5.0, 3.0, 4.0, 40.0),
    (4.0, 4.0, 2.0, 3.0, 50.0),
    (5.0, 6.0, 2.0, 5.0, 60.0),
  ])
  let r = @momentum.aroon(candles, 3)
  assert_all_close(r.up, nan_prefix(3, [100.0, 66.66666666666667, 100.0]))
  assert_all_close(
    r.down,
    nan_prefix(3, [66.66666666666667, 33.333333333333336, 0.0]),
  )
  assert_eq(@momentum.aroon_lookback(3), 3)
}

///|
test "aroon breaks ties towards the most recent extreme" {
  let candles = bars([
    (1.0, 1.0, 1.0, 1.0, 10.0),
    (1.0, 3.0, 1.0, 2.0, 20.0),
    (2.0, 2.0, 1.0, 1.5, 30.0),
    (2.0, 3.0, 1.0, 2.5, 40.0),
  ])
  let r = @momentum.aroon(candles, 3)
  // highest high 3 appears at indices 1 and 3; the most recent wins
  assert_all_close(r.up, nan_prefix(3, [100.0]))
  assert_all_close(r.down, nan_prefix(3, [100.0]))
}

///|
test "aroonosc is the aroon up-down spread" {
  let candles = bars([
    (1.0, 1.0, 1.0, 1.0, 10.0),
    (1.0, 3.0, 2.0, 2.0, 20.0),
    (2.0, 2.0, 1.0, 1.5, 30.0),
    (2.0, 5.0, 3.0, 4.0, 40.0),
    (4.0, 4.0, 2.0, 3.0, 50.0),
    (5.0, 6.0, 2.0, 5.0, 60.0),
  ])
  let out = @momentum.aroonosc(candles, 3)
  assert_all_close(
    out,
    nan_prefix(3, [33.33333333333333, 33.33333333333333, 100.0]),
  )
  assert_eq(@momentum.aroonosc_lookback(3), 3)
}

///|
test "ultosc blends three buying-pressure ratios" {
  let candles = bars([
    (1.0, 2.0, 1.0, 1.5, 10.0),
    (2.0, 3.0, 1.0, 2.5, 20.0),
    (2.5, 3.0, 2.0, 2.0, 30.0),
    (2.0, 4.0, 2.0, 3.5, 40.0),
    (3.5, 5.0, 3.0, 4.0, 50.0),
    (4.0, 4.0, 2.0, 3.0, 60.0),
  ])
  let out = @momentum.ultosc(candles, p1=2, p2=3, p3=4)
  assert_all_close(out, nan_prefix(4, [58.16326530612245, 52.38095238095238]))
  assert_eq(@momentum.ultosc_lookback(4), 4)
}

///|
test "ultosc validates the period ordering" {
  assert_eq(
    err_msg(() => @momentum.ultosc(bars([]), p1=3, p2=2, p3=1)),
    "input series is empty",
  )
  let one = bars([(1.0, 3.0, 1.0, 2.0, 10.0)])
  assert_eq(
    err_msg(() => @momentum.ultosc(one, p1=3, p2=2, p3=1)),
    "invalid period: periods must satisfy p1 <= p2 <= p3",
  )
}

///|
test "dx is the raw ratio that adx smooths" {
  let candles = bars([
    (2.0, 3.0, 1.0, 2.0, 10.0),
    (2.0, 5.0, 2.0, 4.0, 20.0),
    (3.5, 4.0, 3.0, 3.5, 30.0),
    (3.5, 6.0, 4.0, 5.0, 40.0),
    (4.0, 5.0, 3.0, 4.0, 50.0),
  ])
  let out = @momentum.dx(candles, 2)
  assert_all_close(out, nan_prefix(2, [100.0, 100.0, 20.0]))
  // the dx field inside the adx result matches the standalone function
  let r = @momentum.adx(candles, 2)
  assert_all_close(r.dx, out)
  assert_eq(@momentum.dx_lookback(2), 2)
}
