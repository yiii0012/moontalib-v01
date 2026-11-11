// Ichimoku Kinko Hyo (一目均衡表): five lines derived from rolling
// high/low midpoints and displacements. All lines are O(n) via the base
// rolling primitives.

///|
/// Ichimoku decomposition: tenkan, kijun, senkou_a, senkou_b and chikou,
/// all of input length with NaN outside their valid ranges.
pub struct IchimokuResult {
  tenkan : Array[Double]
  kijun : Array[Double]
  senkou_a : Array[Double]
  senkou_b : Array[Double]
  chikou : Array[Double]
}

///|
/// Number of leading NaN values of the tenkan/kijun lines for their periods.
pub fn ichimoku_lookback(tenkan : Int32, kijun : Int32) -> Int32 {
  if kijun > tenkan {
    kijun - 1
  } else {
    tenkan - 1
  }
}

///|
/// Ichimoku Kinko Hyo.
///
/// - `tenkan[i] = (hh(tenkan) + ll(tenkan)) / 2` over the last `tenkan` bars;
/// - `kijun[i]` mirrors it over `kijun` bars;
/// - `senkou_a[i] = (tenkan[i - displacement] + kijun[i - displacement]) / 2`
///   (the midpoint computed `displacement` bars ago, plotted forward);
/// - `senkou_b[i] = (hh(senkou) + ll(senkou)) / 2` from the window ending
///   `displacement` bars ago;
/// - `chikou[i] = close[i + displacement]` (the close plotted backward).
///
/// All lines share the flat-window and NaN rules of the rolling extremes.
pub fn ichimoku(
  candles : @base.Candles,
  tenkan~ : Int32,
  kijun~ : Int32,
  senkou~ : Int32,
  displacement~ : Int32,
) -> IchimokuResult raise @base.TaError {
  @base.validate_candles(candles)
  if tenkan <= 0 || kijun <= 0 || senkou <= 0 || displacement < 0 {
    raise @base.InvalidPeriod(
      "periods must be positive and displacement non-negative",
    )
  }
  let n = candles.close.length()
  let hh_t = @base.rolling_max(candles.high, tenkan)
  let ll_t = @base.rolling_min(candles.low, tenkan)
  let hh_k = @base.rolling_max(candles.high, kijun)
  let ll_k = @base.rolling_min(candles.low, kijun)
  let hh_s = @base.rolling_max(candles.high, senkou)
  let ll_s = @base.rolling_min(candles.low, senkou)
  let tenkan_line : Array[Double] = []
  let kijun_line : Array[Double] = []
  for i in 0..<n {
    tenkan_line.push((hh_t[i] + ll_t[i]) / 2.0)
    kijun_line.push((hh_k[i] + ll_k[i]) / 2.0)
  }
  let senkou_a : Array[Double] = []
  let senkou_b : Array[Double] = []
  let chikou : Array[Double] = []
  for i in 0..<n {
    if i < displacement {
      senkou_a.push(@base.nan())
      senkou_b.push(@base.nan())
    } else {
      senkou_a.push(
        (tenkan_line[i - displacement] + kijun_line[i - displacement]) / 2.0,
      )
      senkou_b.push((hh_s[i - displacement] + ll_s[i - displacement]) / 2.0)
    }
    if i + displacement < n {
      chikou.push(candles.close[i + displacement])
    } else {
      chikou.push(@base.nan())
    }
  }
  { tenkan: tenkan_line, kijun: kijun_line, senkou_a, senkou_b, chikou, }
}
