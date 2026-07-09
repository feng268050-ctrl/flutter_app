#!/bin/sh
# Hidden debug entry — start sshd (P5 / §7.7).
set -eu
if command -v systemctl >/dev/null 2>&1; then
  systemctl start sshd.service 2>/dev/null || systemctl start sshd 2>/dev/null || true
fi
echo "enable-ssh-debug: sshd start requested"
