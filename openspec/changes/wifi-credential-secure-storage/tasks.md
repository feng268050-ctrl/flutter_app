## 1. Prerequisites

- [ ] 1.1 Depend on `hal-secrets-kek-provider` abstract Secrets API (host fake / emu software fallback OK for tests; hardware uses OP-TEE)
- [ ] 1.2 Define Wi‑Fi vault file format (version, per-SSID map, AAD purpose `wifi-psk`) + host encode/decode tests

## 2. HAL vault + wpa integration

- [ ] 2.1 Add Wi‑Fi credential vault service (store/get/delete) sealing via Secrets; path under `/var/lib/wpa_supplicant`
- [ ] 2.2 On connect: vault put, `mem_only_psk=1`, inject `psk`, SelectNetwork, SaveConfig; conf has no plaintext psk
- [ ] 2.3 On selectSaved / forget: inject from vault / delete vault entry with network remove
- [ ] 2.4 Boot / stack-up inject after wpa D-Bus ready for Auto Join networks
- [ ] 2.5 One-shot migration from plaintext `psk=` in conf → vault + scrub conf

## 3. Overlay / docs

- [ ] 3.1 Adjust `run-wpa.sh` or post-start helper if inject must run before HMI
- [ ] 3.2 Document vault path in `docs/storage-layout.md`; conf template stays PSK-free
- [ ] 3.3 Wi‑Fi vault security notes + cross-link to Secrets change (hardware-first; emu software fallback)

## 4. Verification

- [ ] 4.1 Host: vault + migration scrub tests (Secrets fake)
- [ ] 4.2 Device: two SSIDs, no `psk=` in conf, reboot Auto Join, forget clears vault
- [ ] 4.3 Device with Secrets OP-TEE backend: re-seal / smoke (after Secrets change TEE path green)
