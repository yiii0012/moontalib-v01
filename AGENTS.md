# AGENTS.md — moontalib 开发指南

本项目是 [MoonBit](https://docs.moonbitlang.com) 的技术分析指标库。本文件
给人与 AI 代理一份"在这里改代码必须知道的事"。

## 项目结构

- 顶层 `moon.mod` 是模块清单（TOML 风格）。根包（`moontalib.mbt` +
  `moon.pkg`）是门面：所有公开指标在 `@moontalib` 下有一行委托实现。
- 每个子目录是一个包，各有 `moon.pkg`（JSON5 函数式 import 声明）：
  - `base/` — `Candle`/`Candles` 数据模型、`TaError`（`suberror`）、NaN
    与校验原语（`validate_series` / `validate_candles`，均以 `raise`
    报错）、`true_range`、`isqrt`。
  - `overlap/` — SMA/EMA/WMA/HMA/DEMA/TEMA/BBANDS/VWMA 与
    `moving_average` 分发器；`ema_from(data, period, first_valid)` 是
    全部 EMA 链式指标的底层原语。
  - `momentum/` — RSI/MACD/ROC/MOM/CMO/WILLR/STOCH/STOCHF/CCI/TRIX/
    ADX/APO/PPO。
  - `volume/` — OBV/MFI/AD/ADOSC。
  - `volatility/` — TRANGE/ATR/NATR/STDDEV/VARIANCE。
  - `statistic/` — 四种价格变换与滚动 MAX/MIN/SUM。
  - `cmd/demo/` — `moon run cmd/demo` 的演示程序。
- 黑盒测试写在各包 `_test.mbt`（自动以 `@<pkg>` 导入本包）；同一包内
  多个测试文件共享顶层命名空间，辅助函数只定义一次（见 overlap 包）。

## 硬性约定（改代码前必读）

1. **API 一律 `-> T raise TaError`**，不要返回 `Result`（moonc 的
   result_error_return 警告会拦）。不可恢复输入问题映射到四种
   `TaError`：`EmptyInput` / `InvalidPeriod` / `NotEnoughData` /
   `MismatchedLength`。校验顺序固定：先 `validate_candles`（或
   `validate_series`），再检查周期。
2. **输出与输入等长**；数据不足前导窗口的位置填 `base.nan()`。窗口内
   出现 NaN 则该窗口输出 NaN；递归指标（EMA 链/RSI/ATR/ADX）中 NaN
   向后传播。`n == period` 允许（全 NaN 输出），`n < period` 报
   `NotEnoughData`。
3. **指标语义对齐 TA-Lib**：EMA 用前 n 个值的 SMA 做种子；RSI/ATR/ADX
   用 Wilder 平滑；stddev/variance 用总体标准差（分母 n）；CCI 用
   0.015 常数。退化窗口规则写进每个函数的文档注释。
4. **多输出指标**（BBANDS/MACD/STOCH/AdxResult）用只读 `pub struct`
   （跨包只可读不可构造），字段不加 `pub` 修饰。数据模型 `Candle`/
   `Candles` 是 `pub(all)`（跨包可构造）。
5. **新增指标的最小流程**：在对应域包写实现与文档 → 补
   `xxx_lookback` → 在包的 `_test.mbt` 里加手工推演的 golden 测试
   （容差 1e-9）与错误分支测试 → 在门面 `moontalib.mbt` 加一行委托 →
   `moon check && moon test` 全绿 → 更新 README 指标表。
6. **golden 测试值必须可手工复算**。测试注释里写明推导（例如
   `(2+3+4*2)/4`）。禁止"AI 说该是多少就写多少"。

## 2026 MoonBit 语法备忘（本项目实测踩过的坑）

- 泛型函数写作 `fn[T] name(...)`，不是 `fn name[T](...)`。
- `if` 条件与 `+`/`||` 续行不能以运算符开头（多行条件会解析失败），
  拆成独立语句或单行。
- `pub struct` 默认跨包只读；需要外部构造用 `pub(all)`；错误枚举用
  `pub(all) suberror`。
- 捕获错误的写法是 `try expr catch { e => ... } noraise { v => ... }`
  （`try?` 已不存在）。
- `sin`/`cos` 等来自 `moonbitlang/core/math`（自由函数 `@math.sin`）；
  `Double` 没有这些方法，`.abs()` / `.sqrt()` / `.floor()` 是方法。
- 断言函数（`assert_eq` / `fail`）是 raise 上下文的，测试辅助函数
  需要声明 `-> Unit raise`。

## 工具链

- `moon check` — 类型检查（本仓库要求零警告零错误）。
- `moon test` — 65 个单元测试。
- `moon test --update` — 刷新快照（本项目以断言测试为主，无快照）。
- `moon fmt` — 格式化；`moon info` — 生成/检查 `.mbti` 接口文件。
- `moon run cmd/demo` — 运行演示表格。
- 参考 <https://github.com/moonbitlang/skills> 获取更多 MoonBit 技能。
