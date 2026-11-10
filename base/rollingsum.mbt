// O(n) rolling-window sum.

///|
/// Rolling sum over a window of `period` values, computed in O(n).
///
/// Implemented as a running sum with an exact re-accumulation every
/// `period` bars (and whenever a NaN leaves the window), which bounds
/// floating-point drift to roughly one slide. A window containing NaN
/// yields NaN; the output has the same length as the input with a
/// `period - 1` leading NaN prefix.
pub fn rolling_sum(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise TaError {
  guard_period(data, period)
  let n = data.length()
  let out : Array[Double] = []
  let p = period
  let mut sum = 0.0
  let mut dirty = true
  let mut last_nan = -1
  for i in 0..<n {
    if is_nan(data[i]) {
      last_nan = i
    }
    if i >= p {
      sum += data[i] - data[i - p]
      if is_nan(sum) {
        dirty = true
      }
    } else {
      sum += data[i]
    }
    if i < p - 1 || last_nan >= i - p + 1 {
      out.push(nan())
      dirty = true
    } else {
      if dirty || (i - (p - 1)) % p == 0 {
        // exact re-accumulation bounds drift to at most one slide
        sum = 0.0
        for j in (i - p + 1)..<(i + 1) {
          sum += data[j]
        }
        dirty = false
      }
      out.push(sum)
    }
  }
  out
}
