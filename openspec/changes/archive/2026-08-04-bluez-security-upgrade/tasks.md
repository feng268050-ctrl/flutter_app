## 1. Version spike and overlay pin

- [x] 1.1 Confirm current SDK `BLUEZ5_UTILS_VERSION=5.77` and headers package pairing; inventory Rockchip patch stash path
- [x] 1.2 Spike Buildroot recipe for BlueZ **5.87** (or newer 5.x tip); adapt `.mk` / `.hash` / patches as needed
- [x] 1.3 If 5.87 fails, lock highest buildable ≥ 5.82 and document; otherwise lock ≥ 5.87
- [x] 1.4 Add overlay `overlay/buildroot/package/bluez5_utils/` (+ headers) and extend `apply-overlay` sync; keep `sync_bluez5_utils_stock`

## 2. Rebuild and ship userspace

- [x] 2.1 `make apply-overlay` and confirm SDK recipe + Rockchip patch stashed
- [x] 2.2 Dirclean rebuild: `bash scripts/br-make-packages.sh bluez bluez5_utils` (and headers package if separate); rebuild `bluez-alsa` if linked
- [x] 2.3 `make build-rootfs` and verify `target/` `bluetoothd -v` matches pin
- [x] 2.4 `make upgrade`; on device confirm `bluetoothd -v` ≥ pin and `org.bluez` on D-Bus

## 3. Kernel coordination for CVE-2024-8805

- [x] 3.1 Track `kernel-61-lts-rebase` (or equivalent) so shipped kernel is ≥ 6.1.115 (prefer LTS tip)
- [x] 3.2 Record in PR that CVE-2024-8805 is closed by kernel, not BlueZ bump alone

## 4. Optional hardening

- [x] 4.1 H1: Disable OBEX at build or ensure `obexd` never starts on stack-up (unless product requires PBAP/file transfer)
- [x] 4.2 H2: Spike safer `JustWorksRepairing` than `always`; land only with pairing UX sign-off
- [x] 4.3 H3: Trim `ReconnectUUIDs` to profiles still required; retest HID + A2DP reconnect
- [x] 4.4 H4: Only if needed, extend `bluetoothd --noplugin=` denylist for unused plugins

## 5. Regression and residual risk

- [x] 5.1 Smoke: adapter enable, discoverable, phone A2DP Sink opt-in, AVRCP volume, Classic HID / HOGP input, agent prompts
- [x] 5.2 Document residual postponed CVEs still relevant with AVRCP/OBEX left enabled (e.g. CVE-2023-44431)
- [x] 5.3 Note follow-up when upstream publishes fixes for postponed ZDI BlueZ issues
