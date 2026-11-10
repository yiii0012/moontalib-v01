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

///|
fn assert_between(v : Double, lo : Double, hi : Double) -> Unit raise {
  if v != v {
    return
  }
  if v < lo || v > hi {
    fail("value \{v} outside [\{lo}, \{hi}]")
  }
}

///|
/// Deterministic zig-zag close series with no external dependencies.
fn zigzag(n : Int32) -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<n {
    let m = (i % 13).to_double() * 2.0
    let k = (i % 7).to_double() * 1.5
    out.push(100.0 + m - k)
  }
  out
}

///|
fn zigzag_candles(n : Int32) -> @base.Candles {
  let closes = zigzag(n)
  let open : Array[Double] = []
  let high : Array[Double] = []
  let low : Array[Double] = []
  let close : Array[Double] = []
  let volume : Array[Double] = []
  for i in 0..<n {
    let prev = if i == 0 { closes[0] } else { closes[i - 1] }
    open.push(prev)
    close.push(closes[i])
    high.push(if closes[i] > prev { closes[i] + 1.0 } else { prev + 1.0 })
    low.push(if closes[i] < prev { closes[i] - 1.0 } else { prev - 1.0 })
    volume.push(10.0 + i.to_double())
  }
  let candles : @base.Candles = { open, high, low, close, volume, }
  candles
}

///|
test "invariant: bollinger middle is exactly the sma" {
  let closes = zigzag(40)
  let bb = @moontalib.bbands(closes, 10, ndev=2.0)
  let sma10 = @moontalib.sma(closes, 10)
  for i in 9..<40 {
    assert_close(bb.middle[i], sma10[i])
  }
}

///|
test "invariant: oscillators stay inside their bounds" {
  let candles = zigzag_candles(60)
  let closes = candles.close
  let rsi14 = @moontalib.rsi(closes, 14)
  let willr14 = @moontalib.willr(candles, 14)
  let st = @moontalib.stoch(candles, 14, k_slowing=3, d_period=3)
  let ar = @moontalib.aroon(candles, 14)
  let osc = @moontalib.aroonosc(candles, 14)
  for i in 14..<60 {
    assert_between(rsi14[i], 0.0, 100.0)
    assert_between(willr14[i], -100.0, 0.0)
    assert_between(st.k[i], 0.0, 100.0)
    assert_between(ar.up[i], 0.0, 100.0)
    assert_between(ar.down[i], 0.0, 100.0)
    assert_between(osc[i], -100.0, 100.0)
  }
}

///|
test "invariant: obv moves by the bar volume or not at all" {
  let candles = zigzag_candles(40)
  let out = @moontalib.obv(candles)
  for i in 1..<40 {
    let step = out[i] - out[i - 1]
    let v = candles.volume[i]
    if !(step == v || step == -v || step == 0.0) {
      fail("bad obv step at \{i}: \{step}")
    }
  }
}

///|
test "invariant: aroonosc is the aroon spread" {
  let candles = zigzag_candles(40)
  let r = @moontalib.aroon(candles, 14)
  let osc = @moontalib.aroonosc(candles, 14)
  for i in 14..<40 {
    assert_close(osc[i], r.up[i] - r.down[i])
  }
}

///|
test "smoke: the whole facade runs over a 300-bar series" {
  let n = 300
  let candles = zigzag_candles(n)
  let closes = candles.close
  let outputs = [
    @moontalib.sma(closes, 20),
    @moontalib.ema(closes, 20),
    @moontalib.wma(closes, 20),
    @moontalib.hma(closes, 20),
    @moontalib.dema(closes, 20),
    @moontalib.tema(closes, 20),
    @moontalib.rsi(closes, 14),
    @moontalib.roc(closes, 10),
    @moontalib.mom(closes, 10),
    @moontalib.cmo(closes, 14),
    @moontalib.trix(closes, 10),
    @moontalib.stddev(closes, 20),
    @moontalib.variance(closes, 20),
    @moontalib.avgdev(closes, 20),
    @moontalib.max(closes, 20),
    @moontalib.min(closes, 20),
    @moontalib.sum(closes, 20),
    @moontalib.linearreg_slope(closes, 20),
    @moontalib.linearreg_intercept(closes, 20),
    @moontalib.linearreg(closes, 20),
    @moontalib.linearreg_angle(closes, 20),
    @moontalib.tsf(closes, 20),
    @moontalib.obv(candles),
    @moontalib.ad(candles),
    @moontalib.tr_range(candles),
    @moontalib.bop(candles),
    @moontalib.dx(candles, 14),
    @moontalib.aroonosc(candles, 14),
    @moontalib.avg_price(candles),
    @moontalib.med_price(candles),
    @moontalib.typ_price(candles),
    @moontalib.wcl_price(candles),
    @moontalib.mfi(candles, 14),
    @moontalib.willr(candles, 14),
    @moontalib.cci(candles, 14),
    @moontalib.atr(candles, 14),
    @moontalib.natr(candles, 14),
    @moontalib.adosc(candles, 5, 20),
  ]
  for out in outputs {
    assert_eq(out.length(), n)
  }
  let bb = @moontalib.bbands(closes, 20, ndev=2.0)
  let md = @moontalib.macd(closes, 12, 26, 9)
  let st = @moontalib.stoch(candles, 14, k_slowing=3, d_period=3)
  let sf = @moontalib.stochf(candles, 14, d_period=3)
  let adxr = @moontalib.adx(candles, 14)
  let ar = @moontalib.aroon(candles, 14)
  let mm = @moontalib.minmax(closes, 20)
  assert_eq(bb.upper.length(), n)
  assert_eq(md.hist.length(), n)
  assert_eq(st.d.length(), n)
  assert_eq(sf.k.length(), n)
  assert_eq(adxr.dx.length(), n)
  assert_eq(ar.up.length(), n)
  assert_eq(mm.max.length(), n)
  assert_eq(@moontalib.apo(closes, 5, 20, ma_type=@base.Ema).length(), n)
  assert_eq(@moontalib.ppo(closes, 5, 20, ma_type=@base.Sma).length(), n)
  assert_eq(@moontalib.vwma(closes, candles.volume, 20).length(), n)
  // last-bar finiteness spot checks after the warmup windows
  assert_eq(@base.is_nan(@moontalib.sma(closes, 20)[n - 1]), false)
  assert_eq(@base.is_nan(@moontalib.rsi(closes, 14)[n - 1]), false)
  assert_eq(@base.is_nan(@moontalib.atr(candles, 14)[n - 1]), false)
  assert_eq(@base.is_nan(adxr.adx[n - 1]), false)
  assert_eq(@base.is_nan(ar.up[n - 1]), false)
  assert_eq(@base.is_nan(@moontalib.mfi(candles, 14)[n - 1]), false)
  assert_eq(@base.is_nan(@moontalib.tsf(closes, 20)[n - 1]), false)
}
