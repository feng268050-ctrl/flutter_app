## 1. Build tooling — model.properties injection

- [x] 1.1 Add `resolve_focus_scale_ref_value()` in `scripts/model-properties-common.sh` (signed integer env, default `0`, fail on invalid)
- [x] 1.2 Extend `sync_model_properties` in `scripts/emulator-system-common.sh`: merge/write `focus_scale_ref` from `FOCUS_SCALE_REF` env (default `0` when unset and key absent)
- [x] 1.3 Extend `write_model_config` in `scripts/ci/prepare-device.sh`: write `focus_scale_ref=` when model config is pushed; trigger write when only `FOCUS_SCALE_REF` is set
- [x] 1.4 Document `FOCUS_SCALE_REF` in root `Makefile` help and `.env.example`

## 2. App runtime — DeviceModelConfig

- [x] 2.1 Load `focus_scale_ref` in `DeviceModelConfig` with default/fallback to `0` and warning on invalid values
- [x] 2.2 Add `getFocusScaleRef()` accessor
- [x] 2.3 Add unit tests for `focus_scale_ref` parsing (missing, positive, negative, invalid)

## 3. Laser-enable reminder dialog UI

- [x] 3.1 Update `dialog_reminder.xml` card 3: add `ImageView`/`TextView` ids; set tip text to "Adjust focus scale reference on your gun head to the given value"
- [x] 3.2 Add focus-scale image loader helper (dynamic `mipmap` lookup by integer string; blank when resource missing)
- [x] 3.3 Wire `ReminderExactDialog` to bind card 3 from `DeviceModelConfig.getFocusScaleRef()` on show
- [x] 3.4 Verify `make build` succeeds with PNGs under `res/mipmap-anydpi/focus-scale-ref/`; flatten to `mipmap-nodpi` only if AAPT rejects nested layout

## 4. Verification

- [x] 4.1 Run unit tests for `DeviceModelConfig` focus scale ref parsing
- [x] 4.2 Smoke: `FOCUS_SCALE_REF=5 make emulator` (or script path) confirms `focus_scale_ref=5` in guest `model.properties`
- [x] 4.3 Smoke: `make prepare` without `FOCUS_SCALE_REF` confirms default `focus_scale_ref=0`
- [x] 4.4 Manual: open laser enable in quick/engineer mode on emulator with `FOCUS_SCALE_REF=-3`; confirm third card text and illustration (or blank when PNG missing)
