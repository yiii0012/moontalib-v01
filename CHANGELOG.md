# Changelog

## 0.6.0 (2026-11-11)

- feat(base): O(n) rolling primitives — `rolling_max` / `rolling_min` /
  `rolling_argmax` / `rolling_argmin` on monotonic index deques; NaN-tolerant,
  ties resolve to the most recent bar, outputs bit-identical to the window
  scans
- perf: `max` / `min` / `minmax` / `midprice` / `midpoint` / `stoch` /
  `stochf` / `willr` / `aroon` / `aroonosc` all run in O(n) through the
  rolling helpers (previously O(n·period) window scans)
- perf(statistic): the linear-regression family precomputes its per-period
  constants (mean offset, per-offset deviations, denominator)
- feat(demo): trend and regression panel (ADX/+DI/DX, Aroon, Ultimate
  Oscillator, regression slope and forecast)
- test: cross-indicator invariant suite and a 300-bar smoke run over the
  whole facade (91 tests total)
- chore: repository moved to yiii0012/moontalib-v01

## 0.5.0 (2026-11-10)

- feat(momentum): `dx` — standalone Directional Movement Index; the Wilder DI
  computation is shared between `adx` and `dx` and `AdxResult` carries the
  `dx` line
- feat(statistic): `minmax` (rolling min + max in one result) and `avgdev`
  (mean absolute deviation)

## 0.4.0 (2026-11-10)

- feat(momentum): `aroonosc` (Aroon oscillator) and `ultosc` (Ultimate
  Oscillator, three-period 4:2:1 blend)
- feat(statistic): `correl` (rolling Pearson correlation between two series)

## 0.3.0 (2026-11-09)

- feat(statistic): linear-regression family — `linearreg_slope`,
  `linearreg_intercept`, `linearreg`, `linearreg_angle`, `tsf`
- feat(overlap): `midprice`

## 0.2.0 (2026-11-09)

- feat(momentum): `bop` (Balance of Power) and `aroon`
- feat(overlap): `midpoint`

## 0.1.0 (2026-11-09)

- Initial release: 39 indicator functions across overlap / momentum / volume
  / volatility / statistic, with the `@moontalib` facade, golden-value tests
  and a runnable demo.
