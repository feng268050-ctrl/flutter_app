## Context

`hal/sys_info` today exposes host inventory (SoC serial via `/usr/bin/read-serial`, DT model, kernel, app version, CPU/mem/thermal). Product-facing identity (brand / model / factory SN) and tunables (camera IP/type, focus scale, control-card alarm mode) have no single Linux contract: `camera_ip` lives in `board_profile.json`, SN is chip/DT-only, and the plan still mentions a P5.1 `model.properties` path that was never implemented.

lws-ui used flat `model.properties` for similar keys, plus host `make set-prop` / `del-prop` over adb. This change standardizes the file as `/var/lib/hmi/product.ini`, owned by HAL, with shell helpers and `make devices` sharing the same SN rule, and ports the host mutate commands over SSH (with multi-key `set-prop`).

## Goals / Non-Goals

**Goals:**

- One on-device file: `/var/lib/hmi/product.ini` (under existing `VAR_HMI` → `/userdata/hmi`).
- HAL `ProductInfo` abstraction: built-in properties `brand` / `model` / `sn`; extended accessors for known keys; generic `get(key)` for future keys.
- Missing file/key → empty string in HAL; Device Information maps empty → `-`.
- `sn` = non-empty `product.ini` `sn`, else chip/board serial (same chain as today’s `read-device-serial.sh`).
- Host device selection uses **`SN=`** (renamed from `SERIAL=`); optional **`CHIP_ID=`**; deprecated `SERIAL=` alias.
- Host `SN` column / gadget iSerial follows product SN rule (`product.ini` sn → chip ID).
- `SysInfoSnapshot` gains `brand` / `model` / `chipId`; `serialNumber` resolves via `ProductInfo.sn` (ini → chipId fallback).
- Callers of `camera_ip` prefer product.ini via HAL, then board profile helper, then default.
- Host `make set-prop` / `make del-prop` (lws-ui parity over SSH) mutate on-device `product.ini`; `set-prop` accepts multiple assignments in one run.

**Non-Goals:**

- Android `/system/etc/model.properties` or APK changes; adb remount/`set-prop` against `/system`.
- Baking a factory-filled `product.ini` into the git overlay (file is provisioned on device / userdata).
- Moving Modbus gunhead / firmware rows into sys_info.
- Rewriting MediaMTX / `configure-camera-eth0.sh` in this change (only document the new key source; scripts may adopt later).
- In-process hot reload of `ProductInfo` without restarting HMI (operators use `set-prop`/`del-prop`, which restart `hmi.service`).

## Decisions

### D1 — Flat INI under `/var/lib/hmi/product.ini`

**Decision:** Use a flat `key=value` file (optional `#` comments, blank lines ignored). No required `[sections]` for v1. Path default `/var/lib/hmi/product.ini`, injectable for tests/stubs.

**Known keys (v1):**

| Key | Access | Notes |
|-----|--------|--------|
| `brand` | property | string |
| `model` | property | string (product model, not DT `boardModel`) |
| `sn` | property | factory SN; empty → chip serial fallback |
| `camera_ip` | accessor | string |
| `camera_type` | accessor | `1` or `2`; other non-empty values → treat as empty for typed accessor |
| `focus_scale_ref` | accessor | string |
| `control_card_comm_alarm_mode` | accessor | `slide_window` or `immediate`; else empty for typed accessor |

**Alternatives considered:** JSON (heavier for shell/`make devices`); keep `model.properties` name under `/oem/etc` (conflicts with planned mediamtx path and AGENTS `/var/lib/hmi` convention).

### D2 — `ProductInfo` in HAL; thin surface on `SysInfo`

**Decision:**

```text
ProductIniReader  →  Map<String,String>
ProductInfo       →  brand / model / sn / chipId (fields)
                  →  cameraIp() / cameraType() / focusScaleRef()
                     / controlCardCommAlarmMode() / get(key)
LinuxSysInfo      →  holds ProductInfo; snapshot.brand / .model / .serialNumber / .chipId
StubSysInfo       →  injectable ProductInfo or empty defaults
```

- Built-in identity fields are **class properties** (immutable snapshot of last read).
- Extended keys are **methods** (may re-read map; typed validation).
- App MUST NOT parse `product.ini` directly.
- Do **not** put camera/focus/alarm-mode onto `SysInfoSnapshot` (keeps D17 inventory vs product tunables split); Apps that need them take `ProductInfo` from `BoardBindings` / `AppServices`.

**Alternatives considered:** Stuff all keys into `SysInfoSnapshot` (pollutes volatile watch signatures); App-only reader (breaks “abstract in HAL”).

### D3 — Empty string contract (not null) for product fields

**Decision:** Product identity strings use `''` when absent. Device Information / Demo use existing `kUnavailableDisplay` (`-`) when the value is null **or** empty. Chip serial fallback still applies before treating `sn` as empty. Existing non-product `SysInfo` fields may remain nullable.

**Rationale:** Matches the user contract and makes shell/Dart agreement trivial (`[ -z "$v" ]`).

### D4 — Shared SN / ChipID resolution in shell (source of truth for host tools)

**Decision:** Update `read-device-serial.sh` (exposed as `/usr/bin/read-serial`):

1. Default (product SN): if `/var/lib/hmi/product.ini` has non-empty `sn=` → print it; else chip ID chain.
2. `--chip-id`: skip product.ini; DT `serial-number` → `/proc/cpuinfo` `Serial` → `lws-<machine-id>` → `lws-unknown`.

`make devices` table columns: **MODE SN ChipID LocationID IFACE IP USB**. USB-SSH/SSH rows probe live board SN + ChipID. Android adb / RockUSB loader: SN = ChipID = adb SerialNo / upgrade_tool SerialNo.

**Host env (device selection):** Rename `SERIAL=` → **`SN=`** for all host commands that previously used SERIAL (`push-app`, `upgrade`, `shell`, `flash`, `reboot` / `reboot-loader`, `debug-app`, device-target selection for `set-prop`, …). `SN=` matches table **SN** or **ChipID**. **`CHIP_ID=`** match ChipID only (use when `make set-prop SN=…` would overwrite selection). Deprecated **`SERIAL=`** remains an alias for `SN=`. Document in Makefile `help`, `.env.example`, README, AGENTS.md.

Dart `ProductInfo.chipId` via `DeviceSnReader.readChipId()` (`read-serial --chip-id`); `ProductInfo.sn` = ini sn or chipId. `SysInfoSnapshot.chipId` / `serialNumber` mirror those.

**Alternatives considered:** Dart-only ini read + leave shell unchanged (would break `make devices` parity); keep `SERIAL=` as the primary name (rejected — column and env should both say SN).

### D5 — `camera_ip` precedence

**Decision:** `ProductInfo.cameraIp()` if non-empty; else `BoardProfile.helpers.camera_ip`; else boot-self-check default `192.168.1.100`. Update `boot_self_check_camera.dart` (and any HAL helper) accordingly.

### D6 — Device Information UI (lws-ui grouping)

**Decision:** Match lws-ui Settings → Device Information **card grouping**, using the same Material settings chrome as Common Settings (`SettingsScrollView` / `SettingsSectionHeader` / `SettingsGroup` / `SettingsValueRow`; QR via Material `Dialog`):

1. **Identity:** Device Model + QR affordance, Device SN, Gunhead SN  
2. **Versions:** System Version, Kernel Version, Control Card Version, Laser Version, Wire Feeder Version  
3. **Platform:** Display Stack + Camera Type (`1`/`2` → Blue/Red Light) + Focus Scale Reference (`product.ini` `focus_scale_ref`, empty → `-`)

**Device Model display:** `brand + " " + model` with each missing part as `-`; if both missing (computed `- -`), show a single `-`.

**Device QR:** Same v2 payload as lws-ui `DeviceQRCodeUtils`: `SN|2|Model|SystemVersion`, `|` sanitized to `_` in fields. Model segment uses brand/model joined without `-` placeholders. Tap QR icon (or model row affordance) opens a dismissible dialog with the QR image. Do not show Modbus Link on this tab.

**Out of scope for this change:** Check Update button / auto-check OTA checkbox (lws-ui bottom actions); Modbus Link row.

### D7 — Extensibility

**Decision:** `ProductInfo.get(String key)` returns raw trimmed value or `''`. New factory keys can ship in ini without a HAL release; typed accessors are added when Apps need validated enums. Document known keys in HAL dartdoc / this change’s spec.

### D8 — Host `make set-prop` / `del-prop` (SSH, multi set)

**Decision:** Port lws-ui’s `set-prop` / `del-prop` workflow to lws-hmi with these mappings:

| lws-ui | lws-hmi |
|--------|---------|
| adb + `/system/etc/model.properties` | SSH (same device selection as `push-app` / `shell`: `SN` / `CHIP_ID` / `IP`) + `/var/lib/hmi/product.ini` |
| One `KEY=value` per `set-prop` | **One or more** `KEY=value` in one `set-prop` (atomic write of the merged file) |
| One UPPERCASE key per `del-prop` | Same (one key); missing key → warn, exit 0 |
| UPPERCASE CLI → lowercase file key | Same |
| Relaunch Android app | `systemctl restart hmi.service` (or existing board HMI restart helper) after successful mutate |

CLI examples:

```bash
make set-prop BRAND=Innohi MODEL=YNH960 SN=FACTORY-001
CHIP_ID=ABC123 make set-prop SN=FACTORY-001   # multi-board: CHIP_ID selects; SN is product key
make set-prop CAMERA_IP=192.168.1.50 CAMERA_TYPE=2
make set-prop CONTROL_CARD_COMM_ALARM_MODE=immediate
make del-prop CAMERA_IP
```

Implementation sketch:

- Shared host helper to upsert/delete keys in a local temp copy of the remote file (reuse lws-ui style `upsert_*` / `delete_*` logic; skip Make/workflow vars such as `CHIP_ID`, `IP`, deprecated `SERIAL`, `BUILD_JOBS`, … — **not** product `SN`).
- When `SN=` is among product assignments, clear device-select `SN` for that run so Make’s `SN=` does not steal board selection.
- Pull (or create empty) remote `product.ini` via SSH, apply all upserts, push back, `chmod 0644`, then restart HMI once.
- Makefile: pass `$(MAKEOVERRIDES)` and/or filtered goals into the script; for `del-prop KEY` where `KEY` is a Make goal (not `KEY=`), swallow extra goals like lws-ui (dummy `%:` rule scoped carefully).
- Update `Makefile` `help`, README Make commands, and AGENTS.md when the targets are added.

**Alternatives considered:** Only single-key `set-prop` (weaker than requested); edit via `make shell` only (no operator ergonomics); write from Dart on-device (host factory flow still needs Make).

## Risks / Trade-offs

- **[Risk] Factory forgets `product.ini` → SN falls back to chip ID** → Mitigation: document provisioning; Device Information still shows a stable chip SN; Brand/Model correctly show `-`.
- **[Risk] Shell vs Dart SN drift** → Mitigation: D4 — prefer one helper path; tests cover ini-present and ini-absent.
- **[Risk] Invalid `camera_type` / alarm mode silently empty** → Mitigation: typed accessors document allowed values; raw `get` still returns the bad value for diagnostics.
- **[Risk] `/var/lib/hmi` missing before userdata mount** → Mitigation: treat as missing file → empty strings; SN still available from chip via helper after early boot.
- **[Trade-off] product `model` vs DT `boardModel`** → Keep both: DT model remains engineering inventory; product `model` is factory SKU string for About UI.
- **[Risk] Multi-key `set-prop` partially applied if SSH drops mid-push** → Mitigation: merge locally, single remote replace of the whole file; fail closed if push fails (no partial remote apply of half the keys).
- **[Risk] HMI restart interrupts an active weld/session** → Mitigation: document that `set-prop`/`del-prop` restart HMI; factory/setup use before production runs.

## Migration Plan

1. Land HAL reader + `ProductInfo` + tests (stub/host).
2. Update `read-device-serial.sh`; verify `make devices` SN/ChipID with and without ini `sn`.
3. Wire App Device Information + camera IP precedence.
4. Add `make set-prop` / `del-prop` host scripts + help/README; verify multi-key upsert and HMI restart.
5. Factory / ops: use `set-prop` (or place `product.ini` under `/userdata/hmi/`; path `/var/lib/hmi/product.ini`).
6. Rollback: `del-prop` keys or remove ini → chip SN + empty brand/model + profile `camera_ip`.

## Open Questions

- None blocking implementation; confirm factory key spellings match the table in D1 (aligned with lws-ui intent, snake_case standardized).
