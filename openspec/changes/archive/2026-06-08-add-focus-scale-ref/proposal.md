## Why

Operators must align the gun-head focus scale to a machine-specific reference before enabling the laser. That reference varies by device model but is not surfaced in the app today—the laser-enable **Important Reminder** dialog shows a blank third card with generic copy. We need ROM-level configuration (like `camera_type`) so `make prepare` / `make emulator` can inject the correct reference per machine, and the quick/engineer laser-enable flow can show the matching illustration.

## What Changes

- Add **`FOCUS_SCALE_REF`** Make/env variable for **`make prepare`** and **`make emulator`**, written as `focus_scale_ref=<n>` (integer) in `/system/etc/model.properties`. Default **`0`** when unset.
- Load `focus_scale_ref` at App startup via **`DeviceModelConfig`** (integer, default `0`).
- Update the **Important Reminder** dialog (`ReminderExactDialog`) shown when enabling laser in **quick mode** and **engineer mode**:
  - Third card copy → **"Adjust focus scale reference on your gun head to the given value"**
  - Third card image → PNG from `res/mipmap-anydpi/focus-scale-ref/{value}.png` matching `DeviceModelConfig.getFocusScaleRef()`; **blank** when no matching resource exists.
- Update **`.env.example`**, **Makefile help**, and emulator/prepare scripts to document `FOCUS_SCALE_REF`.

## Capabilities

### New Capabilities

- `device-focus-scale-ref-config`: ROM `focus_scale_ref` key, runtime load/default, and App accessor.
- `laser-enable-reminder-dialog`: Important Reminder UI when enabling laser in quick/engineer modes—third-card copy and focus-scale illustration.

### Modified Capabilities

- `build-ci-tooling`: `FOCUS_SCALE_REF` env var for `make prepare` and `make emulator` `model.properties` sync.

## Impact

- **Scripts**: `scripts/model-properties-common.sh` (shared resolver), `scripts/emulator-system-common.sh` (`sync_model_properties`), `scripts/ci/prepare-device.sh` (`write_model_config`), Makefile help, `.env.example`.
- **App**: `DeviceModelConfig`, `ReminderExactDialog` / `dialog_reminder.xml`, focus-scale image loader helper.
- **Resources**: Existing PNGs under `app/src/main/res/mipmap-anydpi/focus-scale-ref/` (no new artwork required).
- **Tests**: `DeviceModelConfig` unit tests for `focus_scale_ref` parsing; optional UI/manual verification on emulator.
