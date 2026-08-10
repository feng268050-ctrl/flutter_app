# A/B upgrade acceptance (smoke)

Product apply path is **`packages/cyber_ota`** (HMI). Board helpers left in rootfs:

| Helper | Role |
|--------|------|
| `ab-preflight.sh` | Host `make upgrade` slot preflight (`KEY=VALUE`) |
| `ab-slot-lib.sh` | Shared by preflight + `ab-boot-confirm.sh` |
| `ab-boot-confirm.service` | Post try-boot commit / rollback |

Retired (must be absent): `ab-upgrade-apply.sh`, `ab-upgrade-stream.sh`, `ab-ota-verify.sh`.

## Happy path (SSH `make upgrade`)

1. Board already has P2.4 GPT + current HMI with `cyber_ota`
2. `make pack-ota` / `make upgrade` (signing key configured)
3. Host HTTP → device download → verify → extract → write → arm → reboot
4. Confirm: `journalctl -u ab-boot-confirm` shows COMMIT

## Failure / refuse cases

1. Pending try-boot → `ab-preflight.sh` fails; host aborts
2. Bad Ed25519 → HMI upgrade page fail; no partition write
3. RockUSB `di` remains unsigned factory/lab path (not this staged contract)
