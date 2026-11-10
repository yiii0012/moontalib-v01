// Blackbox tests for Bollinger Bands and the volume-weighted average.
// Test helpers (is_close, assert_all_close, nan_prefix, err_msg) are shared
// with ma_test.mbt in this package.

///|
test "bbands places the SMA in the middle and ndev sigmas outside" {
  let bb = @overlap.bbands([1.0, 2.0, 3.0, 4.0, 5.0], 3, ndev=1.0)
  // Window stddev of [1,2,3] etc. is sqrt(2/3) ~ 0.816496580927726.
  assert_all_close(bb.middle, nan_prefix(2, [2.0, 3.0, 4.0]))
  assert_all_close(
    bb.upper,
    nan_prefix(2, [2.816496580927726, 3.816496580927726, 4.816496580927726]),
  )
  assert_all_close(
    bb.lower,
    nan_prefix(2, [1.183503419072274, 2.183503419072274, 3.183503419072274]),
  )
  assert_eq(@overlap.bbands_lookback(3), 2)
}

///|
test "bbands marks windows touched by NaN" {
  let bb = @overlap.bbands([1.0, @base.nan(), 3.0, 4.0, 5.0], 3, ndev=1.0)
  assert_all_close(bb.middle, nan_prefix(4, [4.0]))
  assert_all_close(bb.upper, nan_prefix(4, [4.816496580927726]))
  assert_all_close(bb.lower, nan_prefix(4, [3.183503419072274]))
}

///|
test "vwma weights price by volume" {
  let out = @overlap.vwma(
    [1.0, 2.0, 3.0, 4.0, 5.0],
    [1.0, 1.0, 1.0, 2.0, 2.0],
    3,
  )
  // (1+2+3)/3, (2+3+4*2)/4, (3+4*2+5*2)/5
  assert_all_close(out, nan_prefix(2, [2.0, 3.25, 4.2]))
}

///|
test "vwma reports mismatched volume length" {
  assert_eq(
    err_msg(() => @overlap.vwma([1.0, 2.0, 3.0], [1.0, 1.0], 2)),
    "mismatched input lengths: price and volume must have equal lengths",
  )
}

///|
test "vwma yields NaN when the window volume sums to zero" {
  let out = @overlap.vwma([1.0, 2.0, 3.0, 4.0], [0.0, 0.0, 0.0, 0.0], 2)
  assert_all_close(out, nan_prefix(1, [@base.nan(), @base.nan(), @base.nan()]))
}
