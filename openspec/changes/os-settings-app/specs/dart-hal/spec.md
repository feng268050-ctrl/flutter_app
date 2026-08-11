## ADDED Requirements

### Requirement: Platform version and SELinux probes for Settings

The HAL SHALL expose read-only platform inventory fields usable by the Settings Operating System page, including at least: `/etc/os-release` name/version summary; Linux kernel release (existing); SELinux mode as `Disabled` \| `Permissive` \| `Enforcing` (or unavailable); BusyBox version; Glibc version; WPA Supplicant version; BlueZ version; OpenSSL version; OpenSSH version; GStreamer version; Flutter engine/SDK pin string consistent with the image; Buildroot version stamp when baked. Each probe MUST soft-fail independently (null/unavailable) without failing the whole `SysInfo` / platform-versions snapshot. Apps MUST NOT be required to shell out from the UI isolate for these strings when HAL provides them.

#### Scenario: Soft-fail missing BusyBox

- **WHEN** BusyBox is absent or its version string cannot be parsed
- **THEN** the platform-versions snapshot reports that field unavailable and still returns other fields

#### Scenario: SELinux modes

- **WHEN** `/sys/fs/selinux/enforce` reports `0` or `1`, or SELinux is not mounted
- **THEN** the snapshot maps to Permissive, Enforcing, or Disabled/unavailable respectively

### Requirement: Secrets backend status is queryable for Settings Storage

Callers SHALL be able to read the active Secrets / KEK backend identifier as `software` or `op-tee` (and hardware-bound flag when already exposed) without performing seal/unseal, for Settings Storage display. This MUST reuse the existing Secrets provider / OEM `secrets_backend` selection and MUST NOT silently switch backends on query failure.

#### Scenario: Query software backend

- **WHEN** the active Secrets backend is software
- **THEN** a status query reports `software` (or equivalent identifier) without sealing data
