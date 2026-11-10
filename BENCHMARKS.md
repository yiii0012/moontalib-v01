# Benchmarks

`cmd/bench` 在确定性合成行情（无 NaN）上运行各指标并输出校验和；耗时在
Windows 上以 wasm 目标外部计时（`time moon run cmd/bench`）。

- 工作负载：n = 100 000 根 K 线，period = 200，单次运行
- 正确性：优化前后逐指标 checksum 漂移仅出现在浮点末位（相对 ≤ 1e-12），
  90 个单元测试（含 1e-9 容差的 golden 对拍）保持全绿

| 指标 | v0.6.0（窗口扫描） | v0.7.0（O(n)） |
|---|---|---|
| 整轮总耗时 | **4.741 s** | **1.615 s（2.9×）** |
| sma | O(n·p) | O(n) rolling_sum |
| sum | O(n·p) | O(n) rolling_sum |
| stddev | O(n·p) | O(n) 双滚动和 |
| bbands | O(n·p) | O(n) 双滚动和 |
| vwma | O(n·p) | O(n) 双滚动和 |
| wma | O(n·p) | O(n) 滑动增量和 |
| cmo | O(n·p) | O(n) 双滚动和 |
| mfi | O(n·p) | O(n) 双滚动和 |
| ultosc | O(n·p) ×3 | O(n) 六滚动和 |
| correl | O(n·p) | O(n) 五滚动和 |
| max / min / minmax | O(n)（v0.6.0 已完成单调队列） | O(n) |
| stoch / willr / aroon / midprice / midpoint | O(n)（v0.6.0 已完成） | O(n) |
| linearreg 族 / cci / avgdev | O(n·p)（均值已接入滚动和，偏差遍历保留） | O(n·p)，常数减半 |

### 数值说明

- 滚动和采用"每 `period` 根精确重算一次 + 一次滑动增量"的策略，把浮点
  漂移限制在单次滑动的量级（~1e-16 相对）；方差/相关系数这类
  sum-of-products 公式存在固有消减误差，已在测试容差（1e-9）内验证。
- 平坦窗口的方差会被钳制为 0（消除消减产生的极小负值）。
- 含 NaN 的窗口语义与窗口扫描版完全一致：NaN → 输出 NaN，NaN 离开窗口
  后精确恢复。
