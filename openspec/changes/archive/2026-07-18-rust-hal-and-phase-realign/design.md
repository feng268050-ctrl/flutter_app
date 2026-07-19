## Context

lws-hmi today is a **ynh960-first appliance**: Flutter Demo talks to Dart abstract controllers implemented as `Linux*` backends that call `/usr/libexec/{wpa,network,bluetooth,hmi}/`, BlueZ D-Bus, sysfs, and serial. That validated hardware (P2 / P2.1–P2.4) but binds the **Platform API** to a Flutter process and board-specific paths (`gpio_innohi`, `/dev/ttyS5`, AIC8800 bringup).

Product strategy: **multiple motherboards and screens**, **different product Apps**, **shared UI framework (CyberUI)** and **shared embedded OS**. Intermediate layer must be a **portable HAL**, not App-local Dart adapters.

Constraints:

- Keep shipping ynh960; HAL lands as submodule and migrates capability-by-capability.
- Shell persist + boot restore (`settings-restore.service`, `/var/lib/*`) remain authoritative until HAL wraps the same contracts.
- flutter-pi on device for production UI; P3.2 emulator uses UTM + Weston + flutter-embedded-linux + HAL.
- AI stays `libai.so` (C++); HAL does not absorb NPU inference.

## Goals / Non-Goals

**Goals:**

- Define a **stable, versioned Platform API** implemented primarily in **Rust**, exposed to Flutter via a thin Dart client (FFI and/or local IPC).
- Place HAL in-repo as **git submodule / package** (same ownership model as CyberUI), developable in parallel with P3.0 / P3.3.
- Cover **already-integrated P2 hardware** behind HAL capabilities + **board/screen packs** for pin maps and LCD.
- Realign **roadmap docs** to the user’s P1–P5 list; rename FrostUI → **CyberUI**.

**Non-Goals:**

- Rewriting product business UI in this change (that is P4).
- Replacing systemd, A/B upgrade, or flutter-pi with a Rust init.
- One runtime image that auto-detects arbitrary motherboards (compile-time board pack is enough for a small board set).
- Moving CyberUI visual design off Frosted Glass in P3.0 (API named for longevity; look may change later).
- Android product APK / `YNHAPI` adaptation (P5.0; App-layer — not HAL `Android*` backends).
- **Product RGB / indicator LEDs** in the portable HAL (product-/vendor-specific; stay in App).
- Requiring every product to ship display, audio, or any network stack.

## Decisions

### D1 — Layer model (normative)

```
L0  Product App(s)          Flutter pages / business — per product
L1  CyberUI + CyberIME      Shared UI kit (Dart packages / submodules)
L2  Dart HAL client         Thin bindings + streams; no board sysfs
L3  Rust HAL                platformd and/or libhal.so — Platform API truth
L4  Board / Screen pack     profile + DTS/LCD/radio plugins (build-time)
L5  Linux kernel / BlueZ / ALSA / sysfs / serial
    (+ shell oneshots for boot/ops)
```

- **L0** must not import Linux path constants or spawn board helpers directly.
- **L2** mirrors capability APIs; may temporarily wrap legacy `Linux*` during migration.
- **L3** owns observation (events) and preferred control for migrated capabilities.
- **L4** supplies data: network **role → iface** map, Modbus tty (if any), audio route, default orientation, WiFiBT plugin id, LCD param set when display present.
- **L5** shell scripts remain for bring-up/persist until L3 calls them or reimplements safely.

### D2 — Rust HAL shape: daemon + optional library

- **Primary:** `hald` (systemd service) speaking a **versioned IPC** (prefer Unix domain socket + length-prefixed protobuf or JSON-RPC v1; D-Bus optional later for desktop tools).
- **Secondary:** `liblws_hal` / crate `lws_hal` for in-process FFI where latency matters (e.g. GPIO blink timing)—same capability traits, same board profile.
- Flutter uses **one Dart package** (name TBD: `lws_hal` / `cyber_hal`) exposing **D12** public types; connects to `hald` by default on device.

**Alternatives considered:** Dart-only Platform API (rejected: multi-App / multi-board); pure `.so` FFI with no daemon (rejected as sole model: hard to share events across processes and with shell/ops); rewrite all helpers in Rust day one (rejected: too risky).

### D3 — Submodule layout in this monorepo

```
packages/
  cyber_ui/          # git submodule — UI framework
  cyber_ime/         # git submodule — IME
  lws_hal_dart/      # Dart client (may live in HAL repo or here)
hal/                 # git submodule — Rust workspace
  crates/
    lws-hal-api/     # protobuf/schema + version
    lws-hal-core/    # traits, board profile
    lws-hal-linux/   # Linux backends
    hald/            # daemon binary
  boards/
    ynh960/          # board profile TOML/JSON + README
```

Exact repo URLs decided when first submodule is created; until then scaffold under `hal/` and `packages/` is allowed as in-tree stubs.

### D4 — Capability migration order (P3.1)

Migrate behind HAL in this order (lowest risk → highest coupling). **Skip any capability absent from the board profile / capability set.**

1. Board profile load + identity + **capability bitmap** + network role map
2. Backlight / display orientation (only if display present) via `Brightness` / `DisplayOrientation`
3. `SerialPort` map in profile (if present) — **not** product RGB LEDs
4. `AudioManager` / volume (if audio present)
5. `NetworkManager` (event-driven; if network roles advertised)
6. `BluetoothManager` (if present)
7. `TimeService` / `InputManager` / debug access (as needed for Demo parity)

Demo keeps working: each cutover swaps injection in `P2DemoPage` from `Linux*` to HAL client.

### D5 — CyberUI naming and design

- Public name: **CyberUI**; packages `cyber_ui`, `cyber_ime`.
- P3.0 implements **Frosted Glass** look (from lws-ui), with backdrop policy as today’s §6.3 (frozen default / live opt-in).
- Framework API must not encode “Frost” in type names that product Apps depend on long-term (`CyberCard`, `CyberDialog`, …); internal frost renderer may remain an implementation detail.
- Future design refresh = new theme/renderer behind same Cyber* widgets (SwiftUI analogy).

### D6 — Phase roadmap (authoritative mapping)

| New stage | Status | Was (approx.) |
|-----------|--------|----------------|
| Linux P1 | ✅ | P1 |
| Linux P1.5 | ✅ | P1.5 |
| Linux P2 | ✅ | P2 + P2.1 + P2.2 + P2.3 (hardware prep) |
| Linux P2.5 | ✅ | P2.4 (A/B + `make upgrade`) |
| Linux P3.0 | 🔲 | P4 FrostUI → **CyberUI + IME** |
| Linux P3.1 | 🔲 | **new** Rust HAL |
| Linux P3.2 | 🔲 | part of old P2.5 Linux emulator; stack = UTM + Weston + flutter-embedded-linux + HAL |
| Linux P3.3 | 🔲 | old P3 `libai.so` (target ~2026-07-22) |
| Linux P4 | 🔲 | old P5 business migration |
| Linux P5.0 | 🔲 | old P2.5 Android compat |
| Linux P5.1 | 🔲 | old P3.5 engine upgrade (3.24 → 3.41) |

**Dependency intent:** P3.0 and P3.1 may proceed in parallel after P2.5; P3.2 depends on usable HAL client stubs; P3.3 independent of UI kit; P4 needs CyberUI + HAL for settings/hardware pages; P5.0 after core Linux App shape; P5.1 when CyberUI/IME need newer Dart (may slip earlier if blocked).

### D7 — Emulator (P3.2) vs device

- Device: flutter-pi + DRM (unchanged for P4).
- Emulator: UTM VM, Weston (Wayland), **flutter-embedded-linux**, HAL with **sim/fake board pack** and optional host serial bridge to real lower unit (Modbus).
- HAL API identical; board pack `sim` or `host` selects fakes.

### D8 — Event-driven observation (absorbs `platform-event-driven-ui`)

**Decision:** Merge `platform-event-driven-ui` into this change. **Do not** implement a full Dart-only event stack in `Linux*Controller` and later rewrite it in Rust.

**Rule:** For any capability presenting live OS state to UI, after HAL cutover the **primary** observation path SHALL be OS events inside Rust HAL; Dart clients only Stream what HAL pushes. Primary `Timer` + `Process.run` status loops are forbidden for those capabilities.

**Normative event matrix** (from former `platform-event-driven-ui` design):

| Surface | Primary event source (in HAL) | Poll/`Process` status |
|---------|-------------------------------|------------------------|
| Ethernet (if capability present) | Netlink RTM_* on **role-mapped** iface | Forbidden as primary |
| Wi‑Fi (if present) | wpa_supplicant ctrl ATTACH / CTRL-EVENT-* | Forbidden as primary |
| Bluetooth (if present) | BlueZ D-Bus ObjectManager + PropertiesChanged | `bluetoothctl` Timer forbidden as primary |
| LAN SSH debug (if present) | systemd D-Bus unit properties | Forbidden: periodic status script as primary |
| USB HID keyboard (if present) | udev monitor | Forbidden: Timer `ls /dev/input` as primary |
| DateTime timezone/sync | timedate1 / prefs watch; UI 1s clock tick OK | Forbid timedatectl status poll as sole sync |
| Backlight (if present) | inotify on sysfs brightness | One-shot read OK |
| Volume (if present) | ALSA mixer notify when available | Forbid periodic `amixer` get as primary |
| Orientation / HTTP probe / Modbus | Non-goals for event bus (pref+restart / on-demand / bus R-R) | N/A |

Rare reconciliation Get after event-channel reconnect is allowed; tight status loops are not.

**Supersession:** Former `platform-event-driven-ui` is archived at `openspec/changes/archive/2026-07-17-platform-event-driven-ui/` (not synced to main specs). Keep its `design.md` as historical reference for the matrix above.

### D9 — Network interfaces: roles, not fixed `eth0`/`wlan0`

**Decision:** The HAL **Platform API MUST NOT require** kernel names `eth0` or `wlan0`. Apps and HAL clients talk in **roles** (e.g. `ethernet.primary`, `wifi.station`, `camera.link`). The **board profile** maps each advertised role → concrete iface name (ynh960 today: `ethernet.primary`→`eth0`, `wifi.station`→`wlan0`).

**Board-side:** May keep `eth0`/`wlan0` via udev/`systemd.link` for operational familiarity on a given SKU, but that is a **pack choice**, not the cross-product contract. A headless or single-NIC product advertises only the roles it has.

**Rejected:** Hard-coding `eth0`/`wlan0` into the HAL IPC schema as the only identifiers.

### D10 — Optional capabilities (capability discovery)

**Decision:** Every HAL capability is **optional**. `hald` advertises a capability set (and role map) at connect time. Clients MUST probe/`HasCapability` (or equivalent) before use; missing capability → structured `UNSUPPORTED` (not crash, not pretend success).

Examples of valid products: no display (no backlight/orientation), no audio (no volume), no Wi‑Fi, no ethernet, no Bluetooth, no Modbus. Profile and image omit unused backends and event watchers.

### D11 — Product RGB LEDs out of HAL

**Decision:** Three-color (or other) **product indicator LEDs are NOT part of the portable HAL**. They are product-/vendor-specific (paths and pins change by supplier). Remain in the **product App** (or a product-local adapter), optionally reading a **product overlay** outside the shared HAL pack—not `hald`’s public capability surface.

**Rationale:** HAL targets reusable OS facilities across motherboards; decorative/status LEDs are not that.

### D12 — Public naming (industry-style)

**Decision:** Portable HAL public types follow common system-service vocabulary (`*Manager` / `*Service`, `*Device`, `Capabilities`, `*State`), not Flutter-centric `*Controller`. App-layer may keep temporary `*Controller` façades that delegate to HAL during migration.

**Suffix rules:**

| Layer | Suffix | Examples |
|-------|--------|----------|
| HAL public API | `*Manager` or `*Service` (pick one per domain; prefer **Manager** for Android-familiar domains, **Service** for daemon-owned IPC faces—see table below) | `AudioManager`, `TimeService` |
| Hardware object | `*Device` / domain noun | `NetworkDevice`, `BluetoothDevice`, `InputDevice` |
| Snapshot / live state | `*State` / `*Snapshot` / domain config | `LinkState`, `Brightness`, `IpConfig` |
| Discovery | `Capability` / `Capabilities` / `BoardInfo` | |
| Client | `HalClient` | connects to `hald` |
| Implementation only | `*Backend` / `Linux*` / `Stub*` / `Sim*` | not part of stable App-facing names |

**Normative public type catalog (v0 intent):**

| Domain | Primary types | Notes |
|--------|---------------|--------|
| Entry | `HalClient`, `HalApiVersion`, `HalError` | version negotiate |
| Discovery | `Capabilities`, `Capability` (flags/enum), `BoardInfo` | all caps optional |
| Board pack (data) | `BoardProfile` (internal load) | maps roles → iface, etc. |
| Network | `NetworkManager`, `NetworkDevice`, `NetworkDeviceType`, `NetRole`, `Connection`, `LinkState`, `IpConfig`, `WifiNetwork` / `AccessPoint` | roles in profile; no hard-coded `eth0` in API |
| Bluetooth | `BluetoothManager`, `BluetoothAdapter`, `BluetoothDevice`, `BondState`, `PairingRequest` | |
| Display / backlight | `DisplayManager` (optional), `Backlight` / `Brightness`, `DisplayOrientation` | headless → omit |
| Audio | `AudioManager`, `Volume`, `Mute`, `AudioDevice` (optional) | |
| Time | `TimeService`, `WallClock`, `TimeZone`, `TimeSyncMode`, `TimeSyncResult` | |
| Input | `InputManager`, `InputDevice`, `MouseSettings`, `KeyboardPresence` | |
| Serial / bus | `SerialPort` (spec/open); Modbus protocol client may stay App-side | |
| Debug access | `SshDebug` / `DebugAccess` (engineering) | optional |
| Out of HAL | product `StatusLed` / RGB indicators | App/product module |

**Dart migration:** Existing `WifiController`, `EthernetController`, … MAY remain as thin App façades calling `NetworkManager` / `HalClient` until Demo/Settings are updated; new code SHOULD prefer HAL names.

**Rejected as HAL public names:** `*Controller` (UI/App layer), `LinuxWpaWifiController` (implementation), fixed `eth0`/`wlan0` identifiers, `GpioLedController` in portable HAL.

## Risks / Trade-offs

- [Dual stack during migration] → Keep shell contracts; feature-flag HAL per capability; Demo smoke each cutover.
- [Rust aarch64 cross + Buildroot packaging delay] → Host unit tests + `cargo` in Docker; ship `hald` via overlay prebuilt initially if needed.
- [IPC vs FFI latency for timing-sensitive I/O] → Optional in-process path; keep IPC for network/BT.
- [CyberUI rename churn vs lws-ui docs] → Document alias “CyberUI (Frosted Glass design)”; update plan §6.3 names.
- [Scope creep into full OS rewrite] → P3.1 = optional capabilities + ynh960 backends for present P2 caps; radio bringup plugins stay shell until stable; **no product LED in HAL**.
- [Assuming eth0/wlan0 everywhere] → Role map in profile (D9); ynh960 pack supplies today’s names.

## Migration Plan

1. Publish design + update `docs/flutter-pi-hmi-plan.md` / AGENTS phase blurb (this change).
2. Scaffold `hal/` Rust workspace + empty board profile `ynh960`; no App cutover yet.
3. Scaffold `packages/cyber_ui` naming in plan; implement in P3.0.
4. Per-capability: implement in Rust → Dart client → swap Demo → delete or stub `Linux*`.
5. Rollback: App env/`--dart-define=HAL=off` falls back to legacy controllers until P4.

## Open Questions

1. IPC schema: protobuf vs JSON-RPC for v1? (Default lean: **protobuf** in `lws-hal-api`.)
2. Is HAL submodule a **separate GitHub repo** from day one, or in-tree until first external consumer?
3. Should P5.1 (engine 3.41) move before P3.0 if CyberUI needs newer Dart immediately?
4. Official package names: `lws_hal` vs `cyber_hal` vs `embedded_hal_lws`?
5. Canonical role id strings for network (`ethernet.primary` vs `net.ethernet`)? Finalize in `lws-hal-api` v0.
