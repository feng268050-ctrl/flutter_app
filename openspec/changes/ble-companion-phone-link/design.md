## Context

`hal-bluetooth-companion-and-accessories` introduces `BleCompanionServer` (illustrative), Wi‑Fi provision via `WifiController`, and a transport-agnostic device RPC with open questions on GATT UUIDs, frame encoding, and advertise policy. LaserCyber Mobile (`../lasercyber-mobile`, change `ble-companion-device-link`) will be the first phone Central. Without a locked wire doc and HMI pairing session, HAL and App will diverge.

Current phone association on Mobile is QR/SN → cloud bind; LAN features need Wi‑Fi first. Companion BLE fills pre-network onboarding.

Stakeholders: `cyber_hal` / BlueZ, `lws_hmi` pairing UX, LaserCyber Mobile BLE client.

## Goals / Non-Goals

**Goals:**

- Publish a versioned **companion BLE wire protocol** both repos treat as normative for v1.
- Default companion advertise to **operator pairing mode** (timed window + bonding for writes).
- Provide HMI UI to start/stop pairing mode and show correlation (short code and/or QR payload aligned with existing device QR shape where practical).
- Map wire methods to existing HAL: `system.info` / identity, `wifi.provision` → `WifiController` + vault.
- Keep `api_ver` negotiation so N−1 phone clients can detect unsupported features.

**Non-Goals:**

- Implementing the Flutter phone App (sibling change).
- SoftAP, Classic SPP, helmet profiles, LAN/cloud default-off product policy.
- Full settings RPC UI on HMI beyond pairing; allowlisted settings RPC remains HAL-owned from the prior change.
- Claiming regulatory conformity from this change alone.

## Decisions

### D1 — Protocol ownership lives in this change; Mobile mirrors

Canonical protocol text ships under this change (`notes/companion-ble-protocol.md` or equivalent) and is **copied or linked by path** from the Mobile change. UUID namespace, characteristic roles, and RPC method IDs are frozen for `api_ver=1` in that note before either side ships UI.

**Alternative:** Separate protocol repo. Rejected for now—two-repo OpenSpec pair is enough for v1.

### D2 — Encoding: JSON frames over GATT (CBOR deferred)

v1 uses UTF-8 JSON request/response frames with `id`, `method`, `params` / `result` / `error`. Large writes (PSK) use the provision characteristic or chunked RPC write with documented MTU/chunk rules. CBOR may appear in `api_ver≥2` without breaking JSON v1.

**Alternative:** CBOR-only. Rejected for easier phone debugging and parity with existing device JSON habits.

### D3 — Logical GATT layout (illustrative names; UUIDs in protocol note)

- **Device Info** — read SN, model, `api_ver`, optional advertise local name suffix  
- **Provision** — write Wi‑Fi credential payload; notify status  
- **RPC** — write request; notify/indicate response (correlation `id`)  
- Optional **Session** — pairing-window state notify  

Phone filters scan by service UUID (+ optional manufacturer/company id once assigned).

### D4 — Pairing mode default (not always-on advertise)

Companion LE advertise for onboarding runs only while pairing mode is active (operator starts from HMI, or future App-triggered policy). Timeout stops advertise. Writes for provision/settings require bonding unless inside an explicit open window (product: prefer bond-required).

**Alternative:** Always-on companion advertise. Rejected for privacy/RF noise; prior HAL design already recommended pairing-mode.

### D5 — Association correlation

HMI pairing screen shows:

1. Short numeric/alphanumeric **pairing code** (rotated per window), and/or  
2. QR payload compatible with existing Mobile QR parser where possible (`SN|2|Model|SystemVersion` or a documented BLE-assoc extension field).

Phone confirms it connected to the intended unit by matching SN from Device Info GATT with scanned QR or typed code before cloud bind.

### D6 — Cloud bind stays on the phone

Appliance does **not** call cloud bind. After BLE `system.info`, Mobile continues existing `PUT /v1/devices/:sn/bind`. Device only supplies identity + provision + local info.

### D7 — HMI surface

Minimal Settings/Demo entry: “Phone pairing” → start window → show code/QR + countdown → stop/cancel. Uses HAL companion start/stop APIs from the prior change; no second Bluetooth stack.

## Risks / Trade-offs

- **[Risk] Protocol drift between repos** → Single protocol note + `api_ver`; Mobile change tasks require pin to same revision.  
- **[Risk] AIC8800 GATT peripheral gaps** → Inherit HAL spike gate; do not enable ynh960 companion in OEM until spike + protocol R/W accept.  
- **[Risk] iOS background/scan limits** → Pairing is foreground-guided; document that user keeps App open during setup.  
- **[Trade-off] JSON MTU chunking complexity** → Prefer dedicated provision characteristic for PSK to avoid huge RPC frames in v1.  
- **[Trade-off] QR format extension** → Prefer reuse of v2 QR; if BLE-only fields needed, bump QR version in Mobile contract with explicit parser support.

## Migration Plan

1. Land protocol note + HAL method ID alignment while companion capability still gated.  
2. HMI pairing-mode UI behind companion capability.  
3. Joint accept with Mobile Central on ynh960: scan → bond → info → provision → cloud bind.  
4. Rollback: disable pairing UI + companion advertise; QR/LAN paths unchanged.

## Open Questions

1. Exact 128-bit UUID block (company base)—assign in protocol note during first apply spike.  
2. Pairing code length/charset and whether it is required when QR is used.  
3. Whether advertise local name includes truncated SN for list UX (privacy vs convenience).  
4. Multi-phone bonds: single-active RPC session (recommend for v1) vs concurrent.
