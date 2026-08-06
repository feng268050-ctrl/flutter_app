# cyber_upgrade_ui

Shared Flutter upgrade UX for LWS product HMIs: version-check card/dialog,
multi-phase progress, completion tips, and a pluggable [UpgradeChecker].

**Not** an apply engine — whole-device verify/extract/write stays in `cyber_ota`.
**Not** HAL / Modbus — control-board and camera transfer stay in the App behind
adapters.

## Channels

- `UpgradeChannel.systemOta` — multi-phase (download → verify → extract → write → arm)
- `UpgradeChannel.controlBoard` — single transfer phase
- `UpgradeChannel.cameraProgram` — single transfer phase (flash protocol is App-owned;
  this package only supplies check/progress chrome)

## Host make-push

Use `UpgradePolicy(checkVersion: false, requireConfirm: false)` so version gates
and confirm dialogs are skipped while progress UI still runs.

## Post-apply completion

Channels configure finish behavior via `UpgradeCompletionConfig`:

- `UpgradeCompletionConfig.autoReboot(rebootNotice: …)` — system OTA: show notice,
  then the device **reboots automatically** (apply engine / `UpgradePostApplyListener`)
- `UpgradeCompletionConfig.noReboot(successBody: …)` — control-board (and similar)

`UpgradePostApplyAction.autoReboot` is **not** a manual “please reboot” prompt.
Default `autoRebootDelay` is 1.5s so the tip is readable before reboot.
