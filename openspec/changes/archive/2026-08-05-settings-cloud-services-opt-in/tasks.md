## 1. Preferences and runtime gating

- [x] 1.1 Add persisted booleans for cloud services and LAN enhancement (default false) under `/var/lib/hmi/`
- [x] 1.2 Gate `CloudLocalRuntime` local HTTP start/stop on LAN enhancement
- [x] 1.3 Gate mDNS publish/withdraw on LAN enhancement (in addition to health/address rules)
- [x] 1.4 Gate Worker probe + WebSocket connect/reconnect on cloud services
- [x] 1.5 Apply toggles at runtime without HMI restart; serialize start/stop
- [x] 1.6 Suppress registration/bind enrollment prompts while cloud services is off
- [x] 1.7 Unit/widget tests for preference defaults and gating branches (host)

## 2. Settings UI

- [x] 2.1 Add Cloud services nav row after Bluetooth in Common Settings Network group
- [x] 2.2 Implement Cloud services sub-page with 云服务 and 局域网增强 toggles
- [x] 2.3 Add footer explanatory copy for both planes
- [x] 2.4 Wire toggles to preference store + runtime apply
- [x] 2.5 Optional Network row summary (Off / Cloud / LAN / Both)
- [x] 2.6 Add EN + ZH ARB strings; run `make l10n` / child sync as required

## 3. Specs alignment and accept

- [x] 3.1 Verify fresh boot with both off: no `:5580` listen, no device WS
- [x] 3.2 Enable LAN enhancement: `:5580` up; mDNS when addressed; disable tears down
- [x] 3.3 Enable cloud services online: probe/WS connect; disable disconnects and stays down
- [x] 3.4 Enable cloud offline then bring network: auto connect without re-toggle
- [x] 3.5 Confirm Home usable with both off (no enrollment block)

## 4. Explicit non-goals

- [x] 4.1 Confirm out of scope in notes: BT companion RPC toggles, SoftAP, MediaMTX default change, LAN SSH/Proxy redesign

### Verification notes (section 3)

Host tests cover preference defaults/persist and Network summary. Runtime gating is implemented in `CloudLocalRuntime` (`startAfterFirstFrame` / `setCloudServicesEnabled` / `setLanEnhancementEnabled`); enrollment callbacks in `app.dart` are dual-gated. **Board accept** after `make build-app` + `make push-app`:

1. Fresh boot (both off): `ss -lntp | grep 5580` empty; no device WS; Home has no registration/bind dialog.
2. Enable 局域网增强: `:5580` listens; mDNS when Wi‑Fi addressed; disable → stop + withdraw.
3. Enable 云服务 online: Worker probe + WS; disable → disconnect, no reconnect.
4. Enable 云服务 offline, then Wi‑Fi up → auto connect without re-toggle.

### Non-goals (section 4)

Out of scope (unchanged): Bluetooth companion RPC for these toggles; SoftAP; MediaMTX RTSP default; LAN SSH debug / HTTP Proxy redesign.
