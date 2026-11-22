// Batch-vs-stream consistency: pushing the 300-bar series bar by bar must
// reproduce the batch outputs exactly (1e-9).

///|
fn pd_check_stream(
  actual : Array[Double],
  expected : Array[Double],
  name : String,
) -> Unit raise {
  if actual.length() != expected.length() {
    fail("\{name}: length mismatch \{actual.length()} vs \{expected.length()}")
  }
  for i in 0..<actual.length() {
    let a = actual[i]
    let b = expected[i]
    if a != a || b != b {
      if !(a != a && b != b) {
        fail("\{name}[\{i}]: expected \{b}, got \{a}")
      }
    } else if (a - b).abs() > 0.000000001 {
      fail("\{name}[\{i}]: expected \{b}, got \{a}")
    }
  }
}

///|
fn zz300() -> Array[Double] {
  let out : Array[Double] = []
  for i in 0..<300 {
    let m = (i % 13).to_double() * 2.0
    let k = (i % 7).to_double() * 1.5
    out.push(100.0 + m - k)
  }
  out
}

///|
test "stream sma matches the batch sma" {
  let data = zz300()
  let stream = @streaming.SmaStream::new(14)
  let acc : Array[Double] = []
  for y in data {
    acc.push(stream.push(y))
  }
  pd_check_stream(acc, @moontalib.sma(data, 14), "sma")
}

///|
test "stream ema matches the batch ema" {
  let data = zz300()
  let stream = @streaming.EmaStream::new(14)
  let acc : Array[Double] = []
  for y in data {
    acc.push(stream.push(y))
  }
  pd_check_stream(acc, @moontalib.ema(data, 14), "ema")
}

///|
test "stream rsi matches the batch rsi" {
  let data = zz300()
  let stream = @streaming.RsiStream::new(14)
  let acc : Array[Double] = []
  for y in data {
    acc.push(stream.push(y))
  }
  pd_check_stream(acc, @moontalib.rsi(data, 14), "rsi")
}

///|
test "stream rsi recovers from nan bars like the batch" {
  let data = zz300()
  data[150] = @base.nan()
  data[151] = @base.nan()
  let stream = @streaming.RsiStream::new(14)
  let acc : Array[Double] = []
  for y in data {
    acc.push(stream.push(y))
  }
  pd_check_stream(acc, @moontalib.rsi(data, 14), "rsi-nan")
}

///|
fn zz_candles(n : Int32) -> @base.Candles {
  let closes = zz300()
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
test "stream stoch matches the batch stoch" {
  let n = 300
  let candles = zz_candles(n)
  let stream = @streaming.StochStream::new(14, k_slowing=3, d_period=3)
  let ks : Array[Double] = []
  let ds : Array[Double] = []
  for i in 0..<n {
    let bar = stream.push(candles.high[i], candles.low[i], candles.close[i])
    ks.push(bar.k)
    ds.push(bar.d)
  }
  let batch = @moontalib.stoch(candles, 14, k_slowing=3, d_period=3)
  pd_check_stream(ks, batch.k, "stoch k")
  pd_check_stream(ds, batch.d, "stoch d")
}

///|
test "stream atr matches the batch atr" {
  let n = 300
  let candles = zz_candles(n)
  let stream = @streaming.AtrStream::new(14)
  let acc : Array[Double] = []
  for i in 0..<n {
    acc.push(stream.push(candles.high[i], candles.low[i], candles.close[i]))
  }
  pd_check_stream(acc, @moontalib.atr(candles, 14), "atr")
}

///|
test "stream obv matches the batch obv" {
  let n = 300
  let candles = zz_candles(n)
  let stream = @streaming.ObvStream::new()
  let acc : Array[Double] = []
  for i in 0..<n {
    acc.push(stream.push(candles.close[i], candles.volume[i]))
  }
  pd_check_stream(acc, @moontalib.obv(candles), "obv")
}

///|
test "stream bollinger matches the batch bbands" {
  let n = 300
  let candles = zz_candles(n)
  let closes = candles.close
  let stream = @streaming.BollingerStream::new(20)
  let mid : Array[Double] = []
  let up : Array[Double] = []
  let lo : Array[Double] = []
  for i in 0..<n {
    let bar = stream.push(closes[i])
    mid.push(bar.middle)
    up.push(bar.upper)
    lo.push(bar.lower)
  }
  let batch = @moontalib.bbands(closes, 20, ndev=2.0)
  pd_check_stream(mid, batch.middle, "bbands mid")
  pd_check_stream(up, batch.upper, "bbands up")
  pd_check_stream(lo, batch.lower, "bbands lo")
}
