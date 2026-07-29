## Context

lws-ui implements **内置控制板固件升级** as a home-only path parallel to online product OTA:

- Detect `assets/firmware/…/LSW01H####S####.bin` (auto-select newest SW for matching HW).
- Gate: HW equal + bundled SW strictly greater than live control-card versions.
- Confirm dialog → copy asset → `BinUtil` / `ControllerUpgradeHandler` Modbus OTA protocol.
- Progress + success/fail dialogs; `FirmwareUpgradeCoordinator` mutex with `UpgradeActivity`.
- Dev helper `make sync-firmware` (adb push + broadcast; no confirm / no version gate).

lws-hmi already has:

- Product Home (`HomePage`) with Modbus live start after optional boot self-check.
- Device Information Firmware Version from `device.control_card_version`.
- Full `upgrade` holding group in `assets/hal/modbus.json` (0x0000–0x004F window).
- Unused `bundledFirmware*` l10n (en/zh/zh_TW).
- Explicitly deferred product OTA (Settings check-update stub, cloud OTA no-ops).

This change ports the **bundled path** into Flutter and adds a Linux-HMI host helper analogous to lws-ui `sync-firmware`. Reference: sibling repo `/Users/ayon/Workspace/lws-ui` (`BundledFirmwareBootstrap`, `BundledFirmwareVersionGate`, `ControllerUpgradeHandler`, `openspec/specs/startup-bundled-firmware-upgrade`).

## Goals / Non-Goals

**Goals:**

- Parity with lws-ui bundled firmware behavior on Linux HMI (home-only, confirm-required, Modbus transfer).
- Correct version gate and Modbus protocol (128-byte packets, command codes, contiguous FC16 lengths, confirm/timeout success semantics).
- Typed App asset layout under `assets/firmware/control-board/` so `make build-app` / `push-app` ships bins and future firmware types can share the parent tree.
- Host helper `make upgrade-control-board` (control-board-only; no confirm / no version gate).
- Coordinator hook so a future OTA UI cannot flash concurrently.

**Non-Goals:**

- Online zip / manifest OTA, Settings “Check for Updates” client, cloud `command.check_update` / `command.update_system`.
- Host OS `make upgrade` (A/B rootfs / FIT stream), factory flash, GPT repartition.
- Additional firmware types under `assets/firmware/` beyond `control-board/`.
- Process-library bundled import / HomePromptQueue multi-prompt orchestration beyond “after self-check + Modbus ready, before or alongside other home prompts without blocking first paint”.
- Repo-wide Cyber dialog width system (only constrain bundled-firmware dialogs in this change).

## Decisions

### 1. App-layer Modbus upgrade handler + minimal HAL contiguous write

**Choice:** Implement `ControllerUpgradeHandler`-equivalent in `app/lws_hmi/lib/features/bundled_firmware/` using Modbus attribute/group reads plus **contiguous** `writeHoldingRegisters(address, words)`.

**Why:** Protocol is product-specific (LSW01 filename rules, register layout in App `modbus.json`). Catalog `writeGroup('upgrade', …)` always writes the full 80-word window and breaks lws-ui frame lengths; add a narrow HAL/App API for FC16 contiguous writes only.

**Alternatives:** Dedicated `cyber_hal` firmware API — rejected beyond `writeHoldingRegisters`; revisit if a second App needs the full protocol.

### 2. Home-only bootstrap after Modbus + versions ready

**Choice:** Hook from `HomePage` after `ensureModbusLive` (and after boot self-check completes when shown), when `device.control_hw_version` and `device.control_card_version` are available. Subscribe via `RouteAware` / `appRouteObserver` so returning to Home can re-check. Do not check on Settings / Engineer / Monitor / process modes.

**Why:** Matches lws-ui `MainActivity` / HomePrompt eligibility; avoids competing with self-check and non-home workflows.

**Alternatives:** App cold-start global check — rejected (lws-ui forbids blocking splash; prompts off-home).

### 3. Version gate = filename integers, not SemVer

**Choice:** Port `BundledFirmwareVersionGate` / `UpgradeFileReaderUtils` filename parse (`LSW01H####S####.bin`); HW must match; SW must be strictly greater. When multiple bins exist, auto-select the highest SW among HW-matching names.

**Why:** Identical to control-board / lws-ui contract; Device Information SW is the same integer family.

### 4. Asset pipeline: typed `assets/firmware/control-board/`

**Choice:** Keep control-board `.bin` files under `app/lws_hmi/assets/firmware/control-board/` (declared via parent `assets/firmware/` in `pubspec.yaml`). Multiple bins are allowed; runtime picks the newest SW for the live control HW. Parent `assets/firmware/` is reserved for future sibling types.

**Why:** App assets are the runtime source of truth; typed subdirs avoid a flat dump when more firmware kinds land; no repo-root mirror or build-time copy step.

**Alternatives:** Repo-root `firmware/` + build copy (lws-ui style) — rejected. Flat `assets/firmware/*.bin` — rejected once multi-type packaging was required.

### 5. UX: Cyber dialogs + bounded width + existing l10n

**Choice:** Confirm / blocking progress (determinate percent) / success / fail via `showCyberDialog`. Reuse `bundledFirmware*` strings. Constrain dialog content with `maxWidth` (~520) so stretch layouts do not go full-bleed.

**Why:** String parity already landed; CyberUI is the FrostedGlass stand-in on Linux HMI; unbounded `CrossAxisAlignment.stretch` inside dialogs read as full-screen width on the panel.

### 6. Host helper: `make upgrade-control-board`

**Choice:** Host script uploads the selected control-board `.bin` from `assets/firmware/control-board/` over SSH to `/run/hmi/control-board-upgrade/`, then writes `/run/hmi/upgrade-control-board.cmd`. App `SyncFirmwareCommandWatcher` (name retained historically) polls that cmd file and calls `BundledFirmwareBootstrap.startSyncFirmwareUpgrade` (no confirm, `skipSameVersionCheck`).

**Why:** Operators/devs need a direct control-board-only path similar to lws-ui `make sync-firmware`, while keeping transfer inside the HMI. Naming sits under the host `upgrade*` family without streaming OS images.

### 7. Coordinator stub for future OTA

**Choice:** In-app `FirmwareUpgradeCoordinator` with `bundledInProgress` / `otaInProgress` flags. This change only sets bundled flags; OTA flag remains false until P4 OTA UI.

**Why:** Prevents accidental double-flash later without implementing OTA now.

### 8. Emulator / no control card

**Choice:** On P3.2 virt / missing Modbus versions, skip quietly (no blocking error). Same degrade spirit as lws-ui emulator skip.

### 9. Protocol constants + confirm semantics (normative)

Align with lws-ui `DeviceUpgradeConstant` / handler:

| Item | Value |
|------|--------|
| Info command | `0x1234` |
| Data command | `0x55AA` |
| End command | `0x0000` |
| Max packet | 128 bytes |
| Success latch | `0x1212` |
| Fail latch | `0x0202` |
| Confirm timeout → success | 30s after transfer end (boards often apply without latch) |
| Stall / overall timeout | Match lws-ui (30s stall / 60s no-first-packet) |
| Post-end success preference | Live HW/SW already match target → success |
| Fail latch grace | Brief `0x0202` may be transient; require sustained fail before declaring failure |

During transfer: exclusive session / pause competing Modbus poll/watch; resume on end. Confirm poll SHOULD read a consistent `status` group snapshot (HW/SW + ota cmd) rather than interleaved single-attribute reads.

## Risks / Trade-offs

- **[Risk] Protocol drift vs control-board firmware** → Mitigation: port Java handler behavior and constants literally; validate on ynh960 with a known HW=1000 board and current `app/lws_hmi/assets/firmware/control-board/LSW01H1000S*.bin`.
- **[Risk] Modbus live poll fights OTA writes** → Mitigation: exclusive session / pause continuous poll for upgrade duration; resume on end.
- **[Risk] Large `.bin` in App image** → Mitigation: ship only needed release bins under `control-board/`; multi-bin allowed for HW variants / staging but prefer one current SW per HW.
- **[Risk] Confusing `upgrade-control-board` with host OS `make upgrade`** → Mitigation: UI/docs always qualify this path as **control-board only**; helper uploads one `.bin` and never touches boot/rootfs/OEM artifacts.
- **[Trade-off] No full HomePromptQueue** → Acceptable: wire only bundled firmware after self-check; other home prompts remain independent until a later queue change.
- **[Trade-off] Dialog width only for firmware dialogs** → Broader Cyber dialog layout cleanup is separate; this change only fixes the upgrade UX surface.

## Migration Plan

1. Land App + asset under `app/lws_hmi/assets/firmware/control-board/`; ship via `make build-app` + `make push-app` (or rootfs bake for release).
2. Add/replace release `.bin` files under `assets/firmware/control-board/` before release builds (runtime picks newest matching HW).
3. Operators may use `make upgrade-control-board` for forced reflash (ignores version gate); requires running HMI with the cmd watcher.
4. Rollback: remove/replace `.bin` or ship App without upgrade candidate (gate skips); no GPT/partition change.
5. OTA footer and cloud OTA commands remain deferred — no operator migration for Settings check-update.

## Open Questions

- None for this slice. Success path immediately re-reads `device.control_card_version` when available (preferred over waiting for the next live poll).
