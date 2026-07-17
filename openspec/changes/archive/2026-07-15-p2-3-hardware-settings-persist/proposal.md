## Why

`make push-app` / `systemctl restart hmi` kills Wi‑Fi (and drops LAN SSH) because Demo `Process.run` left `wpa_supplicant`/`dhcpcd` in the `hmi.service` cgroup. P2.1 prefs already live under `/var/lib/hmi/`, but nothing restores them after a full reboot without re-entering Demo. P2.3 must fix both: **settings stacks independent of HMI**, and **boot restore via the same helpers**.

## What Changes

- Move Wi‑Fi / wlan0 DHCP / eth0 apply onto **dedicated systemd units** outside `hmi.service` (Demo only `systemctl start/stop` helpers that escape the HMI cgroup).
- Add **wanted markers** (`wifi-wanted`, `eth0-wanted`) and persist **backlight brightness**.
- Add **`settings-restore.service`** oneshot (**`After=hmi.service`**, Nice/idle) that reuses existing `*-up.sh` / eth helpers; Demo watches `*-wanted` and shows starting/connecting like a manual enable while restore runs.
- App controllers write wanted markers on enable/apply and clear them on disable; backlight writes the preference file on set.
- Keep host `push-app` detach+poll (USB and LAN same path).
- **Non-goals:** LAN SSH boot persistence; product Settings UI (P5.2).

## Capabilities

### New Capabilities

- `linux-settings-persist`: Hardware preference schema under `/var/lib/hmi/`, wanted markers, boot restore oneshot, and the invariant that settings daemons must not join the HMI cgroup.

### Modified Capabilities

- `linux-wifi`: Radio enable starts `wlan-wpa.service` (not in-process `wpa_supplicant -B`); DHCP via `wlan-dhcp.service`; `wifi-wanted` on enable.
- `linux-ethernet`: Apply path escapes HMI cgroup via `eth0-network.service`; `eth0-wanted` on apply.
- `linux-backlight`: Persist brightness percent under `/var/lib/hmi/backlight-brightness`.
- `hmi-systemd-boot`: Restore unit enabled at multi-user; deferred radio units remain off unless wanted; HMI restart must not tear down network settings.
- `buildroot-lws-hmi-image`: Overlay units, restore script, preset/`verify-rootfs` checks.

## Impact

- **Rootfs overlay:** new units (`wlan-wpa.service`, `wlan-dhcp.service`, `eth0-network.service`, `settings-restore.service`), helpers, preset, verify scripts.
- **App:** Wi‑Fi / Ethernet / backlight controllers; small unit tests.
- **Docs:** plan §P2.3 status + invariant.
- **Host:** `push-app.sh` already detaches; no behavior change required beyond docs.
