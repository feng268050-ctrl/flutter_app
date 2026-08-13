## Why

Key-switch and E-stop prompts currently mix Operation-failed tips and INFO-style Warn Frost without a consistent safety rule: the Misc “Show Key Switch Alarm” toggle only gates whether a key-off edge shows a prompt, and E-stop always used a yellow/INFO chrome. Operators need a clear split between a **red WARN alarm** (interlock opened while the alarm toggle is on) and a **yellow INFO warning** (blocked Enable Laser, or key-off when the alarm toggle is off). E-stop has no Misc gate and must stay on the warning path only.

## What Changes

- Define a product safety-interlock prompt policy for **key switch** and **E-stop** on Quick / Engineer work screens.
- **Key switch, Misc Show Key Switch Alarm ON:** turning the key off presents a **red WARN** frost (siren + red title). Confirm or key restore dismisses it (and stops SFX). While the key is still off, Enable Laser presents a **yellow INFO** frost (not another red alarm).
- **Key switch, Misc Show Key Switch Alarm OFF:** turning the key off presents a **yellow INFO** frost regardless of Laser Enable session state. Enable Laser while key-off uses the same yellow INFO path (no Operation-failed dark tip).
- **E-stop:** same yellow INFO frost as key-switch-with-toggle-off. No Misc switch. No red WARN path. Confirm or E-stop release dismisses it. Enable Laser while E-stop is active uses the same yellow INFO frost.
- **SFX:** WARN (red) may loop warn SFX; **INFO (yellow) MUST NOT play warn-loop SFX**.
- Keep existing copy (`keySwitchOffAlarmTitle` / `deviceControlKeySwitchOffError`, `emergencyStopAlarmTitle` / `deviceControlEmergencyStopError`). No new Settings switch.
- Prompts remain **not logged alarms** (no C-code / alarm history row).

## Capabilities

### New Capabilities

- `safety-interlock-prompts`: Product Quick/Engineer policy for key-switch and E-stop Warn Frost (WARN vs INFO chrome, Misc gate, Enable Laser vs physical edge, dismiss/restore).

### Modified Capabilities

- (none) — `cyber-alarm-ui` already supplies WARN vs INFO chrome; this change only chooses which style the App uses.

## Impact

- App: `KeySwitchOffPrompt`, `EmergencyStopPrompt`, Quick/Engineer safety-event routing, Laser Enable preflight (`device_control_bar`, `engineer_device_panel`, `quick_mode_page`).
- Settings: existing `showKeySwitchAlarm` Misc toggle (no schema change).
- Packages: `cyber_alarm_ui` `WarnDialogBody` `infoStyle` / `WarnChromeStyle` (consume only).
- Tests: prompt eligibility / chrome selection / dismiss-on-restore.
