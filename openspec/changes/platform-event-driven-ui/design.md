## Context

P2 / P2.1 / P2.2 Demo on `P2DemoPage` already includes (non-exhaustive): device SN + Modbus rows, alarm temps, RGB LEDs, **audio + volume**, **backlight**, **orientation**, **date/time**, **Ethernet**, **USB keyboard**, **Wi‑Fi**, **HTTP proxy + probe**, **LAN SSH debug**, **Bluetooth** (+ A2DP sink).

Linux observation today is inconsistent: Wi‑Fi / Ethernet / BT / keyboard use **Timer + shell/CLI**; that conflicts with the product rule that Demo is OS-standard and reusable by P5 Settings.

Industry pattern (without requiring NetworkManager):

```text
OS truth (wpa / netlink / BlueZ / systemd / udev / sysfs / ALSA)
    — fd / D-Bus / ctrl socket events →
platform controller (snapshot)
    — Dart Streams →
Demo / Settings UI
```

Control plane (enable stack, Apply static IP, helpers escaping HMI cgroup) may still use scripts/units. **Observation plane** must not.

Constraints unchanged: no NM; on-demand Wi‑Fi/BT/eth units; P2.3 restore After=hmi; UI absolute priority; callers use abstract controllers only.

## Goals / Non-Goals

**Goals:**

- Inventory every Demo live-state surface; for each **in-scope** item, specify an event (or subscribe) source and Stream contract.
- One shared engineering rule: **no primary Timer+`Process.run` status loops** in Linux platform controllers.
- Terminal / udev / `systemctl` / phone-side BT changes that affect shown state MUST update UI without re-tapping Demo.
- Keep APIs stable for P5 reuse.

**Non-Goals:**

- NetworkManager / connman / iwd.
- Reworking Modbus as an “OS event bus” (serial request/response + optional Demo refresh remains correct).
- Treating LED mode matrix as externally owned OS state (HMI is authority unless later product says otherwise).
- Orientation live-rotate without HMI restart (still pref file + restart).
- HTTP GET probe becoming a continuous monitor (request/response on demand).
- Sub-millisecond RT guarantees.
- Android backends (P2.5).

## Demo → event matrix (normative for this change)

| Demo surface | Live OS state? | Primary event source | Abstract API | Poll/`Process` status |
|--------------|----------------|----------------------|--------------|------------------------|
| **Ethernet** | Yes | **Netlink** RTM_NEWLINK / DELLINK / NEWADDR / DELADDR on `eth0` | `EthernetController` streams | Forbidden as primary |
| **Wi‑Fi** | Yes | **wpa_supplicant ctrl** ATTACH + CTRL-EVENT-* | `WifiController` streams | Forbidden as primary |
| **Bluetooth** adapter / peers / A2DP units | Yes | **BlueZ D-Bus** (`org.bluez`, ObjectManager + PropertiesChanged); bluealsa via systemd/D-Bus | `BluetoothController` streams | `bluetoothctl` Timer forbidden as primary |
| **LAN SSH debug** | Yes | **systemd D-Bus** unit properties for `lws-hmi-lan-ssh.service` (or helper that only *starts/stops*, status via sd-bus) | `SshDebugController` → add Stream or change-notify | Forbidden: periodic `enable-ssh-debug.sh status` as primary |
| **USB HID keyboard** presence | Yes | **udev** monitor (`SUBSYSTEM=input` / HID keyboard IDs) | New or extend probe → `Stream<KeyboardPresence>` | Forbidden: Timer `ls /dev/input` as primary |
| **Date & time** timezone / sync mode | Partial | **timedate1** D-Bus when present; prefs files for our sync-mode; **wall clock display** may use UI `Timer` (1s) — that is presentation, not OS discovery | `DateTimeController` | Forbid shell `timedatectl` status poll as sole sync of timezone |
| **Backlight** slider | Yes (if external write) | **inotify** (or equivalent) on sysfs `brightness` | `BacklightController` (+ optional Stream) | One-shot read OK; periodic Process N/A |
| **Volume** slider | Yes (if external mixer set) | **ALSA** mixer elem notify / pollfd subscribe | `MediaAudioController` (+ optional Stream for volume) | Forbid periodic `amixer` get as primary |
| **HTTP proxy** fields | Prefs | Optional **inotify** on `/var/lib/lws-hmi/http-proxy` if changed out-of-band | already file-backed | No status poll needed |
| **Orientation** | Pref + restart | N/A mid-session | file Get on load | N/A |
| **Audio playing** | Yes | Existing player stdout / process exit → `playing` Stream | already event-ish | Keep |
| **RGB LEDs** | HMI-owned | N/A | GPIO API | N/A |
| **Modbus SN / temps** | Device bus | Request/response (+ optional slow Demo refresh) | Modbus client | Domain poll OK (not this change’s “OS status” ban) |
| **HTTP probe result** | On demand | N/A | request Future | N/A |

Anything marked **Forbidden as primary** may still use a **rare reconciliation Get** after reconnect of the event channel (lossy bus), never a tight status loop.

## Decisions

### D0 — One rule, many backends

**Choice:** Ship one OpenSpec change covering all in-scope Demo surfaces. Shared guidelines: work off UI isolate; debounce equal snapshots; backoff reconnect; first paint never waits on attach.

**Rationale:** User requirement is completeness; piecemeal Wi‑Fi-only leave Ethernet/BT still nonstandard.

### D1 — Ethernet: Netlink

**Choice:** Long-lived netlink ROUTE socket (Dart FFI or small helper, or `ip monitor link addr` as **one** long-lived process—not per-tick). Map admin up/down, carrier/operstate, IPv4 add/del → `EthAdminState` / `EthLinkState` Streams.

**Shell disconnect example:** `ip link set eth0 down` / unplug cable / `dhcpcd` lease → UI updates.

**Rejected:** `Timer` + `ip -br` every 2s.

### D2 — Wi‑Fi: wpa control interface

**Choice:** As previously designed—ATTACH to `/var/run/wpa_supplicant/<iface>`, CTRL-EVENT → Streams; STATUS Get on attach; L3 via netlink or L2-triggered Get.

**Shell example:** `wpa_cli disconnect|reconnect`.

### D3 — Bluetooth: D-Bus (end interim CLI)

**Choice:** Promote BlueZ D-Bus from “preferred” to **required primary** for adapter Powered/Discoverable/Pairable/Alias and Device1 peer list. Use `dbus` Dart package or `dart:ffi` + sd-bus / gdbus **long-lived** connection with signal match—not `bluetoothctl show` every 3s.

A2DP: subscribe `bluealsa.service` / unit active via systemd D-Bus or bluealsa API when present; keep pref file for wanted.

**Shell/phone example:** `bluetoothctl power off`, phone pair/disconnect → adapter/peers Streams update.

**Rejected:** Keeping bluetoothctl poll as production path.

### D4 — LAN SSH: systemd unit subscription

**Choice:** Extend `SshDebugController` with `Stream<bool> enabled` (or status object). Observe `lws-hmi-lan-ssh.service` ActiveState via systemd D-Bus (`Subscribe` / PropertiesChanged). Enable/disable still call existing helpers (cgroup escape).

**Shell example:** `systemctl stop lws-hmi-lan-ssh` → Demo toggle/state updates.

### D5 — USB keyboard: udev

**Choice:** Replace `Timer.periodic` probe with udev monitor (libudev FFI or `udev` netlink). Emit presence Stream; Demo listens. Initial snapshot on subscribe.

**Shell example:** unplug/plug HID keyboard → presence line updates.

### D6 — Date/time

**Choice:**

- **Displayed clock:** UI timer / `Stream.periodic` reading `DateTime.now()` (or synced offset)—normal for OS shells; not “OS poll abuse”.
- **Timezone / NTP / our sync-mode:** load prefs; subscribe `org.freedesktop.timedate1` when available for Timezone/NTP; file watch on our `time-sync-mode` / `timezone` prefs if helpers rewrite them.

### D7 — Backlight & volume

**Choice:** After local set, write prefs/sysfs as today. Additionally watch sysfs brightness (inotify) and ALSA mixer value changes so external `echo … > brightness` / `amixer sset` update sliders. If ALSA notify is hard on this tree, document stretch: volume watch phase-2 after net stacks.

**Priority:** Net stacks (eth/wifi/bt) + SSH + keyboard **P0** in tasks; backlight/volume/datetime **P1** in same change unless blocked.

### D8 — HTTP proxy

**Choice:** Optional inotify on proxy prefs file so out-of-band edits refresh Demo fields. No continuous network monitor.

### D9 — Lifecycle vs P2.3 restore

Same as Wi‑Fi design: HMI first; restore After=hmi; controllers show `starting` while wanted && channel not up; attach when ready; do not duplicate bring-up while restore owns it.

### D10 — Package sketch

```text
lib/platform/wifi/wpa_control_client.dart          # ctrl socket
lib/platform/netlink/…                             # shared eth (+ optional wlan addr)
lib/platform/bluetooth/bluez_dbus_client.dart
lib/platform/ssh/…                                 # systemd unit watch
lib/platform/input/udev_keyboard_monitor.dart
lib/platform/datetime/…                            # timedate1 optional
```

Demo sections only `listen` Streams; no section-local status Timers except clock face.

## Risks / Trade-offs

- **[Risk] Dart D-Bus / netlink / udev bindings thin on flutter-pi** → Mitigate: small C helpers using libsystemd/libudev/libnl + length-prefixed stdout **events** (one process per subsystem), or FFI; never per-tick CLI.
- **[Risk] Scope creep** → Mitigate: P0 vs P1 in tasks; Modbus/LED explicitly out.
- **[Risk] Permission on dbus/udev** → Mitigate: HMI runs as root today; keep policies for later drop-priv.
- **[Trade-off] Long-lived helpers** → Prefer in-process; helpers only if Dart blocked—must be event printers, not polled by Dart.

## Migration Plan

1. Specs/tasks accept → implement P0 (eth, wifi, bt, ssh, keyboard) behind existing abstracts.
2. Remove Timer status loops; keep helpers for start/stop.
3. Device matrix smoke (table below).
4. P1 backlight/volume/datetime watches.
5. README Demo smoke updated for external changes per surface.

### Device smoke (acceptance)

| Action outside Demo | UI must |
|---------------------|---------|
| `ip link set eth0 down` / unplug | Ethernet link/admin updates |
| `wpa_cli disconnect` | Wi‑Fi phase updates |
| `bluetoothctl power off` / phone disconnect | BT adapter/peers update |
| `systemctl stop lws-hmi-lan-ssh` | LAN SSH shows off |
| unplug USB HID keyboard | Keyboard presence updates |

## Open Questions

1. Prefer pure Dart vs tiny `lws-hmi-*-monitor` event helpers for netlink/udev/D-Bus? (**Default:** Dart/FFI first; event-helper binary if blocked.)
2. Ship volume/backlight watches in same PR train as P0 or immediately after? (**Default:** same change, P1 tasks after P0 green.)
3. Is `dbus` pub package acceptable on pinned Flutter 3.24.4 / flutter-pi? (**Spike in task 1.x.**)
