# P2.1 Wi-Fi / BT — spike notes

## Chip (device-confirmed 2026-07-14)

| Item | Value |
|------|--------|
| SDIO | `mmc2` `vendor=0xc8a1` `device=0x0082` / `0x0182` |
| Chip | **AIC8800D80** (Innohi `rk_wifi_init` table: `c8a1:0082`) |
| Not | Broadcom AP6256 (`02d0:a9bf`) — Innohi still ships `nvram_ap6256` files, but this SKU is AIC |

## Why earlier bring-up failed

1. Rockchip `wifibt-util.sh` chip list has **no** `c8a1:*` → `Failed to detect Wi-Fi/BT chip!`
2. Forced AP6256 / `bcmdhd` cannot bind to AIC SDIO
3. Innohi path needs **`aic8800_bsp` → `aic8800_fdrv` → `aic8800_btlpm`** under `/vendor` or `/system/lib/modules`, plus AIC firmware (`fmacfw_8800d80_u02.bin`, …)
4. `lws_hmi` skips Innohi `rk_wifi_init` install (MainServer block)

## Fixes

| Piece | Change |
|-------|--------|
| Kernel | `lws-hmi-ynh960-wifibt.config` — AIC WLAN + BTLPM modules, FW path `/vendor/etc/firmware` |
| Runtime | `wifibt-bringup.sh` — detect `c8a1`, prefer `rk_wifi_init`, else manual `insmod` + `hciattach` |
| Rootfs hook | `09-lws-hmi-wifibt-innohi.sh` — install `rk_wifi_init`, `/system/lib/modules` → `/vendor/lib/modules` |
| Verify | expect `aic8800_fdrv.ko` + AIC firmware, not `bcmdhd` |

## BT pairing note

Discoverable without a live **Agent1** → phone sees HMI but pairing fails
(Authentication Failed). `bt-pair-agent.sh` must keep `bluetoothctl --agent=…`
running and call `default-agent`. Verify: `cat /tmp/lws-bt-agent.log`,
`kill -0 $(cat /run/lws-hmi-bt-agent.pid)`.

## A2DP Sink (Bluetooth speaker) — opt-in, default off

Phones often fail “连接” without a media profile. Product path is **opt-in**:

| Piece | Role |
|-------|------|
| `BR2_PACKAGE_BLUEZ_ALSA` | bluealsa + aplay (in image) |
| Demo **BT speaker (A2DP)** switch | default off; calls `setA2dpSinkEnabled` |
| Pref `/var/lib/lws-hmi/bt-a2dp-sink` | `1` / `0`; stack-up restores only if `1` |
| `bt-a2dp-sink-up/down.sh` | start/stop bluealsa units |
| `bluealsa.service` | `-p a2dp-sink` → MediaEndpoint |
| `bluealsa-aplay.service` | PCM → board ALSA |
| `bt-audio-prepare.sh` | `RING_SPK_HP` + soft-stop mpg123 |
| `main.conf` `Class=0x240414` | Loudspeaker CoD |
| `bt-pair-agent` + `bt-trust-paired` | PIN auto-yes; **Trust only** after Paired (phone initiates A2DP) |

**vs future BT provisioning:** A2DP Sink is Classic audio; BLE GATT provisioning is independent in theory. AIC8800 does not accept `ControllerMode=bredr` via mgmt, so we stay on default dual and harden pair/A2DP follow-up instead.

### bluealsa exit 127 / `libSegFault.so`

Rockchip `bluez-alsa.mk` used `--enable-debug` → configure links `-lSegFault` (present in sysroot, **not** installed on target). Fix: `apply-overlay` forces `--disable-debug` + `ac_cv_lib_SegFault_backtrace=no`; `lws-hmi-post-build.sh` also copies `libSegFault.so` into target as a safety net for already-built binaries.

### iPhone “连接失败” after PIN

Symptom: agent confirms passkey; journal has  
`src/device.c:search_cb(): … Function not implemented (38)` and/or `Host is down (112)`.

Root cause on this SKU: BlueZ **reverse service discovery** (SDP browse of the phone after the phone initiates the pair). AIC8800 returns ENOSYS; iPhone then drops.

**Fix:**
1. `ReverseServiceDiscovery = false` (+ `RefreshDiscovery = false`) — skip reverse SDP of the phone.
2. After Paired: **Trust only**, never `bluetoothctl connect` from HMI — connect makes us the BR/EDR initiator and BlueZ still SDP-browses the phone → same ENOSYS. Phone must start A2DP Source → our Sink.

Also keep: trust/connect follow-up; omit bad `KernelExperimental=false`; do not force `ControllerMode=bredr` (Not Supported on AIC).

**Retest:** flash + power-cycle. On device optionally `rm -rf /var/lib/bluetooth/*` once (or HMI Remove + iPhone 忽略). Adapter → BT speaker → Pairable → pair again. Journal should **not** show `search_cb` for the phone MAC right after PIN.

### A2DP audio quality / Demo volume

- `Missing RTP packets` / kernel `Unexpected start frame`: BT ACL jitter (common on Wi‑Fi+BT combo). Mitigate with larger `bluealsa-aplay` PCM buffer + `Nice=-10`. Some residual warnings under RF load are expected; audible glitches should drop.
- Demo **Volume** now also calls `bt-a2dp-volume.sh` (BlueALSA soft-volume). ALSA DAC mixer alone does not change BT loudness when soft-volume is enabled.
- Journal spam `set_volume() … No such file or directory (-2)` / `Couldn't set BT device volume`: bluealsa SoftVolume on **A2DP Sink** still wrote BlueZ `MediaTransport.Volume` → AIC `avrcp_set_volume` ENOENT. Soft volume already works; patch `0002-lws-a2dp-sink-softvol-skip-avrcp.patch` skips that write. Needs `bluez-alsa` rebuild.


Scan OK but Demo stuck on `obtainingIp`: preference for `clientid` over default
`duid` (consumer APs often ignore DUID). `wlan0-dhcp.sh` waits for lease and
falls back to `udhcpc`; Dart surfaces helper stderr on failure.


After `apply-overlay` → **kernel** → **rootfs** → flash:

1. `verify-env` — `aic8800_*.ko`, `rk_wifi_init`, AIC firmware
2. Demo Wi‑Fi → `wlan0` + associate + HTTP
3. Demo BT Discoverable → phone finds `lws-hmi` → pairs → **连接成功** + music on speaker
4. `verify-boot` — wifibt still deferred at boot
