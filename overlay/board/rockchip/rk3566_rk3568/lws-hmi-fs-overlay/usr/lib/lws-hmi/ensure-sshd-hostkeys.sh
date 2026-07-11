#!/bin/sh
# Ensure OpenSSH host keys exist (Buildroot image has sshd disabled at boot — keys may be missing).
set -eu

TARGET_DIR="${1:-}"

if [ -n "$TARGET_DIR" ]; then
	SSH_DIR="${TARGET_DIR}/etc/ssh"
else
	SSH_DIR=/etc/ssh
fi

mkdir -p "$SSH_DIR"
chmod 755 "$SSH_DIR" 2>/dev/null || true

if ls "$SSH_DIR"/ssh_host_*_key >/dev/null 2>&1; then
	exit 0
fi

find_keygen() {
	if command -v ssh-keygen >/dev/null 2>&1; then
		command -v ssh-keygen
		return 0
	fi
	if [ -n "$TARGET_DIR" ]; then
		local br_root="${TARGET_DIR%%/build/*}"
		if [ -x "$br_root/host/bin/ssh-keygen" ]; then
			echo "$br_root/host/bin/ssh-keygen"
			return 0
		fi
	fi
	if [ -x /usr/bin/ssh-keygen ]; then
		echo /usr/bin/ssh-keygen
		return 0
	fi
	return 1
}

find_openssl() {
	if command -v openssl >/dev/null 2>&1; then
		command -v openssl
		return 0
	fi
	if [ -x /usr/bin/openssl ]; then
		echo /usr/bin/openssl
		return 0
	fi
	return 1
}

generate_with_keygen() {
	local keygen="$1"
	if [ -z "$TARGET_DIR" ] && "$keygen" -A >/dev/null 2>&1; then
		return 0
	fi
	"$keygen" -t ed25519 -f "$SSH_DIR/ssh_host_ed25519_key" -N "" -q
	"$keygen" -t rsa -f "$SSH_DIR/ssh_host_rsa_key" -N "" -q
}

generate_with_openssl() {
	local openssl="$1"
	if [ ! -f "$SSH_DIR/ssh_host_rsa_key" ]; then
		"$openssl" genrsa -out "$SSH_DIR/ssh_host_rsa_key" 3072
		chmod 600 "$SSH_DIR/ssh_host_rsa_key"
	fi
	if [ ! -f "$SSH_DIR/ssh_host_ed25519_key" ]; then
		"$openssl" genpkey -algorithm ED25519 -out "$SSH_DIR/ssh_host_ed25519_key"
		chmod 600 "$SSH_DIR/ssh_host_ed25519_key"
	fi
}

if KEYGEN="$(find_keygen)"; then
	generate_with_keygen "$KEYGEN"
elif OPENSSL="$(find_openssl)"; then
	generate_with_openssl "$OPENSSL"
else
	echo "ensure-sshd-hostkeys: need ssh-keygen or openssl (TARGET_DIR=${TARGET_DIR:-live})" >&2
	exit 1
fi

if ! ls "$SSH_DIR"/ssh_host_*_key >/dev/null 2>&1; then
	echo "ensure-sshd-hostkeys: no keys created under $SSH_DIR" >&2
	exit 1
fi
