## 1. Board stream helpers

- [x] 1.1 Add a small board-side preflight helper (or libexec command) that prints active/inactive letter, try-boot state, and resolved inactive rootfs / boot / boot_b / oem device paths + capacities using `ab-slot-lib.sh`
- [x] 1.2 Add board helpers to backup `boot`→`boot_b`, stream-write stdin to a named partition with expected byte count, arm try-boot + set status, and reboot — without requiring full images under `/userdata/ota/`
- [x] 1.3 Keep `ab-upgrade-apply.sh` staged digest-then-dd path intact for online OTA

## 2. Host `make upgrade` stream path

- [x] 2.1 Rewrite `scripts/upgrade-remote.sh` to preflight over SSH, then stream `rootfs.img` and only the inactive letter’s FIT (optional oem) with progress into partition writers
- [x] 2.2 Ensure mid-stream / preflight failures exit non-zero and never arm try-boot; remove full-image stage-to-`/userdata/ota/` from the default path
- [x] 2.3 Keep host GPT size checks (`verify-firmware-partitions.sh`) and missing-artifact fail-fast behavior

## 3. Docs and acceptance

- [x] 3.1 Update README / Makefile help wording: stream-to-partition vs flash; not online OTA staging
- [x] 3.2 Update `docs/storage-layout.md` and `docs/ab-upgrade-acceptance.md` for stream upgrade vs staged OTA
- [x] 3.3 Smoke on device: happy-path `make upgrade`, abort/truncate before arm still boots active letter, and manual staged apply still works
