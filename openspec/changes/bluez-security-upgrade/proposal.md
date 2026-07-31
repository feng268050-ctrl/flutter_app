## Why

Device and Buildroot ship **BlueZ 5.77** (`bluetoothd` / `bluetoothctl`). Upstream tip is **5.87**. An NVD/Debian review found: (1) **CVE-2024-8805** (HIGH 8.8, HID/Just-Works adjacent) is fixed in the **Linux kernel** (≥ 6.1.115; alias CVE-2024-53144), not by bumping userspace — our kernel is still **6.1.99**; (2) several ZDI AVRCP/PBAP/OBEX issues remain **unfixed upstream** even on Debian sid 5.87 (postponed); (3) releases after 5.77 still carry useful AVRCP/HID/OBEX hardening (e.g. 5.82 PDU length checks). Product uses A2DP Sink + AVRCP + Classic HID / HOGP, with `JustWorksRepairing = always` and HID/HOG reconnect UUIDs — so we should take every available upgrade and reduce unused surface even when some High CVEs cannot be closed completely.

## What Changes

- Pin Buildroot **`bluez5_utils` (+ headers)** from **5.77 → 5.87** (or newest 5.x at implement time, floor **≥ 5.87**) via git-tracked overlay recipe + `apply-overlay` sync; keep **stock** Device1 Connect/Disconnect (continue stashing Rockchip’s ABI-breaking patch).
- Rebuild with `scripts/br-make-packages.sh` so stamps do not reuse 5.77 binaries; verify on device `bluetoothd -v`.
- Explicitly **depend on / coordinate with** `kernel-61-lts-rebase` for **CVE-2024-8805** (kernel BT); do not claim userspace alone closes it.
- Apply **optional hardening** where product allows: disable or omit unused OBEX/PBAP if not required; review `JustWorksRepairing` / discoverable defaults; keep HID/A2DP behavior required by `linux-bluetooth`.
- Document residual risk: Debian-postponed AVRCP/PBAP High/Medium issues may remain after 5.87 — acceptance is “best available tip + reduced surface,” not zero CVE.
- **Out of scope:** replacing BlueZ; A2DP Source / HFP product roles; rewriting Dart HAL; claiming full closure of postponed ZDI CVEs.

## Capabilities

### New Capabilities

- `buildroot-bluez-security`: Overlay-owned BlueZ version pin, stock-patch policy, rebuild/verify, coordination with kernel LTS for CVE-2024-8805, optional profile hardening, and residual-risk documentation.

### Modified Capabilities

- `linux-bluetooth`: Security posture for shipped BlueZ version floor and optional OBEX/policy hardening without removing required A2DP Sink / HID / HOGP behaviors.
- `linux-sdk-own-tree`: Confirm `bluez5_utils` overlay pin stays on the always-injected Buildroot package sync path (with existing stock-patch stash).
- `buildroot-lws-hmi-image`: Rootfs BlueZ userspace matches the overlay pin (not vendor 5.77).

## Impact

- Overlay: `overlay/buildroot/package/bluez5_utils/` (+ headers if split), `scripts/apply-overlay.sh` sync; `lws_hmi_bt.config` / `main.conf` hardening knobs as decided.
- Build: `make apply-overlay`, `bash scripts/br-make-packages.sh … bluez5_utils` (and headers), `make build-rootfs`, `make upgrade`.
- Runtime regression: adapter bring-up, phone A2DP Sink (opt-in), AVRCP volume, Classic HID / HOGP input, pairing agent, bluealsa path.
- Cross-change: `kernel-61-lts-rebase` for HID Just-Works kernel fix; `openssl-cve-upgrade` independent.
- Residual: CVE-2023-44431 / CVE-2023-51596 and related postponed items may still apply until upstream ships fixes — mitigate by surface reduction where possible.
