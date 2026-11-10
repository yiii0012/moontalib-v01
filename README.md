# moontalib

[![CI](https://github.com/yiii0012/moontalib/actions/workflows/ci.yml/badge.svg)](https://github.com/yiii0012/moontalib/actions/workflows/ci.yml)

**moontalib** 是 MoonBit 的技术分析指标库 —— 一个 TA-Lib 风格的工具箱，用于处理股票与加密货币的 OHLCV 行情数据。纯 MoonBit 实现，零第三方依赖，原生 / WASM / JS 三后端可用。

> TA-Lib-style technical analysis indicator library for MoonBit. Pure MoonBit,
> zero third-party dependencies, works on native / wasm / js backends.

## 为什么需要它

MoonBit 生态里已经有了行情数据、图表库（moonchart 等）和事件驱动回测引擎
（moon-certified/finance/backtest 的 QuantStart/Zipline 风格实现），唯独缺
少中间这一层"行情 → 指标"的纯函数计算库。Zipline 的标准搭档正是 TA-Lib ——
moontalib 补上的就是这块拼图。

- **指标公式全部有据可依**：语义对齐 TA-Lib（SMA 种子 EMA、Wilder 平滑、
  总体标准差、0.015 常数 CCI 等），可与其他生态的实现逐值对拍；
- **全库 65 个单元测试**：每个指标都有手工推演的 golden 值，外加
  "MACD = EMA(fast) − EMA(slow)"式的交叉不变量校验；
- **`moon check` 零警告**：错误处理采用 MoonBit 2026 惯用的
  `-> T raise TaError` 风格，`pub(all)` 构造可见性、`suberror` 错误类型。

## 指标清单（v0.2，42 个公开函数）

### overlap —— 均线与通道

| 函数 | lookback | 说明 |
|---|---|---|
| `sma` | n−1 | 简单移动平均 |
| `ema` / `ema_from` | n−1 | 指数移动平均（前 n 个值的 SMA 作种子，TA-Lib 约定） |
| `wma` | n−1 | 线性加权移动平均（最新一根权重 n） |
| `hma` | n+⌊√n⌋−2 | Hull 移动平均 |
| `dema` | 2(n−1) | 双重指数移动平均 |
| `tema` | 3(n−1) | 三重指数移动平均 |
| `bbands` | n−1 | 布林带（总体标准差，上/中/下轨） |
| `vwma` | n−1 | 成交量加权移动平均 |
| `midpoint` | n−1 | 滚动中点价：(max + min) / 2 |
| `moving_average` | — | SMA/EMA 选择器（APO/PPO 共用） |

### momentum —— 动量与摆动指标

| 函数 | lookback | 说明 |
|---|---|---|
| `rsi` | n | 相对强弱指数（Wilder 平滑） |
| `macd` | (slow−1)+(signal−1) | MACD 线 / 信号线 / 柱状图 |
| `roc` | n | 变动率（百分比） |
| `mom` | n | 动量 |
| `cmo` | n | Chande 动量振荡器 |
| `willr` | n−1 | 威廉 %R |
| `stoch` / `stochf` | (p−1)+(ks−1)+(d−1) | 随机指标（慢速 / 快速） |
| `cci` | n−1 | 顺势指标（0.015 归一化常数） |
| `trix` | 3(n−1)+1 | 三重 EMA 的百分比变动率 |
| `adx` | 2n−1 | 平均趋向指数（同时返回 +DI / −DI） |
| `apo` / `ppo` | slow−1 | 绝对 / 百分比价格振荡器 |
| `bop` | 0 | 平衡量：(close − open) / (high − low) |
| `aroon` | n | 阿隆指标（窗口 period+1 根含当前 K 线；并列极值取最近者） |

### volume —— 成交量指标

| 函数 | lookback | 说明 |
|---|---|---|
| `obv` | 0 | 能量潮（OBV） |
| `mfi` | n | 资金流量指标（MFI） |
| `ad` | 0 | Chaikin 集散线（A/D Line） |
| `adosc` | slow−1 | Chaikin A/D 振荡器 |

### volatility —— 波动率

| 函数 | lookback | 说明 |
|---|---|---|
| `tr_range` | 0 | 每根 K 线的真实波幅 |
| `atr` | n | 真实波幅均值（Wilder 平滑） |
| `natr` | n | 归一化 ATR（占收盘价百分比） |
| `stddev` / `variance` | n−1 | 滚动总体标准差 / 方差 |

### statistic —— 价格变换与滚动工具

| 函数 | lookback | 说明 |
|---|---|---|
| `avg_price` / `med_price` / `typ_price` / `wcl_price` | 0 | 四种经典价格变换 |
| `max` / `min` / `sum` | n−1 | 滚动窗口最大 / 最小 / 求和 |

每个指标都配有 `xxx_lookback` 辅助函数，返回输出的前导 NaN 个数（`adx`
等复合指标除外，见各函数文档）。

## 安装

```bash
# 已发布到 mooncakes 后（把 yiii0012 换成发布者 ID）
moon add yiii0012/moontalib
```

或直接在 `moon.mod` 中声明依赖后运行 `moon update`。

## 快速开始

```moonbit
import {
  "yiii0012/moontalib",
  "yiii0012/moontalib/base",
}

/// 所有不可恢复的输入问题都会以 `TaError` 抛出，
/// 可在任意 raise 上下文中直接调用。
fn analyze(candles : @base.Candles) -> Unit raise @base.TaError {
  let closes = candles.close
  let sma20 = @moontalib.sma(closes, 20)
  let rsi14 = @moontalib.rsi(closes, 14)
  let bb = @moontalib.bbands(closes, 20, ndev=2.0)
  let macd = @moontalib.macd(closes, 12, 26, 9)
  // 所有输出与输入等长；前 lookback 个位置是 NaN
  let last = closes.length() - 1
  println("close=\{closes[last]} sma20=\{sma20[last]} rsi=\{rsi14[last]}")
  println("bb.upper=\{bb.upper[last]} macd.hist=\{macd.hist[last]}")
}
```

运行完整演示（120 根合成 K 线，9 个指标的固定宽度表格）：

```bash
moon run cmd/demo
```

## 测试

```bash
moon check   # 类型检查，零警告
moon test    # 65 个单元测试（golden 值 + 交叉不变量）
```

## 语义约定

1. **输出与输入等长**。指标输出数组的长度恒等于输入长度。
2. **前导 NaN（lookback）**。数据不足前导窗口的位置一律为 NaN；
   每个指标提供 `xxx_lookback` 查询这个长度。
3. **窗口内 NaN 即 NaN**。某个窗口只要含 NaN，该位置的输出就是 NaN
   （pandas 滚动语义）；递归型指标（EMA 链、RSI、ATR、ADX）中 NaN 会
   向后传播。
4. **错误用 `raise` 表达**。空输入 → `EmptyInput`；周期 ≤ 0 →
   `InvalidPeriod`；周期 > 输入长度 → `NotEnoughData`；Candles 列长度
   不一致 → `MismatchedLength`。除这些显式错误外，指标对"数据刚够"的
   情形是宽容的（全 NaN 输出而非报错）。
5. **EMA 以 SMA 为种子**（TA-Lib 约定）；RSI / ATR / ADX 用 Wilder
   平滑；`stddev` / `variance` 用总体标准差（分母 n）；CCI 用 0.015
   归一化常数。平坦窗口的规则在各函数文档中逐个写明（如随机指标
   hh==ll 读 0、WILLR 由 %R = %K − 100 恒等式得 −100）。

## 架构

```
moontalib/
├── moontalib.mbt     门面：import 一次拿到全部指标（@moontalib.sma 等）
├── base/             Candle/Candles 数据模型、TaError、NaN 与校验原语
├── overlap/          均线族（SMA/EMA/WMA/HMA/DEMA/TEMA/BBANDS/VWMA）
├── momentum/         动量族（RSI/MACD/STOCH/CCI/ADX/TRIX/...）
├── volume/           成交量族（OBV/MFI/AD/ADOSC）
├── volatility/       波动率族（ATR/NATR/STDDEV/VARIANCE/TRANGE）
├── statistic/        价格变换与滚动工具
└── cmd/demo/         可运行示例（moon run cmd/demo）
```

依赖方向：`base ← overlap ← momentum`；`base ← volume/volatility/statistic`；
门面聚合全部子包，无循环依赖。

## 路线图

- [ ] v0.2：流式 / 增量 API（append-only 缓冲区，O(1) 更新最新值）
- [ ] v0.2：更多指标（ADX 家族扩展、AROON、BOP、SAR、Ichimoku、K 线形态）
- [ ] v0.3：O(n) 滚动窗口实现（当前窗口扫描为 O(n·period)，对 ≤ 500 的
  常用周期完全够用）
- [ ] v0.3：`Float` 变体与 `FixedArray` 后端（降低 GC 压力）

## 发布

```bash
moon login        # 填入 mooncakes.io 的 token
moon publish      # 首次发布前先把 yiii0012 替换成你的 mooncakes 用户名
```

## License

Apache-2.0
