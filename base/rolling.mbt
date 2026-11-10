// O(n) rolling-window primitives built on monotonic deques.
//
// The deque is an index ring buffer; `last_nan` tracks NaN contamination so
// the outputs match the window-scan semantics used across moontalib: a
// window containing NaN yields NaN (or index -1 for the argmax/argmin
// variants). Ties resolve to the most recent bar, matching the update rules
// of the window-scan implementations.

///|
/// Rolling maximum over a window of `period` values, computed in O(n).
/// Ties resolve to the most recent bar; a window containing NaN yields NaN;
/// the output has the same length as the input with a `period - 1` leading
/// NaN prefix.
pub fn rolling_max(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise TaError {
  guard_period(data, period)
  rolling_extreme(data, period, true)
}

///|
/// Rolling minimum over a window of `period` values, computed in O(n).
pub fn rolling_min(
  data : Array[Double],
  period : Int32,
) -> Array[Double] raise TaError {
  guard_period(data, period)
  rolling_extreme(data, period, false)
}

///|
/// Index of the most recent maximum inside each window (0-based), or -1
/// when the window contains NaN; computed in O(n).
pub fn rolling_argmax(
  data : Array[Double],
  period : Int32,
) -> Array[Int32] raise TaError {
  guard_period(data, period)
  rolling_argextreme(data, period, true)
}

///|
/// Index of the most recent minimum inside each window (0-based), or -1
/// when the window contains NaN; computed in O(n).
pub fn rolling_argmin(
  data : Array[Double],
  period : Int32,
) -> Array[Int32] raise TaError {
  guard_period(data, period)
  rolling_argextreme(data, period, false)
}

///|
/// Shared period validation for the rolling primitives.
fn guard_period(data : Array[Double], period : Int32) -> Unit raise TaError {
  if data.length() == 0 {
    raise EmptyInput
  }
  if period <= 0 {
    raise InvalidPeriod("period must be positive, got \{period}")
  }
  if period > data.length() {
    raise NotEnoughData(
      "period \{period} exceeds input length \{data.length()}",
    )
  }
}

///|
/// Shared monotonic-deque core. `want_max` keeps a value-decreasing
/// candidate deque (max), `want_min` a value-increasing one (min); popping
/// on ties keeps the most recent extreme index.
fn rolling_extreme(
  data : Array[Double],
  period : Int32,
  want_max : Bool,
) -> Array[Double] {
  let n = data.length()
  let out : Array[Double] = []
  let cap = period + 1
  let dq : FixedArray[Int32] = FixedArray::make(cap, 0)
  let mut head = 0
  let mut tail = 0
  let mut size = 0
  let mut last_nan = -1
  for i in 0..<n {
    let v = data[i]
    if is_nan(v) {
      last_nan = i
    } else {
      while size > 0 {
        let back = dq[(tail - 1 + cap) % cap]
        let take = if want_max { data[back] <= v } else { data[back] >= v }
        if take {
          tail = (tail - 1 + cap) % cap
          size -= 1
        } else {
          break
        }
      }
      dq[tail] = i
      tail = (tail + 1) % cap
      size += 1
    }
    while size > 0 && dq[head] < i - period + 1 {
      head = (head + 1) % cap
      size -= 1
    }
    if i < period - 1 || last_nan >= i - period + 1 || size == 0 {
      out.push(nan())
    } else {
      out.push(data[dq[head]])
    }
  }
  out
}

///|
/// Index variant of the monotonic-deque core: the head holds the most
/// recent extreme index; NaN windows report -1.
fn rolling_argextreme(
  data : Array[Double],
  period : Int32,
  want_max : Bool,
) -> Array[Int32] {
  let n = data.length()
  let out : Array[Int32] = []
  let cap = period + 1
  let dq : FixedArray[Int32] = FixedArray::make(cap, 0)
  let mut head = 0
  let mut tail = 0
  let mut size = 0
  let mut last_nan = -1
  for i in 0..<n {
    let v = data[i]
    if is_nan(v) {
      last_nan = i
    } else {
      while size > 0 {
        let back = dq[(tail - 1 + cap) % cap]
        let take = if want_max { data[back] <= v } else { data[back] >= v }
        if take {
          tail = (tail - 1 + cap) % cap
          size -= 1
        } else {
          break
        }
      }
      dq[tail] = i
      tail = (tail + 1) % cap
      size += 1
    }
    while size > 0 && dq[head] < i - period + 1 {
      head = (head + 1) % cap
      size -= 1
    }
    if i < period - 1 || last_nan >= i - period + 1 || size == 0 {
      out.push(-1)
    } else {
      out.push(dq[head])
    }
  }
  out
}
