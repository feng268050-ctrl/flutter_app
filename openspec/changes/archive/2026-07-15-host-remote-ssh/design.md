## Context

USB plug-ssh starts a dedicated `sshd` with `ListenAddress=192.168.55.1` and a private PidFile. A global drop-in currently hard-codes the same `ListenAddress`, so `systemctl start sshd` cannot serve eth0/wlan0. Host `make connect` expects an IP reachable on the LAN. P2.1 already ships eth0/wlan0 demos; LAN sshd was planned for P5 §7.7 and is pulled forward.

## Goals / Non-Goals

**Goals:**

- On-demand LAN/WLAN sshd (`root` / `rockchip`), default off, not in `multi-user.target.wants`.
- Demo toggle after HTTP / Proxy.
- Coexist with USB plug-ssh (cable + LAN both usable when possible).
- Host connect/disconnect/select (already done) documented against this on-device path.
- Plan + OpenSpec updated for P2.1 ownership.

**Non-Goals:**

- Boot-time always-on LAN sshd or production “open port 22”.
- Flutter product settings / secret 5-tap UI (still P5); Demo toggle is the P2.1 entry.
- `make reboot-loader` over LAN SSH.

## Decisions

### 1. Dedicated LAN sshd via systemd unit (outside hmi cgroup)

**Choice:** `ssh-debug-lan.service` with **`Type=simple`** and **`lan-ssh-run.sh` → `sshd -D`**. Listen addresses are **eth0/wlan0 global IPv4 only** (never `0.0.0.0`, never `192.168.55.1`). USB plug-ssh keeps its own sshd on `192.168.55.1`. No `[Install]` / not in `multi-user.target.wants`.

**Rationale:** Demo UI starts LAN SSH via Flutter `Process.run`, so sshd must live in a unit outside `hmi.service`'s cgroup. Binding only LAN IPs lets USB-SSH keep port 22 on the ECM address at the same time (two ListenAddress IPs, two sshd processes).

### 2. Split sshd_config.d

**Choice:** Global drop-in keeps `PasswordAuthentication` / `PermitRootLogin` only. USB bind address remains CLI `-o ListenAddress=192.168.55.1` in `usb-plug-ssh-start.sh` (already present).

**Rationale:** Removes the accidental “any sshd is usb-only” trap.

### 3. USB + LAN coexistence

**Choice:** Two sshd processes — LAN on eth0/wlan0 IPs only; USB always starts usb0-only sshd on `192.168.55.1`. Enabling LAN MUST NOT stop USB sshd. On LAN disable, if usb0 is still up and USB sshd is down, restart USB plug-ssh.

### 3b. Wi-Fi outside hmi cgroup

**Choice:** `wifi-stack-up.sh` starts **`wlan-wpa.service`**; DHCP uses **`wlan-dhcp.service`**. Neither is in `multi-user.target.wants`.

**Rationale:** Demo `Process.run` previously left `wpa_supplicant`/`dhcpcd` in `hmi.service`'s cgroup; `make push-app` → `systemctl stop hmi` killed Wi-Fi and dropped LAN SSH. Same class of bug as LAN sshd before `ssh-debug-lan.service`.

### 4. Demo toggle

**Choice:** `SshDebugController` → enable/disable/status scripts; section immediately after `HttpDemoSection`.

## Risks / Trade-offs

- **[Risk] Port 22 on LAN while debug on** → Acceptable for lab; eth0/wlan0 only; default off.
- **[Risk] No LAN IPv4 when enabling** → `lan-ssh-run.sh` exits; Demo/script surfaces error (bring up eth/wlan first).

## Migration Plan

- Host-only pieces already usable once LAN script + flash land.
- Rebuild rootfs + app for toggle.

## Open Questions

- None blocking.
