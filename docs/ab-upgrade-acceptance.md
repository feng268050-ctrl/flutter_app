# A/B upgrade — device acceptance

Run after flashing an image built with the A/B `parameter-buildroot-fit.txt` GPT.

See also: [`storage-layout.md`](storage-layout.md), [`ab-slot-misc.md`](ab-slot-misc.md).

## Paths

| Path | Mechanism |
|------|-----------|
| **`make upgrade`** (dev) | Stream-to-partition over SSH (`ab-upgrade-stream.sh`) |
| **Online OTA** (future) | Download → `/userdata/ota/` → `ab-upgrade-apply.sh` |
| **`make flash`** | RockUSB `update.img` (GPT / U-Boot / factory) |

## Positive path — stream upgrade (`make upgrade`)

1. `make apply-overlay` → `make build-kernel` → `make build-rootfs` → `make build-img`
2. **One-time** `make flash` (repartitions to `boot`/`boot_b` + `rootfs_a`/`rootfs_b`)
3. Confirm boot letter **A**: HMI up; `ls /dev/disk/by-partlabel/` shows `boot`, `boot_b`, `rootfs_a`, `rootfs_b`
4. Optionally set a Wi‑Fi or other pref under `/userdata` (survives upgrade)
5. Change kernel and/or rootfs (e.g. rebuild), then:
   ```bash
   make build-kernel
   make build-rootfs
   make upgrade
   ```
6. Expect: console progress advances **while** inactive rootfs/FIT are written (no long silent post-upload `dd`); reboot; HMI up on the other letter; prefs intact
7. Confirm: `journalctl -u ab-boot-confirm` shows COMMIT

## Negative path — stream abort before arm

1. Start `make upgrade` and interrupt the SSH/stream mid-rootfs (or kill the host process)
2. Expect: host exits non-zero; **try-boot not armed**; board still boots the previous active letter; prefs intact; no uboot rewrite

Also verify mounted-root / misc protection via board preflight:

1. Arm or simulate stale misc metadata whose `active` letter disagrees with the rootfs block device mounted as `/`
2. Run `make upgrade` (or board `ab-upgrade-stream.sh preflight`)
3. Expect: preflight fails before any partition write

## Staged apply still works (online OTA contract)

**Today (P2.5 helpers):** digest / `.sha256` (and optional manifest) under `/userdata/ota/` — integrity only, not product authenticity.

1. Stage a valid bundle under `/userdata/ota/` (`boot.img`, `boot_b.img`, `rootfs.img`, digests, manifest)
2. Run `/usr/libexec/hmi/ab-upgrade-apply.sh` (or the session copy under `/userdata/ota/`)
3. Expect: digest verify → `dd` → arm try-boot → reboot

Corrupt staged digest:

1. Stage a corrupt `boot.img` or wrong digest under `/userdata/ota/`
2. Run staged apply
3. Expect: `apply.status=fail`; **active letter unchanged**; prefs intact; no uboot rewrite

**P4.8 product OTA (planned):** same A/B write model; gate is **Ed25519 `*.img.sig` only** — no separate product digest / `.sha256` check. See [`storage-layout.md`](storage-layout.md) OTA section.

App-only development is outside this A/B upgrade path; use `make build-app` followed by `make push-app`.
