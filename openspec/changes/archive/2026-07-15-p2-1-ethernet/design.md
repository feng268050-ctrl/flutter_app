## Context

P2.1 Wi‑Fi already ships abstract `WifiController` + Demo UI with **DHCP / static IPv4** on **wlan0**, backed by `wlan0-dhcp.sh` / `wlan0-static.sh` (helpers refuse eth0). Plan §7.1 / §12 now scopes P2.1 Ethernet to **RJ45 link smoke**, and defers IPC camera segment addressing (`configure-camera-eth0.sh`) to **P5.1**.

Operators still lack a Demo path to enable eth0, see carrier, and assign DHCP or static IPv4 — so PHY/DTS issues (e.g. MDIO addr on ynh960) stay invisible until late.

Constraints (same as Wi‑Fi slice):

- No NetworkManager / systemd-networkd / resolved.
- Do **not** enable `dhcpcd.service` at boot; App/helpers only.
- First paint MUST NOT await eth0 link / DHCP (§7.0).
- eth0 helpers MUST NOT reconfigure wlan0 or usb0; wlan0 helpers MUST keep refusing eth0.

## Goals / Non-Goals

**Goals:**

- Reusable Dart **`EthernetController`** parallel to `WifiController`: admin link up/down, link/carrier status streams, DHCP|static IPv4 on **eth0**.
- Overlay helpers for eth0 DHCP/static (+ minimal link up if needed); persist preference under `/var/lib/lws-hmi/eth0-ipv4`.
- Demo section **above Wi‑Fi**: interface toggle, link status (carrier, MAC, speed when known), IPv4 mode + fields, Apply.
- Preserve Plan A boot: no eth0 DHCP at start; `hmi.service` unchanged.

**Non-Goals:**

- IPC camera planner / ping camera / RTSP / MediaMTX (`configure-camera-eth0.sh` remains P5.1).
- Product Settings / FrostUI / status bar (P5.2).
- Bridging, VLANs, bonding, IPv6 product UX.
- Android Ethernet backend (P2.5 plugs alternate impl behind the same abstract).
- Changing wlan0 API or merging IPv4 model types (optional later DRY).

## Decisions

### D1 — Package layout (mirror Wi‑Fi)

```text
lib/platform/ethernet/
  ethernet_models.dart              # link phase, EthIpv4Config + store parser
  ethernet_controller.dart          # abstract
  linux_ethernet_controller.dart    # Process → helpers + `ip`/`ethtool` reads

lib/ui/demo/ethernet_demo_section.dart
```

Wire in `p2_demo_page.dart` **before** `WifiDemoSection`. Callers depend on `EthernetController`, not the Linux class.

**Alternatives considered:** Fold eth0 into `WifiController` — rejected (different L2 model; no SSID). Shared `NetIfaceController` — deferred; duplicate parallel packages match existing Wi‑Fi/BT style and keep this diff small.

### D2 — Abstract Ethernet API (normative)

| Surface | Behavior |
|---------|----------|
| `Stream` / getters for link | phases e.g. `down`, `noCarrier`, `configuring`, `up`, `error` + optional message |
| `setInterfaceEnabled(bool)` | `ip link set eth0 up/down` (via helper or direct); does not start boot DHCP |
| `getIpv4Config` / `setIpv4Config` | `dhcp` \| `static` with address / prefix / optional gateway / dns |
| `linkDetails()` | carrier, MAC, speed/duplex when available, current IPv4 |
| `dispose()` | cancel polls / subscriptions |

No scan, connect-to-SSID, or forget — those stay Wi‑Fi-only.

### D3 — Helpers and persistence

| Helper | Role |
|--------|------|
| `eth0-dhcp.sh [start\|stop]` | dhcpcd/udhcpc on **eth0 only**; refuse wlan0/usb0; stop clears lease on eth0 |
| `eth0-static.sh <addr> <prefix> [gw] [dns]` | replace addr + optional route/DNS snippet for eth0; stop eth0 DHCP first |
| optional `eth0-link.sh up\|down` | thin wrapper around `ip link` if controller prefers one entrypoint |

Persist `/var/lib/lws-hmi/eth0-ipv4` with the same key style as `wlan0-ipv4` (`mode=`, `address=`, `prefix=`, `gateway=`, `dns=`). On Demo Apply or App start **after first frame**, Linux controller may re-apply saved config when interface is enabled — MUST be async.

**Default mode:** `dhcp` for RJ45 bring-up realism when a DHCP server is available (laptop share / lab switch); static remains first-class for shop floor.

**Why not reuse wlan0 scripts with `IFACE=` env:** wlan0 scripts hard-refuse eth0 today; dedicated eth0 scripts make the boundary obvious and avoid accidental cross-iface breaks.

### D4 — Carrier monitoring without blocking UI

Linux controller MAY poll `ip -br link show eth0` / `carrier` sysfs on a short timer while the Demo section is mounted, or refresh on user actions. Polling MUST run off the first-frame path; construct controller after first paint like Wi‑Fi (existing `_networkSectionsReady` pattern).

### D5 — Relationship to P5.1 camera eth0

Product IPC mode later uses `configure-camera-eth0.sh` to place eth0 on the camera `/24`. That **may overwrite** Demo/P5.2 static/DHCP prefs temporarily. This change documents the conflict but does **not** implement camera coordinator or conflict UI. Demo remains the P2.1 bring-up / general RJ45 tool.

### D6 — Buildroot / verify

- dhcpcd already in rootfs for wlan0 — reuse binary; still keep `dhcpcd.service` disabled.
- Extend `verify-rootfs-overlay.sh` and `env-verify.sh` to expect eth0 helpers + `eth0-ipv4` template (or ensure path created at runtime).
- No defconfig change required unless a tool is missing (`ip` already present).

### D7 — Spec / plan touchpoints

- New capability `linux-ethernet`; delta `p2-device-demo-ui`, `buildroot-lws-hmi-image`, `hmi-systemd-boot`.
- Plan §12: keep Ethernet checkbox; note Demo+controller landed when tasks done (board smoke still operator-verified).

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| eth0 DHCP fights USB gadget or wlan0 routes | Helpers hard-code `-i eth0` / refuse other ifaces; document default route collisions in Demo error text |
| ynh960 PHY not link-up | Controller surfaces `noCarrier` / error; DTS fix remains kernel overlay work (`kernel-evb-dts-deferred`) |
| P5.1 camera script overwrites Demo IPs | Out of scope here; later coordinator owns handoff |
| dhcpcd concurrent on wlan0 + eth0 | Separate pidfiles (`/run/lws-hmi-dhcpcd-eth0.pid`); document both may run |
| Operators expect camera auto-address in Demo | Demo copy says “Ethernet (RJ45)” — not “IPC camera” |

## Migration Plan

1. Land overlay helpers + verify scripts → `make apply-overlay` / `build-rootfs` / `build-img`.
2. Land Dart platform + Demo → `make build-app` (+ rootfs/img if bundle baked) or `push-app` for iteration.
3. Board smoke: cable to PC/switch → link LED → DHCP or static → ping peer.
4. Rollback: remove Demo section / helpers; eth0 returns to unconfigured L2-only.

## Open Questions

1. Whether Demo should show a one-line hint that IPC camera addressing is P5.1 (recommend **yes**, short subtitle).
2. Whether enabling eth0 at Demo open should auto-apply last-saved IPv4 (recommend **yes**, mirror Wi‑Fi reconnect spirit when radio on).
