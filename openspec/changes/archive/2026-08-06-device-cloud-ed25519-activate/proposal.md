## Why

Cloud device identity today is effectively SN-only (WebSocket admission by registered serial). The product needs a durable per-device **Ed25519** key so the HMI can cryptographically prove possession when activating and when minting device access tokens. Factory registration already places the SN in the cloud inventory; what is missing is first-online key generation, flash-surviving private-key storage, and a one-shot activate call that binds the public key to that SN.

## What Changes

- On first cloud use (云服务 enabled, network available, non-empty Vendor Storage SN): if no sealed cloud private key exists locally, **generate an Ed25519 keypair**, seal the private key via HAL Secrets, persist the sealed blob in **Rockchip Vendor Storage**, and call the api-server **activate** API with `sn` + public key.
- After a successful activate (or when a sealed key already exists), **never regenerate or overwrite** the local key; SN change / `FORCE` rewrite MUST NOT silently mint a new cloud key.
- Use the private key to **sign** token-mint requests (TLS carries the response). Do **not** encrypt access tokens with the device public key (Ed25519 is signature-only).
- Add a Vendor Storage ID for the sealed cloud-key blob (alongside existing SN/brand/model IDs).
- Cross-repo: api-server OpenSpec change owns `POST …/activate` (and token mint) contracts; this change consumes them.

## Capabilities

### New Capabilities

- `device-cloud-ed25519-activate`: First-online Ed25519 key lifecycle (generate → Secrets seal → Vendor Storage → activate), immutability rules, and signed device access-token requests against the pinned API origin.

### Modified Capabilities

- `vendor-storage-identity`: Extend the ID map with a frozen custom ID for the sealed cloud Ed25519 private-key blob (read/write helpers or documented ID constant).

## Impact

- **App / HAL:** cloud runtime (gated by 云服务), Secrets seal/unseal, Vendor Storage helpers, Ed25519 (Dart crypto), pinned API origin client.
- **Rootfs / board:** `vendor-storage-ids.txt` (+ optional thin read/write helper for the sealed blob); identity SN still from existing helpers.
- **api-server (sibling repo):** OpenSpec change for device activate + Ed25519-verified token mint; persist public key and `is_activated`.
- **Out of scope here:** factory admin device registration (already exists); changing SN-only WebSocket admission in the same slice (may remain SN-gated until token/WS auth is wired in a follow-up); SoftAP / Bluetooth companion.
