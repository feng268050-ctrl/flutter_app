# Shared host helpers for make screenshot / record-screen.
# Requires: CMD_PATH, STATUS_PATH, remote(), die() already defined by caller.
# shellcheck shell=bash

capture_host_mkdir() {
	remote "mkdir -p /run/hmi /var/lib/hmi/capture"
}

# Print first status line and seq= (default 0). Sets CAPTURE_HOST_STATUS / CAPTURE_HOST_SEQ.
capture_host_read_status() {
	local raw st seq
	raw="$(remote "cat '${STATUS_PATH}' 2>/dev/null || true" || true)"
	st="$(printf '%s\n' "$raw" | head -1 | tr -d '\r')"
	seq="$(printf '%s\n' "$raw" | grep -E '^seq=' | head -1 | cut -d= -f2- | tr -d '\r' || true)"
	[[ "$seq" =~ ^[0-9]+$ ]] || seq=0
	CAPTURE_HOST_STATUS="$st"
	CAPTURE_HOST_SEQ="$seq"
}

# One SSH session polls on-device (50ms) until status matches want*.
# Completes when:
#   - status is error:*, or
#   - status matches want* AND (seq > min_seq  OR  status changed since wait started)
# The status-change gate works with older libhmi_capture.so that never writes seq=.
# Args: want_prefix min_seq wait_sec
# Sets CAPTURE_HOST_STATUS to the final status line (or error:*).
capture_host_wait_status() {
	local want="$1" min_seq="$2" wait_sec="$3"
	local out line st
	echo "waiting for capture status~${want} (seq>${min_seq} or status-change, up to ${wait_sec}s)…" >&2
	# Remote loop avoids hundreds of SSH round-trips (main cause of "stuck" host).
	out="$(
		remote "STATUS='${STATUS_PATH}'; WANT='${want}'; MIN_SEQ='${min_seq}'; WAIT='${wait_sec}'; \
first_st=''; seen_change=0; last=''; deadline=\$((SECONDS + WAIT)); \
while [ \"\$SECONDS\" -lt \"\$deadline\" ]; do \
  if [ -f \"\$STATUS\" ]; then \
    st=\$(head -1 \"\$STATUS\" | tr -d '\\r'); \
    seq=\$(grep -E '^seq=' \"\$STATUS\" 2>/dev/null | head -1 | cut -d= -f2- | tr -d '\\r'); \
    case \"\$seq\" in ''|*[!0-9]*) seq=0 ;; esac; \
    if [ -z \"\$first_st\" ]; then first_st=\"\$st\"; \
    elif [ \"\$st\" != \"\$first_st\" ]; then seen_change=1; fi; \
    if [ \"\$st\" != \"\$last\" ]; then \
      echo \"PROGRESS:\$st seq=\$seq change=\$seen_change\"; \
      last=\"\$st\"; \
    fi; \
    case \"\$st\" in \
      error:*) echo \"RESULT:\$st\"; exit 0 ;; \
    esac; \
    case \"\$st\" in \
      \$WANT*) \
        if [ \"\$seq\" -gt \"\$MIN_SEQ\" ] || [ \"\$seen_change\" -eq 1 ]; then \
          echo \"RESULT:\$st\"; exit 0; \
        fi ;; \
    esac; \
  fi; \
  sleep 0.05; \
done; \
echo \"RESULT:timeout:\${last:-empty}\"; exit 1"
	)" || true

	st=""
	while IFS= read -r line; do
		case "$line" in
		PROGRESS:*)
			echo "  ${line#PROGRESS:}" >&2
			;;
		RESULT:*)
			st="${line#RESULT:}"
			;;
		esac
	done <<<"$out"

	if [[ -z "$st" ]]; then
		die "capture wait failed (no result from device)"
	fi
	if [[ "$st" == timeout:* ]]; then
		die "timeout waiting for status~${want} (last: ${st#timeout:}). Is HMI or OS Settings running with cyber_capture?"
	fi
	CAPTURE_HOST_STATUS="$st"
	printf '%s\n' "$st"
}

capture_host_write_cmd() {
	local line="$1"
	remote "mkdir -p /run/hmi /var/lib/hmi/capture && printf '%s\n' '${line}' > '${CMD_PATH}.tmp' && mv -f '${CMD_PATH}.tmp' '${CMD_PATH}'"
}

# If a previous record/screenshot left the device busy, stop it so the next
# arm can enter idle. Fixes: status already "recording" → new record-start
# returns rc=-1 and host wait never sees a status change.
capture_host_preflight_clear() {
	local wait_sec="${1:-20}"
	local st
	capture_host_read_status
	st="${CAPTURE_HOST_STATUS:-}"
	case "$st" in
	recording|stopping|armed|encoding)
		echo "preflight: clearing leftover capture status=${st}" >&2
		capture_host_write_cmd "record-stop"
		capture_host_wait_status done 0 "$wait_sec" >/dev/null
		# Drop leftover staging so the next pull does not grab an old file.
		remote "rm -rf /var/lib/hmi/capture/rec-* /var/lib/hmi/capture/shot-* 2>/dev/null || true" || true
		;;
	esac
}
