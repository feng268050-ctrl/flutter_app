## 1. Store and facades (App layer)

- [x] 1.1 Add `AdvancedSettingsStore` for `/var/lib/hmi/advanced-settings.json` with AI + dangerous keys and lws-ui defaults
- [x] 1.2 Add `AiAssistanceSettings` facade (read/write + notify) used by non-UI consumers
- [x] 1.3 Add `DangerousOperationsSettings` facade + pure policy helpers mirroring `LaserEnableAlarmGuard` rules (unit-tested)
- [x] 1.4 Provide `AdvancedSettingsScope` (or AppServices) warm-load at App start

## 2. Advanced Settings UI (CyberUI)

- [x] 2.1 Replace `advanced_settings_tab.dart` placeholder with sectioned scroll layout (Offset, Power, Temperature, AI, Dangerous)
- [x] 2.2 AI Assistance: two `SettingsSwitchRow` / `CyberSwitch` rows wired to store
- [x] 2.3 Dangerous Operations: five `CyberSwitch` rows with hint text, correct order, wired to store
- [x] 2.4 Threshold sections: show shell controls (numeric fields or “coming soon” rows) without blocking AI/dangerous
- [x] 2.5 Ensure click SFX on switch via existing Cyber click registry pattern

## 3. Consumer wiring

- [x] 3.1 Document and wire AI facade into any existing StreamDetect / stain / zero-point HMI modules (skip if absent; leave TODO)
- [x] 3.2 Wire dangerous facade into warn severity / laser interrupt when those modules exist; else export API only
- [x] 3.3 On dangerous toggle OFF, call re-evaluate interrupt if `LaserWorkGuard`-equivalent exists

## 4. Thresholds (optional stretch)

- [x] 4.1 Map known Modbus attribute ids for power/temp/offset when present in `modbus.json`
- [x] 4.2 Read/watch into UI; writes via HAL attributes only when catalogued

## 5. Verification

- [x] 5.1 Unit tests: defaults, persist round-trip, policy helpers (keepLaserOn vs allow-*)
- [x] 5.2 Widget/UI: Advanced tab shows Cyber switches; restart retains values
- [x] 5.3 Confirm Misc JSON unchanged by Advanced toggles
- [x] 5.4 `make build-app` smoke
