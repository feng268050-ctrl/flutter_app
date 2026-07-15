## Context

P2.1 delivered on-demand Wi‑Fi / Ethernet / BT helpers and prefs files. Starting long-lived daemons from Flutter `Process.run` put them in `hmi.service`'s cgroup, so `push-app` → `systemctl stop hmi` killed Wi‑Fi. LAN SSH already uses `lws-hmi-lan-ssh.service` for the same class of bug. P2.3 extends that pattern to settings stacks and adds boot restore.

## Goals / Non-Goals

**Goals**

- HMI restart / push-app MUST NOT bring down Wi‑Fi, eth0 IP, BT stack (already mostly unit-backed), or other settings daemons.
- Cold boot restores P2.1 prefs when `*-wanted` (or equivalent) says so, using **the same helpers** Demo uses.
- Plan A KPI: restore must not require waiting for WLAN association before starting `hmi.service` (soft-fail + journal).

**Non-Goals**

- Persist LAN SSH debug across reboot.
- Product Settings UI / status bar (P5.2).
- NetworkManager / SoftAP.

## Decisions

### 1. Isolation invariant

**Choice:** Settings long-lived processes run only under dedicated units (`lws-hmi-wpa`, `lws-hmi-wlan0-dhcp`, `lws-hmi-eth0`, existing `bluetooth.service`). Helpers re-enter via `systemctl start` when not already `LWS_*_IN_UNIT`.

**Rationale:** Same fix as LAN SSH; Demo stays a thin client.

### 2. Wanted markers

**Choice:** `/var/lib/lws-hmi/wifi-wanted` and `eth0-wanted` (presence = restore). Cleared on radio/interface disable. Those paths resolve under **`/userdata/lws-hmi/`** via prefs-bind.

### 2b. Prefs on userdata

**Choice:** After `param-update` mounts userdata, `lws-hmi-prefs-bind.sh` migrates seed/runtime files and `ln -sfn /userdata/lws-hmi /var/lib/lws-hmi`. Existing helper/Dart paths keep `/var/lib/lws-hmi/...`.

**Rationale:** Separates **survives A/B upgrade** (userdata) from **factory reset on `make flash`** (must wipe `/userdata/lws-hmi` — tracked for implementation; see `docs/storage-layout.md` §Prefs).

**Policy:**

| Path | Prefs |
|------|--------|
| reboot / push-app / HMI restart | keep |
| `make upgrade` (P2.4 rootfs A/B only) | keep — never touch userdata |
| `make flash` | clear — factory reset |

**Rationale:** Prefer files alone do not imply “user left Wi‑Fi on.”

### 3. Boot restore oneshot

**Choice:** `lws-hmi-settings-restore.service` Type=oneshot, `WantedBy=multi-user.target`, **`After=hmi.service`** (+ `param-update`), pulled via `hmi.service` `Wants=`. `Nice=10` + idle I/O + short post-HMI sleep. Restore runs **after** UI is up (not parallel). App `syncFromSystem()` watches `*-wanted` and shows `starting`/associating like a manual toggle while restore works.

**Rationale:** UI absolute priority — first home frame and responsiveness beat network bring-up; operators still see live restore progress in Demo.

### 4. Backlight persist

**Choice:** `/var/lib/lws-hmi/backlight-brightness` stores 0–100 percent; restore writes sysfs via small helper or inline in restore script.

### 5. push-app

**Choice:** Keep host detach + status poll for both transports.

## Risks / Trade-offs

- **[Risk] dhcpcd under oneshot + KillMode** → Use `KillMode=none` + `ExecStop` cleanup (already for wlan0-dhcp).
- **[Risk] Restore races PHY probe** → Soft-fail; Demo can re-Apply; journal logs.
- **[Risk] Old images still spawn wpa -B in HMI** → Need flash; verify forbids `-B` in wifi-stack-up.

## Migration Plan

1. Land overlay units + restore; App wanted/backlight.
2. Flash; toggle Wi‑Fi off/on once to migrate to units.
3. Accept push-app over LAN and reboot restore.
