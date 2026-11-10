// Blackbox tests for the O(n) rolling primitives.

///|
fn assert_all_close(
  actual : Array[Double],
  expected : Array[Double],
) -> Unit raise {
  if actual.length() != expected.length() {
    fail("length mismatch: \{actual.length()} vs \{expected.length()}")
  }
  for i in 0..<actual.length() {
    let a = actual[i]
    let b = expected[i]
    if !(a != a && b != b) && !(a != a || b != b) {
      if (a - b).abs() > 0.000000001 {
        fail("index \{i}: expected \{b}, got \{a}")
      }
    }
  }
}

///|
fn nan_prefix(count : Int32, rest : Array[Double]) -> Array[Double] {
  let out : Array[Double] = []
  for _ in 0..<count {
    out.push(@base.nan())
  }
  for v in rest {
    out.push(v)
  }
  out
}

///|
fn[T] r_err_msg(f : () -> T raise @base.TaError) -> String {
  try f() catch {
    e => e.to_string()
  } noraise {
    _ => "no error"
  }
}

///|
test "rolling_max and rolling_min match the window extremes" {
  let data = [3.0, 1.0, 4.0, 1.5, 5.0, 2.0]
  assert_all_close(
    @base.rolling_max(data, 3),
    nan_prefix(2, [4.0, 4.0, 5.0, 5.0]),
  )
  assert_all_close(
    @base.rolling_min(data, 3),
    nan_prefix(2, [1.0, 1.0, 1.5, 1.5]),
  )
}

///|
test "rolling extremes break ties towards the most recent bar" {
  // 2.0 appears at indices 0 and 2 inside the first full window; the value
  // of the max is 2.0 either way, and 1.0 stays the minimum.
  let data = [2.0, 1.0, 2.0, 3.0]
  assert_all_close(@base.rolling_max(data, 3), nan_prefix(2, [2.0, 3.0]))
  assert_all_close(@base.rolling_min(data, 3), nan_prefix(2, [1.0, 1.0]))
}

///|
test "rolling primitives mark NaN windows" {
  let data = [1.0, @base.nan(), 3.0, 4.0, 5.0]
  let mx = @base.rolling_max(data, 3)
  assert_eq(@base.is_nan(mx[0]), true)
  assert_eq(@base.is_nan(mx[1]), true)
  assert_eq(@base.is_nan(mx[2]), true)
  assert_eq(@base.is_nan(mx[3]), true)
  assert_eq(mx[4], 5.0)
}

///|
test "rolling primitives reject degenerate periods" {
  let data = [1.0, 2.0]
  assert_eq(
    r_err_msg(() => @base.rolling_max(data, 0)),
    "invalid period: period must be positive, got 0",
  )
  assert_eq(
    r_err_msg(() => @base.rolling_min(data, 3)),
    "not enough data: period 3 exceeds input length 2",
  )
}

///|
test "rolling argmax and argmin report the most recent extreme index" {
  let data = [1.0, 3.0, 2.0, 3.0, 1.0]
  assert_eq(@base.rolling_argmax(data, 3), [-1, -1, 1, 3, 3])
  assert_eq(@base.rolling_argmin(data, 3), [-1, -1, 0, 2, 4])
}
