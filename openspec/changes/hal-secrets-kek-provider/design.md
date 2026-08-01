## Context

Appliance secrets (Wi‑Fi PSK vault first) need a single KEK/seal service. Desktop keyrings are unsuitable. Rockchip SDK has OP-TEE-related hooks; product HMI does not yet expose a HAL Secrets API. Sibling change `wifi-credential-secure-storage` owns the Wi‑Fi vault format and wpa `mem_only_psk` inject; **this change owns the KEK layer** those vaults call.

Constraints: Flutter 3.24 / Dart HAL; RK3566/3568 boards; root often present in debug builds; no TPM on this line.

## Goals / Non-Goals

**Goals:**
- Abstract `Secrets` / `KekProvider` in `cyber_hal` (seal/unseal with AAD)
- OP-TEE-backed production path (PKCS#11 TA and/or dedicated TA + HUK secure storage)
- Interim software KEK for bring-up, clearly marked
- Board profile selection; unit-testable fakes for host
- Document threat model and RED interim disclaimer

**Non-Goals:**
- Operator-facing Keychain UI
- gnome-keyring / libsecret / macOS Keychain
- Full Wi‑Fi vault / `mem_only_psk` (belongs to `wifi-credential-secure-storage`)
- Full-disk encryption; shipping Notified Body dossier
- Mandatory external SE chip in v1 (optional later backend)

## Decisions

### D1 — Thin seal API, not a full PKCS#11 facade for Apps

**Choice:** HAL exposes something like `seal({aad, plaintext}) → blob` and `unseal({aad, blob}) → plaintext` (plus optional `backendId` / `isHardwareBound`). Wi‑Fi vault and future callers use only this.

**Why:** Apps must not depend on Cryptoki details; backends can swap (interim → TEE → SE).

**Alternatives:** Expose raw PKCS#11 to Flutter — rejected (heavy, easy to misuse). Per-feature crypto — rejected (duplication).

### D2 — Prefer OP-TEE PKCS#11 TA when viable; else small wrap TA

**Choice:** Spike order: (1) tee-supplicant + libteec present, (2) PKCS#11 TA usable for AES key wrap / secret key objects, (3) if PKCS#11 too heavy or missing on vendor image, ship a minimal “seal” TA using OP-TEE secure storage (REE FS or RPMB).

**Why:** PKCS#11 is the standard reusable HSM API; a tiny TA is a fallback with less surface.

**Alternatives:** Only custom TA — works but less reusable for OpenSSL/certs later. Only software — insufficient for RED production path.

### D3 — HUK + secure storage backend

**Choice:** Production TEE path MUST rely on platform HUK-derived secure storage (prefer **RPMB** when eMMC supports it; otherwise REE FS encrypted by OP-TEE with documented residual risk). Interim software KEK MUST NOT read OTP HUK from Linux userspace (if impossible, treat as interim only).

**Why:** Device-bound, non-exportable root is the SSM story.

### D4 — Interim software KEK

**Choice:** HKDF (or equivalent) from stable device identifiers available to Linux (e.g. serial / chip id from existing product/hal paths) + optional salt file under restricted userdata. `backendId = interim_software`. Debug log may state backend name only.

**Why:** Unblocks vault development before TEE image is ready.

### D5 — No desktop keyring

**Choice:** Explicitly out of scope; do not add libsecret.

### D6 — Relationship to Wi‑Fi vault change

**Choice:** `wifi-credential-secure-storage` **consumes** this API for wrap/unwrap of vault DEK (or per-secret seal). OP-TEE spike and TeeKekProvider live **here**; Wi‑Fi change keeps vault format, migration, inject, mem_only_psk.

**Why:** Separation of concerns; other secrets reuse KEK without Wi‑Fi coupling.

### D7 — Dart ↔ native bridge

**Choice:** Prefer calling OP-TEE from a small native helper or FFI in `cyber_hal` (decision after spike: pure Dart cannot link libteec). Host tests use in-memory fake provider.

## Risks / Trade-offs

- [Vendor OP-TEE binary without usable PKCS#11 / HUK] → Fall back to custom TA or keep interim; escalate to Innohi for RPMB/HUK bring-up.
- [RPMB not provisioned] → REE FS secure storage with documented weakness vs offline disk clone.
- [FFI/ABI churn with Flutter embedder] → Isolate TEE calls behind `cyber_hal` Linux-only implementation; stub elsewhere.
- [Apps call unseal too widely] → Keep API Linux/HAL-internal; App uses Wi‑Fi controller only for PSK flows.
- [Interim mistaken for production] → Spec + board flag `secrets.backend=interim|optee`; release gate prefers optee when RED path required.

## Migration Plan

1. Land API + interim backend + fakes/tests.
2. Complete OP-TEE spike; enable client packages on images that support it.
3. Point Wi‑Fi vault at Secrets API (sibling change).
4. When OP-TEE green: switch board profile default; re-seal existing vault DEKs (version bump).
5. Rollback: flip profile to interim (accept weaker security) or require re-entry of Wi‑Fi PSKs after wipe.

## Open Questions

- Vendor vs mainline OP-TEE on ynh960 factory images (spike).
- PKCS#11 TA present or custom seal TA only.
- Whether seal runs only in HMI process or also a privileged `/usr/libexec` helper for early boot Wi‑Fi inject.
