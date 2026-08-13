#!/usr/bin/env bash
# SBOM + CVE audit of published APP rootfs.img (make audit-cve).
# Syft (SBOM) → Grype (primary CVE) → cve-bin-tool (secondary).
#
# Usage:
#   make audit-cve
#   APP=lws_hmi bash scripts/audit-cve.sh
#
# Env:
#   APP=          Flutter/app id (default lws_hmi) → output/firmware/<APP>/rootfs.img
#   STRICT=1      fail on Critical/High from Grype (and High/Critical from cve-bin-tool)
#   FAIL_ON=high  same as STRICT=1 (Grype --fail-on high)
#   ROOTFS_IMG=   override path to rootfs image
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/app-select.sh
source "$ROOT/scripts/app-select.sh"

app_select_resolve

ROOTFS_IMG="${ROOTFS_IMG:-$APP_ROOTFS_IMG}"
STRICT="${STRICT:-0}"
FAIL_ON="${FAIL_ON:-}"
EXTRACT_DIR="${AUDIT_EXTRACT_DIR:-$ROOT/.cache/audit-rootfs/$APP}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  make audit-cve
  APP=lws_hmi bash scripts/audit-cve.sh

Scan published APP rootfs.img with Syft (SBOM), Grype (CVE), and cve-bin-tool
(secondary). Writes output/audit/cve-<stamp>/.

Env:
  APP=              app id (default lws_hmi)
  ROOTFS_IMG=       override image path
  STRICT=1          exit non-zero on Critical/High findings
  FAIL_ON=high      same as STRICT=1 (also accepted: critical)
  AUDIT_EXTRACT_DIR= override extract work dir (default .cache/audit-rootfs/<APP>)

Host tools (must be on PATH):
  syft     https://github.com/anchore/syft#installation
           brew install syft
  grype    https://github.com/anchore/grype#installation
           brew install grype
  cve-bin-tool
           pipx install cve-bin-tool
           # or: pip install --user cve-bin-tool

macOS: rootfs extract uses Docker linux/amd64 (privileged loop mount).
Before release audits: make fetch-cve-db
  (or: CVE_BIN_UPDATE=now make audit-cve — slower; prefer fetch-cve-db)
EOF
}

want_strict() {
	[[ "$STRICT" == "1" || "$FAIL_ON" == "high" || "$FAIL_ON" == "critical" ]]
}

grype_fail_on() {
	case "${FAIL_ON:-}" in
	critical) echo critical ;;
	*) echo high ;;
	esac
}

require_tools() {
	# pipx installs often land in ~/.local/bin (may not be on non-interactive PATH).
	export PATH="${HOME}/.local/bin:${PATH}"
	local missing=()
	command -v syft >/dev/null 2>&1 || missing+=("syft")
	command -v grype >/dev/null 2>&1 || missing+=("grype")
	command -v cve-bin-tool >/dev/null 2>&1 || missing+=("cve-bin-tool")
	if [[ ${#missing[@]} -gt 0 ]]; then
		die "missing host tool(s): ${missing[*]}

Install hints:
  syft:          brew install syft
                 # or curl -sSfL https://raw.githubusercontent.com/anchore/syft/main/install.sh | sh -s -- -b /usr/local/bin
  grype:         brew install grype
                 # or curl -sSfL https://raw.githubusercontent.com/anchore/grype/main/install.sh | sh -s -- -b /usr/local/bin
  cve-bin-tool:  brew install pipx && pipx install cve-bin-tool
                 # OSV source needs gsutil; script disables OSV/EPSS by default
                 # First DB fill: make fetch-cve-db

See: bash scripts/audit-cve.sh --help"
	fi
}

extract_rootfs() {
	local img="$1" dest="$2"
	echo "==> extracting rootfs → $dest"
	rm -rf "$dest"
	mkdir -p "$dest"

	if [[ "$(uname -s)" == Darwin ]]; then
		command -v docker >/dev/null 2>&1 || die "Docker required on macOS to extract ext4 rootfs.img"
		# Skip apply-overlay; only need privileged loop mount + copy.
		env SKIP_OVERLAY=1 bash "$ROOT/scripts/docker-run.sh" bash -c "
set -euo pipefail
IMG='/work/lws-hmi/${img#"$ROOT"/}'
DEST='/work/lws-hmi/${dest#"$ROOT"/}'
mkdir -p /mnt/audit-rootfs \"\$DEST\"
mount -o loop,ro \"\$IMG\" /mnt/audit-rootfs
# Prefer rsync; fall back to cp -a
if command -v rsync >/dev/null 2>&1; then
  rsync -a --delete /mnt/audit-rootfs/ \"\$DEST\"/
else
  rm -rf \"\$DEST\"/*
  cp -a /mnt/audit-rootfs/. \"\$DEST\"/
fi
umount /mnt/audit-rootfs
"
		return 0
	fi

	# Native Linux: loop-mount (may need root).
	local mnt
	mnt="$(mktemp -d "${TMPDIR:-/tmp}/lws-audit-mnt.XXXXXX")"
	cleanup_mnt() {
		umount "$mnt" 2>/dev/null || true
		rmdir "$mnt" 2>/dev/null || true
	}
	trap cleanup_mnt RETURN
	if ! mount -o loop,ro "$img" "$mnt" 2>/dev/null; then
		if command -v sudo >/dev/null 2>&1; then
			sudo mount -o loop,ro "$img" "$mnt" ||
				die "failed to mount $img (need loop mount privileges)"
		else
			die "failed to mount $img (need loop mount privileges)"
		fi
	fi
	if command -v rsync >/dev/null 2>&1; then
		rsync -a "$mnt"/ "$dest"/
	else
		cp -a "$mnt"/. "$dest"/
	fi
	cleanup_mnt
	trap - RETURN
}

count_grype_high() {
	local json="$1"
	[[ -f "$json" ]] || {
		echo 0
		return
	}
	python3 - "$json" <<'PY' 2>/dev/null || echo 0
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    print(0)
    raise SystemExit
sevs = {"Critical", "High"}
n = 0
for m in data.get("matches") or []:
    sev = ((m.get("vulnerability") or {}).get("severity") or "").capitalize()
    if sev in sevs or (m.get("vulnerability") or {}).get("severity") in ("Critical", "High", "critical", "high"):
        n += 1
print(n)
PY
}

count_cve_bin_high() {
	local json="$1"
	[[ -f "$json" ]] || {
		echo 0
		return
	}
	python3 - "$json" <<'PY' 2>/dev/null || echo 0
import json, sys
path = sys.argv[1]
try:
    data = json.load(open(path))
except Exception:
    print(0)
    raise SystemExit
# cve-bin-tool JSON shapes vary; walk for severity fields.
sevs = {"CRITICAL", "HIGH", "Critical", "High"}
n = 0
def walk(o):
    global n
    if isinstance(o, dict):
        sev = o.get("severity") or o.get("Severity")
        if sev in sevs:
            n += 1
        for v in o.values():
            walk(v)
    elif isinstance(o, list):
        for v in o:
            walk(v)
walk(data)
print(n)
PY
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

[[ -f "$ROOTFS_IMG" ]] || die "missing rootfs image: $ROOTFS_IMG
Run: APP=$APP make build-rootfs"

require_tools

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$ROOT/output/audit/cve-$STAMP"
mkdir -p "$OUT_DIR" "$(dirname "$EXTRACT_DIR")"
LATEST_LINK="$ROOT/output/audit/cve-latest"

extract_rootfs "$ROOTFS_IMG" "$EXTRACT_DIR"
[[ -d "$EXTRACT_DIR" ]] || die "extract failed: $EXTRACT_DIR empty"

echo "==> Syft SBOM"
syft "dir:$EXTRACT_DIR" -o cyclonedx-json >"$OUT_DIR/sbom.cdx.json"

echo "==> Grype (primary CVE)"
set +e
if want_strict; then
	grype "sbom:$OUT_DIR/sbom.cdx.json" -o json --file "$OUT_DIR/grype.json" --fail-on "$(grype_fail_on)"
	grype_rc=$?
else
	grype "sbom:$OUT_DIR/sbom.cdx.json" -o json --file "$OUT_DIR/grype.json"
	grype_rc=$?
fi
grype "sbom:$OUT_DIR/sbom.cdx.json" -o table >"$OUT_DIR/grype.txt" 2>/dev/null || true
set -e

echo "==> cve-bin-tool (secondary)"
# OSV data source shells out to gsutil (often missing on macOS hosts) — disable it.
# Prefer json-mirror NVD; skip daily refresh when DB already populated (-u never after first success).
# Do NOT pass -q: cve-bin-tool's live progress (file scan / checkers) goes to stderr.
CVE_BIN_UPDATE="${CVE_BIN_UPDATE:-never}"
CVE_BIN_DISABLE="${CVE_BIN_DISABLE:-OSV,EPSS}"
set +e
cve-bin-tool "$EXTRACT_DIR" \
	-f json \
	-o "$OUT_DIR/cve-bin-tool" \
	-n json-mirror \
	-u "$CVE_BIN_UPDATE" \
	-d "$CVE_BIN_DISABLE" \
	2> >(tee "$OUT_DIR/cve-bin-tool.stderr" >&2)
cve_rc=$?
set -e
# Normalize output filename (-o is a basename/prefix; tool appends .json).
if [[ -f "$OUT_DIR/cve-bin-tool.json" ]]; then
	:
elif [[ -f "$OUT_DIR/cve-bin-tool.report.json" ]]; then
	mv -f "$OUT_DIR/cve-bin-tool.report.json" "$OUT_DIR/cve-bin-tool.json"
elif compgen -G "$OUT_DIR/cve-bin-tool*.json" >/dev/null; then
	first_json="$(ls -1 "$OUT_DIR"/cve-bin-tool*.json | head -1)"
	[[ "$first_json" == "$OUT_DIR/cve-bin-tool.json" ]] || mv -f "$first_json" "$OUT_DIR/cve-bin-tool.json"
fi
if [[ ! -f "$OUT_DIR/cve-bin-tool.json" ]]; then
	echo "[]" >"$OUT_DIR/cve-bin-tool.json"
	echo "WARNING: cve-bin-tool did not produce JSON (exit $cve_rc); wrote empty []; see cve-bin-tool.stderr" >&2
fi

GRYPE_HIGH="$(count_grype_high "$OUT_DIR/grype.json")"
CVEBIN_HIGH="$(count_cve_bin_high "$OUT_DIR/cve-bin-tool.json")"
REPORT_TXT="$OUT_DIR/report.txt"

{
	echo "lws-hmi image CVE audit"
	echo "stamp: $STAMP"
	echo "APP: $APP"
	echo "rootfs: $ROOTFS_IMG"
	echo "extract: $EXTRACT_DIR"
	echo "syft: $(command -v syft)"
	echo "grype: $(command -v grype) (exit $grype_rc)"
	echo "cve-bin-tool: $(command -v cve-bin-tool) (exit $cve_rc)"
	echo "grype_critical_high: $GRYPE_HIGH"
	echo "cve_bin_tool_critical_high: $CVEBIN_HIGH"
	echo "strict: $(want_strict && echo 1 || echo 0)"
	echo "hint: before release audits run: make fetch-cve-db"
	echo "report: $REPORT_TXT"
} >"$OUT_DIR/summary.txt"

rm -f "$LATEST_LINK"
ln -s "cve-$STAMP" "$LATEST_LINK"

{
	echo "════════════════════════════════════════════════════════════"
	echo " Image CVE audit (APP=$APP)"
	echo "════════════════════════════════════════════════════════════"
	echo " Rootfs:    $ROOTFS_IMG"
	echo " Stamp:     $STAMP"
	echo " Grype Critical/High:      $GRYPE_HIGH"
	echo " cve-bin-tool Critical/High: $CVEBIN_HIGH"
	echo "────────────────────────────────────────────────────────────"
	if [[ -f "$OUT_DIR/grype.json" && "$GRYPE_HIGH" -gt 0 ]]; then
		echo " Grype Critical/High (top)"
		echo "────────────────────────────────────────────────────────────"
		python3 - "$OUT_DIR/grype.json" <<'PY' 2>/dev/null || true
import json, sys
data = json.load(open(sys.argv[1]))
rows = []
for m in data.get("matches") or []:
    v = m.get("vulnerability") or {}
    sev = (v.get("severity") or "").capitalize()
    if sev not in ("Critical", "High"):
        continue
    art = (m.get("artifact") or {})
    name = art.get("name") or "?"
    ver = art.get("version") or "?"
    cve = v.get("id") or "?"
    rows.append((sev, cve, f"{name}@{ver}"))
# Critical first
order = {"Critical": 0, "High": 1}
rows.sort(key=lambda r: (order.get(r[0], 9), r[1]))
for sev, cve, pkg in rows[:40]:
    print(f"  [{sev:8}] {cve:20} {pkg}")
if len(rows) > 40:
    print(f"  … +{len(rows) - 40} more (see grype.json / grype.txt)")
PY
		echo "────────────────────────────────────────────────────────────"
	fi
	if [[ -f "$OUT_DIR/grype.txt" ]]; then
		echo " Grype table (excerpt)"
		echo "────────────────────────────────────────────────────────────"
		head -n 35 "$OUT_DIR/grype.txt" | sed 's/^/  /'
		lines="$(wc -l <"$OUT_DIR/grype.txt" | tr -d ' ')"
		if [[ "${lines:-0}" -gt 35 ]]; then
			echo "  … (full table: $OUT_DIR/grype.txt)"
		fi
		echo "────────────────────────────────────────────────────────────"
	fi
	echo " Artifacts: $OUT_DIR"
	echo "   report.txt          this summary"
	echo "   sbom.cdx.json       Syft SBOM"
	echo "   grype.json/.txt     primary CVE"
	echo "   cve-bin-tool.json   secondary scan"
	echo "════════════════════════════════════════════════════════════"
} | tee "$REPORT_TXT"

if want_strict; then
	if [[ "$grype_rc" -ne 0 ]]; then
		die "STRICT: Grype failed or reported findings at/above $(grype_fail_on) (exit $grype_rc); see $REPORT_TXT"
	fi
	if [[ "$CVEBIN_HIGH" -gt 0 ]]; then
		die "STRICT: cve-bin-tool reported $CVEBIN_HIGH Critical/High finding(s); see $REPORT_TXT"
	fi
fi

exit 0
