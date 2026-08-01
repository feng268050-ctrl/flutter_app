## 1. Sequencing and docs

- [x] 1.1 Confirm `docs/platform-os-oem-sdk-plan.md` marks **W5** multi-DT FIT and that Factory Test remains a later paused wave
- [x] 1.2 Keep `kernel-61-lts-rebase` proposal/tasks noting **blocked on** `multi-board-fit-dt` (do not start LTS merge until §5 done)
- [x] 1.3 Document board inventory + FIT conf naming in `docs/linux-sdk-vendor-import.md` (SoT still `overlay/kernel/`; DT not in OEM)

## 2. U-Boot selection spike

- [x] 2.1 On ynh960 with current prebuilt U-Boot, prove how to boot a named FIT configuration (`bootm …#conf-…` / env / script)
- [x] 2.2 Record the chosen selection mechanism (env name, factory default, or pack-time bake) in design open-questions resolution notes
- [x] 2.3 If prebuilt U-Boot cannot select conf, document the minimal factory/SKU workaround without blocking multi-FDT packaging

## 3. Board inventory and ITS

- [x] 3.1 Add SoC-family board inventory consumed by FIT packaging (start with `ynh960` only)
- [x] 3.2 Replace/extend `board/boot-slim.its` (or generator) for shared `kernel` + `fdt-<board_id>` + `conf-<board_id>`; default = `ynh960`
- [x] 3.3 Wire lunch / `make build-kernel` to build inventoried DTBs and pack them into dual A/B FITs
- [x] 3.4 Keep publishing bare `Image` for `make emulator` (no `conf-sim` in product FIT)

## 4. Overlay / apply-overlay

- [x] 4.1 Ensure `apply-overlay` / patch-ynh960 path still installs ynh960 DTSI set for the default board
- [x] 4.2 Structure overlay so additional board ids can be added to inventory without rewriting ITS by hand each time
- [x] 4.3 Align OEM pack manifests: `board_id` equals FIT conf name; no startup DTB under `oem/`

## 5. Verify and ynh960 regression

- [x] 5.1 Extend verify (or build post-check) to list FIT conf names and fail on missing inventory DTB / oversized FIT
- [x] 5.2 `FORCE_PLATFORM_OVERLAY=1 make apply-overlay` → `make build-kernel` → size check → `make upgrade` on ynh960
- [x] 5.3 Smoke: display, eth/Wi‑Fi as available, HMI start; confirm loaded DT matches ynh960 overlay expectations
- [x] 5.4 Confirm `make build-emulator` / `make emulator` still uses bare Image + QEMU virt DT

## 6. Hand-off to kernel LTS

- [x] 6.1 Mark W5 complete in platform plan status table when §5 passes
- [x] 6.2 Unblock `openspec/changes/kernel-61-lts-rebase` implementation (rebase all inventoried board overlays on LTS tip)
