import 'package:cyber_hal/sys_info.dart';

export 'package:cyber_hal/sys_info.dart'
    show PlatformVersionsSnapshot, LinuxPlatformVersions;

/// Logical section for the Operating System inventory page.
final class PlatformVersionSection {
  const PlatformVersionSection({
    required this.titleKey,
    required this.rows,
  });

  /// ARB key passed to [AppLocalizations] (e.g. `osPlatformSection`).
  final String titleKey;
  final List<(String labelKey, String? Function(PlatformVersionsSnapshot) value)> rows;
}

/// Grouped inventory rows (soft-fail values → null → em dash in UI).
List<PlatformVersionSection> platformVersionSections(
  PlatformVersionsSnapshot snap,
) {
  return [
    PlatformVersionSection(
      titleKey: 'osPlatformSection',
      rows: [
        ('operatingSystemLabel', (s) => s.operatingSystem),
        ('linuxKernelLabel', (s) => s.kernelRelease),
        ('buildrootLabel', (s) => s.buildrootVersion),
        ('flutterLabel', (s) => s.flutterVersion),
      ],
    ),
    PlatformVersionSection(
      titleKey: 'osSecuritySection',
      rows: [
        ('opensslLabel', (s) => s.opensslVersion),
        ('opensshLabel', (s) => s.opensshVersion),
        ('selinuxLabel', (s) => s.selinuxMode),
      ],
    ),
    PlatformVersionSection(
      titleKey: 'osRuntimeSection',
      rows: [
        ('busyboxLabel', (s) => s.busyboxVersion),
        ('glibcLabel', (s) => s.glibcVersion),
        ('gstreamerLabel', (s) => s.gstreamerVersion),
      ],
    ),
    PlatformVersionSection(
      titleKey: 'osConnectivitySection',
      rows: [
        ('wpaSupplicantLabel', (s) => s.wpaSupplicantVersion),
        ('bluezLabel', (s) => s.bluezVersion),
      ],
    ),
  ];
}

/// Legacy flat list (tests / callers).
List<(String, String?)> platformVersionRows(PlatformVersionsSnapshot snap) {
  final out = <(String, String?)>[];
  for (final section in platformVersionSections(snap)) {
    for (final row in section.rows) {
      out.add((row.$1, row.$2(snap)));
    }
  }
  return out;
}
