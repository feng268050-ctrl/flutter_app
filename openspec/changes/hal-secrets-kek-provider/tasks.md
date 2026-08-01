## 1. Spike (hardware path is the product path)

- [ ] 1.1 On ynh960: verify OP-TEE / tee-supplicant / libteec (PKCS#11 TA if present); HUK/RPMB; write `notes.md`
- [ ] 1.2 Decide PKCS#11 TA vs minimal seal TA for v1; record resolution in design

## 2. HAL API

- [ ] 2.1 Add abstract Secrets/KekProvider (seal/unseal + backend id + isHardwareBound) and in-memory fake for host tests
- [ ] 2.2 Implement OP-TEE-backed provider (FFI or native helper) as the real-board default
- [ ] 2.3 Implement software-fallback provider for emulator/sim/host only (not product default)
- [ ] 2.4 Wire `BoardBindings`: real boards → OP-TEE; sim/emulator → software fallback; no `interim` prod flag

## 3. Image / overlay (required for product)

- [ ] 3.1 Enable Buildroot/overlay packages for tee-supplicant / OP-TEE client on product images
- [ ] 3.2 Dedicated TEE unit / lifecycle outside HMI cgroup as needed

## 4. Docs and tests

- [ ] 4.1 Security notes: hardware-first policy; software fallback only when hardware unavailable; residual risks; no RED conformity claim
- [ ] 4.2 Host tests: fake + software-fallback round-trip, wrong-AAD failure; assert real-board binding selects OP-TEE when mocked available

## 5. Handoff

- [ ] 5.1 Confirm `wifi-credential-secure-storage` consumes this API only (no duplicate KEK)
