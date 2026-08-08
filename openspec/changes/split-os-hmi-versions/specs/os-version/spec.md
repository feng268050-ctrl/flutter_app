## ADDED Requirements

### Requirement: Rootfs stamps product OS Version

The product image SHALL include a single-line SemVer **OS Version** stamp in rootfs (repo SoT under `board/` or overlay, baked by `apply-overlay` / `build-rootfs`). The initial OS Version SHALL be **`1.0.0`**. The stamp MUST be readable on-device without the Flutter app (shell/`cat`). The stamp MUST NOT be derived from the Flutter HMI `pubspec.yaml`.

#### Scenario: Fresh image has OS 1.0.0

- **WHEN** an operator inspects the OS Version stamp on a rootfs built after this change with no further bumps
- **THEN** the file content is `1.0.0` (optional trailing newline only)

#### Scenario: OS stamp independent of HMI pubspec

- **WHEN** the Flutter HMI pubspec version is `1.0.41` and the OS stamp is `1.0.0`
- **THEN** both values MAY coexist; reading the OS stamp MUST NOT return `1.0.41`

### Requirement: Device software can read OS Version

The HAL and/or product App SHALL expose the running **OS Version** string from the rootfs stamp for Settings, QR/identity payloads that need an OS field, and whole-device OTA version compare. Missing or unreadable stamp MUST surface as unavailable (`-` in UI) rather than silently substituting the HMI app version.

#### Scenario: SysInfo or App reads stamp

- **WHEN** the OS Version stamp file exists and contains `1.2.3`
- **THEN** the App/HAL OS Version API returns `1.2.3`

#### Scenario: Missing stamp does not fake HMI version

- **WHEN** the OS Version stamp is absent
- **THEN** OS Version consumers MUST NOT fall back to `kHmiVersion` / pubspec as if it were the OS Version
