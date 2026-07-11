## Context

lws-hmi P1 delivers a **single OTG USB port** on ynh960 used for **RockUSB** flashing in bootloader (MaskROM/Loader) and **no USB enumeration** during normal Linux runtime — `adbd` is explicitly disabled (`lws_hmi_base.config`). App deployment today follows **rootfs overlay** (`make build-app` → `build-rootfs` → `flash`) or ad-hoc serial access. The product plan (`docs/flutter-pi-hmi-plan.md` §6.2, §7.7) maps Android **adb** to **on-demand sshd** over the network; engineering discussion concluded that for **make-driven iteration**, **USB ECM + ssh/scp** is preferable to MSC/MTP or serial scripts, with **plug-to-enable** behavior (like adb) rather than a hidden screen tap before each session.

An optional kernel fragment `lws-hmi-debug-usb.config` already enables **ECM + FunctionFS** but is **not** in default `ynh960_defconfig` and has **no userspace wiring**. Host flash tooling (`scripts/flash-usb.sh`) already standardizes **`SERIAL=`** selection for multi-device RockUSB and adb.

**Constraints:**

- **Plan A boot KPI**: `hmi.service` critical chain must remain `local-fs.target` only; USB debug must not block first home frame.
- **Single image**: No separate “dev” firmware; USB debug is a runtime mode, default-off without VBUS.
- **Single OTG port**: Cannot simultaneously be USB host (panel U-disk) and gadget; Linux runtime uses **device mode** for debug.
- **App layout**: `/opt/hmi/lib/libapp.so`, `/opt/hmi/data/flutter_assets/` (meta-flutter); engine stays on rootfs `/usr/lib`.

## Goals / Non-Goals

**Goals:**

- **Plug USB cable (VBUS)** → board brings up **ECM gadget + `usb0` + sshd on `usb0` only** within a few seconds; **unplug** → teardown gadget and stop ssh on `usb0`.
- Host **`make push-app`** pushes Flutter release artifacts and restarts `hmi.service` without `build-rootfs` / `flash`.
- **`make devices`** lists connected **USB-SSH** boards with **`SERIAL`**, **`LocationID`**, host **`IFACE`**, and **`ADDR`** (`192.168.55.1`); **`SERIAL=`** selects target when multiple connected (same ergonomics as `make flash`).
- Per-device identity via USB **`iSerial`** (stable hardware serial).
- Password login **`root` / `rockchip`** acceptable for this debug channel.
- Extend **`boot-verify.sh`** to assert USB debug units are **not** enabled at boot.

**Non-Goals:**

- `adbd`, MSC, MTP, or drag-and-drop GUI update flows.
- LAN-wide ssh on `eth0`/`wlan0` (§7.7 hidden SSH remains a separate P5 track).
- Signed OTA bundles, rollback partitions, or `/oem` app partition migration.
- Windows USB driver automation (document macOS/Linux first; RNDIS/NCM follow-up if needed).

## Decisions

### 1. Transport: USB ECM + OpenSSH (not adbd / MSC)

**Choice:** **configfs USB composite** with **ECM** function; **`sshd`** with **`ListenAddress 192.168.55.1`** bound to **`usb0`** only.

**Rationale:** Team wraps deployment in **`make`** (`scp`/`ssh`); ECM is already sketched in repo; no Android adbd dependency; no filesystem corruption risk of MSC; casual users do not get a drive letter.

**Alternatives considered:**

- **adbd** — familiar but contradicts P1 removal and product direction.
- **MSC staging** — poor fit for automation; dual-mount hazards.
- **Screen tap then USB** — rejected per product preference for adb-like plug behavior.

### 2. Lifecycle: VBUS-triggered start/stop (plug-to-debug)

**Choice:** **udev** rule (or **systemd path** unit) on OTG **VBUS attach** starts `lws-hmi-usb-plug-ssh.service`; **detach** stops it and runs teardown.

**Rationale:** Matches adb USB debugging UX; **unplug closes attack surface** automatically; no forgotten debug session after a §7.7-style toggle.

**Alternatives considered:**

- **Always-on gadget at boot** — rejected (KPI + security).
- **Manual `systemctl start`** — rejected for target UX (serial not acceptable for UI devs).

### 3. Addressing: fixed /24 on every device; disambiguate by host interface

**Choice:** Device always **`192.168.55.1/24`** on `usb0`; host script assigns **`192.168.55.2/24`** on the **per-cable** interface (`en*` / `usb*`).

**Rationale:** `make push-app` uses a constant target IP; multi-device disambiguation via **`ssh -o BindInterface=$IFACE`** (or route scoped to interface), not per-board IP allocation.

**Alternatives considered:**

- **Unique IP per `iSerial`** — adds discovery/DHCP complexity without benefit if BindInterface works.

### 4. Device identity: USB gadget `iSerial` == `SERIAL` column

**Choice:** Read stable serial from **Device Tree `serial-number`** or Rockchip SoC ID; set gadget string **`iSerial`**; host correlates **`iSerial` ↔ USB topology ↔ netdev** via sysfs (Linux) / **ioreg** (macOS).

**Rationale:** Same mental model as **`adb devices`** and existing **`make flash SERIAL=`**; reuse env var **`SERIAL`** / **`LWS_HMI_SERIAL`**.

### 5. sshd posture: password auth, usb0-only, not enabled at boot

**Choice:** Ship **`sshd`** in rootfs (already planned for P5 §7.7) but **`systemd preset disable sshd.service`** remains; plug service **`ExecStartPre`** starts sshd or spawns **`sshd -o ListenAddress=192.168.55.1`** instance; **`PasswordAuthentication yes`** for `root` with default password **`rockchip`** (Buildroot default unless changed).

**Rationale:** User explicitly accepts adb-equivalent trust model; restricting to **`usb0`** prevents LAN exposure.

**Alternatives considered:**

- **Key-only** — stronger but higher friction for `make` scripts; deferred as optional hardening.

### 6. HMI during push: keep `hmi.service` running; restart after copy

**Choice:** Do **not** stop HMI when ECM comes up; **`make push-app`** runs **`systemctl restart hmi.service`** after `scp`.

**Rationale:** Unlike MSC, no exclusive mount; shorter maintenance window.

### 7. Host scripts: parallel to `flash-usb.sh`

**Choice:** Add **`scripts/usb-ssh-devices.sh`** and **`scripts/push-app.sh`**; extend **`make devices`** to merge RockUSB (`upgrade_tool ld`) and USB-SSH rows in one table with a **`MODE`** column; add Makefile target **`push-app`**. Extend **`run_bootloader`** in **`scripts/flash-usb.sh`** to support Linux boards.

**Rationale:** One device list for flash, push-app, and bootloader — same **`SERIAL=`** mental model as today; no separate `devices-usb-ssh` target.

### 8. Linux bootloader: USB-SSH + `reboot-rockusb-loader`

**Choice:** When **`make bootloader`** runs and no RockUSB device is already connected, prefer **Linux USB-SSH** if a USB-SSH row exists in **`make devices`**: `ssh` to **`root@192.168.55.1`** (with **`BindInterface`** when `SERIAL=` is set) and execute **`/usr/lib/lws-hmi/reboot-rockusb-loader`**, then **`wait_for_rockusb`** (existing). If **adb** is available and no USB-SSH target is selected, fall back to **`adb reboot loader`** (Android / legacy). Do **not** use `busybox reboot loader` or `systemctl reboot` on the board.

**Rationale:** P1 Linux image has no adbd; **`reboot-rockusb-loader`** (committed separately) uses kernel **`RESTART2`** with mode **`loader`** to enter RockUSB Loader — the same end state as **`adb reboot loader`**, enabling **`make flash`** without UART. Reuses USB ECM link from plug-ssh so UI developers need not run serial commands.

**Prerequisites:** Board image includes **`/usr/lib/lws-hmi/reboot-rockusb-loader`** (built during **`make build-rootfs`**); USB plug-ssh active (cable connected) for the SSH path.

**Alternatives considered:**

- **Serial-only `reboot-rockusb-loader`** — rejected for target UX (same reason as plug-ssh).
- **Always adb** — fails on Linux image without adbd.

### 9. Kernel: enable ECM in default ynh960 defconfig

**Choice:** New fragment **`lws-hmi-usb-gadget.config`** (ECM + configfs + dwc3 gadget) added to **`RK_KERNEL_CFG_FRAGMENTS`**; retire or subsume optional `lws-hmi-debug-usb.config` to avoid duplicate maintenance.

**Rationale:** Feature is part of standard developer image, not a manual fragment toggle.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| **[Risk] Two boards → same `192.168.55.1` routing ambiguity** | Host **`BindInterface`**; require **`SERIAL=`** when count > 1; document in `make devices`. |
| **[Risk] macOS interface naming changes (`en7` → `en8`)** | Resolve by USB **LocationID / iSerial**, not cached iface names. |
| **[Risk] Host IP not configured on plug** | `push-app.sh` runs `ifconfig`/`ip addr add` on detected iface before `scp`. |
| **[Risk] Accidental USB plug in field exposes ssh** | **usb0-only** listen; unplug teardown; document physical access threat model; optional future key-only. |
| **[Risk] Gadget compose delays or breaks if cable already connected at boot** | udev **add** events at boot; `push-app` retries ping (adb wait-for-device pattern). |
| **[Risk] Confusion with RockUSB Loader mode** | Different USB PID / mode column in `make devices`; flash still uses MaskROM/Loader, not Linux ECM; **`make bootloader`** explicitly transitions Linux → Loader before **`make flash`**. |
| **[Risk] `sshd` accidentally enabled on LAN** | `boot-verify.sh` + `ListenAddress` drop-in; preset keeps `sshd.service` disabled. |

## Migration Plan

1. Land kernel fragment + rootfs overlay (udev/systemd, scripts, sshd drop-in).
2. Rebuild firmware once: `make apply-overlay` → `make build-rootfs` → `make build-img` → `make flash`.
3. Add host scripts to repo; developers `make build-app` then `make push-app` (no rootfs rebuild for app-only).
4. Update `README.md`, `AGENTS.md` rebuild table, and `docs/flutter-pi-hmi-plan.md` §6.2 / §7.7.
5. **Rollback:** Remove udev rules and kernel fragment; reflash previous `update.img`; no partition migration required.

## Open Questions

1. **Exact Rockchip udev/VBUS sysfs path** on ynh960 DT — confirm on hardware during implementation (`extcon`, `udc` state, or `dwc3` role switch).
2. **Windows hosts** — if required, add NCM/RNDIS function to composite in a follow-up change.
3. **Whether `openssh` root password** remains `rockchip` on shipping images or is rotated per customer (debug doc only vs image change).
