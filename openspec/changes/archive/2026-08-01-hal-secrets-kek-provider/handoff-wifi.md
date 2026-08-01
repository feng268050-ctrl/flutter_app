# Handoff — wifi-credential-secure-storage

Sibling change `wifi-credential-secure-storage` **already** specifies:

- Vault obtains seal/unseal from abstract HAL Secrets / KEK only
- MUST NOT embed a separate OP-TEE or software KEK implementation
- Backend selection owned by `hal-secrets-kek` via OEM
  `board_profile.json` → `secrets_backend` (`software` | `optee`)
- Current ynh960 default: **software** (live HW fingerprint HKDF; no salt/KEK
  file); flip to `optee` when Innohi TA signing is available

## API to consume (landed)

```dart
import 'package:cyber_hal/secrets.dart';
// Prefer via BoardBindings — App Wi‑Fi UI need not import secrets.dart:
final kek = BoardBindings(profile).secrets();
final blob = await kek.seal(plaintext: bytes, aad: aad);
final plain = await kek.unseal(blob: blob, aad: aad);
```

- Host tests: `FakeKekProvider` or `secrets(override: …)`
- Emulator / `sim`: software (`secrets_backend: software` or heuristic)
- `ynh960` (current): `SoftwareFallbackKekProvider` via `secrets_backend: software`
- `ynh960` (later): set `secrets_backend: optee` → `OpteeKekProvider` (needs vendor-signed TA)

No duplicate KEK module should be added under Wi‑Fi HAL.
