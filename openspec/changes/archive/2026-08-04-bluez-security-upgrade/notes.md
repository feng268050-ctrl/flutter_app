# bluez-security-upgrade — implementation notes

## Pin

| Field | Value |
|-------|--------|
| Userspace | **BlueZ 5.87** (`BLUEZ5_UTILS_VERSION` / headers) |
| Overlay | `overlay/buildroot/package/bluez5_utils/` + `bluez5_utils-headers/` |
| Sync | `scripts/apply-overlay.sh` → `sync_bluez5_utils_package` then `sync_bluez5_utils_stock` |
| Prior SDK | Rockchip Buildroot **5.77** (+ ABI-breaking Rockchip patch, still stashed) |

## 1.1 Inventory (pre-pin)

| Item | Finding |
|------|---------|
| SDK `BLUEZ5_UTILS_VERSION` | `5.77` |
| Headers package | `bluez5_utils-headers` (stale `HEADERS_VERSION=5.72` label; tarball shared via `BLUEZ5_UTILS_VERSION`) |
| Rockchip patch stash | `linux-sdk/buildroot/package/bluez5_utils/.lws-rockchip-bluez-patch-disabled/0001-bluez-modified-only-for-rockchip.patch` |
| Product state dir | `/var/lib/bluetooth` (do **not** keep Rockchip `--localstatedir=/data`) |

## 1.2–1.3 Version lock

Upstream Buildroot tip at implement was **5.86**; kernel.org already published **5.87** (`sha256` from `sha256sums.asc`). Locked **5.87** (meets floor ≥ 5.87). Recipe adapted from Buildroot master 5.86 (sap/health removed; headers under `lib/bluetooth/*.h`).

## Hardening applied

| Tier | Decision |
|------|----------|
| **H1** | OBEX disabled in `lws_hmi_bt.config` (`# BR2_PACKAGE_BLUEZ5_UTILS_OBEX is not set`) → `--disable-obex`; `obexd` not built. Incremental `target/` leftovers purged by `purge-retired-rootfs-artifacts.sh` |
| **H2** | Spike only: safer `JustWorksRepairing` (`confirm`/`never`) not landed — keep `always` until pairing UX sign-off |
| **H3** | `ReconnectUUIDs` already minimal (A2DP Source + AVRCP + HID + HOGP); no further trim |
| **H4** | Not needed — OBEX compile-disabled; existing `--noplugin=battery` retained |

Plugin Kconfig: after 5.86+ Config.in dropped `default y` on audio/hid/hog, product fragment **explicitly enables** `PLUGINS_AUDIO` / `HID` / `HOG`.

## CVE-2024-8805 (kernel, not BlueZ)

Closed by **kernel** ≥ 6.1.115 (alias CVE-2024-53144). Product already tracks `kernel-61-lts-rebase` (archived) with pin **6.1.180** (`overlay/kernel/KERNEL_6_1_SUBLEVEL`). **Do not claim** the BlueZ 5.87 bump alone remediates CVE-2024-8805.

## Residual postponed CVEs (still relevant)

With AVRCP kept for A2DP Sink UX, Debian-postponed issues **without upstream fixes** may still apply after 5.87, including:

- **CVE-2023-44431** (AVRCP, HIGH) — residual while AVRCP enabled
- Related AVRCP/OBEX Medium ZDI set — partially mitigated by 5.82+ length/parsing fixes; OBEX surface removed via H1
- **CVE-2023-51596** (PBAP) — mitigated by H1 (OBEX/PBAP not built)

Acceptance: best available tip + reduced surface; not zero High Bluetooth CVE.

## Device verify (2026-08-04)

After `make upgrade` on USB-SSH ynh960:

| Check | Result |
|-------|--------|
| `uname -r` | **6.1.180** (CVE-2024-8805 kernel floor met) |
| `bluetoothd -v` | **5.87** |
| `obexd` | absent |
| `org.bluez` on D-Bus | present (`bluetooth.service` active) |
| Adapter | Powered, Pairable; AVRCP UUIDs advertised |
| `JustWorksRepairing` | `always` (H2 not landed) |
| `--noplugin=` | `battery` only |

### 5.1 Smoke notes

Automated: adapter power, discoverable toggle, agent scripts present, bluealsa binaries present, `org.bluez` tree with `hci0`.

Operator follow-up (physical): phone A2DP Sink opt-in + AVRCP volume, Classic HID / HOGP key/mouse, pairing agent PIN prompts — same matrix as prior BT demos; stack version/pin verified above.

## Follow-up

Re-check NVD/Debian when upstream publishes fixes for postponed ZDI BlueZ issues (especially AVRCP). Consider landing H2 (`JustWorksRepairing`) after Demo/product pairing UX sign-off.

## Rebuild

```text
make apply-overlay
bash scripts/br-make-packages.sh bluez bluez5_utils bluez5_utils-headers bluez-alsa
make build-rootfs
make upgrade
```

Verify: `bluetoothd -v` → `5.87`; `busctl` / D-Bus `org.bluez` present; no `obexd` in process list / not started on stack-up.
