## Context

Appliance secrets (Wi‑Fi PSK vault first) need a single KEK/seal service. Desktop keyrings are unsuitable. Rockchip SDK has OP-TEE-related hooks; product HMI does not yet expose a HAL Secrets API. Sibling change `wifi-credential-secure-storage` owns the Wi‑Fi vault; **this change owns the KEK layer**.

**Policy:** One production standard — **hardware (OP-TEE) first on real boards**. Software KEK is **only** a fallback when TEE hardware/stack is unavailable (emulator, host tests, sim profile). There is **no** separate “bring-up interim” track for product images.

Constraints: Flutter 3.24 / Dart HAL; RK3566/3568 boards; no TPM on this line.

## Goals / Non-Goals

**Goals:**
- Abstract `Secrets` / `KekProvider` in `cyber_hal` (seal/unseal with AAD)
- OP-TEE-backed sealing as the **default and required** path on appliance hardware
- Software device-bound KEK **only** when hardware TEE is unavailable (emulator / sim / host fake)
- Auto-detect or board-profile probe: hardware → else fallback
- Unit-testable fake provider for host
- Threat-model docs (hardware vs fallback scope)

**Non-Goals:**
- Dual “dev vs prod” crypto policies on the same hardware SKU
- Operator-facing Keychain UI; gnome-keyring / libsecret
- Wi‑Fi vault / `mem_only_psk` (→ `wifi-credential-secure-storage`)
- Full-disk encryption; Notified Body dossier in-repo
- Mandatory discrete SE chip in v1 (optional later backend behind same API)

## Decisions

### D1 — Thin seal API

**Choice:** `seal({aad, plaintext}) → blob`, `unseal({aad, blob}) → plaintext`, plus `backendId` / `isHardwareBound`.

**Why:** Callers never touch Cryptoki; backends swap without App changes.

### D2 — Hardware first, single production standard

**Choice:** On ynh960/961/962 (and any real-board profile), Secrets **MUST** use OP-TEE (PKCS#11 TA and/or minimal seal TA + HUK secure storage). Product builds MUST enable tee-supplicant / client packages. Failure to initialize TEE on hardware is an **error** (or explicit degraded mode with loud logging) — not a quiet “interim prod” default.

**Why:** User requirement — no bring-up/production split; RED/SSM story is hardware-bound.

**Alternatives:** Interim-as-default until spike — rejected.

### D3 — Software only when hardware unavailable

**Choice:** Software HKDF KEK (`backendId = software_fallback`) allowed only when:
- board/profile is emulator / `sim_virt` / host unit-test fake, **or**
- runtime TEE probe fails **and** profile explicitly allows fallback (emulator), **or**
- host CI without TEE.

Real hardware profiles SHOULD **fail closed** (or refuse seal) if TEE is missing rather than silently using software — exact fail-closed vs allowlist decided at implement after spike, but **must not** treat software as normal product path.

**Why:** Emulator still needs vault tests; field units must not ship software-as-default.

### D4 — OP-TEE shape

**Choice:** Spike: tee-supplicant + libteec → prefer PKCS#11 TA for wrap; else minimal seal TA. Prefer **RPMB** secure storage when eMMC supports it; else OP-TEE REE FS with documented residual risk.

### D5 — No desktop keyring

**Choice:** Out of scope.

### D6 — Wi‑Fi vault consumes this API

**Choice:** Vault seals via abstract Secrets only; no duplicate KEK in Wi‑Fi module.

### D7 — Dart ↔ native

**Choice:** FFI or small native helper for OP-TEE; host tests use in-memory fake (counts as “hardware unavailable”).

## Risks / Trade-offs

- [OP-TEE not ready on current product image] → Treat as **blocker for hardware SKU**, not an excuse to default software on device; escalate Innohi / enable packages in this change’s overlay tasks.
- [RPMB unprovisioned] → REE FS under OP-TEE still hardware-bound via HUK; document offline-clone residual risk.
- [Silent software fallback on hardware] → Forbidden as default; probe + profile gates; tests assert hardware profile selects OP-TEE.
- [FFI/embedder churn] → Isolate behind `cyber_hal` Linux impl.
- [Emulator vault not transferable to device] → Expected; re-seal or re-enter secrets on hardware.

## Migration Plan

1. Spike and enable OP-TEE client on product images.
2. Land API + OP-TEE backend + fake/software fallback for emu/tests.
3. Board bindings: hardware profiles → OP-TEE; sim/emulator → software fallback.
4. Wi‑Fi vault consumes API; if any early software-sealed blobs exist on a device that later gains TEE, re-seal under hardware backend (version bump) or force re-entry.
5. Rollback of TEE stack on hardware = product incident, not “switch to interim prod.”

## Open Questions

- Fail-closed vs explicit `allow_software_fallback=1` on rare hardware bring-up jigs (default: fail-closed for product profiles).
- Vendor vs mainline OP-TEE; PKCS#11 vs custom TA.
- Early-boot seal helper vs in-HMI only.
