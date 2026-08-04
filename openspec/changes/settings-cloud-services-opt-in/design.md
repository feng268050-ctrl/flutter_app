## Context

`lws_hmi` already ships cloud (Worker probe + device WebSocket) and LAN enhancement (`DeviceLocalHttpServer` on `:5580` + Avahi `_lws-device._tcp`) via `CloudLocalRuntime.startAfterFirstFrame()`, which starts local HTTP unconditionally and drives cloud connect when network/origin allow. Common Settings → Network lists Wi‑Fi, HTTP Proxy, LAN SSH debug, and Bluetooth—no operator control for cloud/LAN enhancement.

Roadmap: Bluetooth companion is the default management plane; IP cloud and LAN HTTP are opt-in. This change adds Settings UX + preference gating only (proposal/design; implementation follows later). Related HAL Bluetooth companion change may later expose RPC to toggle the same preferences; not required here.

UI naming: product tab is **Common Settings** (常用设置); operator-facing row **云服务**; sub-switches **云服务** and **局域网增强**.

## Goals / Non-Goals

**Goals:**

- Network group entry → Cloud services sub-page with two switches and footer help.
- Both preferences default **off**, persisted across reboot.
- Runtime honors preferences: cloud WS/probe only when 云服务 on; `:5580` + mDNS only when 局域网增强 on.
- Enable → start/connect when network suitable; disable → stop/withdraw promptly.
- Independent toggles (cloud without LAN and vice versa).

**Non-Goals:**

- Bluetooth companion RPC for these toggles (follow-up).
- Changing LAN SSH debug or HTTP Proxy behavior.
- Redesigning registration QR payload or Worker APIs.
- SoftAP; changing MediaMTX RTSP default (camera local preview remains product-owned unless separately gated).
- Implementing UI in this propose-only step.

## Decisions

### D1 — Two independent preferences, one Settings page

Persist `cloud_services_enabled` and `lan_enhancement_enabled` (names illustrative) under App HMI settings (e.g. extend `CloudSettingsStore` or a small `NetworkPlanesStore` under `/var/lib/hmi/`). Defaults `false`.

One nav row **云服务** opens the page; summary on the Network list MAY show Off / Cloud / LAN / Both (localized).

**Alternative:** Separate Network rows for each switch. Rejected—user asked one entry and a sub-page with two items + footer.

### D2 — Gate runtime start, not object construction

`CloudLocalRuntime` MAY still be constructed at App scope. `startAfterFirstFrame` (and network-driven reconnect) MUST:

- Start/stop `DeviceLocalHttpServer` and mDNS only when `lan_enhancement_enabled`
- Run origin probe / WS connect / auto-reconnect only when `cloud_services_enabled`

Toggling at runtime applies without requiring HMI process restart.

**Alternative:** Lazy-construct entire runtime only when either flag on. Possible later; preference gating of start paths is enough for v1.

### D3 — Footer copy explains planes (not legal text)

Bottom of page: short localized paragraphs—

- **云服务:** remote Worker connectivity, binding/registration, cloud upload/commands when online  
- **局域网增强:** same-LAN HTTP `:5580` + mDNS discovery for phone/tools on the local network  

Exact EN/ZH strings authored in ARB at implementation; mirror lws-ui tone if a match exists, else product-authored.

### D4 — Enrollment UX when cloud off

While `cloud_services_enabled` is false: MUST NOT enqueue registration/bind dialogs from WS auth or users-probe. Secret-tap cloud environment tier MAY remain editable (for next enable) but MUST NOT by itself start WS.

When operator enables 云服务 with network up: begin probe/connect; existing registration flows MAY then run.

### D5 — Network row placement

Append **云服务** after **Bluetooth** in the Network `SettingsGroup` (Wi‑Fi → Proxy → LAN SSH → Bluetooth → Cloud services).

### D6 — Interaction with “network available”

Reuse existing “suitable network” signals used by `CloudLocalRuntime` (Wi‑Fi/Ethernet addressing). Enabling a plane while offline: persist on, start/connect when link appears. Disabling: tear down even if link remains.

### D7 — Factory / debug

No forced-on for production defaults. Engineering may document how to enable for `make push-app` mobile LAN testing; optional future env override is out of scope unless needed during implementation.

## Risks / Trade-offs

- **[Risk] Mobile/dev workflows assume always-on `:5580`** → Document enable path; factory test / debug notes.  
- **[Risk] Home/guidance prompts assume cloud enrollment** → Gate prompts; verify Home still usable offline.  
- **[Risk] Partial start races when toggling quickly** → Serialize start/stop on runtime; idempotent stop.  
- **[Trade-off] Cloud off but LAN on** → Phone on same LAN works; cloud features unavailable—intentional.  
- **[Trade-off] MediaMTX still App-owned** → Not tied to 局域网增强 unless product later decides; avoids breaking camera preview.

## Migration Plan

1. Ship preferences default off → **behavior break** vs today’s always-on LAN/cloud after first frame.  
2. Operators who need cloud/LAN turn them on once; persisted afterward.  
3. Rollback: revert gating and restore unconditional start (feature flag optional during rollout).

## Open Questions

1. Network list summary: single Off vs detailed Cloud/LAN/Both? (Recommend detailed.)  
2. Should enabling 云服务 immediately show bind/registration if unbound, or wait for first WS failure? (Prefer existing post-connect classification.)  
3. Any need to gate outbound cloud HTTP uploads (Monitor upload) behind the same switch? (Recommend yes—same preference.)
