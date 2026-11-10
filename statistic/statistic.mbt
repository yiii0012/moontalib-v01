// Price transforms and rolling utilities (TA-Lib "Statistic Functions" and
// "Price Transform" groups).

///|
/// Applies a per-bar transform of (open, high, low, close); any NaN
/// component maps to NaN.
fn transform(
  candles : @base.Candles,
  f : (Double, Double, Double, Double) -> Double,
) -> Array[Double] raise @base.TaError {
  @base.validate_candles(candles)
  let n = candles.close.length()
  let out : Array[Double] = []
  for i in 0..<n {
    let o = candles.open[i]
    let h = candles.high[i]
    let l = candles.low[i]
    let c = candles.close[i]
    if @base.is_nan(o) || @base.is_nan(h) || @base.is_nan(l) || @base.is_nan(c) {
      out.push(@base.nan())
    } else {
      out.push(f(o, h, l, c))
    }
  }
  out
}

///|
/// Average price: `(open + high + low + close) / 4`.
pub fn avg_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  transform(candles, fn(o : Double, h : Double, l : Double, c : Double) {
    (o + h + l + c) / 4.0
  })
}

///|
/// Median price: `(high + low) / 2`.
pub fn med_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  transform(candles, fn(o : Double, h : Double, l : Double, c : Double) {
    let _o = o
    let _c = c
    (h + l) / 2.0
  })
}

///|
/// Typical price (used by CCI and MFI): `(high + low + close) / 3`.
pub fn typ_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  transform(candles, fn(o : Double, h : Double, l : Double, c : Double) {
    let _o = o
    (h + l + c) / 3.0
  })
}

///|
/// Weighted close price (TA-Lib `WCLPRICE`): `(high + low + 2 * close) / 4`.
pub fn wcl_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  transform(candles, fn(o : Double, h : Double, l : Double, c : Double) {
    let _o = o
    (h + l + 2.0 * c) / 4.0
  })
}

///|
/// Number of leading NaN values produced by `max`/`min`/`sum` for the given
/// period.
pub fn window_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Rolling maximum over a window of `period` values. A NaN inside the window
/// yields NaN.
pub fn max(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  @base.rolling_max(data, period)
}

///|
/// Rolling minimum over a window of `period` values. A NaN inside the window
/// yields NaN.
pub fn min(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  @base.rolling_min(data, period)
}

///|
/// Rolling sum over a window of `period` values. A NaN inside the window
/// yields NaN.
pub fn sum(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let mut acc = 0.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let v = data[j]
      if @base.is_nan(v) {
        valid = false
        break
      }
      acc += v
    }
    if valid {
      out.push(acc)
    } else {
      out.push(@base.nan())
    }
  }
  out
}

///|
/// Rolling extremes over a window: min and max arrays of equal length.
/// A NaN inside the window yields NaN for both.
pub struct MinMaxResult {
  min : Array[Double]
  max : Array[Double]
}

///|
/// Number of leading NaN values produced by `minmax` for the given period.
pub fn minmax_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Rolling minimum and maximum over a window of `period` values, computed in
/// a single pass.
pub fn minmax(
  data : Array[Double],
  period : Int32,
) -> MinMaxResult raise @base.TaError {
  @base.validate_series(data, period)
  let min = @base.rolling_min(data, period)
  let max = @base.rolling_max(data, period)
  { min, max, }
}

///|
/// Number of leading NaN values produced by `avgdev` for the given period.
pub fn avgdev_lookback(period : Int32) -> Int32 {
  period - 1
}

///|
/// Mean absolute deviation over a rolling window:
/// `sum(|x - mean|) / period`. A flat window reads 0; a NaN inside the
/// window yields NaN.
pub fn avgdev(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @base.validate_series(data, period)
  let n = data.length()
  let out : Array[Double] = []
  for i in 0..<n {
    if i < period - 1 {
      out.push(@base.nan())
      continue
    }
    let mut sum = 0.0
    let mut valid = true
    for j in (i - period + 1)..<(i + 1) {
      let v = data[j]
      if @base.is_nan(v) {
        valid = false
        break
      }
      sum += v
    }
    if !valid {
      out.push(@base.nan())
      continue
    }
    let mean = sum / period.to_double()
    let mut dev = 0.0
    for j in (i - period + 1)..<(i + 1) {
      dev += (data[j] - mean).abs()
    }
    out.push(dev / period.to_double())
  }
  out
}
