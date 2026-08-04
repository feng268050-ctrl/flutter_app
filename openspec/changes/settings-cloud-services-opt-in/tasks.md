## 1. Preferences and runtime gating

- [ ] 1.1 Add persisted booleans for cloud services and LAN enhancement (default false) under `/var/lib/hmi/`
- [ ] 1.2 Gate `CloudLocalRuntime` local HTTP start/stop on LAN enhancement
- [ ] 1.3 Gate mDNS publish/withdraw on LAN enhancement (in addition to health/address rules)
- [ ] 1.4 Gate Worker probe + WebSocket connect/reconnect on cloud services
- [ ] 1.5 Apply toggles at runtime without HMI restart; serialize start/stop
- [ ] 1.6 Suppress registration/bind enrollment prompts while cloud services is off
- [ ] 1.7 Unit/widget tests for preference defaults and gating branches (host)

## 2. Settings UI

- [ ] 2.1 Add Cloud services nav row after Bluetooth in Common Settings Network group
- [ ] 2.2 Implement Cloud services sub-page with 云服务 and 局域网增强 toggles
- [ ] 2.3 Add footer explanatory copy for both planes
- [ ] 2.4 Wire toggles to preference store + runtime apply
- [ ] 2.5 Optional Network row summary (Off / Cloud / LAN / Both)
- [ ] 2.6 Add EN + ZH ARB strings; run `make l10n` / child sync as required

## 3. Specs alignment and accept

- [ ] 3.1 Verify fresh boot with both off: no `:5580` listen, no device WS
- [ ] 3.2 Enable LAN enhancement: `:5580` up; mDNS when addressed; disable tears down
- [ ] 3.3 Enable cloud services online: probe/WS connect; disable disconnects and stays down
- [ ] 3.4 Enable cloud offline then bring network: auto connect without re-toggle
- [ ] 3.5 Confirm Home usable with both off (no enrollment block)

## 4. Explicit non-goals

- [ ] 4.1 Confirm out of scope in notes: BT companion RPC toggles, SoftAP, MediaMTX default change, LAN SSH/Proxy redesign
