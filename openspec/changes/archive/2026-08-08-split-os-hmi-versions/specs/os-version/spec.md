## ADDED Requirements

### Requirement: Rootfs stamps product OS Version in os-release

The product image SHALL identify itself as a Cyber OS distribution via **`/etc/os-release`** with at least:

- `NAME="Cyber OS"`
- `ID=cyberos`
- `ID_LIKE="buildroot"`
- `VERSION="<semver>"` (full SemVer, e.g. `1.0.0`) — product OS Version used for Settings and whole-device OTA
- `VERSION_ID=<major>.<minor>` (e.g. `1.0` for `1.0.0`)
- `PRETTY_NAME="Cyber OS <semver>"`

The initial OS Version SHALL be **`1.0.0`** (`VERSION_ID=1.0`). The stamp MUST be readable on-device without the Flutter app. The Flutter HMI `pubspec.yaml` MUST NOT be used as the OS Version source.

#### Scenario: Fresh image has Cyber OS 1.0.0

- **WHEN** an operator inspects `/etc/os-release` on a rootfs built after this change with no further bumps
- **THEN** `NAME` is `Cyber OS`, `ID` is `cyberos`, `VERSION` is `1.0.0`, and `VERSION_ID` is `1.0`

#### Scenario: OS stamp independent of HMI pubspec

- **WHEN** the Flutter HMI pubspec version is `1.0.41` and `/etc/os-release` `VERSION` is `1.0.0`
- **THEN** both values MAY coexist; reading OS Version MUST NOT return `1.0.41`

### Requirement: Device software can read OS Version

The HAL and/or product App SHALL expose the running **OS Version** string from `/etc/os-release` **`VERSION=`** for Settings, identity payloads that need an OS field, and whole-device OTA version compare. Missing or unreadable stamp MUST surface as unavailable (`-` in UI) rather than silently substituting the HMI app version.

#### Scenario: SysInfo or App reads VERSION

- **WHEN** `/etc/os-release` contains `VERSION="1.2.3"`
- **THEN** the App/HAL OS Version API returns `1.2.3`

#### Scenario: Missing stamp does not fake HMI version

- **WHEN** `/etc/os-release` is absent or has no usable `VERSION=`
- **THEN** OS Version consumers MUST NOT fall back to `kHmiVersion` / pubspec as if it were the OS Version
