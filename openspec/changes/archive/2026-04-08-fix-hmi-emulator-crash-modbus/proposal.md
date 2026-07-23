## Why

The HMI app crashes on startup in the Android Studio emulator, blocking local development, validation, and regression testing. A focused investigation is needed now because the likely Modbus initialization path may be incompatible with emulator environments and can cause early process termination.

## What Changes

- Investigate emulator-only crash paths during app startup and capture deterministic root-cause evidence (logs, stack traces, and initialization timeline).
- Add defensive startup behavior around Modbus setup so emulator-incompatible operations do not crash the app process.
- Introduce graceful fallback and explicit user-visible state for Modbus-unavailable scenarios in emulator/runtime environments where hardware dependencies are missing.
- Improve crash diagnostics for startup modules so future environment-specific failures are easier to identify and triage.

## Capabilities

### New Capabilities
- `startup-crash-analysis`: Standardized startup crash evidence collection and failure classification for emulator/device-specific runtime differences.

### Modified Capabilities
- `system-wifi-privileged-control`: Adjust runtime behavior so unavailable privileged/system integrations in emulator-like environments fail gracefully instead of crashing startup.

## Impact

- Android app startup flow, especially service initialization ordering.
- Modbus-related integration points and their environment capability checks.
- Error handling/logging around system-level dependencies.
- Emulator QA workflow and local developer validation reliability.
