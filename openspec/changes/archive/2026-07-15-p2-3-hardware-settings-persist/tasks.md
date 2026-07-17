## 1. Units & helpers (isolation)

- [x] 1.1 Keep / finish `wlan-wpa.service` + `wlan-wpa.service-run.sh`; `wifi-stack-up` starts unit only
- [x] 1.2 Keep / finish `wlan-dhcp.service`; `wlan0-dhcp.sh` re-enters via unit
- [x] 1.3 Add `eth0-network.service` + route `eth0-dhcp.sh` (and apply path) outside HMI cgroup
- [x] 1.4 Update wifi-stack-down / eth0 stop to stop dedicated units; preset disable on-demand units

## 2. Wanted markers + restore

- [x] 2.1 Add restore script applying wifi/eth0/backlight/orientation/BT A2DP from `/var/lib/hmi/`
- [x] 2.2 Add `settings-restore.service` After=hmi (UI-first), WantedBy=multi-user
- [x] 2.3 Wire Demo/helper paths to create/clear `wifi-wanted` / `eth0-wanted`
- [x] 2.4 Bind `/var/lib/hmi` → `/userdata/{wpa_supplicant,network,bluetooth,hmi}` after userdata mount; restore After=param-update
- [x] 2.5 Demo `syncFromSystem()` so UI matches restored stacks

## 3. App

- [x] 3.1 Wi‑Fi controller writes/clears `wifi-wanted`
- [x] 3.2 Ethernet controller writes/clears `eth0-wanted`
- [x] 3.3 Backlight persists percent to `backlight-brightness`; tests if present

## 4. Verify & docs

- [x] 4.1 `verify-rootfs-overlay` / `boot-verify` checks for units, preset, no `wpa -B`, restore in wants
- [x] 4.2 Update plan P2.3 status + invariant; app README smoke note
- [x] 4.3 Confirm `push-app` remains unified detach path (no LAN-only fork)
