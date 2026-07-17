## Context

P2.3 introduced `/var/lib/hmi/` (→ `/userdata/{wpa_supplicant,network,bluetooth,hmi}`) prefs plus `restore-settings.sh` after HMI. Simple knobs (backlight, media volume, display orientation, mouse) were persisted by Dart writing files, while apply/restore used shell. `change-backlight` without persist showed the split is user-visible: SSH apply ≠ reboot restore.

Network/BT already mostly persist inside shell helpers / units. This change unifies the **simple HW knobs** on verb-noun shell commands.

## Goals / Non-Goals

**Goals:**

- One writer path per simple HW pref: shell helper applies runtime state **and** persists the canonical file.
- Flutter Linux backends call those helpers (Process) for set; get may still read sysfs / ALSA / pref files.
- Operator PATH commands for knobs operators already use over SSH (`change-backlight`, plus volume / orientation / mouse apply).
- Keep file paths and restore/`hmi-launch` consumers unchanged.

**Non-Goals:**

- Migrating Wi‑Fi / eth0 / BT / HTTP proxy / datetime writers (already shell- or unit-centric, or out of this slice).
- Putting systemd-only helpers (`apply-eth0`, `run-wpa`, …) on PATH.
- Changing userdata layout or A/B prefs survival policy.
- Making Flutter parse/write preference files for these four knobs after migration (except read-only get / status if needed).

## Decisions

### D1 — Scope: four simple knobs first

**Choice:** backlight, media volume, display orientation, mouse settings.

**Why:** Same pattern (percent or small conf → file → restore/launch). Network stacks already have helpers.

**Alt:** Migrate every `/var/lib/hmi` writer — deferred; larger surface, little SSH pain.

### D2 — Script names (verb + noun)

| Command / script | Pref file | Apply |
|---|---|---|
| `change-backlight` | `backlight-brightness` | sysfs brightness |
| `change-volume` | `media-volume` | ALSA mixer (same as restore/amixer path) |
| `change-orientation` | `display-orientation` | write pref; optional `systemctl try-restart hmi` when `--apply` |
| `apply-mouse-settings` | `mouse.conf` | write conf; flutter-pi reload is HMI-start / existing path |

**Why:** Matches AGENTS.md verb-noun; `change-*` for continuous knobs, `apply-*` for conf blob.

**Alt:** Single `set-hw` with subcommands — rejected (harder PATH discoverability).

### D3 — Flutter invokes shell, does not dual-write

**Choice:** `set*` on Linux backends runs `/usr/bin/change-backlight` (etc.) or `/usr/libexec/hmi/*.sh` if PATH not guaranteed inside service. No second Dart `File.write` for the same pref.

**Why:** Avoids race / divergence; SSH and Demo share code.

**Alt:** Keep Dart write + shell write — rejected (exactly the bug class).

### D4 — PATH exposure

**Choice:** Link `change-backlight`, `change-volume`, `change-orientation`, `apply-mouse-settings` in `post-build.sh`; verify-rootfs asserts them.

**Why:** Operators recover black screen / mute without full paths.

### D5 — Orientation restart

**Choice:** Helper always persists; applying flutter-pi `-o` stays “restart HMI” (existing). Demo may pass a flag or call `systemctl try-restart hmi` after helper returns, same as today.

**Why:** Shell owns file; process lifecycle can stay in Dart or a thin `--restart-hmi` flag later.

### D6 — Volume apply implementation

**Choice:** Mirror `restore-settings.sh` amixer (or existing media volume apply logic) inside `change-volume.sh`.

**Why:** Boot restore and Demo share one mixer write path.

## Risks / Trade-offs

- **[Risk] Process.run latency on slider drag** → Mitigation: keep existing coalesce / latest-wins in Demo; helper must stay cheap (sysfs / amixer only).
- **[Risk] Helper missing on old images** → Mitigation: soft-fail + debugPrint; daily path is `build-rootfs` + upgrade.
- **[Risk] Orientation restart loops** → Mitigation: helper does not restart unless explicitly asked; Demo keeps current restart policy.
- **[Trade-off] Dart unit tests that mock File prefs** → Rewrite to fake Process or extract thin wrapper; accept test churn.

## Migration Plan

1. Land shell helpers + persist (backlight may already persist) + post-build links + verify.
2. Point Flutter backends at helpers; update tests.
3. `make apply-overlay` / `build-rootfs` / `upgrade`; SSH `change-backlight 80` then reboot confirms file + panel.
4. Rollback: reintroduce Dart writes (prefs schema unchanged).

## Open Questions

None blocking; datetime / proxy remain Dart-or-mixed until a follow-up if needed.
