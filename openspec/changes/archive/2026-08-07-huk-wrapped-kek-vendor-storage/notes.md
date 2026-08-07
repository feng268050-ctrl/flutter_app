# Spike: PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY on ynh960

**Date:** 2026-08-07  
**BL32:** `rk3568_bl32_v2.15`  
**Board:** ynh960 (USB SSH)

## Result: **PASS**

| Check | Result |
|-------|--------|
| System PTA UUID present in BL32 | yes (`3a2f8978-…` found in binary) |
| User TA `TEE_OpenTASession(PTA_SYSTEM)` | OK |
| `PTA_SYSTEM_DERIVE_TA_UNIQUE_KEY` (32 B, empty extra) | OK |
| Two derives in one invoke (TA internal compare) | match |
| Two CA `derive-probe` invocations | same b64 (`DERIVE_OK …`) |

## Method

Temporary `TA_SEAL_CMD_DERIVE_PROBE` + `secrets-seal-ca derive-probe` (exports derived key to REE **for spike only**; production wrap must not leave the wrap key in plaintext on REE).

```text
/usr/libexec/board/secrets-seal-ca derive-probe
# DERIVE_OK x2wMJ5LWe91LQf3l+VkqU3b9QVVLrX8Vy2rACz77p7Y=
```

## Implication

Proceeded with design D1/D2: random seal KEK + AES-GCM wrap under TA-unique HUK-derived key → Vendor Storage ID 23. RPMB not required for this path. Device smoke after land: wipe `/userdata/tee` → unseal OK; cloud ID 22 seed unchanged.
