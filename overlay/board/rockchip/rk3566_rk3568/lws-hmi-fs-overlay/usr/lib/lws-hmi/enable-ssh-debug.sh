#!/bin/sh
# Prod §7.7: on-demand sshd (hidden UI gesture / POST /v1/ssh). Not auto-started at boot.
set -eu
if command -v systemctl >/dev/null 2>&1; then
  systemctl start sshd.service 2>/dev/null || systemctl start sshd 2>/dev/null || true
fi
echo "enable-ssh-debug: sshd start requested"
