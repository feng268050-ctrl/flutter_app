## Why

Hardware prefs under `/var/lib/lws-hmi/` are written by Flutter controllers today (backlight, media volume, orientation, mouse), while boot restore and SSH operators use (or should use) shell helpers. That split caused bugs such as `change-backlight` applying sysfs without persisting, so reboot restore overwrote the operator’s change. Persistence MUST be owned by the same verb-noun shell commands that apply hardware state, with Flutter calling those commands (or reading results) instead of writing preference files itself.

## What Changes

- Make **apply + persist** the contract of board helpers for simple hardware knobs: backlight (already started), media volume, display orientation, and mouse settings.
- Add/extend verb-noun scripts under `/usr/lib/lws-hmi/` that write the canonical preference files used by `restore-settings.sh` / `hmi-launch.sh`.
- Expose operator-facing ones on `/usr/bin` where appropriate (`change-backlight` already; add volume / orientation / mouse as needed).
- Change Linux Flutter backends to **invoke those helpers** (or stop dual-writing) so Demo, SSH, and boot restore share one persistence path.
- Keep preference **file paths and schema** stable (`backlight-brightness`, `media-volume`, `display-orientation`, `mouse.conf`); no userdata layout break.
- Out of scope for this change: rewriting Wi‑Fi/eth0/BT stack helpers (they already persist via shell/units); LAN SSH debug (session-only); A/B upgrade prefs policy (unchanged).

## Capabilities

### New Capabilities

- `shell-hw-persist`: Verb-noun board helpers that apply simple hardware settings and persist the same files boot restore / HMI launch consume; Flutter MUST NOT be the sole writer of those prefs.

### Modified Capabilities

- `linux-backlight`: Persist requirement moves from “HMI writes preference file” to “setting brightness (HMI or shell) goes through `change-backlight`, which persists.”
- `linux-media-audio`: Volume set persists via shell helper (`change-volume` or equivalent), not Dart-only file write.
- `linux-display-orientation`: Orientation preference write goes through shell helper used by `hmi-launch.sh`.
- `linux-mouse-settings`: Mouse conf write goes through shell helper; flutter-pi still reads the same file on start.
- `linux-settings-persist`: Clarify that simple HW prefs are written by shell apply commands; Flutter controllers call helpers rather than writing those `/var/lib/lws-hmi/*` files directly.

## Impact

- Overlay: `change-backlight.sh` (complete persist if not already), new `change-volume.sh` / `change-orientation.sh` / `apply-mouse-settings.sh` (names TBD in design), `restore-settings.sh` callers, `lws-hmi-post-build.sh` PATH links, `verify-rootfs-overlay.sh` / `env-verify.sh`.
- App: `LinuxSysfsBacklight`, `LinuxMediaAudioController`, `LinuxFlutterPiOrientation`, `LinuxMouseSettings` (+ tests that today assert Dart file writes).
- Docs: `AGENTS.md` naming convention already covers verb-noun; update app/platform notes if they say Flutter owns persist.
- No GPT / kernel / Buildroot package pin changes expected.
