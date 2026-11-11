// Blackbox tests for the Ichimoku system (bars helper shared with ma_test).

///|
test "ichimoku lines match hand-computed values" {
  let candles = bars([
    (1.0, 2.0, 1.0, 1.5, 10.0),
    (1.5, 4.0, 2.0, 3.0, 20.0),
    (3.0, 3.0, 1.0, 2.0, 30.0),
    (2.0, 6.0, 3.0, 5.0, 40.0),
    (5.0, 5.0, 2.0, 4.0, 50.0),
    (4.0, 7.0, 4.0, 6.0, 60.0),
    (6.0, 6.0, 3.0, 5.0, 70.0),
    (5.0, 8.0, 5.0, 7.0, 80.0),
  ])
  let r = @overlap.ichimoku(
    candles,
    tenkan=2,
    kijun=3,
    senkou=4,
    displacement=2,
  )
  // tenkan[i] = (hh2 + ll2) / 2, valid from i=1
  assert_all_close(r.tenkan, nan_prefix(1, [2.5, 2.5, 3.5, 4.0, 4.5, 5.0, 5.5]))
  // kijun[i] = (hh3 + ll3) / 2, valid from i=2
  assert_all_close(r.kijun, nan_prefix(2, [2.5, 3.5, 3.5, 4.5, 4.5, 5.5]))
  // senkou_a[i] = (tenkan[i-2] + kijun[i-2]) / 2; kijun is still NaN at
  // i-2 = 1, so senkou_a only becomes finite from i=4
  assert_all_close(r.senkou_a, nan_prefix(4, [2.5, 3.5, 3.75, 4.5]))
  // senkou_b[i] uses the senkou window ending at i-2; hh4/ll4 are valid
  // from i=3, so senkou_b only becomes finite from i=5
  assert_all_close(r.senkou_b, nan_prefix(5, [3.5, 3.5, 4.0]))
  // chikou[i] = close[i + 2], NaN on the last two bars
  assert_all_close(r.chikou, [
    2.0,
    5.0,
    4.0,
    6.0,
    5.0,
    7.0,
    @base.nan(),
    @base.nan(),
  ])
  assert_eq(@overlap.ichimoku_lookback(2, 3), 2)
}
