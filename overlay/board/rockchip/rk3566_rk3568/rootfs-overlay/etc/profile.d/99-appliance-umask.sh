# Lynis AUTH-9328 / SHLL-6230: prefer 027 over Buildroot default 022 in profile.d/umask.sh.
# Interactive shells only; systemd services do not source this.
umask 027
