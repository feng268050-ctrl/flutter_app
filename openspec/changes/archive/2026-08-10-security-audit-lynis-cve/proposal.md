## Why

The product image has hardened pieces (OpenSSL pin, GStreamer/BlueZ security bumps, SELinux permissive) but operators still lack a **repeatable host Make path** to produce a configuration/hardening report on a live board and a **SBOM + CVE** report from the built rootfs. Ad-hoc NVD reviews do not scale across package bumps. The old `make audit` flash preflight was removed (host path / Docker volume false failures); reclaiming that name for **Lynis** avoids colliding with a dead meaning.

## What Changes

- Add **`make audit`**: SSH to a selected device, stage **Lynis** ephemerally (not baked into product rootfs), stream the **native Lynis console report** (colored via `-Q`; not `--cronjob`), and pull artifacts to `output/audit/`.
- Add **`make audit-cve`**: against the built APP rootfs image (default `output/firmware/<APP>/rootfs.img`), run **Syft** (SBOM) + **Grype** (primary CVE) and **cve-bin-tool** (secondary); write reports under `output/audit/`.
- Add **`make fetch-cve-db`**: refresh host Grype + cve-bin-tool vulnerability DBs before release audits.
- Add host scripts + Makefile help under a dedicated **`Audit:`** group / README / `docs/make-commands.md` / AGENTS rebuild notes.
- Document host tool prerequisites; macOS image extract/mount via Docker `linux/amd64` when needed.
- **Out of scope:** auto-remediation; CI fail-on-every-CVE; baking Lynis into appliance rootfs; Dart pub-only SBOM; reinstating flash-preflight `audit`.

## Capabilities

### New Capabilities

- `host-security-audit`: Host Make workflows for live-board Lynis hardening reports (`make audit`) and image SBOM/CVE reports (`make audit-cve` via Syft + Grype + cve-bin-tool), including report layout under `output/audit/` and tool prerequisite checks.

### Modified Capabilities

- (none) — no product rootfs/kernel requirement changes; audits are host-driven against an already-built image and a reachable board.

## Impact

- **Makefile / docs:** `audit`, `audit-cve`, `fetch-cve-db`; `Audit:` help group; README / `docs/make-commands.md` / AGENTS.md.
- **Scripts:** `scripts/audit-lynis.sh`, `scripts/audit-cve.sh`, `scripts/fetch-cve-db.sh`, `scripts/lynis-custom.prf`.
- **Host deps:** Lynis (`.cache/lynis` clone), Syft, Grype, cve-bin-tool; Docker on macOS for ext4 extract.
- **Artifacts:** `output/audit/` only; product rootfs unchanged (Lynis not packaged).
- **Risk:** DB freshness → `make fetch-cve-db`; false positives → report-only default (`STRICT=1` optional).
