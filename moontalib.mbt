// moontalib — TA-Lib-style technical analysis indicators for MoonBit.
//
// This root package is a convenience facade: import `yiii0012/moontalib` once
// and reach every indicator through `@moontalib`. Functions delegate to the
// domain subpackages (overlap, momentum, volume, volatility, statistic),
// which can also be imported directly. Types live in `yiii0012/moontalib/base`
// (`@base.Candle`, `@base.Candles`, `@base.TaError`, `@base.MAType`) and the
// multi-output structs in their indicator packages.

// ---------------------------------------------------------------------------
// overlap — moving averages and bands
// ---------------------------------------------------------------------------

///|
/// Simple moving average. See `overlap/ma` for semantics.
pub fn sma(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.sma(data, period)
}

///|
/// Exponential moving average (SMA-seeded, TA-Lib convention).
pub fn ema(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.ema(data, period)
}

///|
/// EMA over a series that only becomes valid at `first_valid`.
pub fn ema_from(
  data : Array[Double],
  period : Int32,
  first_valid : Int32,
) -> Array[Double] {
  @overlap.ema_from(data, period, first_valid)
}

///|
/// Weighted moving average (most recent bar weighted by `period`).
pub fn wma(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.wma(data, period)
}

///|
/// Hull moving average.
pub fn hma(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.hma(data, period)
}

///|
/// Double exponential moving average.
pub fn dema(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.dema(data, period)
}

///|
/// Triple exponential moving average.
pub fn tema(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.tema(data, period)
}

///|
/// Moving average with a selectable flavor (SMA or EMA).
pub fn moving_average(
  data : Array[Double],
  period : Int32,
  ma_type~ : @base.MAType,
) -> Array[Double] raise @base.TaError {
  @overlap.moving_average(data, period, ma_type~)
}

///|
/// Bollinger Bands (population standard deviation over the window).
pub fn bbands(
  data : Array[Double],
  period : Int32,
  ndev~ : Double,
) -> @overlap.BBands raise @base.TaError {
  @overlap.bbands(data, period, ndev~)
}

///|
/// Volume-weighted moving average of `price` weighted by `volume`.
pub fn vwma(
  price : Array[Double],
  volume : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.vwma(price, volume, period)
}

///|
/// Midpoint over a rolling window: `(max + min) / 2`.
pub fn midpoint(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @overlap.midpoint(data, period)
}

// ---------------------------------------------------------------------------
// momentum — oscillators and rate-of-change measures
// ---------------------------------------------------------------------------

///|
/// Relative Strength Index (Wilder smoothing).
pub fn rsi(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @momentum.rsi(data, period)
}

///|
/// Moving Average Convergence/Divergence with signal line and histogram.
pub fn macd(
  data : Array[Double],
  fast_period : Int32,
  slow_period : Int32,
  signal_period : Int32,
) -> @momentum.Macd raise @base.TaError {
  @momentum.macd(data, fast_period, slow_period, signal_period)
}

///|
/// Rate of change in percent over `period` bars.
pub fn roc(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @momentum.roc(data, period)
}

///|
/// Momentum: `close[i] - close[i - period]`.
pub fn mom(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @momentum.mom(data, period)
}

///|
/// Chande Momentum Oscillator.
pub fn cmo(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @momentum.cmo(data, period)
}

///|
/// Williams %R.
pub fn willr(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @momentum.willr(candles, period)
}

///|
/// Stochastic Oscillator (slowed %K, %D = SMA of %K).
pub fn stoch(
  candles : @base.Candles,
  period : Int32,
  k_slowing~ : Int32,
  d_period~ : Int32,
) -> @momentum.Stoch raise @base.TaError {
  @momentum.stoch(candles, period, k_slowing~, d_period~)
}

///|
/// Fast Stochastic: raw %K and its SMA (%D) without slowing.
pub fn stochf(
  candles : @base.Candles,
  period : Int32,
  d_period~ : Int32,
) -> @momentum.Stoch raise @base.TaError {
  @momentum.stochf(candles, period, d_period~)
}

///|
/// Commodity Channel Index.
pub fn cci(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @momentum.cci(candles, period)
}

///|
/// TRIX: percent rate of change of a triple-EMA.
pub fn trix(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @momentum.trix(data, period)
}

///|
/// Average Directional Index with +DI / -DI (Wilder).
pub fn adx(
  candles : @base.Candles,
  period : Int32,
) -> @momentum.AdxResult raise @base.TaError {
  @momentum.adx(candles, period)
}

///|
/// Absolute Price Oscillator: `fast_MA - slow_MA`.
pub fn apo(
  data : Array[Double],
  fast_period : Int32,
  slow_period : Int32,
  ma_type~ : @base.MAType,
) -> Array[Double] raise @base.TaError {
  @momentum.apo(data, fast_period, slow_period, ma_type~)
}

///|
/// Percentage Price Oscillator: `100 * (fast_MA - slow_MA) / slow_MA`.
pub fn ppo(
  data : Array[Double],
  fast_period : Int32,
  slow_period : Int32,
  ma_type~ : @base.MAType,
) -> Array[Double] raise @base.TaError {
  @momentum.ppo(data, fast_period, slow_period, ma_type~)
}

///|
/// Balance of Power: `(close - open) / (high - low)`.
pub fn bop(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @momentum.bop(candles)
}

///|
/// Aroon up/down lines.
pub fn aroon(
  candles : @base.Candles,
  period : Int32,
) -> @momentum.AroonResult raise @base.TaError {
  @momentum.aroon(candles, period)
}

// ---------------------------------------------------------------------------
// volume — volume-based indicators
// ---------------------------------------------------------------------------

///|
/// On-Balance Volume.
pub fn obv(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @volume.obv(candles)
}

///|
/// Money Flow Index.
pub fn mfi(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @volume.mfi(candles, period)
}

///|
/// Chaikin Accumulation/Distribution Line.
pub fn ad(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @volume.ad(candles)
}

///|
/// Chaikin A/D Oscillator: EMA(fast) - EMA(slow) of the A/D line.
pub fn adosc(
  candles : @base.Candles,
  fast_period : Int32,
  slow_period : Int32,
) -> Array[Double] raise @base.TaError {
  @volume.adosc(candles, fast_period, slow_period)
}

// ---------------------------------------------------------------------------
// volatility — range and dispersion measures
// ---------------------------------------------------------------------------

///|
/// True range per bar (`tr_range[i]` matches `base.true_range(candles, i)`).
pub fn tr_range(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @volatility.tr_range(candles)
}

///|
/// Average True Range (Wilder smoothing).
pub fn atr(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @volatility.atr(candles, period)
}

///|
/// Normalized ATR: `100 * ATR / close`.
pub fn natr(
  candles : @base.Candles,
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @volatility.natr(candles, period)
}

///|
/// Population standard deviation over a rolling window.
pub fn stddev(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @volatility.stddev(data, period)
}

///|
/// Population variance over a rolling window.
pub fn variance(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @volatility.variance(data, period)
}

// ---------------------------------------------------------------------------
// statistic — price transforms and rolling utilities
// ---------------------------------------------------------------------------

///|
/// Average price: `(open + high + low + close) / 4`.
pub fn avg_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @statistic.avg_price(candles)
}

///|
/// Median price: `(high + low) / 2`.
pub fn med_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @statistic.med_price(candles)
}

///|
/// Typical price: `(high + low + close) / 3`.
pub fn typ_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @statistic.typ_price(candles)
}

///|
/// Weighted close price: `(high + low + 2 * close) / 4`.
pub fn wcl_price(candles : @base.Candles) -> Array[Double] raise @base.TaError {
  @statistic.wcl_price(candles)
}

///|
/// Rolling maximum over a window.
pub fn max(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @statistic.max(data, period)
}

///|
/// Rolling minimum over a window.
pub fn min(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @statistic.min(data, period)
}

///|
/// Rolling sum over a window.
pub fn sum(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise @base.TaError {
  @statistic.sum(data, period)
}
