## Context

Operators need repeatable security evidence for the ynh960 appliance image: (1) live hardening/config findings via Lynis on a board reachable over USB-SSH or LAN SSH, and (2) SBOM + CVE coverage of what actually ships in `output/firmware/<APP>/rootfs.img`. Recent package work (OpenSSL, GStreamer, BlueZ, kernel LTS, SELinux) was driven by one-off audits; the Make surface should make the next audit cheap.

The former `make audit` was a **flash preflight** (`scripts/audit-firmware.sh`) and was removed because it false-failed on the macOS Docker volume SDK layout. That name is free and should mean **security audit**, not flash readiness (`make check-prebuilt` / device discovery already cover flash gates).

Constraints: macOS hosts cannot loop-mount ext4 natively; rootfs builds already use Docker `linux/amd64`. Device selection already exists (`scripts/device-target.sh`, USB-SSH helpers). Product rootfs size budget is tight — do not ship audit toolchains in the appliance by default.

## Goals / Non-Goals

**Goals:**

- `make audit` produces a Lynis report for a selected live device and stores it under `output/audit/`.
- `make audit-cve` produces Syft SBOM + Grype CVE report + cve-bin-tool secondary report for the built APP rootfs image under `output/audit/`.
- Clear host prerequisite checks; Docker path for image extract on macOS.
- Documented Make/help/docs/AGENTS alignment.

**Non-Goals:**

- Failing CI/release builds on every finding by default.
- Baking Lynis, Syft, Grype, or cve-bin-tool into product rootfs.
- Scanning Dart `pubspec` / npm graphs as the primary SoT (optional later).
- Auto-patching packages from report output.
- Reintroducing flash-preflight under `make audit`.
- Claiming compliance certifications from these reports alone.

## Decisions

### D1 — Reclaim `make audit` for Lynis (not flash preflight)

**Choice:** `make audit` → `scripts/audit-lynis.sh`. Flash readiness stays on existing targets (`check-prebuilt`, `devices`, `flash`).

**Alternatives:** `make audit-lynis` / keep `audit` unused — rejected; user asked for `make audit`, and the old meaning is gone.

### D2 — Lynis is ephemeral on-device (not a Buildroot package)

**Choice:** Host stages a Lynis tree (git clone under `.cache/lynis/`), uploads to `/tmp/lynis-audit/`, **`chown -R 0:0`** after upload (macOS UID 501 breaks Lynis SafePerms), runs `lynis audit system -Q` (colored, non-interactive; **not** `--cronjob` which forces `COLORS=0`), pulls reports, then removes the upload. Ship `scripts/lynis-custom.prf` into the staged tree to skip BusyBox-incompatible `TIME-3185`. Do **not** add `BR2_PACKAGE_LYNIS` to the product defconfig.

**Alternatives:** (a) Bake Lynis into rootfs — rejected (size + attack surface; user preference). (b) `--cronjob` for non-interactive — rejected (disables colors).

### D3 — Device selection matches other host SSH tools

**Choice:** Reuse `device-target` / USB-SSH session helpers (`SN=`, `IP=`, emulator). Fail fast if no device. Same password/sshpass patterns as `make push-app` / `make upgrade`.

**Alternatives:** Hard-code `192.168.55.1` — rejected.

### D4 — `make audit-cve` SoT is published APP `rootfs.img`

**Choice:** Default input `output/firmware/<APP>/rootfs.img` (`APP=lws_hmi`) only — see D10. Pipeline:

1. Ensure image exists (error with “run `make build-rootfs`” if missing).
2. Extract/mount to `.cache/audit-rootfs/<APP>/` (Linux host: loop mount; **macOS: Docker** privileged loop mount).
3. **Syft** scan the filesystem tree → CycloneDX JSON SBOM.
4. **Grype** scan the SBOM (or the dir) → JSON + human-readable summary (severity counts).
5. **cve-bin-tool** scan the same tree as a second pass (`CVE_BIN_UPDATE=never`; OSV/EPSS disabled — refreshed via D5).
6. Write all artifacts under `output/audit/cve-<stamp>/` (see D7).

**Alternatives:** Scan Buildroot `target/` inside `linux-sdk` — rejected as primary (macOS volume / not the published artifact). Scan `factory.img` whole — too coarse; rootfs is the userspace CVE surface. Optional `oem.img` — deferred (D10).

### D5 — Host CVE DB refresh via `make fetch-cve-db`

**Choice:** Separate target `scripts/fetch-cve-db.sh` runs `grype db update` and `cve-bin-tool -u now -n json-mirror -d OSV,EPSS` (OSV needs `gsutil`). Daily `make audit-cve` keeps `CVE_BIN_UPDATE=never` so scans do not re-download DBs.

**Alternatives:** Always update inside `audit-cve` — rejected (slow / noisy). Document-only brew commands — rejected (operators forget).

### D6 — Default exit policy: report succeeds even if findings exist

**Choice:** Default exit 0 when the audit **ran successfully**, regardless of Lynis warnings or CVE counts. Optional `STRICT=1` (or `FAIL_ON=high`) fails non-zero when Grype/cve-bin-tool report Critical/High. Lynis hardening index is informational unless STRICT.

**Alternatives:** Always fail on any CVE — rejected (noisy; blocks daily use).

### D7 — Report layout under `output/audit/`

**Choice:**

```text
output/audit/
  lynis-<stamp>/
    lynis-console.txt  # streamed Lynis native TTY report (source of truth for operators)
    lynis.log
    lynis-report.dat
    summary.txt        # host metadata (SN/IP/stamp)
  cve-<stamp>/
    sbom.cdx.json
    grype.json
    grype.txt
    cve-bin-tool.json
    report.txt         # host severity summary (+ Grype Critical/High list)
    summary.txt
  lynis-latest → …
  cve-latest → …
```

**Alternatives:** Only custom boxed summary — rejected (operators want Lynis native output). Only stdout — rejected (need durable artifacts).

### D8 — Docs and AGENTS; `make help` under **Audit:**

**Choice:** Dedicated help section:

```text
Audit:
  make audit                 # Lynis on device → output/audit/lynis-*
  make audit-cve             # Syft SBOM + Grype + cve-bin-tool → output/audit/cve-*
  make fetch-cve-db          # refresh host Grype + cve-bin-tool DBs
```

AGENTS rebuild: host scripts only → **none** for firmware (except when changing rootfs inputs for CVE scan).

### D9 — Scanner progress on the host TTY

**Choice:** Stream tool progress to the terminal. Lynis stdout is teed. `cve-bin-tool` runs **without** `-q`, stderr teed to `cve-bin-tool.stderr`. Syft writes SBOM on stdout; its progress/UI goes to stderr (leave stderr unredirected).

**Alternatives:** Quiet all scanners — rejected (operators asked for live progress).

### D10 — `audit-cve` scope is APP `rootfs.img` only

**Choice:** Scan only the published APP rootfs image (default `output/firmware/<APP>/rootfs.img`). Do **not** scan `boot.img` / `oem.img` / `factory.img` / Dart pub graphs in this change.

**Alternatives:** OEM=1 optional oem scan — deferred.

## Risks / Trade-offs

| Risk | Mitigation |
|------|------------|
| Lynis noise / false positives on embedded Buildroot | Document expected appliance deltas; do not treat score as a ship gate |
| Syft misses statically linked / uncommon aarch64 packages | cve-bin-tool second pass; accept residual blind spots |
| cve-bin-tool false positives on stripped binaries | Mark as secondary; summarize High/Critical only in `summary.txt` |
| macOS cannot mount ext4 | Always run extract/scan inside Docker `linux/amd64` when `uname` is Darwin |
| Tool DB outdated → missed CVEs | `make fetch-cve-db` before release `audit-cve`; default scan uses `CVE_BIN_UPDATE=never` |
| Uploading Lynis needs disk + SSH time | Use `/tmp`; clean up on EXIT trap; keep tree small |
| Name confusion with deleted flash audit | Docs explicitly say security Lynis; no firmware path checks |

## Migration Plan

1. Land scripts + Make targets + docs (no image rebuild required).
2. Operators install host tools once; run `make audit` against a board; run `make audit-cve` after `make build-rootfs`.
3. **Rollback:** remove targets/scripts/docs; no device state to revert (Lynis upload is ephemeral).

## Open Questions

- None — locked at archive: Lynis ephemeral + `-Q` + `TIME-3185` skip + root `chown`; `fetch-cve-db` separate; `STRICT=1` / `FAIL_ON=high` optional; rootfs-only CVE SoT; no `fetch-audit-tools` pin (docs-first brew/PATH).
