## 1. Alarm readiness state wiring

- [x] 1.1 Add readiness flags in `WarnInfoFragment` to represent whether valid `DEVICE_STATUS_KEY` and `DEVICE_DATA_KEY` values are available.
- [x] 1.2 Bind readiness flags to layout variables so XML expressions can gate checked-state evaluation.
- [x] 1.3 Ensure null/unavailable cache paths keep readiness false and avoid default "healthy" interpretation.

## 2. Alarm Information checked-state gating

- [x] 2.1 Update active checkbox `checked` data-binding expressions in `fragment_warn_info.xml` to return unchecked when readiness is false.
- [x] 2.2 Use combined readiness (`statusReady && dataReady`) for tiles that depend on both status alarm bits and data error flags.
- [x] 2.3 Preserve existing online alarm semantics for all tiles once readiness is true.

## 3. Verification

- [x] 3.1 Validate offline behavior (no lower controller connected): Alarm Information does not show green "normal" checks from default values.
- [x] 3.2 Validate connected behavior: ready state transitions correctly and checkbox logic matches current alarm semantics.
- [x] 3.3 Run lint/static checks for modified files and resolve any introduced issues.
