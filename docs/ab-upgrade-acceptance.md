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

## Slot B FIT / resource smoke (host, before flash)

After `make build-kernel`, both FITs must pass RSCE + PARTLABEL gates (also enforced inside `build-kernel-ab.sh` / `verify-boot-fit.sh`):

```bash
python3 scripts/patch-resource-img-partlabel.py --self-test
python3 scripts/patch-resource-img-partlabel.py --verify output/firmware/boot.img rootfs_a
python3 scripts/patch-resource-img-partlabel.py --verify output/firmware/boot_b.img rootfs_b
bash scripts/verify-boot-fit.sh output/firmware boot.img
bash scripts/verify-boot-fit.sh output/firmware boot_b.img
```

On device, **true B** means cmdline and misc agree — not misc alone:

```text
grep PARTLABEL= /proc/cmdline   # PARTLABEL=rootfs_b
. /usr/libexec/ab/ab-slot-lib.sh; ab_slot_read   # active B
```

Expect boot splash on B; soft poweroff then cold power-on must reach userspace (no early `drm-logo@0` / `panic_on_set_idle` from stale RSCE — see [`ab-slot-misc.md`](ab-slot-misc.md) pitfalls).

## Failure / refuse cases

1. Pending try-boot → `ab-preflight.sh` fails; host aborts
2. Bad Ed25519 → HMI upgrade page fail; no partition write
3. RockUSB `di` remains unsigned factory/lab path (not this staged contract)
4. Stale `resource.img` ENTR SHA-1 after PARTLABEL edit → `build-kernel` / `--verify` must fail; do not ship `boot_b.img`
