# Spike / verification notes — ynh960 OP-TEE / software KEK (2026-08-01)

Device: USB-SSH `192.168.55.1`, kernel `6.1.99` aarch64, DTB compatible `rockchip,rk3566-evb2-lp4x-v10`.

## Summary (after this change’s image work)

| Item | Status |
|------|--------|
| BL32 (OP-TEE) in boot chain | **Present** — `bl32-v2.15` / optee revision **3.13** (`9f2aca7d`) |
| Kernel `CONFIG_TEE` / `CONFIG_OPTEE` | **=y** |
| `/dev/tee0` / `/dev/teepriv0` | **Present** (DT `ynh960-optee.dtsi` applied) |
| `tee-supplicant` / `libteec` | **In rootfs**; unit **active** (`/dev/teepriv0`) |
| PKCS#11 / `libckteec` | **Not used** (v1 = minimal seal TA) |
| Seal TA + `secrets-seal-ca` | **Shipped**; OpenSession → **`0xffff000f` (TEEC_ERROR_SECURITY)** with `default_ta.pem` |
| OEM `secrets_backend` | **`software`** on ynh960 |
| Software KEK on-device smoke | **PASS** (HMI entry temp smoke 2026-08-01): round-trip + wrong-AAD fail-closed |

## Spike detail (pre-image)

### Secure world

- Trust packaging uses `rkbin` BL32 (`rk3568_bl32_v2.15.bin`).
- BL32 strings include Secure Storage TA, Rockchip HUK helpers, AES-GCM — not a blank stub.
- No clear PKCS#11 TA markers → **v1 does not depend on `libckteec`**.

### Gaps closed by this change

1. **DT:** `ynh960-optee.dtsi` (`linaro,optee-tz` / SMC) → `/dev/tee*`.
2. **Userspace:** `BR2_PACKAGE_OPTEE_CLIENT`, `tee-supplicant.service` (positional device, not `-d`).
3. **Seal TA/CA:** `make build-secrets-seal` → overlay `usr/lib/optee_armtz/*.ta` + `secrets-seal-ca` (merged `/usr`; no top-level `lib/`).

### Still blocked for `optee` field use

- Vendor BL32 rejects OP-TEE **default** TA signing key.
- **Need** Innohi/Rockchip `TA_SIGN_KEY` (or BL32 rebuilt with product public key), then:
  `TA_SIGN_KEY=… FORCE=1 make rebuild-secrets-seal` → apply-overlay / rootfs / upgrade.
- Then set OEM `"secrets_backend": "optee"` and re-seal or re-enter software-sealed secrets.

### RPMB / storage

- `/dev/mmcblk0rpmb` present; prefer OP-TEE RPMB when provisioned.
- Until then, REE FS under `/var/lib/tee` is HUK-bound with offline-clone residual risk (`docs/hal-secrets-kek.md`).

## Software KEK verification (product path today)

Temporary HMI `main()` smoke (removed after run) via `BoardBindings(profile).secrets()`:

```text
board=ynh960 pref=software backend=software_fallback hwBound=false
seal_len=76 roundtrip=PASS plain=lws-software-kek-smoke-v1
wrong_aad=PASS (fail-closed)
```

## Policy reminder

- Selection = OEM `secrets_backend`; no silent TEE↔software fallback.
- Wi‑Fi vault must consume abstract API only — see `handoff-wifi.md`.
