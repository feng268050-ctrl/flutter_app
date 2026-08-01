## 1. Prerequisites

- [x] 1.1 Depend on `hal-secrets-kek-provider` abstract Secrets API (host fake / emu software fallback OK for tests; hardware uses OP-TEE)
- [x] 1.2 Define Wi‑Fi vault file format (version, per-SSID map, AAD purpose `wifi-psk`) + host encode/decode tests

## 2. HAL vault + wpa integration

- [x] 2.1 Add Wi‑Fi credential vault service (store/get/delete) sealing via Secrets; path under `/var/lib/wpa_supplicant`
- [x] 2.2 On connect: vault put, `mem_only_psk=1`, inject `psk`, SelectNetwork, SaveConfig; conf has no plaintext psk
- [x] 2.3 On selectSaved / forget: inject from vault / delete vault entry with network remove
- [x] 2.4 Boot / stack-up inject after wpa D-Bus ready for Auto Join networks
- [x] 2.5 One-shot migration from plaintext `psk=` in conf → vault + scrub conf

## 3. Overlay / docs

- [x] 3.1 Adjust `run-wpa.sh` or post-start helper if inject must run before HMI
- [x] 3.2 Document vault path in `docs/storage-layout.md`; conf template stays PSK-free
- [x] 3.3 Wi‑Fi vault security notes + cross-link to Secrets change (hardware-first; emu software fallback)

## 4. Verification

- [x] 4.1 Host: vault + migration scrub tests (Secrets fake)
- [x] 4.2 Device: two SSIDs, no `psk=` in conf, reboot Auto Join, forget clears vault
- [ ] 4.3 Device with Secrets OP-TEE backend: re-seal / smoke (after Secrets change TEE path green)
  - Blocked 2026-08-01 on ynh960: `secrets_backend: software`; OP-TEE
    `secrets-seal probe` fails TA session (`TEEC_ERROR_SECURITY` / vendor
    `TA_SIGN_KEY` needed). Re-run when OEM flips to `optee` + signed TA.
