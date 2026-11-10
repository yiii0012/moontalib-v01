// Benchmark harness: runs the window-scanning indicators over a large
// synthetic series and prints per-indicator checksums. Timing is done
// externally (bash `time`), so the harness only guarantees a fixed,
// deterministic workload.

///|
fn bench_candles(n : Int32) -> @base.Candles {
  let open : Array[Double] = []
  let high : Array[Double] = []
  let low : Array[Double] = []
  let close : Array[Double] = []
  let volume : Array[Double] = []
  let mut prev = 100.0
  for i in 0..<n {
    let t = i.to_double()
    let price = 100.0 +
      12.0 * @math.sin(t / 7.0) +
      3.0 * @math.sin(t / 3.1) +
      t * 0.05
    let o = prev
    let c = price
    let body_top = if o > c { o } else { c }
    let body_bottom = if o < c { o } else { c }
    open.push(o)
    high.push(body_top + 0.4 + 1.5 * @math.sin(t * 1.7).abs())
    low.push(body_bottom - 0.4 - 1.5 * @math.cos(t * 1.3).abs())
    close.push(c)
    volume.push(900.0 + 700.0 * @math.sin(t / 4.7) + 20.0 * t)
    prev = c
  }
  { open, high, low, close, volume, }
}

///|
fn checksum(name : String, arr : Array[Double]) -> Unit {
  let mut acc = 0.0
  for v in arr {
    if v == v {
      acc += v
    }
  }
  println("\{name} n=\{arr.length()} checksum=\{acc}")
}

///|
fn run_bench(n : Int32) -> Unit raise @base.TaError {
  let candles = bench_candles(n)
  let closes = candles.close
  let period = 200
  // O(n*period) window-scan indicators (the optimization targets)
  checksum("sma", @moontalib.sma(closes, period))
  checksum("sum", @moontalib.sum(closes, period))
  checksum("wma", @moontalib.wma(closes, period))
  checksum("stddev", @moontalib.stddev(closes, period))
  checksum("vwma", @moontalib.vwma(closes, candles.volume, period))
  checksum("cmo", @moontalib.cmo(closes, period))
  checksum("mfi", @moontalib.mfi(candles, period))
  checksum("ultosc", @moontalib.ultosc(candles, p1=10, p2=20, p3=period))
  checksum("correl", @moontalib.correl(closes, candles.high, period))
  checksum("linearreg", @moontalib.linearreg(closes, period))
  checksum("cci", @moontalib.cci(candles, period))
  checksum("avgdev", @moontalib.avgdev(closes, period))
  // multi-output
  let bb = @moontalib.bbands(closes, period, ndev=2.0)
  checksum("bbands_mid", bb.middle)
  // O(n) references for comparison
  checksum("ema", @moontalib.ema(closes, period))
  checksum("atr", @moontalib.atr(candles, period))
  checksum("max", @moontalib.max(closes, period))
}

///|
fn main {
  let n = 100000
  println("bench start: n=\{n} period=50")
  try run_bench(n) catch {
    e => println("bench failed: \{e.to_string()}")
  } noraise {
    _ => println("bench done")
  }
}
