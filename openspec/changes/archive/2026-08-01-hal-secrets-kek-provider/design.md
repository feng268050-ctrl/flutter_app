## Context

Appliance secrets (Wi‑Fi PSK vault first) need a single KEK/seal service. Desktop keyrings are unsuitable. Rockchip SDK has OP-TEE-related hooks; product HMI exposes HAL Secrets via `cyber_hal`. Sibling change `wifi-credential-secure-storage` owns the Wi‑Fi vault; **this change owns the KEK layer**.

**Policy (landed):** Both **OP-TEE** and **device-bound software** backends exist. **OEM `secrets_backend`** chooses which one runs. Current **ynh960 ships `software`** because vendor TA signing is unavailable; OP-TEE stack is provisioned and fail-closed when selected. No silent “try OP-TEE then fall back to software” on the same seal call.

Constraints: Flutter 3.24 / Dart HAL; RK3566/3568 boards; no TPM on this line.

## Goals / Non-Goals

**Goals:**
- Abstract `Secrets` / `KekProvider` in `cyber_hal` (seal/unseal with AAD)
- OP-TEE-backed sealing (`secrets-seal` + seal TA) when profile selects `optee`
- Device-bound software KEK (live HW fingerprint HKDF, blob v3, no secret-on-disk) when profile selects `software`
- OEM profile field `secrets_backend`; ynh960 default `software` until TA signing available
- Unit-testable fake provider for host
- Threat-model docs (`docs/hal-secrets-kek.md`)

**Non-Goals:**
- Silent auto-fallback between backends on a failed seal
- Operator-facing Keychain UI; gnome-keyring / libsecret
- Wi‑Fi vault / `mem_only_psk` (→ `wifi-credential-secure-storage`)
- Full-disk encryption; Notified Body dossier in-repo
- Mandatory discrete SE chip in v1 (optional later backend behind same API)

## Decisions

### D1 — Thin seal API

**Choice:** `seal({aad, plaintext}) → blob`, `unseal({aad, blob}) → plaintext`, plus `backendId` / `isHardwareBound`.

**Why:** Callers never touch Cryptoki; backends swap without App changes.

### D2 — OEM selects backend (supersedes earlier “hardware-only product default”)

**Choice:** `board_profile.json` → `secrets_backend`: `"software"` | `"optee"`. Product ynh960 (OEM + App asset) ships **`software`**. Setting `"optee"` selects `OpteeKekProvider` (fail-closed if TEE/TA missing — never silent software).

**Why:** Unblocks Wi‑Fi vault and on-device seal without waiting on Innohi `TA_SIGN_KEY`; one-line cutover to hardware seal when keys arrive.

**Alternatives:** Always OP-TEE on real boards with fail-closed until TA works — rejected for product schedule (vault blocked indefinitely). Silent TEE→software fallback — rejected (ambiguous trust).

### D3 — Software KEK is device-bound, not “host-only”

**Choice:** `SoftwareFallbackKekProvider` derives KEK at runtime from live factors (chip id **required** + at least one of eth/wlan MAC, eMMC CID, distinct DT serial). HKDF-SHA256 with **public** domain salt/info (`lws-hmi-software-kek-v3`); AES-256-GCM; blob magic `LWSS` **v3**. **No KEK file and no salt file on disk.**

**Allowed on:** any profile that selects `software` (including ynh960 today), plus sim/emu when omitted/heuristic, host tests with injectors/fake.

**Why:** Ciphertext alone does not unseal on another board; root on the *same* device can still re-derive (documented residual risk).

### D4 — OP-TEE shape (resolved 2026-08-01)

**Choice:** **Minimal seal TA + CA via `libteec`** for v1 — **not** PKCS#11 / `libckteec`.

**Why (spike `notes.md`):** Vendor BL32 (`bl32-v2.15`) exposes Secure Storage + AES-GCM and Rockchip HUK helpers; no PKCS#11 TA / `ckteec` evidence. Prefer RPMB secure storage when provisioned; else OP-TEE REE FS under `/var/lib/tee` with documented residual risk.

**Native shape:** `/usr/libexec/hmi/secrets-seal` → `secrets-seal-ca`; TA UUID owned by this product. Field units reject TAs signed with upstream `default_ta.pem` until `TA_SIGN_KEY` matches BL32 (`TEEC_ERROR_SECURITY` / `0xffff000f`).

### D5 — No desktop keyring

**Choice:** Out of scope.

### D6 — Wi‑Fi vault consumes this API

**Choice:** Vault seals via abstract Secrets only; no duplicate KEK in Wi‑Fi module. See `handoff-wifi.md`.

### D7 — Dart ↔ native

**Choice:** Native helper (`secrets-seal`) for OP-TEE; host tests use in-memory fake; software path is pure Dart (`cryptography` package).

### D8 — Profile field and unset heuristic

**Choice:** Explicit `secrets_backend` preferred. When omitted: sim / `sim_*` / virt / emu / `portable-smoke` → software; other board ids → optee.

## Risks / Trade-offs

- [Vendor TA signing missing] → ynh960 stays on software; OP-TEE OpenSession fails `0xffff000f` until `TA_SIGN_KEY=… FORCE=1 make rebuild-secrets-seal`.
- [Software KEK on product] → Explicit profile; multi-factor bind; no secret-on-disk; residual: same-device root / identity clones — documented in `docs/hal-secrets-kek.md`.
- [RPMB unprovisioned] → REE FS under OP-TEE still HUK-bound; offline-clone residual risk.
- [Silent software fallback when `optee` selected] → Forbidden; fail-closed.
- [Emulator vault not transferable to device] → Expected; re-seal or re-enter secrets on hardware.

## Migration Plan

1. ~~Spike + enable OP-TEE client / DT / tee-supplicant~~ **Done.**
2. ~~API + both backends + fake~~ **Done.**
3. ~~OEM `secrets_backend`; ynh960 = software~~ **Done.** On-device software seal/unseal smoke **PASS** (2026-08-01).
4. Wi‑Fi vault consumes API (`wifi-credential-secure-storage`).
5. When vendor TA key arrives: rebuild signed `.ta`, set `secrets_backend: optee`, OEM upgrade; re-seal or re-enter any software-sealed blobs.

## Open Questions

- ~~Fail-closed vs allow_software_fallback~~ → **D2/D8:** profile selects; selected backend fail-closed.
- ~~PKCS#11 vs custom TA~~ → **D4:** minimal seal TA.
- Early-boot seal helper vs in-HMI only — still open; v1 is in-HMI / on-demand helper.
- RPMB provisioning for OP-TEE secure storage — follow-up when enabling `optee` in field.
