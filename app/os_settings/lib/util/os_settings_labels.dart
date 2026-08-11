import 'package:cyber_hal/network.dart';
import 'package:os_settings/l10n/app_localizations.dart';

String ethernetLinkPhaseLabel(AppLocalizations l10n, EthLinkPhase phase) {
  return switch (phase) {
    EthLinkPhase.up => l10n.ethLinkConnected,
    EthLinkPhase.down => l10n.ethLinkDisconnected,
    EthLinkPhase.noCarrier => l10n.ethLinkNoCarrier,
    EthLinkPhase.configuring => l10n.ethLinkConfiguring,
    EthLinkPhase.error => l10n.ethLinkError,
  };
}

String platformVersionLabel(AppLocalizations l10n, String labelKey) {
  return switch (labelKey) {
    'operatingSystemLabel' => l10n.operatingSystemLabel,
    'linuxKernelLabel' => l10n.linuxKernelLabel,
    'selinuxLabel' => l10n.selinuxLabel,
    'busyboxLabel' => l10n.busyboxLabel,
    'glibcLabel' => l10n.glibcLabel,
    'wpaSupplicantLabel' => l10n.wpaSupplicantLabel,
    'bluezLabel' => l10n.bluezLabel,
    'opensslLabel' => l10n.opensslLabel,
    'opensshLabel' => l10n.opensshLabel,
    'gstreamerLabel' => l10n.gstreamerLabel,
    'flutterLabel' => l10n.flutterLabel,
    'buildrootLabel' => l10n.buildrootLabel,
    _ => labelKey,
  };
}

String platformVersionSectionTitle(AppLocalizations l10n, String titleKey) {
  return switch (titleKey) {
    'osPlatformSection' => l10n.osPlatformSection,
    'osSecuritySection' => l10n.osSecuritySection,
    'osRuntimeSection' => l10n.osRuntimeSection,
    'osConnectivitySection' => l10n.osConnectivitySection,
    _ => titleKey,
  };
}
