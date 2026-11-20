# testdata — 独立对照（pandas / pandas-ta）

本目录是 **独立对照测试**：用 Python（numpy / pandas / pandas-ta）按
README「语义约定」一节记录的公开语义，独立实现全套指标参考版本，生成
golden 数据，供 MoonBit 侧逐值对拍（容差 1e-9）。

## 独立性说明

- 参考实现与 MoonBit 实现**零共享代码**：Python 侧基于 numpy / pandas 的
  rolling / ewm 原语独立编写，是对同一份公开语义文档的另一种实现；
- 对拍范围：全部 53 个公开指标函数（fixture 覆盖 v0.8 目录下的每个函数）；
- 数据：300 根确定性 zig-zag 合成行情（纯整数/半整数运算，跨语言逐位一致，
  见 `generate_fixtures.py` 的 `zigzag_candles`）；
- NaN 窗口语理（NaN → NaN、离开窗口精确恢复）由 MoonBit 侧单元测试单独
  覆盖；fixtures 均为无 NaN 干净数据上的数值对拍。

## 重新生成

```bash
python goldendata/generate_fixtures.py   # 需要 pandas / numpy / pandas-ta
```

- 环境：Python 3.13.5, pandas 3.1.1, numpy 2.2.6, pandas-ta 0.4.71b0
- 输出：`goldendata/fixtures.json` 与 `goldendata/pandas_fixtures.mbt`
  （后者为 GENERATED 文件，请勿手改）

## 覆盖与已知边界

- 加性窗口族（sma/sum/bbands/stddev/vwma）：pandas rolling 原语直接对拍；
- 递归族（ema/MACD/atr）：按 TA-Lib 的 SMA 种子约定在 numpy 中独立实现
  递推后对拍（与 pandas_ta 的 rma 种子约定不同，后者种子收敛后与本项目
  差异在 1e-7 量级——属种子约定差异，非实现错误）；
- 极值族（max/min/minmax/midprice/midpoint/stoch/aroon）：pandas rolling
  max/min 与"并列取最近"的自定义 argmax/argmin 惯用法对拍；
- 相关系数/方差：sum-of-products 公式存在固有消减，已通过 1e-9 容差验证。

pandas_ta 0.4.71b0 用于对参考实现做抽查（约定一致的指标上，
numpy 参考与 pandas_ta 输出一致）。
