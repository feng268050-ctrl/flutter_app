## Why

Product direction is **Bluetooth-first management**; cloud Worker/WebSocket and LAN HTTP `:5580`/mDNS are **optional enhancements**, not always-on. Today `CloudLocalRuntime` starts local HTTP and cloud probe after first frame with no operator opt-in, which conflicts with that model and with Settings as the place to turn network enhancement planes on. Operators need an explicit Common Settings → Network entry to enable **云服务** and **局域网增强**, both default off.

## What Changes

- Add a **云服务** (Cloud services) nav row under Common Settings → Network that opens a sub-page.
- Sub-page exposes two independent switches: **云服务** and **局域网增强**, plus footer explanatory copy for each.
- Persist both preferences (default **off**); restore across reboot.
- **BREAKING (behavior):** When 云服务 is off, do not probe Worker origins or maintain cloud WebSocket (no auto cloud connect). When 局域网增强 is off, do not bind LAN HTTP `:5580` or publish mDNS.
- When a switch is turned on (or was on and network becomes available), start/connect the corresponding plane; when turned off, stop/tear down that plane promptly.
- Keep Device Information cloud-environment secret-tap and registration UX available, but gated so they only matter / prompt when 云服务 is enabled (or document no enrollment nag while off).

## Capabilities

### New Capabilities

- `settings-cloud-services`: Common Settings Network → Cloud services page (two toggles, footer help, persistence, runtime gating of cloud vs LAN enhancement).

### Modified Capabilities

- `settings-ui`: Network group gains the Cloud services entry (placement and summary).
- `device-local-http-api`: Local HTTP server start gated by 局域网增强 preference.
- `device-mdns-advertise`: mDNS publish gated by 局域网增强 (and existing health/address rules).
- `device-cloud-websocket`: Cloud WS connect/reconnect gated by 云服务 preference.
- `device-registration-ui`: Registration/bind enrollment prompts MUST NOT fire while 云服务 is off.

## Impact

- **App UI:** `common_settings_tab.dart` Network group; new settings page; ARB EN/ZH(+ child sync) strings.
- **Runtime:** `CloudLocalRuntime.startAfterFirstFrame` and related connect/mdns/http paths must respect preferences; may split “always construct” vs “start when wanted”.
- **Persist:** new keys under App settings store (e.g. `/var/lib/hmi/…`) — not OEM `product.ini`.
- **Related (out of scope):** Bluetooth companion RPC to toggle these planes; changing enrollment/cloud feature matrix beyond gating; SoftAP.
