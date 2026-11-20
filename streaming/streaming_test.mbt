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
