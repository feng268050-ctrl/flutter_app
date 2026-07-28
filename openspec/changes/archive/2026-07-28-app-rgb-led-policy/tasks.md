## 1. Decision + holder wiring

- [x] 1.1 Add `RgbLedDecision` (red/yellow/green + yellow/ready bypass rules)
- [x] 1.2 Add `LaserEnableLedHolder` and sync from DeviceControl / Quick / Engineer
- [x] 1.3 Add `RgbLedPolicyDriver` (watch Modbus + warn + dangerous + holder)

## 2. Lifecycle + blink correctness

- [x] 2.1 Start policy from warn-alarm controller after stack is live
- [x] 2.2 Coalesce concurrent refresh; suppress on LED Settings override
- [x] 2.3 HAL/App same-mode skip; `resetAllOff` / `force` Off at policy start
- [x] 2.4 LED Settings enter: override + force Off; leave resumes policy

## 3. Verification

- [x] 3.1 Unit tests: decision, policy driver, GPIO controller, HAL blink/force
- [x] 3.2 OpenSpec artifacts for `rgb-gpio-indicator-lights` (+ GPIO/settings deltas)
