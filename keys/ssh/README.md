# Team SSH host key (USB-SSH / LAN SSH debug)

Product rootfs ships `/root/.ssh/authorized_keys` from this directory’s **`id_ed25519.pub`**.

| File | In git | Role |
|------|--------|------|
| `id_ed25519.pub` | yes | Baked into rootfs; source for overlay sync |
| `id_ed25519` | **no** (gitignored) | Host `make push-app` / `upgrade` / `shell` identity |

Algorithm: **Ed25519** (same family as OTA / cloud signing keys elsewhere in the repo).

## First time / new developer

1. Obtain `id_ed25519` from the team (internal distribution only — not per device).
2. Place at `keys/ssh/id_ed25519` (`chmod 600`).
3. Or regenerate team key (coordination required): `make ssh-keys` then reflash / rewrite device `authorized_keys`.

## Regenerate (breaks existing SSH until rootfs refresh)

```bash
FORCE=1 make ssh-keys
make apply-overlay
make build-rootfs
make upgrade
```

## Lost key on a board

No USB-SSH recovery path. Use **TTL serial console** → login as `root` (console password unchanged) → edit `/root/.ssh/authorized_keys`.

SSH is **public-key only** (`PasswordAuthentication no`); console login still uses the Buildroot root password.
