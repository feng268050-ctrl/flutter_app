## 1. Spike

- [ ] 1.1 On ynh960: verify OP-TEE / tee-supplicant / libteec (and PKCS#11 TA if present); note HUK/RPMB; write `notes.md` in this change
- [ ] 1.2 Decide PKCS#11 TA vs minimal seal TA for v1; record in design open questions resolution

## 2. HAL API

- [ ] 2.1 Add abstract Secrets/KekProvider (seal/unseal + backend id) and in-memory fake for host tests
- [ ] 2.2 Implement `InterimSoftwareKekProvider` (device-bound HKDF; labeled interim)
- [ ] 2.3 Implement OP-TEE-backed provider (FFI or native helper) behind the same API when spike allows
- [ ] 2.4 Wire `BoardBindings` / board profile flag `secrets.backend=interim|optee`

## 3. Image / overlay (when TEE path exists)

- [ ] 3.1 Add Buildroot/overlay enablement for tee-supplicant / OP-TEE client packages as required by spike
- [ ] 3.2 Ensure TEE stack is outside HMI cgroup concerns (dedicated unit if needed)

## 4. Docs and gates

- [ ] 4.1 Security notes: API shape, interim vs OP-TEE, residual risks; no RED conformity claim
- [ ] 4.2 Host unit tests for fake + interim round-trip and wrong-AAD failure

## 5. Handoff

- [ ] 5.1 Confirm `wifi-credential-secure-storage` consumes this API for vault DEK wrap (no duplicate KEK code there)
