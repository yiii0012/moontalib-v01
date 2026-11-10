/// moontalib demo: computes a battery of indicators over 120 synthetic
/// OHLCV bars and prints the last rows as a fixed-width table.
///
/// Run with `moon run cmd/demo` from the project root.

///|
/// Fixed-width 2-decimal formatting; NaN renders as "n/a".
fn fmt2(x : Double) -> String {
  if x != x {
    return "n/a"
  }
  let scaled = if x < 0.0 { -x * 100.0 } else { x * 100.0 }
  let units = (scaled + 0.5).floor().to_int()
  let int_part = units / 100
  let frac = units % 100
  let sign = if x < 0.0 { "-" } else { " " }
  let frac_text = if frac < 10 { "0\{frac}" } else { "\{frac}" }
  "\{sign}\{int_part}.\{frac_text}"
}

///|
fn pad(text : String, width : Int32) -> String {
  let mut out = text
  while out.length() < width {
    out = " " + out
  }
  out
}

///|
/// Deterministic pseudo-market: a smooth sine mix plus a mild drift, so
/// every run prints the same table and stays easy to eyeball.
fn demo_candles(count : Int32) -> @base.Candles {
  let open : Array[Double] = []
  let high : Array[Double] = []
  let low : Array[Double] = []
  let close : Array[Double] = []
  let volume : Array[Double] = []
  let mut prev_close = 100.0
  for i in 0..<count {
    let t = i.to_double()
    let price = 100.0 +
      12.0 * @math.sin(t / 7.0) +
      3.0 * @math.sin(t / 3.1) +
      t * 0.18
    let o = prev_close
    let c = price
    let up_wick = 0.4 + 1.5 * @math.sin(t * 1.7).abs()
    let down_wick = 0.4 + 1.5 * @math.cos(t * 1.3).abs()
    let body_top = if o > c { o } else { c }
    let body_bottom = if o < c { o } else { c }
    let v = 900.0 + 700.0 * @math.sin(t / 4.7) + 40.0 * t
    open.push(o)
    high.push(body_top + up_wick)
    low.push(body_bottom - down_wick)
    close.push(c)
    volume.push(v)
    prev_close = c
  }
  { open, high, low, close, volume, }
}

///|
fn run_demo() -> Unit raise @base.TaError {
  let candles = demo_candles(120)
  let closes = candles.close
  let sma10 = @moontalib.sma(closes, 10)
  let ema12 = @moontalib.ema(closes, 12)
  let rsi14 = @moontalib.rsi(closes, 14)
  let bb = @moontalib.bbands(closes, 20, ndev=2.0)
  let macd_out = @moontalib.macd(closes, 12, 26, 9)
  let st = @moontalib.stoch(candles, 14, k_slowing=3, d_period=3)
  let atr14 = @moontalib.atr(candles, 14)
  let adx14 = @moontalib.adx(candles, 14)
  let mfi14 = @moontalib.mfi(candles, 14)
  let n = candles.length()
  println(
    "moontalib demo — \{n} synthetic bars, one @moontalib import, nine indicators",
  )
  println("")
  println(
    "   bar |   close |   SMA10 |   EMA12 |   RSI14 |  BB.mid |  BB.up |   MACD |  STOCHK |   ATR14 |   ADX14 |   MFI14",
  )
  println(
    "  -----+---------+---------+---------+---------+---------+--------+--------+---------+---------+---------+--------",
  )
  let start = n - 15
  for i in start..<n {
    let mut line = pad("\{i}", 6)
    line = line + " |" + pad(fmt2(candles.close[i]), 8)
    line = line + " |" + pad(fmt2(sma10[i]), 8)
    line = line + " |" + pad(fmt2(ema12[i]), 8)
    line = line + " |" + pad(fmt2(rsi14[i]), 8)
    line = line + " |" + pad(fmt2(bb.middle[i]), 8)
    line = line + " |" + pad(fmt2(bb.upper[i]), 7)
    line = line + " |" + pad(fmt2(macd_out.macd[i]), 7)
    line = line + " |" + pad(fmt2(st.k[i]), 8)
    line = line + " |" + pad(fmt2(atr14[i]), 8)
    line = line + " |" + pad(fmt2(adx14.adx[i]), 8)
    line = line + " |" + pad(fmt2(mfi14[i]), 8)
    println(line)
  }
  println("")
  println("Every output has the same length as the input; positions before an")
  println("indicator's lookback window are NaN and render as \"n/a\".")
  println("")
  // Second panel: trend and regression indicators over the same bars.
  let aroon14 = @moontalib.aroon(candles, 14)
  let osc14 = @moontalib.aroonosc(candles, 14)
  let ult = @moontalib.ultosc(candles, p1=7, p2=14, p3=28)
  let slope14 = @moontalib.linearreg_slope(closes, 14)
  let tsf14 = @moontalib.tsf(closes, 14)
  println("trend / regression panel — same 120 bars")
  println("")
  println(
    "   bar |   ADX14 |    +DI |     DX |  AROON | AROONOSC |  ULTOSC | LRSLOPE |   TSF14",
  )
  println(
    "  -----+---------+--------+--------+--------+----------+---------+---------+--------",
  )
  for i in start..<n {
    let mut line = pad("\{i}", 6)
    line = line + " |" + pad(fmt2(adx14.adx[i]), 8)
    line = line + " |" + pad(fmt2(adx14.plus_di[i]), 7)
    line = line + " |" + pad(fmt2(adx14.dx[i]), 7)
    line = line + " |" + pad(fmt2(aroon14.up[i]), 7)
    line = line + " |" + pad(fmt2(osc14[i]), 9)
    line = line + " |" + pad(fmt2(ult[i]), 8)
    line = line + " |" + pad(fmt2(slope14[i]), 8)
    line = line + " |" + pad(fmt2(tsf14[i]), 7)
    println(line)
  }
}

///|
fn main {
  try run_demo() catch {
    e => println("demo failed: \{e.to_string()}")
  } noraise {
    _ => ()
  }
}
