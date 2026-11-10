// Blackbox tests for the O(n) rolling sum.

///|
fn naive_window_sum(data : Array[Double], i : Int32, p : Int32) -> Double {
  let mut s = 0.0
  for j in (i - p + 1)..<(i + 1) {
    s += data[j]
  }
  s
}

///|
test "rolling_sum matches the naive window sum" {
  let data = [3.0, 1.0, 4.0, 1.5, 5.0, 2.0, 0.5, 7.0]
  for p in [2, 3, 5] {
    let out = @base.rolling_sum(data, p)
    for i in (p - 1)..<data.length() {
      let expected = naive_window_sum(data, i, p)
      let diff = (out[i] - expected).abs()
      if diff > 0.000000001 {
        fail("p=\{p} index \{i}: expected \{expected}, got \{out[i]}")
      }
    }
  }
}

///|
test "rolling_sum yields NaN for NaN windows and recovers" {
  let data = [1.0, @base.nan(), 3.0, 4.0, 5.0]
  let out = @base.rolling_sum(data, 3)
  assert_eq(@base.is_nan(out[0]), true)
  assert_eq(@base.is_nan(out[1]), true)
  assert_eq(@base.is_nan(out[2]), true)
  assert_eq(@base.is_nan(out[3]), true)
  assert_eq(out[4], 12.0)
}

///|
test "rolling_sum output length matches input and prefix is NaN" {
  let data = [1.0, 2.0, 3.0]
  let out = @base.rolling_sum(data, 2)
  assert_eq(out.length(), 3)
  assert_eq(@base.is_nan(out[0]), true)
  assert_eq(out[1], 3.0)
  assert_eq(out[2], 5.0)
}

///|
test "rolling_sum rejects degenerate periods" {
  let data = [1.0, 2.0]
  assert_eq(
    r_err_msg(() => @base.rolling_sum(data, 0)),
    "invalid period: period must be positive, got 0",
  )
  assert_eq(
    r_err_msg(() => @base.rolling_sum(data, 3)),
    "not enough data: period 3 exceeds input length 2",
  )
}
