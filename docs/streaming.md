# 流式（增量）指标 API：更新语义与使用指南

`streaming` 包提供逐根推送的增量式指标求值器。**核心保证：逐根 push 的输
出与对应的批量函数在相同位置上完全一致（1e-9 容差内一致，由一致性测试逐
值验证）。** 使用场景：行情流接入、实时看板、仅在内存中保留最新窗口的长
运行进程。

## 快速开始

```moonbit
import {
  "yiii0012/moontalib/streaming",
  "yiii0012/moontalib/base",
}

///|
fn demo(candles : @base.Candles) -> Unit {
  let rsi = @streaming.RsiStream::new(14)
  let sma = @streaming.SmaStream::new(20)
  for i in 0..<candles.length() {
    let bar = {
      open: candles.open[i],
      high: candles.high[i],
      low: candles.low[i],
      close: candles.close[i],
      volume: candles.volume[i],
    }
    let r = rsi.push(bar.close)
    let s = sma.push(bar.close)
    if r != r || s != s {
      // 预热期：尚无完整窗口，值为 NaN
      continue
    }
    println("bar \{i}: rsi=\{r} sma=\{s}")
  }
}
```

## 更新语义（与批量函数逐条对应）

| 语义项 | 流式行为 | 批量对应 |
|---|---|---|
| 预热 | 推送数 < period 时返回 NaN | 输出前 lookback 个位置为 NaN |
| 首个有效值 | SMA/EMA 在第 period 次 push；RSI 在第 period+1 次 push | 批量输出在同一下标首次出现 |
| 种子 | SMA/EMA 用前 period 个值的均值作种子（TA-Lib 约定）；RSI 用前 p 个变动的均值 | 与批量完全相同的种子公式 |
| 递推 | 之后每次 push 应用一次递推步 | 与批量逐位置相同 |
| NaN 输入 | 窗口被污染 → NaN；污染 bar 离开窗口后**在同一下标**精确恢复（重新累加） | 批量在同一下标恢复 |
| 复杂度 | 每次 push O(1)（SMA/EMA/RSI） | 批量整段 O(n) |

## 覆盖范围

| 求值器 | 更新语义类别 | 每 push 复杂度 |
|---|---|---|
| `SmaStream` | 窗口和（环形缓冲 + 漂移有界的重累加） | O(1) |
| `EmaStream` | SMA 种子 + 递推 | O(1) |
| `RsiStream` | Wilder 递推（SMA 种子） | O(1) |

后继版本将按相同的"与批量一致"测试模式扩展到 Stoch、Aroon、ADX 等多输
出指标。

## 一致性保证是怎么测的

`streaming_test.mbt` 将 300 根确定性 zig-zag 行情逐根推入各求值器，把收
集到的输出与批量函数（`@moontalib.sma` / `@moontalib.ema` / `@moontalib.rsi`）
在全部 300 个位置上做 1e-9 容差对拍——包括第 150/151 根人为注入的 NaN
bar，验证污染与恢复行为在流式与批量两侧完全一致。任何偏离都会在 CI 中
失败。

## 已知边界

- RSI 流式在 push 期间收到 NaN close 时，后续输出保持 NaN（与批量的
  NaN 传播语义一致），直到……与批量相同：不会自动恢复（RSI 的递推在
  批量侧同样是 NaN 永久传播），推送有效数据前请自行过滤。
- 多输出指标（布林带、MACD、Stoch）的流式版本在路线图中。
