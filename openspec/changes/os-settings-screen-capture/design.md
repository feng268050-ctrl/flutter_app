## Context

Archived `flutter-native-screen-capture` delivered `packages/cyber_capture`, `libhmi_capture.so`, eLinux present-hook, and host `make screenshot` / `record-screen` via `/run/hmi/capture.cmd`. Only `app/lws_hmi` starts the watcher. OS Settings is a separate Flutter seat (`/opt/os_settings`, `os-settings.service`) that Conflicts with `hmi.service` — when Settings is foreground, HMI is stopped and capture commands go unanswered.

## Goals / Non-Goals

**Goals:**

- OS Settings initializes `cyber_capture` with the **same** command file and staging paths as HMI.
- Host Make works without seat-specific flags when Settings is the active embedder.
- Spec delta documents multi-seat expectation.

**Non-Goals:**

- New host Make targets or alternate cmd paths (`/run/os_settings/…`).
- Native/embedder changes.
- Product Settings UI “screen recorder” for end users.
- Emulator-only paths beyond existing capture behavior.

## Decisions

### D1 — Same control plane (`/run/hmi/capture.cmd`)

Reuse `CapturePaths.commandFile` / `captureRoot`. The `hmi` in the path is historical runtime namespace shared by seat helpers; both Apps already use `/run/hmi` for other markers. Avoids host script forks.

### D2 — Thin App bootstrap only

Mirror `lws_hmi`: path dep + `CaptureCommandWatcher.start()` in `OsSettingsApp` init / dispose. No Settings UI chrome.

### D3 — Spec as MODIFIED `hmi-screen-capture`

Extend requirements so the active Flutter seat SHALL honor capture when it depends on `cyber_capture` — first additional consumer is `os_settings`.

## Risks / Trade-offs

- **[Risk] Seat switch mid-record** → Mitigation: recording stops when embedder exits; host may see error/timeout — document operator should not switch seats during record.
- **[Trade-off] Path name `/run/hmi/` on Settings seat** → Acceptable; rename would be a larger FHS cleanup, out of scope.
