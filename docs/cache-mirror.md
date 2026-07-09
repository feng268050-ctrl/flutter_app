# Team cache mirror (NAS / HTTP)

Large build inputs live under `.cache/` and are **not** in git. Use a shared NAS (or HTTP static directory) so the team can copy multi‑GB artifacts instead of re-downloading from the internet.

## Layout

Mirror root (`LWS_HMI_CACHE_ROOT` or `LWS_HMI_CACHE_URL`):

```
lws-hmi-cache/
└── flutter-engine/
    └── <version>/                    # overlay/buildroot/flutter-engine.version
        ├── flutter-<version>.tar.gz
        └── flutter-<version>.tar.gz.sha256
```

Future categories can follow the same pattern, e.g.:

```
opencv/<ver>/opencv-<ver>.tar.gz
flutter-sdk/<ver>/flutter_linux_<ver>-stable.tar.xz
```

Version pins in the repo must match the directory name.

## Configuration (`.env`)

```bash
# SMB/NFS mount on the developer machine (recommended)
LWS_HMI_CACHE_ROOT=/Volumes/nas/lws-hmi-cache

# Optional HTTP mirror of the same tree (works inside Docker without mounting NAS)
# LWS_HMI_CACHE_URL=https://nas.example.com/lws-hmi-cache

# After a successful gclient download, copy tarball + sha256 to NAS (default: 1)
LWS_HMI_CACHE_PUBLISH=1
```

Docker (`make shell`, `build-*` on macOS) mounts `LWS_HMI_CACHE_ROOT` into the container when the path exists.

## Commands

| Command | Role |
|---------|------|
| `make fetch-flutter-engine` | Local `.cache/` → NAS/HTTP → gclient |
| `make refetch-flutter-engine` | Force re-download |
| `make cache-publish-flutter-engine` | Upload existing tarball to NAS |
| `make build-flutter-engine` | Compile only (requires tarball in `.cache/`) |

## Workflows

**First machine (fills NAS):**

```bash
make fetch-flutter-engine          # downloads via gclient, auto-publishes if ROOT writable
# or, if tarball already in .cache/:
make cache-publish-flutter-engine
```

**Other machines:**

```bash
# .env: LWS_HMI_CACHE_ROOT=...
make fetch-flutter-engine          # copies from NAS in seconds
make build-flutter-engine
```

**HTTP-only (no NAS mount):**

```bash
# .env: LWS_HMI_CACHE_URL=https://...
make fetch-flutter-engine          # curl from HTTP inside Docker
```

## NAS setup suggestions

1. Create a dedicated share, e.g. `//nas/lws-hmi-cache` or `/volume1/lws-hmi-cache`.
2. Give the team read/write; CI/build bots read-only is enough for consumers.
3. Optionally expose the same tree via nginx/WebDAV for `LWS_HMI_CACHE_URL`.
4. Do **not** put this directory in the git repo; only small compiled `prebuilt/` outputs belong in git.

## Implementation

- `scripts/cache-mirror.sh` — fetch/publish helpers
- `scripts/fetch-flutter-engine.sh` — uses mirror before gclient
