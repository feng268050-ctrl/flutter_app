# Team NAS cache

Large build inputs live under `.cache/` and are **not** in git. Mount a shared NAS so the team can copy multi‑GB artifacts instead of re-downloading from the internet.

## Layout

Mirror root (`NAS_CACHE_ROOT`):

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
# SMB/NFS mount on the developer machine
NAS_CACHE_ROOT=/Volumes/nas/lws-hmi-cache

# 1 = never write back to NAS (CI / read-only mount); default 0 = publish after fetch
# NAS_READ_ONLY=0
```

Docker (`make sdk-shell`, `build-*` on macOS) mounts `NAS_CACHE_ROOT` into the container when the path exists.

## Commands

| Command | Role |
|---------|------|
| `make fetch-flutter-engine` | Local `.cache/` → NAS → gclient |
| `make refetch-flutter-engine` | Force re-download |
| `make cache-publish-flutter-engine` | Upload existing tarball to NAS (always writes) |
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
# .env: NAS_CACHE_ROOT=...
make fetch-flutter-engine          # copies from NAS in seconds
make build-flutter-engine
```

## NAS setup suggestions

1. Create a dedicated share, e.g. `//nas/lws-hmi-cache` or `/volume1/lws-hmi-cache`.
2. Give the team read/write; CI/build bots can use `NAS_READ_ONLY=1`.
3. Do **not** put this directory in the git repo; only small compiled `prebuilt/` outputs belong in git.

## Implementation

- `scripts/cache-mirror.sh` — fetch/publish helpers (NAS mount only)
- `scripts/fetch-flutter-engine.sh` — uses mirror before gclient
