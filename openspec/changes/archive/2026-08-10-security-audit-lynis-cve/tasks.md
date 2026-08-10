## 1. Lynis host path (`make audit`)

- [x] 1.1 Add `scripts/audit-lynis.sh`: resolve device via existing SSH/device-target helpers; stage Lynis from host cache or clone into `.cache/lynis/`; upload to device temp dir; run non-interactive `lynis audit system`; pull log/report; clean up remote tree (EXIT trap)
- [x] 1.2 Write host artifacts under `output/audit/lynis-<stamp>/` (log/report + `summary.txt` with SN/IP/time); fail clearly when no device or Lynis missing
- [x] 1.3 Wire Makefile `audit` target + `.PHONY`; keep behavior independent of the deleted flash-preflight script

## 2. Image CVE path (`make audit-cve`)

- [x] 2.1 Add `scripts/audit-cve.sh`: resolve `APP=` rootfs path (`output/firmware/<APP>/rootfs.img`); error if missing with `make build-rootfs` hint
- [x] 2.2 Extract/mount rootfs tree for scanning (Darwin → Docker `linux/amd64` loop mount or equivalent; Linux host may mount locally); tear down mount/work dir on EXIT
- [x] 2.3 Run Syft → SBOM JSON; Grype → JSON + text; cve-bin-tool → secondary report; write all under `output/audit/cve-<stamp>/` plus `summary.txt` severity counts
- [x] 2.4 Prerequisite checks for `syft` / `grype` / `cve-bin-tool` with install hints; default exit 0 on findings; implement documented `STRICT=1` (or `FAIL_ON=high`) non-zero on Critical/High
- [x] 2.5 Wire Makefile `audit-cve` target + `.PHONY`

## 3. Docs and agent rebuild notes

- [x] 3.1 Update Makefile `help` with a dedicated `Audit:` group listing `make audit` and `make audit-cve` (not under Build/Debug/Misc)
- [x] 3.2 Update README Make commands and `docs/make-commands.md` (怎么用 / 何时用 / 参数: `APP=`, `SN=`, `IP=`, `STRICT=`)
- [x] 3.3 Update AGENTS.md rebuild table: these scripts/docs → none for firmware; exercise `make audit` / `make audit-cve` (CVE needs prior rootfs)

## 4. Smoke verification

- [x] 4.1 Dry-run / help: `make help` shows `Audit:` with both targets; missing-device and missing-rootfs paths print expected errors
- [x] 4.2 On a board (when available): `make audit` produces `output/audit/lynis-*` and leaves no Lynis tree under `/tmp` on device after exit
- [x] 4.3 After `make build-rootfs`: `make audit-cve` produces SBOM + Grype + cve-bin-tool artifacts under `output/audit/cve-*`
