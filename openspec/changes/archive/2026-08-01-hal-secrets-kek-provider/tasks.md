## 1. Spike (OP-TEE path readiness)

- [x] 1.1 On ynh960: verify OP-TEE / tee-supplicant / libteec; HUK/RPMB; write `notes.md`
- [x] 1.2 Decide PKCS#11 TA vs minimal seal TA for v1; record resolution in design (→ minimal seal TA)

## 2. HAL API

- [x] 2.1 Add abstract Secrets/KekProvider (seal/unseal + backend id + isHardwareBound) and in-memory fake for host tests
- [x] 2.2 Implement OP-TEE-backed provider (`secrets-seal` / CA+TA); fail-closed when selected but TEE/TA unavailable
- [x] 2.3 Implement device-bound software provider (live multi-factor HKDF, blob v3, no KEK/salt on disk)
- [x] 2.4 Wire `BoardBindings.secrets()` via OEM `secrets_backend` (`software` | `optee`); unset heuristic for sim/emu vs other boards

## 3. Image / overlay

- [x] 3.1 Enable Buildroot/overlay packages for tee-supplicant / OP-TEE client on product images
- [x] 3.2 Dedicated `tee-supplicant` unit / lifecycle outside HMI cgroup
- [x] 3.3 DT optee node + seal TA/CA overlay path (`make build-secrets-seal`); TA vendor signing remains field blocker

## 4. Docs and tests

- [x] 4.1 Security notes: both backends; OEM selection; software residual risks; no RED conformity claim (`docs/hal-secrets-kek.md`)
- [x] 4.2 Host tests: fake + software round-trip, wrong-AAD, factor-mismatch; profile `software` / `optee` selection
- [x] 4.3 Device-bound software KEK: live HW fingerprint → HKDF; blob v3; no salt/KEK on disk
- [x] 4.4 OEM `secrets_backend`; ynh960 default `software`; profile flip selects OP-TEE
- [x] 4.5 On-device software seal/unseal smoke on ynh960 (PASS 2026-08-01; temp HMI entry removed after)

## 5. Handoff

- [x] 5.1 Confirm `wifi-credential-secure-storage` consumes this API only (no duplicate KEK) — see `handoff-wifi.md`

## 6. Follow-up (out of this change’s close criteria; track when enabling field OP-TEE)

- [ ] 6.1 Obtain Innohi/Rockchip `TA_SIGN_KEY` (or matching BL32); rebuild signed seal `.ta`; verify `secrets-seal probe` / seal round-trip
- [ ] 6.2 Set ynh960 OEM `secrets_backend: optee`; migrate or re-enter any software-sealed vault blobs
- [ ] 6.3 Optional: provision OP-TEE RPMB secure storage vs REE FS under `/var/lib/tee`
