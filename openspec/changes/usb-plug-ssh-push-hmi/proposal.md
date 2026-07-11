## Why

P1 ships a lean HMI image with **no adbd** and no default remote debug path; iterating on the Flutter app today requires **serial shell** or a full **rootfs reflash** — impractical once boards leave the bench and for UI developers who do not use UART. The product has a **single OTG USB port** (same port used for RockUSB flash in bootloader). We need an **ADB-like developer workflow** encapsulated as **`make push-app`**: plug USB → push `libapp.so` + assets → restart HMI, **without reflashing** `update.img`. USB **ECM virtual Ethernet + sshd** (not mass storage / MTP) matches the team's automation-first workflow and raises the bar for casual misuse compared to exposing a drag-and-drop disk.

## What Changes

- Enable **USB gadget ECM** on the ynh960 Linux image (kernel fragment in default defconfig) with **plug-to-start / unplug-to-stop** behavior — no screen tap or serial command required when VBUS is present.
- Run **OpenSSH `sshd` only while USB debug is active**, listening on **`usb0` only** (`ListenAddress`), with **password auth** (`root` / `rockchip`, same practical posture as unsecured USB adb).
- Assign a **stable USB gadget `iSerial`** per device (SoC/DT serial) for identity — analogous to `adb devices` serial.
- Use a **fixed USB link network** (device `192.168.55.1/24`; host configures `192.168.55.2` on the matching interface) so `make` scripts do not depend on Wi‑Fi or board IP.
- Add host tooling: extend **`make devices`** to a **single merged table** (RockUSB + USB-SSH rows with **`MODE`** column: `Loader` / `Maskrom` / `USB-SSH`; columns `SERIAL`, `LocationID`, `IFACE`, `ADDR`), and **`make push-app`** (`SERIAL=` when multiple boards) to `scp` artifacts and `ssh systemctl restart hmi.service`.
- Extend **`make bootloader`** (existing `scripts/flash-usb.sh`) so a board running **Linux** reboots into **RockUSB Loader** via **`ssh … /usr/lib/lws-hmi/reboot-rockusb-loader`** over the USB ECM link (same `SERIAL=` / `BindInterface` as `push-app`); retain **adb reboot loader** as fallback when adb is available.
- Add board-side helper scripts and **systemd/udev** integration for gadget compose/teardown; **do not** add `sshd` or ECM to `multi-user.target.wants` — no debug surface at boot without a connected USB host.
- Update **`docs/flutter-pi-hmi-plan.md` §6.2 / §7.7** narrative: USB plug-to-debug as the primary **app iteration** path; LAN hidden SSH remains optional for P5.

**Non-goals (this change):**

- Replacing **`make flash`** / RockUSB MaskROM workflow.
- USB mass storage (MSC) or MTP.
- Re-enabling **`adbd`**.
- OTA / signed update bundles (P5).
- Windows RNDIS/NCM bring-up (may be follow-up; document macOS/Linux first).

## Capabilities

### New Capabilities

- `usb-plug-ssh-debug`: Target-side USB ECM gadget, VBUS-triggered start/stop, `usb0` addressing, per-device `iSerial`, `sshd` bound to `usb0` with password auth, teardown on disconnect, no boot-time enable.
- `host-push-app`: Host `make devices` / `make push-app`, USB serial → host interface resolution (`BindInterface`), `SERIAL=` multi-device selection aligned with `scripts/flash-usb.sh`, integration with `make build-app` outputs; extend **`make bootloader`** for Linux via USB-SSH + `reboot-rockusb-loader`.

### Modified Capabilities

_(none — no archived specs under `openspec/specs/` yet; P1 change specs remain historical. Planning doc §7.7 will be updated in prose during implementation.)_

## Impact

- **Kernel**: `overlay/kernel/rockchip/lws-hmi-usb-gadget.config` (or extend debug fragment) added to `board/ynh960_defconfig` `RK_KERNEL_CFG_FRAGMENTS`; ECM + configfs mass_storage **not** required.
- **Rootfs overlay**: `usr/lib/lws-hmi/usb-plug-ssh-*.sh`, udev rules or systemd units, optional `sshd_config.d` snippet for `ListenAddress usb0`.
- **Buildroot**: `openssh` already present; ensure `BR2_PACKAGE_OPENSSH_SERVER` and runtime dirs; **no** `BR2_PACKAGE_ANDROID_ADBD`.
- **Host**: `scripts/push-app.sh`, `scripts/usb-ssh-devices.sh` (names TBD), Makefile targets; extend `scripts/flash-usb.sh` **`bootloader`** for Linux USB-SSH path; README / AGENTS.md rebuild table row for overlay-only vs app-only.
- **Boot KPI**: Must not add `After=` / `Wants=` USB debug into `hmi.service` critical chain; verify via `boot-verify.sh` extensions.
- **Security posture**: Physical USB + knowledge of fixed IP/credentials; not exposed on `wlan0`/`eth0`; unplug closes ssh. Document threat model for field units.
