# AVC sample — enable-selinux bring-up (2026-08-10)

Device: L1SZ2026070001 after `make upgrade` (kernel #111 + rootfs_b).
Mode: Permissive (`getenforce` / `sestatus`).

## Boot

- `SELinux: Initializing.`
- `systemd[1]: Successfully loaded SELinux policy in ~119ms`
- systemd built with `+SELINUX`

## Sample denials (permissive=1)

From first boot `dmesg` (truncated):

```
avc:  denied  { getattr } for  pid=177 comm="systemd-ssh-gen" path="/usr/sbin/sshd"
  scontext=system_u:system_r:systemd_generator_t tcontext=system_u:object_r:sshd_exec_t tclass=file

avc:  denied  { execute } for  pid=177 comm="systemd-ssh-gen" name="sshd"
  scontext=system_u:system_r:systemd_generator_t tcontext=system_u:object_r:sshd_exec_t tclass=file

avc:  denied  { search } for  pid=190 comm="systemd-journal" name="/"
  scontext=system_u:system_r:syslogd_t tcontext=system_u:object_r:ramfs_t tclass=dir
```

Feed these (plus soak under HMI / MediaMTX / AI) into a follow-up
`selinux-product-policy` change before considering Enforcing.

Do **not** `setenforce 1` on this image.
