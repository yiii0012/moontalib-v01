// Streaming (incremental) indicator evaluators.
//
// push one bar at a time and get the same values the batch functions would
// produce at that index — guaranteed by consistency tests in
// streaming_test.mbt (batch vs stream equality at 1e-9 over a 300-bar
// series).
//
// Semantics (identical to the batch implementations):
// - warmup: pushes before the first full window return NaN
// - NaN bars poison their window exactly like the batch implementations
// - recovery: once the poisoned bars leave the window, values recover
//   exactly (fresh re-accumulation, same position as the batch)
//
// Evaluators: SmaStream, EmaStream, RsiStream, StochStream, AtrStream,
// ObvStream, BollingerStream. Complexity per push: O(1) for every
// evaluator (window sums and monotonic deques are maintained incrementally).

///|
/// Streaming simple moving average. Push one close per bar; returns the
/// mean of the last `period` values (NaN during warmup).
pub struct SmaStream {
  priv period : Int32
  priv ring : FixedArray[Double]
  priv mut head : Int32
  priv mut size : Int32
  priv mut sum : Double
  priv mut dirty : Bool
  priv mut count : Int32
  priv mut last_nan : Int32
}

///|
pub fn SmaStream::new(period : Int32) -> SmaStream {
  {
    period,
    ring: FixedArray::make(period, 0.0),
    head: 0,
    size: 0,
    sum: 0.0,
    dirty: false,
    count: 0,
    last_nan: -1,
  }
}

///|
pub fn SmaStream::push(self : SmaStream, y : Double) -> Double {
  let p = self.period
  self.count += 1
  if self.size == p {
    self.sum -= self.ring[self.head]
    self.head = (self.head + 1) % p
    self.size -= 1
  }
  self.ring[(self.head + self.size) % p] = y
  self.size += 1
  self.sum += y
  if @base.is_nan(y) {
    self.last_nan = self.count - 1
    self.dirty = true
  }
  if self.count < p || self.last_nan >= self.count - p {
    self.dirty = true
    return @base.nan()
  }
  if self.dirty {
    self.sum = 0.0
    for k in 0..<self.size {
      self.sum += self.ring[(self.head + k) % p]
    }
    self.dirty = false
  }
  if self.count > self.last_nan + p && (self.count - p) % p == 0 {
    self.sum = 0.0
    for k in 0..<self.size {
      self.sum += self.ring[(self.head + k) % p]
    }
  }
  self.sum / p.to_double()
}

///|
/// Streaming exponential moving average with the TA-Lib SMA seed: the first
/// `period` pushes warm up (NaN), the next push returns the seed mean, and
/// later pushes recurse with `k = 2 / (period + 1)`.
pub struct EmaStream {
  priv period : Int32
  priv mut sum : Double
  priv mut seeded : Bool
  priv mut prev : Double
  priv mut count : Int32
  priv k : Double
}

///|
pub fn EmaStream::new(period : Int32) -> EmaStream {
  {
    period,
    sum: 0.0,
    seeded: false,
    prev: 0.0,
    count: 0,
    k: 2.0 / (period.to_double() + 1.0),
  }
}

///|
pub fn EmaStream::push(self : EmaStream, y : Double) -> Double {
  self.count += 1
  if !self.seeded {
    self.sum += y
    if self.count == self.period {
      self.prev = self.sum / self.period.to_double()
      self.seeded = true
      return self.prev
    }
    return @base.nan()
  }
  self.prev = self.k * y + (1.0 - self.k) * self.prev
  self.prev
}

///|
/// Streaming RSI (Wilder). Push one close per bar; NaN during warmup; the
/// first value lands on push `period + 1` and Wilder updates follow.
pub struct RsiStream {
  priv period : Int32
  priv mut prev_close : Double
  priv mut avg_gain : Double
  priv mut avg_loss : Double
  priv mut seeded : Bool
  priv mut count : Int32
}

///|
pub fn RsiStream::new(period : Int32) -> RsiStream {
  {
    period,
    prev_close: 0.0,
    avg_gain: 0.0,
    avg_loss: 0.0,
    seeded: false,
    count: 0,
  }
}

///|
fn rsi_from(gain : Double, loss : Double) -> Double {
  if @base.is_nan(gain) || @base.is_nan(loss) {
    return @base.nan()
  }
  if loss == 0.0 {
    100.0
  } else {
    100.0 - 100.0 / (1.0 + gain / loss)
  }
}

///|
pub fn RsiStream::push(self : RsiStream, y : Double) -> Double {
  let p = self.period
  if self.count == 0 {
    self.prev_close = y
    self.count += 1
    return @base.nan()
  }
  let d = y - self.prev_close
  self.prev_close = y
  self.count += 1
  if @base.is_nan(d) {
    self.avg_gain = @base.nan()
    self.avg_loss = @base.nan()
    self.seeded = true
    return @base.nan()
  }
  if !self.seeded {
    if d > 0.0 {
      self.avg_gain += d
    } else {
      self.avg_loss -= d
    }
    if self.count < p + 1 {
      return @base.nan()
    }
    // push count == p + 1 delivers the change at bar p; the seed now covers
    // exactly p changes (bars 1..p), matching the batch seed
    self.avg_gain = self.avg_gain / p.to_double()
    self.avg_loss = self.avg_loss / p.to_double()
    self.seeded = true
    return rsi_from(self.avg_gain, self.avg_loss)
  }
  if d > 0.0 {
    self.avg_gain = (self.avg_gain * (p - 1).to_double() + d) / p.to_double()
    self.avg_loss = self.avg_loss * (p - 1).to_double() / p.to_double()
  } else {
    self.avg_gain = self.avg_gain * (p - 1).to_double() / p.to_double()
    self.avg_loss = (self.avg_loss * (p - 1).to_double() - d) / p.to_double()
  }
  rsi_from(self.avg_gain, self.avg_loss)
}

///|
/// Streaming Stochastic Oscillator (TA-Lib STOCH convention): raw %K is
/// smoothed by a running SMA over `k_slowing` bars (slow %K), and %D is a
/// running SMA of slow %K over `d_period` bars. Push one bar per call and
/// receive both lines; NaN during warmup; NaN bars poison their windows and
/// recover exactly when they leave, matching the batch implementation.
pub struct StochBar {
  k : Double
  d : Double
}

///|
pub struct StochStream {
  priv period : Int32
  priv mut count : Int32
  // monotonic deques over highs (max) and lows (min); entries are ring
  // slots of the bars they refer to, values are re-read from the ring
  priv mut max_head : Int32
  priv mut max_tail : Int32
  priv mut max_size : Int32
  priv mut min_head : Int32
  priv mut min_tail : Int32
  priv mut min_size : Int32
  priv ring_h : FixedArray[Double]
  priv ring_l : FixedArray[Double]
  priv ring_i : FixedArray[Int32]
  priv dq_max : FixedArray[Int32]
  priv dq_min : FixedArray[Int32]
  // bar index of the most recent NaN bar; any window containing it is poisoned
  priv mut last_bad : Int32
  priv mut fast_k : Double
  priv slow_k : SmaStream
  priv d_stream : SmaStream
}

///|
pub fn StochStream::new(
  period : Int32,
  k_slowing~ : Int32,
  d_period~ : Int32,
) -> StochStream {
  let cap = period + 1
  {
    period,
    count: 0,
    max_head: 0,
    max_tail: 0,
    max_size: 0,
    min_head: 0,
    min_tail: 0,
    min_size: 0,
    ring_h: FixedArray::make(cap, 0.0),
    ring_l: FixedArray::make(cap, 0.0),
    ring_i: FixedArray::make(cap, 0),
    dq_max: FixedArray::make(cap, 0),
    dq_min: FixedArray::make(cap, 0),
    last_bad: -1,
    fast_k: @base.nan(),
    slow_k: SmaStream::new(k_slowing),
    d_stream: SmaStream::new(d_period),
  }
}

///|
/// Streaming Stochastic Oscillator. Push one bar per call; returns the slow
/// %K and %D lines. Flat windows read 0; NaN bars poison their windows and
/// recover exactly when they leave, matching the batch implementation.
pub fn StochStream::push(
  self : StochStream,
  high : Double,
  low : Double,
  close : Double,
) -> StochBar {
  let p = self.period
  let cap = p + 1
  let i = self.count
  self.count += 1
  let slot = i % cap
  self.ring_h[slot] = high
  self.ring_l[slot] = low
  self.ring_i[slot] = i
  let bad = @base.is_nan(high) || @base.is_nan(low) || @base.is_nan(close)
  if bad {
    self.last_bad = i
  }
  // max deque (monotonic decreasing from head); NaN bars act as barriers
  // and are evicted by bar index like any other entry
  if !bad {
    while self.max_size > 0 {
      let back = (self.max_tail - 1 + cap) % cap
      if self.ring_h[self.dq_max[back]] <= high {
        self.max_tail = back
        self.max_size -= 1
      } else {
        break
      }
    }
  }
  self.dq_max[self.max_tail] = slot
  self.max_tail = (self.max_tail + 1) % cap
  self.max_size += 1
  while self.max_size > 0 && self.ring_i[self.dq_max[self.max_head]] < i - p + 1 {
    self.max_head = (self.max_head + 1) % cap
    self.max_size -= 1
  }
  // min deque (monotonic increasing from head)
  if !bad {
    while self.min_size > 0 {
      let back = (self.min_tail - 1 + cap) % cap
      if self.ring_l[self.dq_min[back]] >= low {
        self.min_tail = back
        self.min_size -= 1
      } else {
        break
      }
    }
  }
  self.dq_min[self.min_tail] = slot
  self.min_tail = (self.min_tail + 1) % cap
  self.min_size += 1
  while self.min_size > 0 && self.ring_i[self.dq_min[self.min_head]] < i - p + 1 {
    self.min_head = (self.min_head + 1) % cap
    self.min_size -= 1
  }
  // raw %K: finite only when the window is full and uncontaminated
  if i < p - 1 ||
    self.last_bad >= i - p + 1 ||
    self.max_size == 0 ||
    self.min_size == 0 {
    self.fast_k = @base.nan()
  } else {
    let hh = self.ring_h[self.dq_max[self.max_head]]
    let ll = self.ring_l[self.dq_min[self.min_head]]
    let range = hh - ll
    self.fast_k = if range == 0.0 { 0.0 } else { 100.0 * (close - ll) / range }
  }
  // slow %K = running SMA of raw %K; %D = running SMA of slow %K
  let k = self.slow_k.push(self.fast_k)
  let d = self.d_stream.push(k)
  { k, d, }
}

///|
/// Streaming Average True Range (Wilder). Push one bar per call
/// (high, low, close); NaN during warmup; the seed lands on push
/// `period + 1` and Wilder updates follow. NaN bars poison the recursion
/// exactly like the batch implementation.
pub struct AtrStream {
  priv period : Int32
  priv mut prev_close : Double
  priv mut sum : Double
  priv mut prev : Double
  priv mut seeded : Bool
  priv mut count : Int32
}

///|
pub fn AtrStream::new(period : Int32) -> AtrStream {
  { period, prev_close: 0.0, sum: 0.0, prev: 0.0, seeded: false, count: 0, }
}

///|
fn true_range_at(high : Double, low : Double, prev_close : Double) -> Double {
  if @base.is_nan(high) || @base.is_nan(low) {
    return @base.nan()
  }
  if prev_close != prev_close {
    return high - low
  }
  let a = (high - prev_close).abs()
  let b = (low - prev_close).abs()
  let m = if a > b { a } else { b }
  let hl = high - low
  if hl > m {
    hl
  } else {
    m
  }
}

///|
pub fn AtrStream::push(
  self : AtrStream,
  high : Double,
  low : Double,
  close : Double,
) -> Double {
  let p = self.period
  self.count += 1
  if @base.is_nan(high) || @base.is_nan(low) || @base.is_nan(close) {
    self.prev = @base.nan()
    return @base.nan()
  }
  if self.count == 1 {
    self.prev_close = close
    return @base.nan()
  }
  let tr = true_range_at(high, low, self.prev_close)
  self.prev_close = close
  if !self.seeded {
    self.sum += tr
    if self.count < p + 1 {
      return @base.nan()
    }
    self.prev = self.sum / p.to_double()
    self.seeded = true
    return self.prev
  }
  self.prev = (self.prev * (p - 1).to_double() + tr) / p.to_double()
  self.prev
}

///|
/// Streaming On-Balance Volume. Push one bar per call (close, volume);
/// the first push seeds the running total with its raw volume.
pub struct ObvStream {
  priv mut prev_close : Double
  priv mut acc : Double
  priv mut count : Int32
}

///|
pub fn ObvStream::new() -> ObvStream {
  { prev_close: 0.0, acc: 0.0, count: 0, }
}

///|
pub fn ObvStream::push(
  self : ObvStream,
  close : Double,
  volume : Double,
) -> Double {
  self.count += 1
  if self.count == 1 {
    self.prev_close = close
    self.acc = volume
    return self.acc
  }
  let bad = @base.is_nan(self.acc) ||
    @base.is_nan(self.prev_close) ||
    @base.is_nan(close) ||
    @base.is_nan(volume)
  if bad {
    self.acc = @base.nan()
  } else if close > self.prev_close {
    self.acc += volume
  } else if close < self.prev_close {
    self.acc -= volume
  }
  self.prev_close = close
  self.acc
}

///|
/// One Bollinger Band bar produced by `BollingerStream::push`.
pub struct BollingerBar {
  middle : Double
  upper : Double
  lower : Double
}

///|
/// Streaming Bollinger Bands over a close series: running sums of y and
/// y^2 with an exact re-accumulation every `period` pushes (drift bounded
/// to one slide), matching the batch implementation. Push one close per
/// call; NaN during warmup; NaN bars poison their window.
pub struct BollingerStream {
  priv period : Int32
  priv ring : FixedArray[Double]
  priv mut head : Int32
  priv mut size : Int32
  priv mut sum : Double
  priv mut sum_sq : Double
  priv mut dirty : Bool
  priv mut count : Int32
  priv mut last_nan : Int32
}

///|
pub fn BollingerStream::new(period : Int32) -> BollingerStream {
  {
    period,
    ring: FixedArray::make(period, 0.0),
    head: 0,
    size: 0,
    sum: 0.0,
    sum_sq: 0.0,
    dirty: false,
    count: 0,
    last_nan: -1,
  }
}

///|
pub fn BollingerStream::push(
  self : BollingerStream,
  y : Double,
) -> BollingerBar {
  let p = self.period
  self.count += 1
  if self.size == p {
    let old = self.ring[self.head]
    self.sum -= old
    self.sum_sq -= old * old
    self.head = (self.head + 1) % p
    self.size -= 1
  }
  self.ring[(self.head + self.size) % p] = y
  self.size += 1
  self.sum += y
  self.sum_sq += y * y
  if @base.is_nan(y) {
    self.last_nan = self.count - 1
    self.dirty = true
  }
  if self.count < p || self.last_nan >= self.count - p {
    self.dirty = true
    return { middle: @base.nan(), upper: @base.nan(), lower: @base.nan(), }
  }
  if self.dirty || (self.count - p) % p == 0 {
    self.sum = 0.0
    self.sum_sq = 0.0
    for k in 0..<self.size {
      let v = self.ring[(self.head + k) % p]
      self.sum += v
      self.sum_sq += v * v
    }
    self.dirty = false
  }
  let pd = p.to_double()
  let mean = self.sum / pd
  let v = (self.sum_sq - self.sum * mean) / pd
  let varr = if v < 0.0 { 0.0 } else { v }
  let sd = varr.sqrt()
  { middle: mean, upper: mean + 2.0 * sd, lower: mean - 2.0 * sd, }
}
