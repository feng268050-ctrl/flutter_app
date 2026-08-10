# host-security-audit Specification

## Purpose

Host Make workflows for live-board Lynis hardening audits and published-rootfs SBOM/CVE scans, without baking audit toolchains into the product image.

## Requirements

### Requirement: Host make audit runs Lynis on a live device

The build system SHALL provide `make audit` that selects a device via the existing host SSH device-selection mechanism (`SN=`, `IP=`, USB-SSH / LAN SSH / emulator as supported by `device-target`), stages Lynis onto the device only for the duration of the run (MUST NOT require Lynis to be preinstalled in the product rootfs), executes a non-interactive Lynis system audit with **native Lynis console output** (colored; MUST NOT use Lynis `--cronjob`, which disables colors — use `-Q` / equivalent), retrieves the Lynis log/report/console artifacts to the host under `output/audit/`, and removes the staged Lynis tree from the device. The target MUST fail with a clear error when no suitable device is reachable or when Lynis cannot be obtained on the host.

#### Scenario: Successful Lynis audit streams native report

- **WHEN** a developer runs `make audit` with a reachable selected device and Lynis available on the host (PATH or cache)
- **THEN** the host terminal shows Lynis's own report including Hardening index / Warnings / Suggestions
- **AND** the host writes artifacts under `output/audit/` including at least `lynis-console.txt` and `lynis-report.dat`

#### Scenario: No device selected

- **WHEN** a developer runs `make audit` with no reachable USB-SSH/SSH/emulator device
- **THEN** the command exits non-zero with an error directing the operator to `make devices` / connect / `SN=` / `IP=`

#### Scenario: Lynis not baked into product image

- **WHEN** a stock product rootfs (without a Lynis package) is deployed
- **THEN** `make audit` still works by staging Lynis ephemerally over SSH rather than requiring a rootfs rebuild to include Lynis

### Requirement: Host make audit-cve produces SBOM and dual CVE reports

The build system SHALL provide `make audit-cve` that scans the published APP rootfs image (default `output/firmware/<APP>/rootfs.img`, honoring `APP=` like other firmware targets). The scan MUST (1) produce a software bill of materials with **Syft**, (2) produce a primary vulnerability report with **Grype**, and (3) produce a secondary vulnerability report with **cve-bin-tool** against the same extracted filesystem tree. On macOS hosts, filesystem extract/mount of the ext4 image MUST run via Docker `linux/amd64` (or an equivalent Linux helper already used by the repo) because the macOS host cannot loop-mount ext4 natively. Missing host tools MUST fail with install hints. Missing `rootfs.img` MUST fail with guidance to run `make build-rootfs` (same `APP=`).

#### Scenario: Successful CVE audit writes SBOM and reports

- **WHEN** a developer runs `make audit-cve` with `output/firmware/<APP>/rootfs.img` present and Syft, Grype, and cve-bin-tool available
- **THEN** the host writes under `output/audit/` a Syft SBOM file, a Grype report, a cve-bin-tool report, and a short summary with severity counts

#### Scenario: Missing rootfs image

- **WHEN** a developer runs `make audit-cve` and the APP `rootfs.img` is absent
- **THEN** the command exits non-zero and tells the operator to build rootfs for that `APP=`

#### Scenario: Missing scanner tools

- **WHEN** a developer runs `make audit-cve` and Syft, Grype, or cve-bin-tool is not available
- **THEN** the command exits non-zero with concise install guidance for the missing tool(s)

### Requirement: Host make fetch-cve-db refreshes vulnerability databases

The build system SHALL provide `make fetch-cve-db` that updates the host Grype vulnerability database and refreshes the cve-bin-tool cache using NVD `json-mirror` while disabling data sources that require unavailable host tools (at least OSV / EPSS by default). The target MUST NOT scan `rootfs.img`.

#### Scenario: Successful DB refresh

- **WHEN** a developer runs `make fetch-cve-db` with `grype` and `cve-bin-tool` on PATH
- **THEN** Grype DB status is refreshed and the cve-bin-tool cache under the host home directory is updated without requiring a rootfs image

### Requirement: Audit targets are documented and non-destructive to release images

`make audit`, `make audit-cve`, and `make fetch-cve-db` MUST appear in Makefile `help` under a dedicated **`Audit:`** section (same grouping style as `Setup:`, `Debug:`, `Cloud + Upgrade:`, etc.), and in README Make commands and `docs/make-commands.md`. Running these targets MUST NOT modify `factory.img` / OTA package contents or bake audit tools into the product rootfs. Default successful completion MUST exit zero even when Lynis findings or CVEs are reported, unless an explicit strict mode env var (documented in help / make-commands) is set to fail on Critical/High findings.

#### Scenario: Help lists Audit group

- **WHEN** a developer runs `make help`
- **THEN** output includes an `Audit:` section header that lists `make audit`, `make audit-cve`, and `make fetch-cve-db` with brief descriptions

#### Scenario: Default exit ignores finding severity

- **WHEN** `make audit-cve` completes scanning and Grype reports at least one High or Critical CVE and strict mode is unset
- **THEN** the command still exits zero and leaves the CVE reports on disk under `output/audit/`
