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
// Complexity per push: SMA/EMA O(1), RSI O(1).

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
