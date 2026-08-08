/// Product **HMI Version** (Flutter app `versionName`).
///
/// Keep in sync with `pubspec.yaml` `version:` (name+build).
/// Build number is 5 digits: major*10000 + minor*100 + patch (1.0.40 → 10040).
/// OS Version is stamped in rootfs `/etc/os-release` (`VERSION=` / Cyber OS).
const String kHmiVersion = '1.0.41';

/// HMI build number (`versionCode` / pubspec `+N`).
const int kHmiVersionCode = 10041;
