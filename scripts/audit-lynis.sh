#!/usr/bin/env bash
# Live-board Lynis hardening audit over USB-SSH / registered SSH (make audit).
# Stages Lynis ephemerally (not baked into product rootfs).
# Prints Lynis's own colored console report (not a custom summary).
#
# Usage:
#   make audit
#   SN=<sn> bash scripts/audit-lynis.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/usb-ssh-session.sh
source "$ROOT/scripts/usb-ssh-session.sh"

LYNIS_CACHE="${LYNIS_CACHE:-$ROOT/.cache/lynis}"
LYNIS_REPO_URL="${LYNIS_REPO_URL:-https://github.com/CISOfy/lynis.git}"
LYNIS_REF="${LYNIS_REF:-master}"
REMOTE_DIR="/tmp/lynis-audit"
STRICT="${STRICT:-0}"
FAIL_ON="${FAIL_ON:-}"

die() {
	echo "ERROR: $*" >&2
	exit 1
}

usage() {
	cat <<'EOF'
Usage:
  make audit
  SN=<sn> bash scripts/audit-lynis.sh

Stage Lynis onto a live board, stream its native (colored) report to the
terminal, pull reports to output/audit/lynis-<stamp>/, then remove the staged
tree. Lynis is NOT installed in the product rootfs.

Env:
  SN= / IP=       device selection (see make devices)
  STRICT=1        exit non-zero when the Lynis report contains Warnings
  FAIL_ON=high    alias for STRICT=1
  LYNIS_REF=      git ref for .cache/lynis clone (default master)
  LWS_SSH_IDENTITY=  host private key (default keys/ssh/id_ed25519)
EOF
}

remote() {
	usb_ssh_session_run_ssh "$ROOT" "$IFACE" "$@"
}

scp_from() {
	local src="$1" dest="$2"
	usb_ssh_session_run_scp "$ROOT" "$IFACE" \
		"${TARGET_USER:-root}@${TARGET_ADDR}:$src" "$dest"
}

want_strict() {
	[[ "$STRICT" == "1" || "$FAIL_ON" == "high" || "$FAIL_ON" == "critical" ]]
}

ensure_lynis() {
	if [[ -x "$LYNIS_CACHE/lynis" ]]; then
		patch_lynis_busybox_usrmerge
		return 0
	fi
	if command -v git >/dev/null 2>&1; then
		echo "==> cloning Lynis ($LYNIS_REF) → $LYNIS_CACHE"
		mkdir -p "$(dirname "$LYNIS_CACHE")"
		rm -rf "$LYNIS_CACHE"
		git clone --depth 1 --branch "$LYNIS_REF" "$LYNIS_REPO_URL" "$LYNIS_CACHE" ||
			git clone --depth 1 "$LYNIS_REPO_URL" "$LYNIS_CACHE"
		[[ -x "$LYNIS_CACHE/lynis" ]] || die "Lynis clone missing executable at $LYNIS_CACHE/lynis"
		patch_lynis_busybox_usrmerge
		return 0
	fi
	die "Lynis not found at $LYNIS_CACHE/lynis and git is unavailable.
Install: git clone $LYNIS_REPO_URL $LYNIS_CACHE"
}

# Buildroot usr-merge: /bin → /usr/bin, so readlink -f /bin/ps is /usr/bin/busybox.
# Upstream Lynis only matches /bin/busybox → SHELL_IS_BUSYBOX=0 → IsRunning uses
# GNU `ps -C` (unsupported by BusyBox) → false "rngd not found" for CRYP-8004 etc.
patch_lynis_busybox_usrmerge() {
	local f="$LYNIS_CACHE/include/osdetection"
	[[ -f "$f" ]] || return 0
	if grep -q '/usr/bin/busybox' "$f"; then
		return 0
	fi
	if ! grep -q 'SYMLINK.*=.*"/bin/busybox"' "$f"; then
		echo "WARN: Lynis osdetection BusyBox check shape changed; skip usr-merge patch" >&2
		return 0
	fi
	# shellcheck disable=SC2016
	sed -i.bak \
		's|"\${SYMLINK}" = "/bin/busybox"|"${SYMLINK}" = "/bin/busybox" -o "${SYMLINK}" = "/usr/bin/busybox"|' \
		"$f"
	rm -f "$f.bak"
	echo "==> patched Lynis BusyBox detect for usr-merge (/usr/bin/busybox)"
}

cleanup_remote() {
	remote "rm -rf '$REMOTE_DIR'" 2>/dev/null || true
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
	usage
	exit 0
fi

ensure_lynis

usb_ssh_session_prepare "$ROOT"

STAMP="$(date +%Y%m%d-%H%M%S)"
OUT_DIR="$ROOT/output/audit/lynis-$STAMP"
mkdir -p "$OUT_DIR"
LATEST_LINK="$ROOT/output/audit/lynis-latest"
CONSOLE_TXT="$OUT_DIR/lynis-console.txt"

trap cleanup_remote EXIT

echo "==> staging Lynis → ${TARGET_USER}@${TARGET_ADDR}:$REMOTE_DIR"
export COPYFILE_DISABLE=1
remote "rm -rf '$REMOTE_DIR' && mkdir -p '$REMOTE_DIR'"
tar --exclude='._*' --exclude='.DS_Store' --exclude='.git' -C "$LYNIS_CACHE" -cf - . |
	remote "tar -xf - -C '$REMOTE_DIR'"
# Appliance profile (scripts/lynis-custom.prf): skip BusyBox TIME-3185 + false klogd LOGG-2138.
if [[ -f "$ROOT/scripts/lynis-custom.prf" ]]; then
	remote "cat >'$REMOTE_DIR/custom.prf'" <"$ROOT/scripts/lynis-custom.prf"
fi
# Lynis refuses to run if include/* is not owned by root (macOS uploads keep host UID).
remote "chown -R 0:0 '$REMOTE_DIR' && chmod -R u+rwX '$REMOTE_DIR' && chmod 0755 '$REMOTE_DIR/lynis'"
remote "rm -f /var/run/lynis.pid /run/lynis.pid /root/lynis.pid '$REMOTE_DIR/lynis.pid' 2>/dev/null || true"

echo "==> running Lynis (native colored console)"
echo ""
# Prefer -Q over --cronjob: cronjob forces COLORS=0. -Q is still non-interactive.
set +e
remote "export TERM='${TERM:-xterm-256color}'; cd '$REMOTE_DIR' && ./lynis audit system -Q \
	--auditor 'lws-hmi' \
	--log-file '$REMOTE_DIR/lynis.log' \
	--report-file '$REMOTE_DIR/lynis-report.dat' \
	2>'$REMOTE_DIR/lynis-stderr.txt'" | tee "$CONSOLE_TXT"
lynis_rc=${PIPESTATUS[0]}
set -e
echo ""

echo "==> pulling reports → $OUT_DIR"
scp_from "$REMOTE_DIR/lynis.log" "$OUT_DIR/lynis.log" || true
scp_from "$REMOTE_DIR/lynis-report.dat" "$OUT_DIR/lynis-report.dat" || true
scp_from "$REMOTE_DIR/lynis-stderr.txt" "$OUT_DIR/lynis-stderr.txt" || true

REPORT="$OUT_DIR/lynis-report.dat"
WARN_COUNT=0
if [[ -f "$REPORT" ]]; then
	WARN_COUNT="$(grep -cE '^warning\[\]=' "$REPORT" 2>/dev/null || true)"
	WARN_COUNT="${WARN_COUNT:-0}"
fi

DEVICE_OS="$(remote "cat /etc/os-release 2>/dev/null | head -5" || true)"
DEVICE_UNAME="$(remote "uname -a" || true)"

{
	echo "lws-hmi Lynis audit"
	echo "stamp: $STAMP"
	echo "mode: staged"
	echo "transport: ${TRANSPORT:-}"
	echo "target: ${TARGET_USER}@${TARGET_ADDR}"
	echo "iface: ${IFACE:-}"
	echo "SN: ${SN:-}"
	echo "IP: ${IP:-}"
	echo "lynis_exit: $lynis_rc"
	echo "warnings: $WARN_COUNT"
	echo "console: $CONSOLE_TXT"
	echo "report_dat: $REPORT"
	echo "log: $OUT_DIR/lynis.log"
	echo "--- uname ---"
	echo "$DEVICE_UNAME"
	echo "--- os-release (head) ---"
	echo "$DEVICE_OS"
} >"$OUT_DIR/summary.txt"

rm -f "$LATEST_LINK"
ln -s "lynis-$STAMP" "$LATEST_LINK"

cleanup_remote
trap - EXIT

echo "Artifacts: $OUT_DIR"
echo "  lynis-console.txt   Lynis terminal report (same as above)"
echo "  lynis-report.dat    machine-readable"
echo "  lynis.log           full log"

if want_strict && [[ "$WARN_COUNT" -gt 0 ]]; then
	die "STRICT=1: Lynis reported $WARN_COUNT warning(s); see $CONSOLE_TXT"
fi

exit 0
